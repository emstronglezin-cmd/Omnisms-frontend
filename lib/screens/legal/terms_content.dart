import 'dart:ui' show Locale;

import 'privacy_content.dart' show PrivacyBlock, PrivacySection;

/// Contenu des conditions générales d'utilisation, séparé de la mise en page.
///
/// Même discipline de rédaction que la politique de confidentialité
/// (`privacy_content.dart`) :
///   - seules des informations VÉRIFIABLES dans le code sont affirmées ;
///   - tout ce qui relève de l'identité légale, d'un engagement juridique,
///     d'un prix contractuel ou d'une règle de responsabilité est un
///     emplacement explicite `PrivacyBlockKind.placeholder`, jamais une
///     invention.
///
/// Le modèle de blocs est celui de la page de confidentialité : un seul rendu
/// pour les deux documents, donc une seule hiérarchie visuelle à maintenir.
abstract class TermsContent {
  /// Date de dernière mise à jour, affichée en haut de page.
  String get updatedOn;

  List<PrivacySection> get sections;
}

/// Implémentation française.
///
/// Chaque affirmation est reliée à un élément réel du dépôt :
///   - `lib/screens/subscription_screen.dart`      → montant et devise affichés
///   - `lib/services/payment_service.dart`         → routes de paiement et de statut
///   - `lib/services/offline_storage_service.dart` → cache hors ligne
///   - `lib/services/push_service.dart`, `lib/config/api_config.dart`
///                                                 → état réel des notifications
///   - `lib/screens/settings/settings_screen.dart` → suppression de compte
///   - `public/app.js`, `vercel.json`, `firebase.json` → application web (PWA)
class TermsContentFr implements TermsContent {
  @override
  String get updatedOn => '11 octobre 2026';

  @override
  List<PrivacySection> get sections => [
        PrivacySection(title: 'Objet de ce document', blocks: [
          PrivacyBlock.paragraph(
            "Cette page décrit les conditions dans lesquelles l'application "
            'OmniSMS est mise à disposition et utilisée. Elle explique ce que '
            'le service fait réellement, comment un compte fonctionne, comment '
            "l'abonnement Premium est activé et quelles sont les limites "
            'techniques connues au jour de la mise à jour.',
          ),
          PrivacyBlock.note(
            "Les blocs marqués « À COMPLÉTER » correspondent à des mentions "
            "juridiques qui ne peuvent pas être déduites du code : identité de "
            "l'éditeur, obligations des utilisateurs, responsabilité, droit "
            "applicable. Ils doivent être renseignés et validés par l'éditeur "
            'avant toute publication. Tant que ces blocs sont présents, cette '
            'page ne constitue pas un contrat opposable.',
          ),
        ]),

        PrivacySection(title: 'Éditeur du service', blocks: [
          PrivacyBlock.placeholder(
            "EMPLACEMENT À COMPLÉTER PAR L'ÉDITEUR AVANT PUBLICATION : raison "
            'sociale, forme juridique, adresse postale, pays '
            "d'établissement, numéro d'enregistrement, représentant légal et "
            'adresse e-mail de contact réellement surveillée. Aucune '
            "information légale n'a été inventée ici.",
          ),
          PrivacyBlock.paragraph(
            'Éléments techniques vérifiables dans la configuration du projet : '
            "le serveur d'OmniSMS est hébergé par un prestataire tiers "
            "(Render) et l'application web est servie comme un site statique "
            '(Vercel / Firebase Hosting, répertoire `build/web`).',
          ),
          PrivacyBlock.placeholder(
            "EMPLACEMENT À COMPLÉTER : mentions formelles de l'hébergeur "
            '(nom, adresse postale, contact) telles qu\'exigées par la '
            "réglementation applicable à l'éditeur.",
          ),
        ]),

        PrivacySection(title: 'Le service', blocks: [
          PrivacyBlock.paragraph(
            'OmniSMS est une application de messagerie disponible sous forme '
            "d'application Android et d'application web installable (PWA). "
            'Elle permet :',
          ),
          PrivacyBlock.bullets('Fonctionnalités disponibles', [
            "Échanger des messages texte, des messages vocaux et des images avec d'autres comptes OmniSMS.",
            "Envoyer des SMS à des personnes qui n'utilisent pas l'application : l'envoi passe par un prestataire SMS choisi côté serveur.",
            'Créer et gérer des groupes (nom, description, photo, membres).',
            "Obtenir la transcription automatique d'un message vocal, traitée côté serveur.",
            "Synchroniser son carnet d'adresses pour identifier qui utilise déjà OmniSMS, et importer ses contacts Google si ce mode de connexion est utilisé.",
            'Consulter une partie de ses données hors connexion : un cache local conserve contacts, messages, groupes et profil, et les actions en attente sont mises en file.',
          ]),
          PrivacyBlock.note(
            "Le service ne contient aucune publicité : aucune régie "
            "publicitaire ni identifiant publicitaire n'est intégré à "
            "l'application.",
          ),
        ]),

        PrivacySection(title: 'Compte et accès', blocks: [
          PrivacyBlock.bullets('Ce que le code met réellement en œuvre', [
            "Un compte est rattaché à un numéro de téléphone, vérifié par un code à usage unique envoyé par SMS.",
            "Le nom d'utilisateur accepte les lettres, les chiffres et les caractères « _ », « . » et « - » ; il doit être unique.",
            "Le mot de passe est transmis au serveur et conservé haché (bcrypt) : il n'est pas stocké en clair.",
            "La photo de profil, le nom affiché et l'adresse e-mail sont facultatifs.",
            "La connexion avec un compte Google est proposée en plus de la connexion classique ; l'autorisation se déroule dans le navigateur, puis le serveur échange le code reçu.",
          ]),
          PrivacyBlock.paragraph(
            "Les identifiants sont personnels. Leur conservation relève de "
            "l'utilisateur : toute activité réalisée depuis un compte "
            "authentifié est rattachée à ce compte.",
          ),
          PrivacyBlock.placeholder(
            "EMPLACEMENT À COMPLÉTER : règles applicables en cas d'usage "
            'abusif, de suspension ou de fermeture de compte à '
            "l'initiative de l'éditeur (motifs, procédure, préavis, voie de "
            'recours). Ces engagements juridiques ne peuvent pas être déduits '
            'du code.',
          ),
        ]),

        PrivacySection(title: 'Suppression du compte', blocks: [
          PrivacyBlock.paragraph(
            "La suppression est accessible depuis l'application "
            '(Paramètres, puis « Supprimer mon compte ») et depuis une page '
            'web publique de suppression. La demande est traitée par le '
            'serveur, qui applique un délai de 30 jours avant effacement, '
            'comme décrit dans la politique de confidentialité.',
          ),
          PrivacyBlock.note(
            "La suppression efface le compte et les données associées côté "
            "serveur. Les messages déjà reçus par un correspondant restent "
            "chez lui : ils font partie de son propre historique.",
          ),
        ]),

        PrivacySection(title: 'Abonnement Premium', blocks: [
          PrivacyBlock.bullets('Fonctionnement vérifiable dans le code', [
            "Le montant affiché dans l'application au jour de la mise à jour est de 2 000 FCFA (devise XOF) ; c'est ce montant qui est transmis au serveur lors de la création du paiement.",
            "Le paiement est encaissé par un prestataire tiers (Leekpay / SaaSPay) via une page de paiement créée par le serveur OmniSMS : aucune donnée de paiement ni aucune clé de prestataire n'est présente dans l'application.",
            "L'abonnement n'est activé que lorsque le serveur confirme le statut : l'application interroge le statut du paiement puis le statut Premium du compte. Une simple redirection vers la page de paiement ne vaut pas activation.",
            "Un paiement annulé, refusé ou expiré est affiché comme tel : aucun accès Premium n'est ouvert.",
            "L'utilisateur peut actualiser manuellement le statut depuis l'écran d'abonnement.",
          ]),
          PrivacyBlock.placeholder(
            "EMPLACEMENT À COMPLÉTER : conditions tarifaires contractuelles "
            '(prix définitif et taxes, durée de validité, renouvellement '
            "automatique ou non, évolution des tarifs, remboursement, "
            'résiliation et droit de rétractation). Ces éléments relèvent du '
            "serveur et de la politique commerciale de l'éditeur ; ils ne sont "
            "pas lisibles dans le code de l'application.",
          ),
          PrivacyBlock.note(
            "Sur Android et iOS, la distribution d'un abonnement numérique "
            "peut imposer l'usage du système de paiement de la plateforme "
            '(Google Play Billing, achat intégré Apple). Cet aspect est '
            "décrit dans le rapport de préparation à la publication et doit "
            'être tranché avant toute mise en ligne sur ces magasins.',
          ),
        ]),

        PrivacySection(title: 'Limites techniques connues', blocks: [
          PrivacyBlock.bullets('État réel au jour de la mise à jour', [
            "Le service fonctionne en ligne : sans connexion, l'application affiche les données mises en cache et met en file les actions à synchroniser.",
            "Les notifications s'affichent tant que l'application est ouverte ou active en arrière-plan. La réception de notifications à distance, application fermée, n'est pas encore active : le jeton de notification poussée est obtenu par l'application mais aucun point d'entrée serveur n'est configuré pour le recevoir.",
            "Les SMS envoyés à des personnes hors OmniSMS dépendent du prestataire utilisé par le serveur : leur acheminement et les volumes disponibles ne sont pas garantis par l'application elle-même.",
            "La transcription des messages vocaux est un traitement automatique : elle peut comporter des erreurs et dépend de la qualité de l'enregistrement.",
          ]),
          PrivacyBlock.placeholder(
            'EMPLACEMENT À COMPLÉTER : engagements de disponibilité, niveaux '
            'de service, quotas de SMS et de stockage, ainsi que les limites '
            "de responsabilité de l'éditeur. Aucun engagement de ce type n'est "
            'affirmé ici faute de pouvoir être vérifié.',
          ),
        ]),

        PrivacySection(title: 'Données personnelles', blocks: [
          PrivacyBlock.paragraph(
            'Le traitement des données personnelles est décrit dans la '
            'politique de confidentialité, accessible depuis les mêmes '
            "écrans que cette page (Paramètres, Connexion, Inscription) et "
            "depuis l'adresse publique `/privacy`.",
          ),
        ]),

        PrivacySection(title: 'Propriété intellectuelle', blocks: [
          PrivacyBlock.placeholder(
            "EMPLACEMENT À COMPLÉTER : titularité de la marque et du code, "
            "étendue de la licence d'utilisation concédée à l'utilisateur, "
            'restrictions (copie, redistribution, ingénierie inverse) et '
            'statut des contenus publiés par les utilisateurs. Ces clauses '
            "doivent être rédigées par l'éditeur.",
          ),
        ]),

        PrivacySection(title: 'Droit applicable et litiges', blocks: [
          PrivacyBlock.placeholder(
            "EMPLACEMENT À COMPLÉTER : droit applicable, juridictions "
            'compétentes, procédure de réclamation préalable et, le cas '
            'échéant, dispositif de médiation de la consommation. Aucune '
            'juridiction ni aucune loi ne peut être déduite du code : cette '
            "mention doit être rédigée par l'éditeur.",
          ),
        ]),

        PrivacySection(title: 'Modifications de ces conditions', blocks: [
          PrivacyBlock.paragraph(
            'Cette page peut évoluer avec le service. La date de dernière mise '
            'à jour figure en haut de page.',
          ),
          PrivacyBlock.placeholder(
            "EMPLACEMENT À COMPLÉTER : modalités d'information des "
            'utilisateurs en cas de modification substantielle (canal, délai, '
            'conséquences en cas de refus).',
          ),
        ]),
      ];
}

/// Sélection du contenu selon la langue.
///
/// Le français est la langue de référence. Une nouvelle langue s'ajoute ici,
/// sans modifier la mise en page.
TermsContent termsContentFor(Locale? locale) {
  switch (locale?.languageCode) {
    // case 'en': return TermsContentEn();
    default:
      return TermsContentFr();
  }
}
