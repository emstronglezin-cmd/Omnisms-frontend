import 'dart:io' as io;

import 'package:flutter_test/flutter_test.dart';
import 'package:omnisms/services/push_service.dart';

String _read(String path) => io.File(path).readAsStringSync();

void main() {
  group('Service push — états', () {
    test('au repos, aucun jeton n’est inventé', () {
      final push = PushService.pourTest();
      expect(push.etat, EtatPush.nonTente);
      expect(push.jeton, isNull);
      expect(push.operationnel, isFalse);
      expect(push.enAttenteServeur, isFalse);
    });

    test('chaque état produit un libellé explicite', () {
      expect(
        PushService.pourTest(etat: EtatPush.nonTente).resume(),
        contains('non initialisées'),
      );
      expect(
        PushService.pourTest(etat: EtatPush.configurationAbsente).resume(),
        contains('Firebase non configuré'),
      );
      expect(
        PushService.pourTest(etat: EtatPush.permissionRefusee).resume(),
        contains('Permission refusée'),
      );
      expect(
        PushService.pourTest(etat: EtatPush.erreur, message: 'Panne réseau')
            .resume(),
        contains('Panne réseau'),
      );
    });

    test('un jeton sans endpoint serveur est signalé, pas présenté comme actif',
        () {
      final push = PushService.pourTest(
        etat: EtatPush.jetonObtenu,
        jeton: 'un-jeton',
        enAttenteServeur: true,
      );
      expect(push.operationnel, isTrue,
          reason: 'le jeton existe bien côté application');
      expect(push.enAttenteServeur, isTrue);
      expect(push.resume(), contains('en attente d’un endpoint serveur'));
    });

    test('un jeton enregistré côté serveur annonce le push actif', () {
      final push = PushService.pourTest(
        etat: EtatPush.jetonObtenu,
        jeton: 'un-jeton',
      );
      expect(push.resume(), contains('actives'));
    });
  });

  group('Service push — honnêteté du contrat', () {
    test('l’endpoint d’enregistrement est documenté comme absent', () {
      final config = _read('lib/config/api_config.dart');
      expect(config, contains('pushTokenEndpoint'));
      // La constante vaut null : aucune transmission n'est simulée.
      expect(RegExp(r'static const String\? pushTokenEndpoint = null;')
          .hasMatch(config), isTrue);
    });

    test('le service ne fabrique jamais de jeton', () {
      final source = _read('lib/services/push_service.dart');
      // Le seul jeton accepté provient de FirebaseMessaging.
      expect(source, contains('FirebaseMessaging.instance.getToken()'));
      expect(RegExp(r"_jeton\s*=\s*'").hasMatch(source), isFalse);
    });

    test('l’échec d’initialisation est explicitement invoqué, jamais masqué',
        () {
      final source = _read('lib/services/push_service.dart');
      expect(source, contains('configurationAbsente'));
      expect(source.toLowerCase(), contains('ne lève jamais'));
    });
  });
}
