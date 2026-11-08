import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';

import 'realtime_service.dart';

// Les types de présence vivent dans realtime_service (ils décrivent l'état
// renvoyé par le backend) : on les réexpose pour les consommateurs de
// PresenceService (IHM).
export 'realtime_service.dart'
    show PresenceInfo, PresenceSource, PresenceState, RealtimeService,
    RealtimeStatus;

/// Source unique de vérité de la **présence des destinataires**, côté IHM.
///
/// Règle fondatrice : la présence vient du backend (session Socket.IO), jamais
/// de la connectivité du téléphone. Un téléphone connecté à Internet ne dit
/// rien de l'état du destinataire ; un socket coupé ne prouve pas que le
/// destinataire est hors ligne : la présence devient alors « inconnue ».
///
/// Trois états exposés, jamais devinés :
///   • connecté  — le backend répond « session active » ;
///   • déconnecté — le backend répond « session absente » (avec lastSeen) ;
///   • inconnu   — aucune réponse exploitable (pas de socket, timeout, erreur).
class PresenceService extends ChangeNotifier {
  PresenceService({PresenceSource? realtime})
      : _realtime = realtime ?? RealtimeService.instance {
    _statusSubscription = _realtime.statusStream.listen(_onStatus);
    _presenceSubscription = _realtime.presenceStream.listen(_onPresenceEvent);
  }

  /// Fréquence de rafraîchissement des présences suivies.
  static const Duration refreshInterval = Duration(seconds: 45);

  final PresenceSource _realtime;
  final Map<String, PresenceInfo> _states = <String, PresenceInfo>{};
  final Set<String> _watched = <String>{};

  StreamSubscription<RealtimeStatus>? _statusSubscription;
  StreamSubscription<PresenceInfo>? _presenceSubscription;
  Timer? _refreshTimer;
  bool _disposed = false;

  /// Présence connue d'un utilisateur (jamais `null`).
  PresenceInfo stateOf(String uid) =>
      _states[uid] ?? PresenceInfo.unknown(uid);

  /// `true` tant qu'aucune information fiable n'a été obtenue.
  bool isUnknown(String uid) => stateOf(uid).isUnknown;

  RealtimeStatus get realtimeStatus => _realtime.status;

  /// Suit la présence d'un utilisateur (rafraîchie régulièrement).
  void watch(String uid) {
    if (uid.isEmpty) return;
    final isNew = _watched.add(uid);
    // En arrière-plan, on se contente d'enregistrer l'utilisateur : le
    // rafraîchissement reprendra au retour au premier plan.
    if (!_enPause) _startTimer();
    if (isNew || _states[uid] == null) {
      unawaitedRefresh(uid);
    }
  }

  void unwatch(String uid) {
    _watched.remove(uid);
    if (_watched.isEmpty) _stopTimer();
  }

  void _startTimer() {
    _refreshTimer ??= Timer.periodic(refreshInterval, (_) {
      for (final uid in _watched.toList()) {
        unawaitedRefresh(uid);
      }
    });
  }

  void _stopTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  void unawaitedRefresh(String uid) {
    // Volontairement non attendant : l'IHM affiche « inconnu » en attendant.
    refresh(uid).catchError((Object e) {
      debugPrint('[Presence] refresh($uid) impossible: $e');
    });
  }

  /// Demande la présence réelle au backend et notifie l'IHM.
  Future<PresenceInfo> refresh(String uid) async {
    if (uid.isEmpty) return PresenceInfo.unknown(uid);
    final info = await _realtime.checkPresence(uid);
    _apply(info);
    return info;
  }

  /// Rafraîchit tous les utilisateurs suivis.
  Future<void> refreshAll() async {
    for (final uid in _watched.toList()) {
      await refresh(uid);
    }
  }

  /// L'application passe en arrière-plan : on coupe le rafraîchissement
  /// périodique (économie de batterie). Cela ne change RIEN à l'état affiché :
  /// aucune conclusion n'est tirée d'une application en arrière-plan, la
  /// présence reste celle que le backend a confirmée.
  void mettreEnPause() {
    _enPause = true;
    _stopTimer();
  }

  /// L'application revient au premier plan : on relance le suivi et on
  /// resynchronise immédiatement, sans attendre le prochain tour de timer
  /// (jusqu'à 45 s d'affichage périmé sinon).
  Future<void> reprendre() async {
    _enPause = false;
    _startTimer();
    await refreshAll();
  }

  /// Vrai quand le suivi périodique est suspendu (application en arrière-plan).
  bool get enPause => _enPause;

  bool _enPause = false;

  void _apply(PresenceInfo info) {
    if (_disposed) return;
    final previous = _states[info.uid];
    if (previous == info) return;
    _states[info.uid] = info;
    notifyListeners();
  }

  void _onPresenceEvent(PresenceInfo info) {
    // Événement diffusé par le backend : mise à jour immédiate, sans attendre
    // le prochain rafraîchissement.
    final previous = _states[info.uid];
    final merged = info.lastSeen == null && previous != null
        ? info.copyWith(lastSeen: previous.lastSeen)
        : info;
    _apply(merged);
  }

  void _onStatus(RealtimeStatus status) {
    if (status == RealtimeStatus.connected) {
      // Le socket est revenu : on resynchronise immédiatement.
      for (final uid in _watched.toList()) {
        unawaitedRefresh(uid);
      }
      return;
    }

    if (status == RealtimeStatus.disconnected ||
        status == RealtimeStatus.error ||
        status == RealtimeStatus.connecting) {
      // Perte de la liaison temps réel : AUCune conclusion sur le destinataire.
      // On repasse en « inconnu » — surtout pas en « hors ligne », sinon
      // l'utilisateur croit (à tort) qu'un SMS va partir.
      var changed = false;
      for (final uid in _watched) {
        final current = _states[uid];
        if (current != null && !current.isUnknown) {
          _states[uid] = PresenceInfo(
            uid: uid,
            state: PresenceState.unknown,
            lastSeen: current.lastSeen,
          );
          changed = true;
        }
      }
      if (changed && !_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stopTimer();
    _statusSubscription?.cancel();
    _presenceSubscription?.cancel();
    super.dispose();
  }
}
