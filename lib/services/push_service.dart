import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, debugPrint, visibleForTesting;

import '../config/api_config.dart';
import 'notification_service.dart';

/// États possibles du service de notifications push.
///
/// Ils sont volontairement explicites : l'application doit pouvoir dire
/// POURQUOI le push ne fonctionne pas, jamais se contenter d'échouer en
/// silence ni laisser croire qu'il est actif.
enum EtatPush {
  /// L'initialisation n'a pas encore été tentée.
  nonTente,

  /// Firebase n'a pas pu être initialisé : fichier de configuration absent
  /// (`google-services.json` sur Android, `GoogleService-Info.plist` sur iOS).
  configurationAbsente,

  /// Firebase est configuré, mais l'utilisateur a refusé la permission.
  permissionRefusee,

  /// Jeton d'appareil obtenu. Le push fonctionne côté application ; côté
  /// serveur, il faut encore un endpoint pour l'enregistrer.
  jetonObtenu,

  /// Une erreur inattendue est survenue ; [PushService.message] la décrit.
  erreur,
}

/// Notifications push — FCM sur Android, FCM via APNs sur iOS.
///
/// État réel au moment de l'écriture, sans fard :
///
///  * le code client est complet (permission, jeton, réception, ouverture) ;
///  * **Firebase n'est pas encore configuré** : `google-services.json`
///    annonce l'ancien paquet « omnisms.app » et `GoogleService-Info.plist`
///    est absent. Tant que ces fichiers ne sont pas fournis, l'initialisation
///    échoue et l'état passe à [EtatPush.configurationAbsente] — l'application
///    continue de fonctionner, sans push ;
///  * **le serveur n'expose aucun endpoint d'enregistrement de jeton.** Le
///    jeton est donc conservé localement ; le service signale
///    [PushService.enAttenteServeur] au lieu de prétendre l'avoir transmis.
///
/// Rien n'est simulé : aucun jeton n'est fabriqué, aucune notification
/// locale ne se fait passer pour une notification distante.
class PushService {
  PushService._interne();

  static final PushService instance = PushService._interne();

  /// Constructeur réservé aux tests : il permet de vérifier les libellés
  /// d'état sans initialiser Firebase, donc sans effet de bord.
  @visibleForTesting
  PushService.pourTest({
    EtatPush etat = EtatPush.nonTente,
    String? jeton,
    String? message,
    bool enAttenteServeur = false,
  })  : _etat = etat,
        _jeton = jeton,
        _message = message,
        _enAttenteServeur = enAttenteServeur;

  EtatPush _etat = EtatPush.nonTente;
  String? _jeton;
  String? _message;
  bool _enAttenteServeur = false;
  StreamSubscription<String>? _souscriptionJeton;
  StreamSubscription<RemoteMessage>? _souscriptionMessage;
  StreamSubscription<RemoteMessage>? _souscriptionOuverture;

  /// État courant du service.
  EtatPush get etat => _etat;

  /// Jeton d'appareil fourni par FCM, ou `null` s'il n'a pas pu être obtenu.
  String? get jeton => _jeton;

  /// Explication lisible de l'état courant, destinée à l'utilisateur ou aux
  /// journaux. Toujours renseignée quand l'état n'est pas [EtatPush.jetonObtenu].
  String? get message => _message;

  /// Vrai si l'application dispose d'un jeton mais qu'aucun endpoint serveur
  /// ne permet de l'enregistrer.
  bool get enAttenteServeur => _enAttenteServeur;

  /// Vrai si le push est opérationnel côté application.
  bool get operationnel => _etat == EtatPush.jetonObtenu;

  /// Initialise Firebase, demande la permission et récupère le jeton.
  ///
  /// Ne lève jamais : chaque échec est traduit en état explicite. L'application
  /// doit pouvoir démarrer même quand le push est indisponible.
  Future<void> initialiser() async {
    if (kIsWeb) {
      // Le web dispose déjà de son propre cheminement (voir
      // web_notification_service.dart) ; FCM web n'est pas câblé ici.
      _etat = EtatPush.erreur;
      _message = 'Notifications push non câblées sur le web.';
      return;
    }

    // 1. Firebase. Sans fichier de configuration, cette étape échoue —
    //    c'est le cas aujourd'hui, et c'est un état assumé, pas une erreur
    //    à masquer.
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
    } catch (e) {
      _etat = EtatPush.configurationAbsente;
      _message = 'Firebase n’est pas configuré sur cet appareil : '
          'il manque google-services.json (Android) ou '
          'GoogleService-Info.plist (iOS). Les notifications à distance '
          'sont indisponibles ; le reste de l’application fonctionne.';
      debugPrint('[Push] initialisation Firebase impossible : $e');
      return;
    }

    // 2. Permission.
    try {
      final reglages = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (reglages.authorizationStatus != AuthorizationStatus.authorized &&
          reglages.authorizationStatus != AuthorizationStatus.provisional) {
        _etat = EtatPush.permissionRefusee;
        _message = 'Permission de notification refusée. Vous pouvez '
            'l’accorder dans les réglages du téléphone.';
        return;
      }
    } catch (e) {
      _etat = EtatPush.erreur;
      _message = 'Demande de permission impossible : $e';
      return;
    }

    // 3. Jeton. Sur iOS, le jeton APNs doit exister avant celui de FCM ;
    //    sur simulateur il reste nul — cas prévu, pas d'échec silencieux.
    try {
      final apns = await FirebaseMessaging.instance.getAPNSToken();
      if (apns == null) {
        debugPrint('[Push] jeton APNs indisponible (simulateur ?)');
      }
      _jeton = await FirebaseMessaging.instance.getToken();
    } catch (e) {
      _etat = EtatPush.erreur;
      _message = 'Récupération du jeton impossible : $e';
      return;
    }

    if (_jeton == null) {
      _etat = EtatPush.erreur;
      _message = 'FCM n’a renvoyé aucun jeton d’appareil.';
      return;
    }

    _etat = EtatPush.jetonObtenu;
    _message = null;
    await _transmettreLeJeton(_jeton!);

    // 4. Écouteurs.
    _souscriptionJeton?.cancel();
    _souscriptionJeton =
        FirebaseMessaging.instance.onTokenRefresh.listen(_transmettreLeJeton);

    _souscriptionMessage?.cancel();
    _souscriptionMessage =
        FirebaseMessaging.onMessage.listen(_surMessageAuPremierPlan);

    _souscriptionOuverture?.cancel();
    _souscriptionOuverture =
        FirebaseMessaging.onMessageOpenedApp.listen(_surOuverture);

    // Message reçu alors que l'application était fermée.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _surOuverture(initial);
  }

  /// Transmet le jeton au backend.
  ///
  /// **Le serveur n'expose aujourd'hui aucun endpoint pour cela** : la
  /// constante est donc `null`, le jeton est conservé localement et
  /// l'état [enAttenteServeur] devient vrai. Le jour où la route existe, il
  /// suffit de renseigner [ApiConfig.pushTokenEndpoint] — ce code n'a pas à
  /// changer.
  Future<void> _transmettreLeJeton(String jeton) async {
    final endpoint = ApiConfig.pushTokenEndpoint;
    if (endpoint == null) {
      _enAttenteServeur = true;
      debugPrint('[Push] jeton obtenu mais aucun endpoint serveur pour '
          'l’enregistrer — voir ApiConfig.pushTokenEndpoint');
      return;
    }
    // L'implémentation d'envoi viendra avec l'endpoint ; elle n'est pas
    // simulée ici.
  }

  /// Notification reçue alors que l'application est au premier plan :
  /// FCM ne l'affiche pas, l'application s'en charge.
  void _surMessageAuPremierPlan(RemoteMessage message) {
    final notification = message.notification;
    final donnees = message.data;
    // Un message purement « données » n'a ni titre ni corps : on retombe sur
    // les champs du payload, à défaut sur un libellé générique.
    NotificationService.instance.show(
      messageId: message.messageId ??
          donnees['messageId'] as String? ??
          'fcm-${DateTime.now().microsecondsSinceEpoch}',
      title: notification?.title ??
          donnees['title'] as String? ??
          'Nouveau message',
      body: notification?.body ?? donnees['body'] as String? ?? '',
      conversationId: donnees['conversationId'] as String? ?? '',
    );
  }

  /// L'utilisateur a touché une notification.
  void _surOuverture(RemoteMessage message) {
    final conversationId = message.data['conversationId'] as String?;
    if (conversationId == null) return;
    final rappel = NotificationService.instance.onNotificationTap;
    if (rappel != null) rappel(conversationId);
  }

  void dispose() {
    _souscriptionJeton?.cancel();
    _souscriptionMessage?.cancel();
    _souscriptionOuverture?.cancel();
    _souscriptionJeton = null;
    _souscriptionMessage = null;
    _souscriptionOuverture = null;
  }

  /// Réinitialise l'état — utilisé par les tests.
  void reinitialiserPourTest() {
    _etat = EtatPush.nonTente;
    _jeton = null;
    _message = null;
    _enAttenteServeur = false;
  }

  /// Résumé lisible, destiné à l'écran de réglages.
  String resume() {
    switch (_etat) {
      case EtatPush.jetonObtenu:
        return _enAttenteServeur
            ? 'Jeton prêt — en attente d’un endpoint serveur pour '
                'l’enregistrer.'
            : 'Notifications à distance actives.';
      case EtatPush.configurationAbsente:
        return 'Firebase non configuré : notifications à distance '
            'indisponibles.';
      case EtatPush.permissionRefusee:
        return 'Permission refusée dans les réglages du téléphone.';
      case EtatPush.erreur:
        return _message ?? 'Notifications indisponibles.';
      case EtatPush.nonTente:
        return 'Notifications non initialisées.';
    }
  }
}
