import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// États possibles de la passerelle SMS, tels qu'ils sont exposés au client.
enum EtatPasserelle {
  /// Aucune vérification n'a encore abouti.
  inconnue,

  /// Le service répond : la passerelle est joignable.
  operationnelle,

  /// Le service répond mais le fournisseur n'est pas configuré (clé d'API ou
  /// numéro expéditeur absent côté serveur).
  nonConfiguree,

  /// Le service répond mais la passerelle n'est pas le transport actif :
  /// les SMS partent par un autre chemin (Infobip).
  inactive,

  /// Le service n'a pas répondu : réseau coupé, serveur éteint, etc.
  injoignable,
}

/// Résultat d'une vérification de la passerelle.
///
/// Les états « appareil hors ligne », « éteint », « sans crédit » et « sans
/// SIM » demandés par le cahier des charges **ne sont pas exposés par le
/// backend aujourd'hui** : celui-ci ne publie que `configured` et `active`.
/// Ils sont donc signalés comme indisponibles ([etatsAppareilDisponibles]) au
/// lieu d'être inventés.
class EtatPasserelleResultat {
  const EtatPasserelleResultat({
    required this.etat,
    required this.horodatage,
    this.service,
    this.implementation,
    this.configuree,
    this.active,
    this.transport,
    this.etapesConfiguration = const [],
    this.message,
  });

  final EtatPasserelle etat;
  final DateTime horodatage;
  final String? service;
  final String? implementation;
  final bool? configuree;
  final bool? active;
  final String? transport;
  final List<String> etapesConfiguration;

  /// Explication lisible, en particulier en cas d'échec.
  final String? message;

  /// Vrai si la passerelle peut acheminer des SMS.
  bool get utilisable =>
      etat == EtatPasserelle.operationnelle ||
      (etat == EtatPasserelle.inactive && active == true);

  /// Le backend ne publie pas encore l'état de l'appareil relais
  /// (hors ligne, éteint, sans crédit, sans SIM).
  static const bool etatsAppareilDisponibles = false;

  /// Analyse d'une réponse du serveur.
  ///
  /// Pure : testable sans réseau.
  factory EtatPasserelleResultat.fromJson(
    Map<String, dynamic> json, {
    DateTime? horodatage,
  }) {
    final fournisseur = json['provider'];
    final provider = fournisseur is Map ? fournisseur : const <String, dynamic>{};
    final transportBrut = json['transport'];
    final configuration = json['configuration'];

    final configuree = provider['configured'] == true;
    final active = provider['active'] == true;
    final service = json['status']?.toString();

    EtatPasserelle etat;
    String? message;

    if (service != 'active') {
      etat = EtatPasserelle.inactive;
      message = 'Le service répond mais n’est pas actif ($service).';
    } else if (!configuree) {
      etat = EtatPasserelle.nonConfiguree;
      message = 'Passerelle non configurée côté serveur : clé d’API ou '
          'numéro expéditeur absent.';
    } else if (!active) {
      etat = EtatPasserelle.inactive;
      message = 'Passerelle configurée mais non retenue comme transport : '
          'les SMS partent par un autre chemin.';
    } else {
      etat = EtatPasserelle.operationnelle;
    }

    return EtatPasserelleResultat(
      etat: etat,
      horodatage: horodatage ?? DateTime.now(),
      service: json['service']?.toString(),
      implementation: provider['implementation']?.toString(),
      configuree: configuree,
      active: active,
      transport: transportBrut is Map
          ? transportBrut['name']?.toString()
          : transportBrut?.toString(),
      etapesConfiguration: configuration is Map
          ? configuration.values
              .whereType<String>()
              .toList(growable: false)
          : const [],
      message: message,
    );
  }

  /// Résultat d'un échec de communication.
  factory EtatPasserelleResultat.injoignable(String cause) {
    return EtatPasserelleResultat(
      etat: EtatPasserelle.injoignable,
      horodatage: DateTime.now(),
      message: cause,
    );
  }

  /// Libellé court, pour l'écran de réglages.
  String get libelle {
    switch (etat) {
      case EtatPasserelle.operationnelle:
        return 'Opérationnelle';
      case EtatPasserelle.nonConfiguree:
        return 'Non configurée';
      case EtatPasserelle.inactive:
        return 'Inactive';
      case EtatPasserelle.injoignable:
        return 'Injoignable';
      case EtatPasserelle.inconnue:
        return 'État inconnu';
    }
  }
}

/// Interrogation de l'état de la passerelle SMS.
///
/// Le transport réel est **INfiniReach** : un appareil Android relais
/// enregistré auprès du service, piloté par le backend. L'application ne
/// transforme pas le téléphone de l'utilisateur en passerelle — ce choix est
/// celui qui a été retenu. Elle affiche donc l'état réel du service, explique
/// les pannes et précise ce qui reste à configurer.
class GatewayService {
  GatewayService._interne();

  static final GatewayService instance = GatewayService._interne();

  EtatPasserelleResultat? _dernierEtat;
  EtatPasserelleResultat? get dernierEtat => _dernierEtat;

  /// Interroge `GET /api/webhooks/sms-gateway/status`.
  ///
  /// Ne lève jamais : une panne devient un état [EtatPasserelle.injoignable]
  /// accompagné d'un message lisible.
  Future<EtatPasserelleResultat> recupererEtat() async {
    final uri = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.gatewayStatusEndpoint}');

    try {
      final reponse =
          await http.get(uri, headers: ApiConfig.headers).timeout(
                ApiConfig.requestTimeout,
              );

      if (reponse.statusCode != 200) {
        return _dernierEtat = EtatPasserelleResultat.injoignable(
          'Le serveur a répondu ${reponse.statusCode}. La passerelle est '
          'peut-être en maintenance.',
        );
      }

      final donnees = jsonDecode(reponse.body);
      if (donnees is! Map) {
        return _dernierEtat = EtatPasserelleResultat.injoignable(
          'Réponse inattendue du serveur (format non reconnu).',
        );
      }

      return _dernierEtat = EtatPasserelleResultat.fromJson(
        donnees.cast<String, dynamic>(),
      );
    } on TimeoutException {
      return _dernierEtat = EtatPasserelleResultat.injoignable(
        'Le serveur n’a pas répondu à temps. Il redémarre peut-être : '
        'réessayez dans quelques secondes.',
      );
    } catch (e) {
      debugPrint('[Passerelle] vérification impossible : $e');
      return _dernierEtat = EtatPasserelleResultat.injoignable(
        'Vérification impossible : vérifiez votre connexion Internet.',
      );
    }
  }
}
