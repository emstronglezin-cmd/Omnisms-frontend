import 'dart:ui' show Locale;

/// Contenu de la politique de confidentialité, séparé de la mise en page.
///
/// Structure volontairement internationalisable : [PrivacyContent] décrit la
/// page, chaque langue fournit sa propre implémentation ([PrivacyContentFr]).
/// Ajouter une langue = ajouter une classe + un `case` dans
/// [privacyContentFor].
///
/// RÈGLE DE RÉDACTION (respectée ci-dessous) :
///   - seules des informations VÉRIFIABLES dans le code sont affirmées ;
///   - tout ce qui relève de l'identité légale ou d'un engagement juridique
///     est un emplacement explicite `PrivacyBlockKind.placeholder`, jamais
///     une invention (pas d'e-mail, pas de raison sociale, pas de durée de
///     conservation fantaisiste, pas de chiffrement de bout en bout).
abstract class PrivacyContent {
  /// Date de dernière mise à jour, affichée en haut de page.
  String get updatedOn;

  List<PrivacySection> get sections;
}

/// Type de bloc : influe uniquement sur le rendu.
enum PrivacyBlockKind {
  /// Paragraphe courant.
  paragraph,

  /// Liste à puces.
  bullets,

  /// Encadré d'information (ton neutre).
  note,

  /// Emplacement À COMPLÉTER par l'éditeur avant publication.
  /// Rendu volontairement visible : la page n'est pas publiable en l'état.
  placeholder,
}

class PrivacyBlock {
  const PrivacyBlock(this.kind, this.text, {this.items});

  final PrivacyBlockKind kind;
  final String text;

  /// Éléments de liste (pour [PrivacyBlockKind.bullets]).
  final List<String>? items;

  factory PrivacyBlock.paragraph(String text) =>
      PrivacyBlock(PrivacyBlockKind.paragraph, text);

  factory PrivacyBlock.bullets(String title, List<String> items) =>
      PrivacyBlock(PrivacyBlockKind.bullets, title, items: items);

  factory PrivacyBlock.note(String text) =>
      PrivacyBlock(PrivacyBlockKind.note, text);

  factory PrivacyBlock.placeholder(String text) =>
      PrivacyBlock(PrivacyBlockKind.placeholder, text);
}

class PrivacySection {
  const PrivacySection({required this.title, required this.blocks});

  final String title;
  final List<PrivacyBlock> blocks;
}

/// Implémentation française.
///
/// Chaque affirmation ici est reliée à un élément réel du code :
///   - `routes/me.js`, `routes/auth.js`     → compte, mot de passe (bcrypt), avatar
///   - `routes/otp.js`                      → vérification du numéro
///   - `services/googleOAuth.js`            → connexion et contacts Google
///   - `routes/contacts.v2.js`              → synchronisation du carnet
///   - `services/messageRouter.js`, `services/infobip.js` → SMS sortants
///   - `routes/accountDeletion.js`          → suppression de compte (30 jours)
///   - `lib/services/ads_service.dart`      → publicité Start.io (Android)
///   - `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`
///                                          → permissions demandées
class PrivacyContentFr implements PrivacyContent {
  @override
  String get updatedOn => '23 octobre 2026';

  @override
  List<PrivacySection> get sections => [
        PrivacySection(title: 'Introduction', blocks: [
          PrivacyBlock.paragraph(
            'Cette page explique quelles données OmniSMS traite, pourquoi, à '
                'qui elles sont transmises et comment vous gardez la main '
                'dessus. Elle décrit le fonctionnement réel de '
                "l'application : rien n'est affirmé ici qui ne soit pas "
                'vérifiable dans le code du service.',
          ),
          PrivacyBlock.note(
            'Résumé honnête : OmniSMS est un service de messagerie. Pour '
                "qu'un message arrive, il doit transiter par nos serveurs "
                "et, quand votre correspondant n'utilise pas l'application, "
                "par un opérateur SMS. Vos messages ne sont donc pas "
                'chiffrés de bout en bout, et ils ne sont pas "jamais '
                'partagés" : les cas de transmission sont détaillés plus bas.',
          ),
        ]),

        PrivacySection(title: 'Responsable du traitement', blocks: [
          PrivacyBlock.placeholder(
            "EMPLACEMENT À COMPLÉTER PAR L'ÉDITEUR AVANT PUBLICATION : raison "
                'sociale, forme juridique, adresse postale, pays '
                "d'établissement, numéro d'enregistrement, et identité du "
                'représentant légal. Aucune information légale na pas été '
                "inventée ici : ces champs doivent être renseignés par "
                "l'éditeur de l'application.",
          ),
          PrivacyBlock.placeholder(
            "EMPLACEMENT À COMPLÉTER : adresse e-mail de contact pour "
                "l'exercice de vos droits (accès, rectification, "
                'suppression, opposition). Cette adresse doit exister et être '
                'réellement surveillée avant la publication de la page.',
          ),
        ]),

        PrivacySection(title: 'Données que nous traitons', blocks: [
          PrivacyBlock.bullets('Données de compte', [
            "Numéro de téléphone : utilisé comme identifiant, vérifié par un code à usage unique (OTP) envoyé par SMS.",
            "Nom d'utilisateur, nom affiché, adresse e-mail (facultative).",
            "Mot de passe : stocké haché côté serveur (bcrypt). Il n'est jamais conservé en clair et ne peut pas être relu par nos équipes.",
            "Photo de profil : le fichier que vous choisissez est transmis au serveur, qui le conserve et le renvoie à l'application pour l'affichage.",
          ]),
          PrivacyBlock.bullets('Données issues de Google (si vous utilisez ce mode de connexion)', [
            "Identifiant Google, adresse e-mail, nom et photo de profil transmis par Google lors de l'autorisation.",
            "Contacts Google : uniquement si vous lancez vous-même l'import. Le serveur récupère alors les noms et numéros pour détecter qui utilise déjà OmniSMS.",
          ]),
          PrivacyBlock.bullets('Contacts', [
            "Carnet d'adresses de l'appareil : uniquement si vous accordez la permission et lancez la synchronisation. Les numéros sont envoyés au serveur pour savoir qui est déjà inscrit ; le serveur renvoie la liste avec le nom, le numéro et le statut OmniSMS de chacun.",
            "Les contacts qui n'utilisent pas OmniSMS restent visibles dans votre application mais ne reçoivent rien de notre part tant que vous ne leur envoyez pas de message.",
          ]),
          PrivacyBlock.bullets('Messages et pièces jointes', [
            "Contenu du message, date et heure, expéditeur, destinataire et statut (envoyé, remis, lu).",
            "Messages vocaux et, le cas échéant, leur transcription automatique.",
            "Groupes : nom, description, photo et liste des membres.",
          ]),
          PrivacyBlock.bullets('Données techniques', [
            "Journaux de fonctionnement : erreurs, identifiants techniques, horodatages. Le contenu de vos messages n'est pas écrit dans nos journaux.",
            "Jetons d'authentification permettant de maintenir votre session ouverte.",
          ]),
          PrivacyBlock.bullets('Abonnements, crédits et paiements', [
            "Crédits, abonnements et historique d'opérations. Les paiements sont traités par des prestataires spécialisés ; nous ne recevons pas votre code de paiement.",
          ]),
        ]),

        PrivacySection(title: 'Pourquoi nous les traitons', blocks: [
          PrivacyBlock.bullets('Finalités', [
            "Fournir le service : transmettre vos messages, afficher vos conversations et vos groupes.",
            "Détecter, parmi vos contacts, ceux qui utilisent OmniSMS, afin d'acheminer vos messages par le bon canal.",
            "Vérifier votre numéro de téléphone et sécuriser votre compte.",
            "Afficher des notifications de nouveaux messages.",
            "Assurer la sécurité du service : détection des abus, limitation des envois, antifraude.",
            "Gérer les crédits et les abonnements.",
            "Diffuser des publicités : uniquement sur Android, uniquement pour les comptes non premium, et uniquement si le module publicitaire est activé.",
          ]),
        ]),

        PrivacySection(title: 'Permissions demandées sur votre appareil', blocks: [
          PrivacyBlock.bullets('Android', [
            "Internet : indispensable pour communiquer avec le serveur.",
            "État du réseau : permet d'adapter le comportement de l'application à la qualité de la connexion.",
            "Contacts : uniquement pour la synchronisation de votre carnet, à votre demande.",
            "Microphone : uniquement pour enregistrer un message vocal.",
            "Notifications : uniquement pour vous prévenir de l'arrivée d'un message.",
          ]),
          PrivacyBlock.bullets('iOS', [
            "Contacts : pour la synchronisation de votre carnet, à votre demande.",
            "Microphone : pour les messages vocaux.",
            "Bibliothèque photo : uniquement si vous choisissez une image existante comme photo de profil.",
          ]),
          PrivacyBlock.paragraph(
            "Aucune de ces permissions n'est utilisée en arrière-plan à votre "
                'insu : chacune correspond à une action que vous déclenchez '
                "dans l'application.",
          ),
        ]),

        PrivacySection(title: 'À qui vos données sont transmises', blocks: [
          PrivacyBlock.bullets('Prestataires techniques réellement utilisés', [
            "Google (Firebase / Firestore) : hébergement des données et authentification.",
            "Google OAuth : si vous vous connectez avec Google ou importez vos contacts Google.",
            "Infobip : opérateur utilisé pour envoyer un SMS vers un numéro qui n'utilise pas l'application.",
            "Render : hébergement du serveur de l'application.",
            "Vercel : hébergement de la version web accessible depuis un navigateur.",
            "Leekpay et SaaSPay : traitement des paiements et recharges de crédits.",
            "Start.io : régie publicitaire, uniquement sur Android.",
          ]),
          PrivacyBlock.note(
            "Point important à comprendre : lorsqu'un message est envoyé à un "
                "numéro qui n'utilise pas OmniSMS, il quitte l'application et "
                'transite par un opérateur de téléphonie (Infobip). Il est '
                'donc techniquement impossible de promettre qu\'un message ne '
                'sort jamais de nos systèmes.',
          ),
        ]),

        PrivacySection(title: 'Durée de conservation', blocks: [
          PrivacyBlock.paragraph(
            'Une seule durée est définie techniquement à ce jour : après une '
                'demande de suppression de compte, vos données sont effacées '
                'ou anonymisées, puis purgées définitivement au bout de '
                '30 jours (délai configurable côté serveur).',
          ),
          PrivacyBlock.placeholder(
            'EMPLACEMENT À COMPLÉTER : durées de conservation des messages, '
                'des journaux techniques, des contacts et des pièces jointes. '
                "Ces durées ne sont aujourd'hui définies nulle part dans le "
                "code : elles doivent être décidées par l'éditeur, annoncées "
                'ici, et appliquées techniquement.',
          ),
        ]),

        PrivacySection(title: 'Sécurité', blocks: [
          PrivacyBlock.bullets('Mesures effectivement en place', [
            "Échanges chiffrés entre l'application et le serveur (HTTPS).",
            "Mots de passe hachés avec bcrypt : ils ne sont jamais stockés ni transmis en clair.",
            "Authentification par jeton, révocable lors de la suppression du compte.",
            "Numéros de téléphone hachés (SHA-256 avec sel) dans les demandes de suppression : ils n'y apparaissent jamais en clair.",
          ]),
          PrivacyBlock.note(
            "Ce que nous ne prétendons pas : les messages ne sont pas "
                "chiffrés de bout en bout. Ils sont stockés sur nos serveurs "
                "pour pouvoir être distribués à vos correspondants, y compris "
                "quand votre téléphone est éteint. N'utilisez donc pas "
                "l'application pour transmettre des secrets dont la divulgation "
                'serait critique.',
          ),
        ]),

        PrivacySection(title: 'Vos droits', blocks: [
          PrivacyBlock.paragraph(
            'Selon la réglementation applicable dans votre pays, vous pouvez '
                "demander l'accès à vos données, leur rectification, leur "
                "suppression, la limitation ou l'opposition à certains "
                'traitements.',
          ),
          PrivacyBlock.bullets('Ce que vous pouvez faire directement', [
            "Consulter et corriger votre profil (nom, e-mail, photo) depuis les paramètres de l'application.",
            "Supprimer votre compte depuis l'application : Paramètres → Supprimer mon compte.",
            "Supprimer votre compte depuis le web, via la page publique de suppression de compte fournie par le service.",
            "Révoquer à tout moment les permissions de l'appareil (contacts, microphone, notifications) dans les réglages de votre téléphone.",
            "Désactiver les notifications depuis les paramètres de l'application.",
          ]),
          PrivacyBlock.placeholder(
            "EMPLACEMENT À COMPLÉTER : procédure et adresse pour exercer vos "
                "droits par écrit, délai de réponse annoncé, et autorité de "
                "contrôle compétente (ex. CIL / APDP au Burkina Faso, CNIL en "
                'France, ou autorité équivalente selon le pays de résidence).',
          ),
        ]),

        PrivacySection(title: 'Suppression du compte', blocks: [
          PrivacyBlock.paragraph(
            "La suppression est une fonctionnalité réellement disponible, pas "
                'une promesse. Vous pouvez supprimer votre compte depuis '
                "l'application (Paramètres → Supprimer mon compte) ou depuis "
                'la page web publique prévue à cet effet, qui fonctionne même '
                "si vous n'avez plus accès à l'application.",
          ),
          PrivacyBlock.bullets('Ce qui se passe', [
            "Votre profil (nom, e-mail, photo, numéro de téléphone) est effacé ou anonymisé.",
            "Vos contacts et vos conversations sont supprimés.",
            "Vos crédits restants sont perdus : ils ne sont pas remboursables.",
            "Les données sont purgées définitivement de nos systèmes au bout de 30 jours.",
          ]),
        ]),

        PrivacySection(title: 'Publicité', blocks: [
          PrivacyBlock.paragraph(
            "Un module publicitaire est intégré à l'application Android "
                '(Start.io). Il est désactivé pour les comptes premium, et il '
                "n'est initialisé ni sur iPhone ni sur la version web : aucune "
                'donnée publicitaire ne peut donc y être collectée.',
          ),
          PrivacyBlock.placeholder(
            "EMPLACEMENT À COMPLÉTER AVANT ACTIVATION : identifiant "
                "d'application Start.io, base légale du ciblage publicitaire, "
                "et mention d'un éventuel identifiant publicitaire (AAID) "
                "collecté par la régie. En l'état, le module est présent mais "
                "non configuré : aucune publicité n'est diffusée.",
          ),
        ]),

        PrivacySection(title: 'Mineurs', blocks: [
          PrivacyBlock.placeholder(
            "EMPLACEMENT À COMPLÉTER : âge minimum d'utilisation et sort des "
                "comptes de mineurs. Aucune règle d'âge n'est aujourd'hui "
                "appliquée techniquement dans l'application : cette section "
                "doit être tranchée par l'éditeur.",
          ),
        ]),

        PrivacySection(title: 'Modifications de cette page', blocks: [
          PrivacyBlock.paragraph(
            "Cette page peut évoluer avec l'application. La date de dernière "
                "mise à jour figure en haut de page. Toute modification "
                "substantielle (nouvelle finalité, nouveau destinataire, "
                "nouvelle durée de conservation) devra être signalée aux "
                "utilisateurs.",
          ),
        ]),
      ];
}

/// Sélection du contenu selon la langue.
///
/// Le français est la langue de référence. Une nouvelle langue s'ajoute
/// simplement ici, sans modifier la mise en page.
PrivacyContent privacyContentFor(Locale? locale) {
  switch (locale?.languageCode) {
    // case 'en': return PrivacyContentEn();
    default:
      return PrivacyContentFr();
  }
}
