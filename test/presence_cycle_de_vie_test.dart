import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:omnisms/services/presence_service.dart';
import 'package:omnisms/services/realtime_service.dart';
import 'package:omnisms/widgets/chat/online_status_widget.dart';
import 'package:omnisms/widgets/common/presence_cycle_de_vie.dart';

/// Source de présence factice : reflète ce que répondrait le backend, sans
/// jamais inventer d'état (pas de réponse ⇒ « inconnu »).
class _SourceFactice implements PresenceSource {
  _SourceFactice(this.reponses);

  final Map<String, PresenceInfo> reponses;
  int appels = 0;

  RealtimeStatus _statut = RealtimeStatus.connected;
  final StreamController<RealtimeStatus> _statuts =
      StreamController<RealtimeStatus>.broadcast();
  final StreamController<PresenceInfo> _presences =
      StreamController<PresenceInfo>.broadcast();

  @override
  RealtimeStatus get status => _statut;

  @override
  Stream<RealtimeStatus> get statusStream => _statuts.stream;

  @override
  Stream<PresenceInfo> get presenceStream => _presences.stream;

  @override
  Future<PresenceInfo> checkPresence(String uid,
      {Duration timeout = const Duration(seconds: 6)}) async {
    appels++;
    return reponses[uid] ?? PresenceInfo.unknown(uid);
  }

  Future<void> close() async {
    await _statuts.close();
    await _presences.close();
  }
}

Future<void> _patienter() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cycle de vie — suivi de présence', () {
    test('le retour au premier plan resynchronise immédiatement', () async {
      final source = _SourceFactice({
        'u1': const PresenceInfo(
            uid: 'u1', state: PresenceState.online, lastSeen: null),
      });
      final service = PresenceService(realtime: source);

      service.watch('u1');
      await _patienter();
      final apresPremierSuivi = source.appels;
      expect(apresPremierSuivi, greaterThan(0));

      // Arrière-plan : le suivi périodique est suspendu.
      service.mettreEnPause();
      expect(service.enPause, isTrue);

      // Retour au premier plan : resynchronisation SANS attendre le timer.
      await service.reprendre();
      expect(service.enPause, isFalse);
      expect(source.appels, greaterThan(apresPremierSuivi));

      service.dispose();
      await source.close();
    });

    test(
        'l\'arrière-plan ne conclut jamais « hors ligne » : l\'état connu est '
        'conservé', () async {
      final source = _SourceFactice({
        'u1': PresenceInfo(
          uid: 'u1',
          state: PresenceState.online,
          lastSeen: DateTime(2026, 10, 20, 10),
        ),
      });
      final service = PresenceService(realtime: source);

      service.watch('u1');
      await _patienter();
      expect(service.stateOf('u1').isOnline, isTrue);

      // Passage en arrière-plan : l'état confirmé reste affiché.
      service.mettreEnPause();
      await _patienter();
      expect(service.stateOf('u1').isOnline, isTrue,
          reason: 'une application en arrière-plan ne déconnecte personne');

      service.dispose();
      await source.close();
    });

    testWidgets('le widget relie réellement le cycle de vie au service',
        (tester) async {
      final source = _SourceFactice(const {});
      final service = PresenceService(realtime: source);

      await tester.pumpWidget(
        ChangeNotifierProvider<PresenceService>.value(
          value: service,
          child: const MaterialApp(
            home: PresenceCycleDeVie(child: Scaffold(body: SizedBox())),
          ),
        ),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(service.enPause, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      // Ici l'horloge est simulée : on avance le temps avec `pump` (un
      // `Future.delayed` attendrait indéfiniment).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(service.enPause, isFalse);

      service.dispose();
      await source.close();
    });
  });

  group('Dernière activité connue', () {
    String libelle(DateTime vu) => PresenceStatusText.derniereActivite(vu);

    test('aujourd\'hui : heure seule', () {
      final maintenant = DateTime.now();
      final vu = DateTime(
        maintenant.year,
        maintenant.month,
        maintenant.day,
        18,
        32,
      );
      expect(libelle(vu), "Vu aujourd'hui à 18:32");
    });

    test('hier : mention du jour', () {
      final hier = DateTime.now().subtract(const Duration(days: 1));
      final vu = DateTime(hier.year, hier.month, hier.day, 9, 5);
      expect(libelle(vu), 'Vu hier à 09:05');
    });

    test('dans la semaine : jour de la semaine', () {
      final il_y_a_3_jours = DateTime.now().subtract(const Duration(days: 3));
      const jours = [
        'lundi',
        'mardi',
        'mercredi',
        'jeudi',
        'vendredi',
        'samedi',
        'dimanche',
      ];
      final attendu = jours[il_y_a_3_jours.weekday - 1];
      expect(libelle(il_y_a_3_jours), contains('Vu $attendu à'));
    });

    test('au-delà : date complète', () {
      final ancien = DateTime(2026, 3, 12, 14, 20);
      expect(libelle(ancien), 'Vu le 12/03/26 à 14:20');
    });
  });

  group('Libellés de présence', () {
    test('« inconnu » n\'est jamais traduit par « hors ligne »', () {
      const presence = PresenceInfo.unknown('u1');
      expect(PresenceStatusText(presence: presence).label,
          isNot(contains('Hors ligne')));
      expect(PresenceStatusText(presence: presence).label,
          contains('inconnue'));
    });

    test('hors ligne sans lastSeen : « Hors ligne »', () {
      const presence =
          PresenceInfo(uid: 'u1', state: PresenceState.offline, lastSeen: null);
      expect(PresenceStatusText(presence: presence).label, 'Hors ligne');
    });
  });
}
