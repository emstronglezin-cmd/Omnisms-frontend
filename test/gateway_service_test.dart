import 'dart:io' as io;

import 'package:flutter_test/flutter_test.dart';
import 'package:omnisms/services/gateway_service.dart';

String _read(String path) => io.File(path).readAsStringSync();

void main() {
  group('Passerelle — analyse de la réponse du serveur', () {
    test('service actif, fournisseur configuré et retenu → opérationnelle',
        () {
      final etat = EtatPasserelleResultat.fromJson({
        'status': 'active',
        'service': 'INfiniReach Inbound Webhook v2',
        'provider': {
          'provider': 'sms_gateway',
          'implementation': 'INfiniReach',
          'configured': true,
          'active': true,
        },
        'transport': {'name': 'INfiniReach'},
      });

      expect(etat.etat, EtatPasserelle.operationnelle);
      expect(etat.utilisable, isTrue);
      expect(etat.implementation, 'INfiniReach');
      expect(etat.transport, 'INfiniReach');
      expect(etat.libelle, 'Opérationnelle');
      expect(etat.message, isNull);
    });

    test('fournisseur non configuré → non configurée, avec explication', () {
      final etat = EtatPasserelleResultat.fromJson({
        'status': 'active',
        'provider': {'configured': false, 'active': true},
      });

      expect(etat.etat, EtatPasserelle.nonConfiguree);
      expect(etat.utilisable, isFalse);
      expect(etat.message, contains('clé d’API ou numéro expéditeur'));
    });

    test('configurée mais non retenue comme transport → inactive', () {
      final etat = EtatPasserelleResultat.fromJson({
        'status': 'active',
        'provider': {'configured': true, 'active': false},
      });

      expect(etat.etat, EtatPasserelle.inactive);
      expect(etat.message, contains('un autre chemin'));
    });

    test('service répondant « inactif » → inactive, jamais « opérationnelle »',
        () {
      final etat = EtatPasserelleResultat.fromJson({
        'status': 'maintenance',
        'provider': {'configured': true, 'active': true},
      });

      expect(etat.etat, EtatPasserelle.inactive);
    });

    test('les étapes de configuration serveur sont reprises telles quelles',
        () {
      final etat = EtatPasserelleResultat.fromJson({
        'status': 'active',
        'provider': {'configured': true, 'active': true},
        'configuration': {
          'step1': 'Installer l’application INfiniReach',
          'step2': 'Se connecter et enregistrer l’appareil',
        },
      });

      expect(etat.etapesConfiguration, hasLength(2));
      expect(etat.etapesConfiguration.first, contains('INfiniReach'));
    });

    test('une réponse inattendue n’est jamais considérée comme valide', () {
      final etat = EtatPasserelleResultat.fromJson(<String, dynamic>{});
      expect(etat.etat, EtatPasserelle.inactive);
      expect(etat.utilisable, isFalse);
    });
  });

  group('Passerelle — pannes', () {
    test('serveur injoignable : état et message lisibles', () {
      final etat = EtatPasserelleResultat.injoignable(
          'Le serveur n’a pas répondu à temps.');

      expect(etat.etat, EtatPasserelle.injoignable);
      expect(etat.libelle, 'Injoignable');
      expect(etat.utilisable, isFalse);
      expect(etat.message, contains('pas répondu à temps'));
    });
  });

  group('Passerelle — honnêteté', () {
    test('les états de l’appareil relais sont déclarés indisponibles', () {
      // Cahier des charges : hors ligne, éteint, sans crédit, sans SIM.
      // Ces états ne sont pas publiés par le backend — ils ne sont donc pas
      // affichés. Ce test échouera le jour où ils le deviennent : il faudra
      // alors les brancher pour de bon.
      expect(EtatPasserelleResultat.etatsAppareilDisponibles, isFalse);
    });

    test('l’endpoint interrogé est celui réellement monté côté serveur', () {
      final config = _read('lib/config/api_config.dart');
      expect(config, contains('/api/webhooks/sms-gateway/status'));
    });

    test('aucun envoi par la SIM de l’utilisateur n’est câblé', () {
      final service = _read('lib/services/gateway_service.dart');
      expect(service, isNot(contains('SmsManager')));
      expect(service, isNot(contains('telephony')));
      // Le service consultent l'état : aucun envoi.
      expect(RegExp(r'http\.(post|put|delete)').hasMatch(service), isFalse);
    });
  });
}
