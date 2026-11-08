import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/messaging_provider.dart';
import '../screens/messaging/conversation_screen.dart';

/// ⚠️ Mobile uniquement (APK / IPA). La PWA n'utilise pas ce fichier.

/// Clé de navigation globale : indispensable pour ouvrir une conversation
/// depuis une notification, y compris quand l'application a été lancée par
/// ce tap (aucun `BuildContext` n'est alors disponible dans les services).
final GlobalKey<NavigatorState> navigateurGlobalKey =
    GlobalKey<NavigatorState>(debugLabel: 'OmniSMS');

/// Ouvre la conversation visée par une notification.
///
/// Avant ce correctif, le tap sur une notification se contentait d'un
/// `debugPrint` : l'utilisateur atterrissait sur l'écran d'accueil sans
/// comprendre pourquoi. On ouvre désormais réellement la conversation.
///
/// Cas gérés :
///   • l'application est déjà ouverte → navigation immédiate ;
///   • l'application vient d'être lancée par le tap → l'identifiant est mis
///     en attente, puis traité dès que l'interface est prête
///     ([traiterConversationEnAttente]) ;
///   • la conversation n'est pas encore en mémoire → rechargement depuis
///     `GET /api/messages`, puis navigation ;
///   • identifiant inconnu ou suppression de la conversation → aucun
///     plantage, aucun écran vide : on ne navigue pas.
class NotificationNavigation {
  NotificationNavigation._();

  static final NotificationNavigation instance = NotificationNavigation._();

  /// Conversation à ouvrir dès que l'interface est disponible.
  String? _idEnAttente;

  /// Dernier identifiant traité (évite la double navigation : FCM délivre
  /// parfois l'ouverture deux fois, au démarrage puis via le flux).
  String? _dernierIdOuvert;

  /// Vrai si une conversation attend l'ouverture de l'interface.
  bool get aUneConversationEnAttente => _idEnAttente != null;

  /// Remet le service à zéro : réservé aux tests (le service est un
  /// singleton, son état survivrait sinon d'un test à l'autre).
  @visibleForTesting
  void reinitialiserPourTest() {
    _idEnAttente = null;
    _dernierIdOuvert = null;
  }

  /// Mémorise la conversation à ouvrir (appelé avant que l'interface existe).
  void mettreEnAttente(String conversationId) {
    if (conversationId.isEmpty) return;
    _idEnAttente = conversationId;
  }

  /// Ouvre la conversation [conversationId].
  ///
  /// [titreContact] est le nom figurant dans la notification : il sert de
  /// repli si la conversation n'est pas (ou plus) dans la liste.
  Future<bool> ouvrir(
    String conversationId, {
    String? titreContact,
  }) async {
    if (conversationId.isEmpty) return false;

    final context = navigateurGlobalKey.currentContext;
    if (context == null) {
      // Interface pas encore montée : on attend son signal.
      mettreEnAttente(conversationId);
      return false;
    }
    if (_dernierIdOuvert == conversationId) return false;

    MessagingProvider provider;
    try {
      provider = context.read<MessagingProvider>();
    } catch (e) {
      debugPrint('[Notification] fournisseur indisponible : $e');
      mettreEnAttente(conversationId);
      return false;
    }

    var conversation = _chercher(provider, conversationId);

    // Conversation absente de la mémoire (démarrage à froid) : on recharge.
    if (conversation == null) {
      try {
        await provider.loadConversations();
        conversation = _chercher(provider, conversationId);
      } catch (e) {
        debugPrint('[Notification] rechargement impossible : $e');
      }
    }

    // Copie locale : après un `await`, l'analyse de nullabilité ne peut plus
    // promouvoir la variable d'origine.
    final cible = conversation;
    if (cible == null) {
      debugPrint(
          '[Notification] conversation $conversationId introuvable — '
          'aucune navigation (pas d\'écran vide)');
      return false;
    }

    _dernierIdOuvert = conversationId;
    _idEnAttente = null;

    provider.setActiveConversation(cible.id);
    provider.markConversationAsRead(cible.id);

    // ATTENTION : ne pas `await` le `push`. Le Future rendu par
    // `Navigator.push` ne se termine qu'à la FERMETURE de l'écran : l'attendre
    // bloquerait l'appelant (et le test) indéfiniment. Le nettoyage se fait
    // donc dans le `then`, exactement comme le fait la liste des conversations.
    navigateurGlobalKey.currentState
        ?.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => ConversationScreen(
              conversationId: cible.id,
              contactId: cible.otherUserId,
              contactName: cible.displayName,
              contactImageUrl: cible.otherUserPhotoUrl,
              isGroup: cible.isGroup,
            ),
          ),
        )
        .then((_) => provider.setActiveConversation(null));

    return true;
  }

  /// À appeler quand l'interface est prête (après la première frame) : ouvre
  /// la conversation mémorisée pendant le démarrage, s'il y en a une.
  Future<bool> traiterConversationEnAttente({String? titreContact}) async {
    final enAttente = _idEnAttente;
    if (enAttente == null) return false;
    return ouvrir(enAttente, titreContact: titreContact);
  }

  ConversationModel? _chercher(
    MessagingProvider provider,
    String conversationId,
  ) {
    for (final conv in provider.conversations) {
      if (conv.id == conversationId) return conv;
    }
    return null;
  }
}
