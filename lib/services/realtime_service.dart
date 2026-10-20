import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart' show WidgetsBinding, WidgetsBindingObserver, AppLifecycleState;
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/api_config.dart';

/// État de la liaison temps réel avec le backend.
enum RealtimeStatus {
  /// Aucune tentative en cours (déconnecté volontairement ou jamais connecté).
  disconnected,

  /// Tentative de connexion / reconnexion en cours.
  connecting,

  /// Socket authentifié : la présence de l'utilisateur est active côté backend.
  connected,

  /// Échec de connexion (réseau, serveur, token refusé).
  error,
}

/// Présence d'un utilisateur **telle que la connaît le backend**.
///
/// Trois états distincts, volontairement :
///   • [PresenceState.online]  — session Socket.IO active côté backend ;
///   • [PresenceState.offline] — le backend répond « présent mais déconnecté » ;
///   • [PresenceState.unknown] — **aucune réponse exploitable** (socket coupé,
///     requête expirée, backend injoignable). Ce n'est PAS « hors ligne ».
///
/// La connectivité Internet du téléphone n'est JAMAIS une source de présence :
/// elle ne dit rien de l'état du destinataire ni de l'acceptation du serveur.
enum PresenceState { online, offline, unknown }

/// Information de présence associée à un utilisateur.
class PresenceInfo {
  final String uid;
  final PresenceState state;
  final DateTime? lastSeen;

  const PresenceInfo({
    required this.uid,
    required this.state,
    this.lastSeen,
  });

  const PresenceInfo.unknown(this.uid)
      : state = PresenceState.unknown,
        lastSeen = null;

  bool get isOnline => state == PresenceState.online;
  bool get isOffline => state == PresenceState.offline;
  bool get isUnknown => state == PresenceState.unknown;

  PresenceInfo copyWith({PresenceState? state, DateTime? lastSeen}) =>
      PresenceInfo(
        uid: uid,
        state: state ?? this.state,
        lastSeen: lastSeen ?? this.lastSeen,
      );

  @override
  bool operator ==(Object other) =>
      other is PresenceInfo &&
      other.uid == uid &&
      other.state == state &&
      other.lastSeen == lastSeen;

  @override
  int get hashCode => Object.hash(uid, state, lastSeen);

  @override
  String toString() => 'PresenceInfo($uid, ${state.name}, lastSeen: $lastSeen)';
}

/// Client Socket.IO du backend OmniSMS.
///
/// Pourquoi ce service existe : le routage des messages (`services/messageRouter.js`
/// côté backend) n'envoie un message **en interne** que si le destinataire
/// possède une session Socket.IO active ; sinon il bascule en SMS. Sans ce
/// socket, un utilisateur de l'APK est donc vu « hors ligne » en permanence et
/// tous les messages qui lui sont destinés partent en SMS — alors même qu'il
/// utilise l'application.
///
/// Ce service ne remplace pas l'architecture existante : il branche simplement
/// l'APK sur le mécanisme temps réel déjà utilisé par le backend et la PWA
/// (mêmes événements, même authentification JWT). Le polling déjà en place
/// reste actif : il sert de filet de sécurité si le socket est indisponible.
///
/// Contrat backend (`services/socketService.js`) :
///   • authentification : `auth: { token }` (JWT OmniSMS) — jamais de secret OAuth ;
///   • client → serveur : `heartbeat`, `user:check-online`, `conversation:join`,
///     `conversation:leave`, `typing:start`, `typing:stop`, `message:read` ;
///   • serveur → client : `message:receive`, `new_message`, `user:online`,
///     `user:offline`, `heartbeat:ack`.
/// Source de présence temps réel.
///
/// Interface extraite pour pouvoir tester [PresenceService] sans socket
/// (aucune donnée simulée dans le code de production : les tests fournissent
/// leur propre source).
abstract class PresenceSource {
  RealtimeStatus get status;

  Stream<RealtimeStatus> get statusStream;

  Stream<PresenceInfo> get presenceStream;

  Future<PresenceInfo> checkPresence(String uid, {Duration timeout});
}

class RealtimeService with WidgetsBindingObserver implements PresenceSource {
  RealtimeService._();

  static final RealtimeService instance = RealtimeService._();

  /// Intervalle du heartbeat : le backend expire une présence au bout de
  /// 5 minutes (ONLINE_TTL), on la renouvelle très largement avant.
  static const Duration heartbeatInterval = Duration(seconds: 60);

  /// Délai d'attente d'une réponse de présence.
  static const Duration presenceTimeout = Duration(seconds: 6);

  io.Socket? _socket;
  String? _token;
  String? _uid;
  bool _closedByUser = false;
  bool _observerRegistered = false;
  Timer? _heartbeatTimer;

  RealtimeStatus _status = RealtimeStatus.disconnected;

  final StreamController<RealtimeStatus> _statusController =
      StreamController<RealtimeStatus>.broadcast();
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<PresenceInfo> _presenceController =
      StreamController<PresenceInfo>.broadcast();

  RealtimeStatus get status => _status;

  bool get isConnected => _status == RealtimeStatus.connected;

  /// `true` tant qu'un utilisateur est authentifié et qu'on doit maintenir
  /// la session (même si le socket est momentanément tombé).
  bool get hasSession => _token != null && _uid != null && !_closedByUser;

  Stream<RealtimeStatus> get statusStream => _statusController.stream;

  /// Messages entrants temps réel (`message:receive` / `new_message`).
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  /// Présence diffusée par le backend (`user:online` / `user:offline`).
  Stream<PresenceInfo> get presenceStream => _presenceController.stream;

  void _setStatus(RealtimeStatus status) {
    if (_status == status) return;
    _status = status;
    if (!_statusController.isClosed) _statusController.add(status);
  }

  /// Ouvre la session temps réel (idempotent).
  ///
  /// [token] : JWT OmniSMS (le même que celui des appels HTTP).
  /// [uid]   : identifiant de l'utilisateur connecté (room `user:{uid}`).
  Future<void> connect({required String token, required String uid}) async {
    if (token.isEmpty || uid.isEmpty) return;

    final credentialsChanged = token != _token || uid != _uid;
    _token = token;
    _uid = uid;
    _closedByUser = false;

    if (!_observerRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _observerRegistered = true;
    }

    if (_socket != null && !credentialsChanged) {
      if (!(_socket?.connected ?? false)) _socket?.connect();
      return;
    }

    await _teardownSocket();

    _setStatus(RealtimeStatus.connecting);
    debugPrint('[Realtime] connexion à ${ApiConfig.baseUrl} (uid: $uid)');

    try {
      _socket = io.io(
        ApiConfig.baseUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .setAuth({'token': token})
            .setExtraHeaders({'Authorization': 'Bearer $token'})
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(10000)
            .setReconnectionAttempts(999999)
            .setTimeout(20000)
            .build(),
      );
    } catch (e) {
      debugPrint('[Realtime] initialisation impossible: $e');
      _setStatus(RealtimeStatus.error);
      return;
    }

    final socket = _socket!;

    socket.onConnect((_) {
      debugPrint('[Realtime] connecté (socket: ${socket.id})');
      _setStatus(RealtimeStatus.connected);
      _startHeartbeat();
      _emitHeartbeat();
    });

    socket.onDisconnect((_) {
      debugPrint('[Realtime] déconnecté');
      _stopHeartbeat();
      _setStatus(_closedByUser
          ? RealtimeStatus.disconnected
          : RealtimeStatus.connecting);
    });

    socket.onConnectError((data) {
      // Jamais de détail technique remonté à l'utilisateur : la présence
      // devient simplement « inconnue ».
      debugPrint('[Realtime] erreur de connexion: $data');
      _setStatus(RealtimeStatus.error);
    });

    socket.onError((data) => debugPrint('[Realtime] erreur socket: $data'));

    socket.on('message:receive', (data) => _onInbound(data));
    socket.on('new_message', (data) => _onInbound(data));

    socket.on('user:online', (data) => _onPresenceEvent(data, online: true));
    socket.on('user:offline', (data) => _onPresenceEvent(data, online: false));
  }

  /// Ferme la session temps réel (déconnexion, changement de compte).
  void disconnect() {
    _closedByUser = true;
    _token = null;
    _uid = null;
    _stopHeartbeat();
    _teardownSocket();
    _setStatus(RealtimeStatus.disconnected);
  }

  Future<void> _teardownSocket() async {
    final socket = _socket;
    _socket = null;
    if (socket == null) return;
    try {
      socket.off('message:receive');
      socket.off('new_message');
      socket.off('user:online');
      socket.off('user:offline');
      socket.dispose();
    } catch (e) {
      debugPrint('[Realtime] erreur fermeture: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer =
        Timer.periodic(heartbeatInterval, (_) => _emitHeartbeat());
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _emitHeartbeat() {
    if (!isConnected) return;
    try {
      _socket?.emit('heartbeat');
    } catch (e) {
      debugPrint('[Realtime] heartbeat impossible: $e');
    }
  }

  void _onInbound(dynamic data) {
    if (data == null) return;
    if (data is Map) {
      if (!_messageController.isClosed) {
        _messageController.add(Map<String, dynamic>.from(data));
      }
      return;
    }
    // Le backend peut encapsuler le message ({ message: { … } }).
    if (data is List && data.isNotEmpty && data.first is Map) {
      if (!_messageController.isClosed) {
        _messageController.add(Map<String, dynamic>.from(data.first as Map));
      }
    }
  }

  void _onPresenceEvent(dynamic data, {required bool online}) {
    if (data is! Map) return;
    final uid = (data['uid'] ?? data['userId'] ?? '').toString();
    if (uid.isEmpty) return;
    final lastSeen = _parseDate(data['lastSeen'] ?? data['timestamp']);
    if (!_presenceController.isClosed) {
      _presenceController.add(PresenceInfo(
        uid: uid,
        state: online ? PresenceState.online : PresenceState.offline,
        lastSeen: lastSeen,
      ));
    }
  }

  /// Interroge la présence réelle d'un utilisateur auprès du backend.
  ///
  /// Retourne [PresenceState.unknown] si le socket n'est pas connecté ou si le
  /// backend ne répond pas dans [presenceTimeout] : une absence de réponse
  /// n'est PAS une preuve de déconnexion du destinataire.
  Future<PresenceInfo> checkPresence(
    String uid, {
    Duration timeout = presenceTimeout,
  }) async {
    if (uid.isEmpty) return PresenceInfo.unknown(uid);
    if (!isConnected) return PresenceInfo.unknown(uid);

    final socket = _socket;
    if (socket == null) return PresenceInfo.unknown(uid);

    final completer = Completer<Map<String, dynamic>>();
    try {
      socket.emitWithAck(
        'user:check-online',
        {'targetUid': uid},
        ack: (dynamic data) {
          if (completer.isCompleted) return;
          if (data is Map) {
            completer.complete(Map<String, dynamic>.from(data));
          } else {
            completer.complete(<String, dynamic>{});
          }
        },
      );
    } catch (e) {
      debugPrint('[Realtime] user:check-online impossible: $e');
      return PresenceInfo.unknown(uid);
    }

    Map<String, dynamic> answer;
    try {
      answer = await completer.future.timeout(
        timeout,
        onTimeout: () => <String, dynamic>{},
      );
    } on TimeoutException {
      return PresenceInfo.unknown(uid);
    } catch (e) {
      debugPrint('[Realtime] présence illisible: $e');
      return PresenceInfo.unknown(uid);
    }

    if (answer.isEmpty) return PresenceInfo.unknown(uid);

    final online = answer['online'];
    final lastSeen = _parseDate(answer['lastSeen']);
    if (online == null) return PresenceInfo.unknown(uid);
    final isOnline = online == true || online == 'true' || online == 1;
    return PresenceInfo(
      uid: uid,
      state: isOnline ? PresenceState.online : PresenceState.offline,
      lastSeen: lastSeen,
    );
  }

  void joinConversation(String conversationId) {
    if (conversationId.isEmpty || !isConnected) return;
    _socket?.emit('conversation:join', {'conversationId': conversationId});
  }

  void leaveConversation(String conversationId) {
    if (conversationId.isEmpty || !isConnected) return;
    _socket?.emit('conversation:leave', {'conversationId': conversationId});
  }

  void sendTyping(String receiverId, {required bool typing}) {
    if (receiverId.isEmpty || !isConnected) return;
    _socket?.emit(typing ? 'typing:start' : 'typing:stop', {
      'receiverId': receiverId,
    });
  }

  /// Met à jour le JWT sans provoquer de double session (refresh de token).
  Future<void> updateToken(String token) async {
    if (token.isEmpty || token == _token) return;
    final uid = _uid;
    if (uid == null) return;
    await connect(token: token, uid: uid);
  }

  // ── Cycle de vie ────────────────────────────────────────────
  // Un retour au premier plan doit rétablir la présence au plus vite : sans
  // cela l'utilisateur reste « hors ligne » pour le backend et reçoit des SMS
  // à la place des messages internes.

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!hasSession) return;
    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('[Realtime] reprise au premier plan → reconnexion');
        if (!(_socket?.connected ?? false)) {
          _setStatus(RealtimeStatus.connecting);
          try {
            _socket?.connect();
          } catch (e) {
            debugPrint('[Realtime] reconnexion impossible: $e');
          }
        } else {
          _emitHeartbeat();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        break;
    }
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final text = value.toString();
    if (text.isEmpty) return null;
    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed;
    final millis = int.tryParse(text);
    return millis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(millis);
  }
}
