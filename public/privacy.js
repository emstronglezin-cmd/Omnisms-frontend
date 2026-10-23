/* ============================================================================
 * OmniSMS — Politique de confidentialité (PWA)
 * ----------------------------------------------------------------------------
 * Même contenu que `lib/screens/legal/privacy_content.dart` (application
 * Flutter). Deux bases de code distinctes, un seul texte : toute modification
 * doit être reportée des deux côtés.
 *
 * RÈGLE DE RÉDACTION (identique à la version Flutter) :
 *   - seules des informations VÉRIFIABLES dans le code sont affirmées ;
 *   - l'identité légale, les contacts et les durées de conservation sont des
 *     EMPLACEMENTS « À COMPLÉTER », jamais des inventions.
 *
 * Structure prête pour l'ajout d'autres langues : `PRIVACY_CONTENT.fr`, puis
 * `PRIVACY_CONTENT.en`, etc. + `pickPrivacyContent(lang)`.
 * ========================================================================== */
(function (global) {
  'use strict';

  var fr = {
    updatedOn: '23 octobre 2026',
    sections: [
      {
        title: 'Introduction',
        blocks: [
          { type: 'p', text: "Cette page explique quelles données OmniSMS traite, pourquoi, à qui elles sont transmises et comment vous gardez la main dessus. Elle décrit le fonctionnement réel de l'application : rien n'est affirmé ici qui ne soit pas vérifiable dans le code du service." },
          { type: 'note', text: "Résumé honnête : OmniSMS est un service de messagerie. Pour qu'un message arrive, il doit transiter par nos serveurs et, quand votre correspondant n'utilise pas l'application, par un opérateur SMS. Vos messages ne sont donc pas chiffrés de bout en bout, et ils ne sont pas « jamais partagés » : les cas de transmission sont détaillés plus bas." }
        ]
      },
      {
        title: 'Responsable du traitement',
        blocks: [
          { type: 'todo', text: "EMPLACEMENT À COMPLÉTER PAR L'ÉDITEUR AVANT PUBLICATION : raison sociale, forme juridique, adresse postale, pays d'établissement, numéro d'enregistrement et identité du représentant légal. Aucune information légale n'a été inventée ici." },
          { type: 'todo', text: "EMPLACEMENT À COMPLÉTER : adresse e-mail de contact pour l'exercice de vos droits (accès, rectification, suppression, opposition). Cette adresse doit exister et être réellement surveillée avant la publication de la page." }
        ]
      },
      {
        title: 'Données que nous traitons',
        blocks: [
          { type: 'ul', text: 'Données de compte', items: [
            "Numéro de téléphone : utilisé comme identifiant, vérifié par un code à usage unique (OTP) envoyé par SMS.",
            "Nom d'utilisateur, nom affiché, adresse e-mail (facultative).",
            "Mot de passe : stocké haché côté serveur (bcrypt). Il n'est jamais conservé en clair et ne peut pas être relu par nos équipes.",
            "Photo de profil : le fichier que vous choisissez est transmis au serveur, qui le conserve et le renvoie à l'application pour l'affichage."
          ]},
          { type: 'ul', text: 'Données issues de Google (si vous utilisez ce mode de connexion)', items: [
            "Identifiant Google, adresse e-mail, nom et photo de profil transmis par Google lors de l'autorisation.",
            "Contacts Google : uniquement si vous lancez vous-même l'import. Le serveur récupère alors les noms et numéros pour détecter qui utilise déjà OmniSMS."
          ]},
          { type: 'ul', text: 'Contacts', items: [
            "Carnet d'adresses : uniquement si vous lancez la synchronisation. Les numéros sont envoyés au serveur pour savoir qui est déjà inscrit ; le serveur renvoie la liste avec le nom, le numéro et le statut OmniSMS de chacun.",
            "Les contacts qui n'utilisent pas OmniSMS restent visibles dans votre application mais ne reçoivent rien de notre part tant que vous ne leur envoyez pas de message."
          ]},
          { type: 'ul', text: 'Messages et pièces jointes', items: [
            "Contenu du message, date et heure, expéditeur, destinataire et statut (envoyé, remis, lu).",
            "Messages vocaux et, le cas échéant, leur transcription automatique.",
            "Groupes : nom, description, photo et liste des membres."
          ]},
          { type: 'ul', text: 'Données techniques', items: [
            "Journaux de fonctionnement : erreurs, identifiants techniques, horodatages. Le contenu de vos messages n'est pas écrit dans nos journaux.",
            "Jetons d'authentification permettant de maintenir votre session ouverte."
          ]},
          { type: 'ul', text: 'Abonnements, crédits et paiements', items: [
            "Crédits, abonnements et historique d'opérations. Les paiements sont traités par des prestataires spécialisés ; nous ne recevons pas votre code de paiement."
          ]}
        ]
      },
      {
        title: 'Pourquoi nous les traitons',
        blocks: [
          { type: 'ul', text: 'Finalités', items: [
            "Fournir le service : transmettre vos messages, afficher vos conversations et vos groupes.",
            "Détecter, parmi vos contacts, ceux qui utilisent OmniSMS, afin d'acheminer vos messages par le bon canal.",
            "Vérifier votre numéro de téléphone et sécuriser votre compte.",
            "Afficher des notifications de nouveaux messages.",
            "Assurer la sécurité du service : détection des abus, limitation des envois, antifraude.",
            "Gérer les crédits et les abonnements.",
            "Diffuser des publicités : uniquement sur Android, uniquement pour les comptes non premium, et uniquement si le module publicitaire est activé."
          ]}
        ]
      },
      {
        title: 'Permissions et accès à votre appareil',
        blocks: [
          { type: 'ul', text: 'Application Android', items: [
            "Internet : indispensable pour communiquer avec le serveur.",
            "État du réseau : permet d'adapter le comportement de l'application à la qualité de la connexion.",
            "Contacts : uniquement pour la synchronisation de votre carnet, à votre demande.",
            "Microphone : uniquement pour enregistrer un message vocal.",
            "Notifications : uniquement pour vous prévenir de l'arrivée d'un message."
          ]},
          { type: 'ul', text: 'Application iOS', items: [
            "Contacts : pour la synchronisation de votre carnet, à votre demande.",
            "Microphone : pour les messages vocaux.",
            "Bibliothèque photo : uniquement si vous choisissez une image existante comme photo de profil."
          ]},
          { type: 'p', text: "Aucune de ces permissions n'est utilisée en arrière-plan à votre insu : chacune correspond à une action que vous déclenchez dans l'application. La version web (navigateur) ne demande aucune permission permanente." }
        ]
      },
      {
        title: 'À qui vos données sont transmises',
        blocks: [
          { type: 'ul', text: 'Prestataires techniques réellement utilisés', items: [
            "Google (Firebase / Firestore) : hébergement des données et authentification.",
            "Google OAuth : si vous vous connectez avec Google ou importez vos contacts Google.",
            "Infobip : opérateur utilisé pour envoyer un SMS vers un numéro qui n'utilise pas l'application.",
            "Render : hébergement du serveur de l'application.",
            "Vercel : hébergement de cette version web accessible depuis un navigateur.",
            "Leekpay et SaaSPay : traitement des paiements et recharges de crédits.",
            "Start.io : régie publicitaire, uniquement sur Android."
          ]},
          { type: 'note', text: "Point important à comprendre : lorsqu'un message est envoyé à un numéro qui n'utilise pas OmniSMS, il quitte l'application et transite par un opérateur de téléphonie (Infobip). Il est donc techniquement impossible de promettre qu'un message ne sort jamais de nos systèmes." }
        ]
      },
      {
        title: 'Durée de conservation',
        blocks: [
          { type: 'p', text: "Une seule durée est définie techniquement à ce jour : après une demande de suppression de compte, vos données sont effacées ou anonymisées, puis purgées définitivement au bout de 30 jours (délai configurable côté serveur)." },
          { type: 'todo', text: "EMPLACEMENT À COMPLÉTER : durées de conservation des messages, des journaux techniques, des contacts et des pièces jointes. Ces durées ne sont aujourd'hui définies nulle part dans le code : elles doivent être décidées par l'éditeur, annoncées ici et appliquées techniquement." }
        ]
      },
      {
        title: 'Sécurité',
        blocks: [
          { type: 'ul', text: 'Mesures effectivement en place', items: [
            "Échanges chiffrés entre l'application et le serveur (HTTPS).",
            "Mots de passe hachés avec bcrypt : ils ne sont jamais stockés ni transmis en clair.",
            "Authentification par jeton, révocable lors de la suppression du compte.",
            "Numéros de téléphone hachés (SHA-256 avec sel) dans les demandes de suppression : ils n'y apparaissent jamais en clair."
          ]},
          { type: 'note', text: "Ce que nous ne prétendons pas : les messages ne sont pas chiffrés de bout en bout. Ils sont stockés sur nos serveurs pour pouvoir être distribués à vos correspondants, y compris quand votre téléphone est éteint. N'utilisez donc pas l'application pour transmettre des secrets dont la divulgation serait critique." }
        ]
      },
      {
        title: 'Vos droits',
        blocks: [
          { type: 'p', text: "Selon la réglementation applicable dans votre pays, vous pouvez demander l'accès à vos données, leur rectification, leur suppression, la limitation ou l'opposition à certains traitements." },
          { type: 'ul', text: 'Ce que vous pouvez faire directement', items: [
            "Consulter et corriger votre profil (nom, e-mail, photo) depuis les paramètres.",
            "Supprimer votre compte depuis l'application : Paramètres → Supprimer mon compte.",
            "Supprimer votre compte depuis le web, via la page publique de suppression de compte fournie par le service.",
            "Révoquer à tout moment les permissions (contacts, microphone, notifications) dans les réglages de votre appareil.",
            "Désactiver les notifications depuis les paramètres de l'application."
          ]},
          { type: 'todo', text: "EMPLACEMENT À COMPLÉTER : procédure et adresse pour exercer vos droits par écrit, délai de réponse annoncé, et autorité de contrôle compétente (autorité de protection des données de votre pays)." }
        ]
      },
      {
        title: 'Suppression du compte',
        blocks: [
          { type: 'p', text: "La suppression est une fonctionnalité réellement disponible, pas une promesse. Vous pouvez supprimer votre compte depuis l'application (Paramètres → Supprimer mon compte) ou depuis la page web publique prévue à cet effet, qui fonctionne même si vous n'avez plus accès à l'application." },
          { type: 'ul', text: 'Ce qui se passe', items: [
            "Votre profil (nom, e-mail, photo, numéro de téléphone) est effacé ou anonymisé.",
            "Vos contacts et vos conversations sont supprimés.",
            "Vos crédits restants sont perdus : ils ne sont pas remboursables.",
            "Les données sont purgées définitivement de nos systèmes au bout de 30 jours."
          ]}
        ]
      },
      {
        title: 'Publicité',
        blocks: [
          { type: 'p', text: "Un module publicitaire est intégré à l'application Android (Start.io). Il est désactivé pour les comptes premium, et il n'est initialisé ni sur iPhone ni sur la version web : aucune donnée publicitaire ne peut donc y être collectée." },
          { type: 'todo', text: "EMPLACEMENT À COMPLÉTER AVANT ACTIVATION : identifiant d'application Start.io, base légale du ciblage publicitaire, et mention d'un éventuel identifiant publicitaire collecté par la régie. En l'état, le module est présent mais non configuré." }
        ]
      },
      {
        title: 'Mineurs',
        blocks: [
          { type: 'todo', text: "EMPLACEMENT À COMPLÉTER : âge minimum d'utilisation et sort des comptes de mineurs. Aucune règle d'âge n'est aujourd'hui appliquée techniquement dans l'application : cette section doit être tranchée par l'éditeur." }
        ]
      },
      {
        title: 'Modifications de cette page',
        blocks: [
          { type: 'p', text: "Cette page peut évoluer avec l'application. La date de dernière mise à jour figure en haut de page. Toute modification substantielle (nouvelle finalité, nouveau destinataire, nouvelle durée de conservation) devra être signalée aux utilisateurs." }
        ]
      }
    ]
  };

  var CONTENT = { fr: fr };

  /* ── Rendu ───────────────────────────────────────────────────────────── */

  function escapeHtml(s) {
    return String(s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function renderBlock(b) {
    if (b.type === 'p') {
      return '<p class="privacy-p">' + escapeHtml(b.text) + '</p>';
    }
    if (b.type === 'note') {
      return '<div class="privacy-note">' + escapeHtml(b.text) + '</div>';
    }
    if (b.type === 'todo') {
      return '<div class="privacy-todo"><strong>À compléter</strong> — ' +
        escapeHtml(b.text) + '</div>';
    }
    if (b.type === 'ul') {
      var lis = (b.items || []).map(function (i) {
        return '<li>' + escapeHtml(i) + '</li>';
      }).join('');
      return '<p class="privacy-ul-title">' + escapeHtml(b.text) + '</p>' +
        '<ul class="privacy-ul">' + lis + '</ul>';
    }
    return '';
  }

  /** Rend la politique dans l'élément `el`. */
  function render(el, lang) {
    if (!el) return;
    var c = CONTENT[lang] || CONTENT.fr;
    var html = '<div class="privacy-card">' +
      '<h1 class="privacy-h1">Politique de confidentialité</h1>' +
      '<p class="privacy-updated">Dernière mise à jour : ' +
      escapeHtml(c.updatedOn) + '</p>' +
      '<div class="privacy-note">Cette page décrit le fonctionnement réel de ' +
      "l'application. Les emplacements marqués « À compléter » doivent être " +
      "renseignés par l'éditeur avant publication : ils concernent l'identité " +
      'légale, les contacts et les durées de conservation.</div>';

    c.sections.forEach(function (s) {
      html += '<section class="privacy-section">' +
        '<h2 class="privacy-h2">' + escapeHtml(s.title) + '</h2>' +
        s.blocks.map(renderBlock).join('') +
        '</section>';
    });

    html += '<p class="privacy-footer">Document technique décrivant les ' +
      "traitements réellement mis en œuvre. Il ne constitue pas un avis " +
      "juridique et n'a pas valeur d'engagement contractuel tant que les " +
      "emplacements « À compléter » n'ont pas été validés par l'éditeur.</p>";
    html += '</div>';

    el.innerHTML = html;
  }

  /** Vrai si l'URL courante est la route publique /privacy. */
  function isRoute(pathname) {
    var p = String(pathname || (global.location && global.location.pathname) || '');
    return p.replace(/\/+$/, '') === '/privacy';
  }

  global.OmniSmsPrivacy = {
    content: CONTENT,
    render: render,
    isRoute: isRoute
  };
})(window);
