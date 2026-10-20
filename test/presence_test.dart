import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnisms/services/presence_service.dart';
import 'package:omnisms/services/realtime_service.dart';

/// Fausse source de présence : remplace le socket pour tester la logique
/// d'état. Elle ne produit aucune « fausse présence » : elle ne fait que
/// refléter ce qu'un backend répondrait (online / offline / pas de réponse).
class _FakePresenceSource implements PresenceSource {
  _FakePresenceSource(this.answers);

  final Map<String, PresenceInfo> answers;

  /// `true` pour simuler un backend qui ne répond pas (timeout).
  bool doesNotAnswer = false;

  int checkCalls = 0;

  RealtimeStatus _status = RealtimeStatus.connected;
  final StreamController<RealtimeStatus> _statusController =
      StreamController<RealtimeStatus>.broadcast();
  final StreamController<PresenceInfo> _presenceController =
      StreamController<PresenceInfo>.broadcast();

  @override
  RealtimeStatus get status => _status;

  @override
  Stream<RealtimeStatus> get statusStream => _statusController.stream;

  @override
  Stream<PresenceInfo> get presenceStream => _presenceController.stream;

  @override
  Future<PresenceInfo> checkPresence(String uid,
      {Duration timeout = const Duration(seconds: 6)}) async {
    checkCalls++;
    if (doesNotAnswer) return PresenceInfo.unknown(uid);
    return answers[uid] ?? PresenceInfo.unknown(uid);
  }

  void setStatus(RealtimeStatus status) {
    _status = status;
    _statusController.add(status);
  }

  void broadcast(PresenceInfo info) => _presenceController.add(info);

  Future<void> close() async {
    await _statusController.close();
    await _presenceController.close();
  }
}

/// Laisse tourner la boucle d'événements le temps que les rafraîchissements
/// asynchrones se terminent.
Future<void> _settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late _FakePresenceSource source;
  late PresenceService service;

  final lastSeen = DateTime(2026, 10, 20, 9, 30);

  setUp(() {
    source = _FakePresenceSource({
      'online-uid': PresenceInfo(
        uid: 'online-uid',
        state: PresenceState.online,
        lastSeen: DateTime(2026, 10, 20, 10, 0),
      ),
      'offline-uid': PresenceInfo(
        uid: 'offline-uid',
        state: PresenceState.offline,
        lastSeen: lastSeen,
      ),
    });
    service = PresenceService(realtime: source);
  });

  tearDown(() async {
    service.dispose();
    await source.close();
  });

  group('Présence issue du backend', () {
    test('un utilisateur avec session Socket.IO est « connecté »', () async {
      service.watch('online-uid');
      await _settle();

      final info = service.stateOf('online-uid');
      expect(info.isOnline, isTrue);
      expect(info.isUnknown, isFalse);
    });

    test('un utilisateur sans session est « déconnecté » (avec lastSeen)',
        () async {
      service.watch('offline-uid');
      await _settle();

      final info = service.stateOf('offline-uid');
      expect(info.isOffline, isTrue);
      expect(info.lastSeen, lastSeen);
    });

    test('un utilisateur inconnu du backend reste « inconnu », pas hors ligne',
        () async {
      service.watch('nobody');
      await _settle();

      final info = service.stateOf('nobody');
      expect(info.isUnknown, isTrue);
      expect(info.isOffline, isFalse);
    });

    test('aucune réponse du backend ⇒ « inconnu » (jamais « hors ligne »)',
        () async {
      source.doesNotAnswer = true;
      service.watch('offline-uid');
      await _settle();

      // Règle métier : l'absence de réponse n'est pas une preuve de
      // déconnexion. Afficher « hors ligne » ferait croire à tort qu'un SMS
      // va partir.
      expect(service.stateOf('offline-uid').isUnknown, isTrue);
      expect(service.stateOf('offline-uid').isOffline, isFalse);
    });
  });

  group('Perte et retour de la liaison temps réel', () {
    test('une coupure repasse en « inconnu » sans effacer le lastSeen',
        () async {
      service.watch('offline-uid');
      await _settle();
      expect(service.stateOf('offline-uid').isOffline, isTrue);

      source.setStatus(RealtimeStatus.disconnected);
      await _settle();

      final info = service.stateOf('offline-uid');
      expect(info.isUnknown, isTrue);
      expect(info.lastSeen, lastSeen, reason: 'le lastSeen reste affichable');
    });

    test('une erreur de connexion repasse aussi en « inconnu »', () async {
      service.watch('online-uid');
      await _settle();
      expect(service.stateOf('online-uid').isOnline, isTrue);

      source.setStatus(RealtimeStatus.error);
      await _settle();

      expect(service.stateOf('online-uid').isUnknown, isTrue);
    });

    test('la reconnexion resynchronise immédiatement', () async {
      service.watch('online-uid');
      await _settle();

      source.setStatus(RealtimeStatus.disconnected);
      await _settle();
      expect(service.stateOf('online-uid').isUnknown, isTrue);

      final callsBefore = source.checkCalls;
      source.setStatus(RealtimeStatus.connected);
      await _settle();

      expect(source.checkCalls, greaterThan(callsBefore),
          reason: 'une nouvelle interrogation du backend est attendue');
      expect(service.stateOf('online-uid').isOnline, isTrue);
    });
  });

  group('Événements diffusés par le backend', () {
    test('user:online met à jour sans attendre le rafraîchissement', () async {
      service.watch('nobody');
      await _settle();
      expect(service.stateOf('nobody').isUnknown, isTrue);

      source.broadcast(const PresenceInfo(
        uid: 'nobody',
        state: PresenceState.online,
      ));
      await _settle();

      expect(service.stateOf('nobody').isOnline, isTrue);
    });

    test('user:offline conserve le lastSeen déjà connu', () async {
      service.watch('online-uid');
      await _settle();
      expect(service.stateOf('online-uid').lastSeen,
          DateTime(2026, 10, 20, 10, 0));

      source.broadcast(PresenceInfo(
        uid: 'online-uid',
        state: PresenceState.offline,
        lastSeen: DateTime(2026, 10, 20, 11, 0),
      ));
      await _settle();

      final info = service.stateOf('online-uid');
      expect(info.isOffline, isTrue);
      expect(info.lastSeen, DateTime(2026, 10, 20, 11, 0));
    });
  });

  group('Cycle de vie du suivi', () {
    test('unwatch arrête le suivi (plus de notification)', () async {
      service.watch('online-uid');
      await _settle();
      service.unwatch('online-uid');

      var notified = false;
      service.addListener(() => notified = true);
      source.setStatus(RealtimeStatus.disconnected);
      await _settle();

      expect(notified, isFalse);
    });
  });
}
