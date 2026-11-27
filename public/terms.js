/* ============================================================================
 * OmniSMS : Conditions générales d'utilisation (PWA)
 * ----------------------------------------------------------------------------
 * Même contenu que `lib/screens/legal/terms_content.dart` (application
 * Flutter). Deux bases de code distinctes, un seul texte : toute modification
 * doit être reportée des deux côtés.
 *
 * RÈGLE DE RÉDACTION (identique à la version Flutter et à privacy.js) :
 *   - seules des informations VÉRIFIABLES dans le code sont affirmées ;
 *   - l'identité légale, les engagements contractuels, les tarifs et le droit
 *     applicable sont des EMPLACEMENTS « À COMPLÉTER », jamais des inventions.
 *
 * Mise en page : les classes CSS `privacy-*` sont réutilisées telles quelles
 * (même identité visuelle que la page de confidentialité, aucune nouvelle
 * feuille de style).
 *
 * Structure prête pour l'ajout d'autres langues : `TERMS_CONTENT.fr`, puis
 * `TERMS_CONTENT.en`, etc.
 * ========================================================================== */
(function (global) {
  'use strict';

  var fr = {
    updatedOn: '11 octobre 2026',
    sections: [
      {
        title: 'Objet de ce document',
        blocks: [
          { type: 'p', text: "Cette page décrit les conditions dans lesquelles l'application OmniSMS est mise à disposition et utilisée. Elle explique ce que le service fait réellement, comment un compte fonctionne, comment l'abonnement Premium est activé et quelles sont les limites techniques connues au jour de la mise à jour." },
          { type: 'note', text: "Les blocs marqués « À compléter » correspondent à des mentions juridiques qui ne peuvent pas être déduites du code : identité de l'éditeur, obligations des utilisateurs, responsabilité, droit applicable. Ils doivent être renseignés et validés par l'éditeur avant toute publication. Tant que ces blocs sont présents, cette page ne constitue pas un contrat opposable." }
        ]
      },
      {
        title: 'Éditeur du service',
        blocks: [
          { type: 'todo', text: "EMPLACEMENT À COMPLÉTER PAR L'ÉDITEUR AVANT PUBLICATION : raison sociale, forme juridique, adresse postale, pays d'établissement, numéro d'enregistrement, représentant légal et adresse e-mail de contact réellement surveillée. Aucune information légale n'a été inventée ici." },
          { type: 'p', text: "Éléments techniques vérifiables dans la configuration du projet : le serveur d'OmniSMS est hébergé par un prestataire tiers (Render) et l'application web est servie comme un site statique (Vercel / Firebase Hosting, répertoire build/web)." },
          { type: 'todo', text: "EMPLACEMENT À COMPLÉTER : mentions formelles de l'hébergeur (nom, adresse postale, contact) telles qu'exigées par la réglementation applicable à l'éditeur." }
        ]
      },
      {
        title: 'Le service',
        blocks: [
          { type: 'p', text: "OmniSMS est une application de messagerie disponible sous forme d'application Android et d'application web installable (PWA). Elle permet :" },
          { type: 'ul', text: 'Fonctionnalités disponibles', items: [
            "Échanger des messages texte, des messages vocaux et des images avec d'autres comptes OmniSMS.",
            "Envoyer des SMS à des personnes qui n'utilisent pas l'application : l'envoi passe par un prestataire SMS choisi côté serveur.",
            'Créer et gérer des groupes (nom, description, photo, membres).',
            "Obtenir la transcription automatique d'un message vocal, traitée côté serveur.",
            "Synchroniser son carnet d'adresses pour identifier qui utilise déjà OmniSMS, et importer ses contacts Google si ce mode de connexion est utilisé.",
            "Consulter une partie de ses données hors connexion : un cache local conserve contacts, messages, groupes et profil, et les actions en attente sont mises en file."
          ]},
          { type: 'note', text: "Le service ne contient aucune publicité : aucune régie publicitaire ni identifiant publicitaire n'est intégré à l'application." }
        ]
      },
      {
        title: 'Compte et accès',
        blocks: [
          { type: 'ul', text: 'Ce que le code met réellement en œuvre', items: [
            "Un compte est rattaché à un numéro de téléphone, vérifié par un code à usage unique envoyé par SMS.",
            "Le nom d'utilisateur accepte les lettres, les chiffres et les caractères « _ », « . » et « - » ; il doit être unique.",
            "Le mot de passe est transmis au serveur et conservé haché (bcrypt) : il n'est pas stocké en clair.",
            "La photo de profil, le nom affiché et l'adresse e-mail sont facultatifs.",
            "La connexion avec un compte Google est proposée en plus de la connexion classique ; l'autorisation se déroule dans le navigateur, puis le serveur échange le code reçu."
          ]},
          { type: 'p', text: "Les identifiants sont personnels. Leur conservation relève de l'utilisateur : toute activité réalisée depuis un compte authentifié est rattachée à ce compte." },
          { type: 'todo', text: "EMPLACEMENT À COMPLÉTER : règles applicables en cas d'usage abusif, de suspension ou de fermeture de compte à l'initiative de l'éditeur (motifs, procédure, préavis, voie de recours). Ces engagements juridiques ne peuvent pas être déduits du code." }
        ]
      },
      {
        title: 'Suppression du compte',
        blocks: [
          { type: 'p', text: "La suppression est accessible depuis l'application (Paramètres, puis « Supprimer mon compte ») et depuis une page web publique de suppression. La demande est traitée par le serveur, qui applique un délai de 30 jours avant effacement, comme décrit dans la politique de confidentialité." },
          { type: 'note', text: "La suppression efface le compte et les données associées côté serveur. Les messages déjà reçus par un correspondant restent chez lui : ils font partie de son propre historique." }
        ]
      },
      {
        title: 'Abonnement Premium',
        blocks: [
          { type: 'ul', text: 'Fonctionnement vérifiable dans le code', items: [
            "Le montant affiché dans l'application au jour de la mise à jour est de 2 000 FCFA (devise XOF) ; c'est ce montant qui est transmis au serveur lors de la création du paiement.",
            "Le paiement est encaissé par un prestataire tiers (Leekpay / SaaSPay) via une page de paiement créée par le serveur OmniSMS : aucune donnée de paiement ni aucune clé de prestataire n'est présente dans l'application.",
            "L'abonnement n'est activé que lorsque le serveur confirme le statut : l'application interroge le statut du paiement puis le statut Premium du compte. Une simple redirection vers la page de paiement ne vaut pas activation.",
            "Un paiement annulé, refusé ou expiré est affiché comme tel : aucun accès Premium n'est ouvert.",
            "L'utilisateur peut actualiser manuellement le statut depuis l'écran d'abonnement."
          ]},
          { type: 'todo', text: "EMPLACEMENT À COMPLÉTER : conditions tarifaires contractuelles (prix définitif et taxes, durée de validité, renouvellement automatique ou non, évolution des tarifs, remboursement, résiliation et droit de rétractation). Ces éléments relèvent du serveur et de la politique commerciale de l'éditeur ; ils ne sont pas lisibles dans le code de l'application." },
          { type: 'note', text: "Sur Android et iOS, la distribution d'un abonnement numérique peut imposer l'usage du système de paiement de la plateforme (Google Play Billing, achat intégré Apple). Cet aspect doit être tranché avant toute mise en ligne sur ces magasins." }
        ]
      },
      {
        title: 'Limites techniques connues',
        blocks: [
          { type: 'ul', text: 'État réel au jour de la mise à jour', items: [
            "Le service fonctionne en ligne : sans connexion, l'application affiche les données mises en cache et met en file les actions à synchroniser.",
            "Les notifications s'affichent tant que l'application est ouverte ou active en arrière-plan. La réception de notifications à distance, application fermée, n'est pas encore active : le jeton de notification poussée est obtenu par l'application mais aucun point d'entrée serveur n'est configuré pour le recevoir.",
            "Les SMS envoyés à des personnes hors OmniSMS dépendent du prestataire utilisé par le serveur : leur acheminement et les volumes disponibles ne sont pas garantis par l'application elle-même.",
            "La transcription des messages vocaux est un traitement automatique : elle peut comporter des erreurs et dépend de la qualité de l'enregistrement."
          ]},
          { type: 'todo', text: "EMPLACEMENT À COMPLÉTER : engagements de disponibilité, niveaux de service, quotas de SMS et de stockage, ainsi que les limites de responsabilité de l'éditeur. Aucun engagement de ce type n'est affirmé ici faute de pouvoir être vérifié." }
        ]
      },
      {
        title: 'Données personnelles',
        blocks: [
          { type: 'p', text: "Le traitement des données personnelles est décrit dans la politique de confidentialité, accessible depuis les mêmes écrans que cette page (Paramètres, Connexion, Inscription) et depuis l'adresse publique /privacy." }
        ]
      },
      {
        title: 'Propriété intellectuelle',
        blocks: [
          { type: 'todo', text: "EMPLACEMENT À COMPLÉTER : titularité de la marque et du code, étendue de la licence d'utilisation concédée à l'utilisateur, restrictions (copie, redistribution, ingénierie inverse) et statut des contenus publiés par les utilisateurs. Ces clauses doivent être rédigées par l'éditeur." }
        ]
      },
      {
        title: 'Droit applicable et litiges',
        blocks: [
          { type: 'todo', text: "EMPLACEMENT À COMPLÉTER : droit applicable, juridictions compétentes, procédure de réclamation préalable et, le cas échéant, dispositif de médiation de la consommation. Aucune juridiction ni aucune loi ne peut être déduite du code : cette mention doit être rédigée par l'éditeur." }
        ]
      },
      {
        title: 'Modifications de ces conditions',
        blocks: [
          { type: 'p', text: "Cette page peut évoluer avec le service. La date de dernière mise à jour figure en haut de page." },
          { type: 'todo', text: "EMPLACEMENT À COMPLÉTER : modalités d'information des utilisateurs en cas de modification substantielle (canal, délai, conséquences en cas de refus)." }
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
      return '<div class="privacy-todo"><strong>À compléter</strong> : ' +
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

  /** Rend les conditions générales dans l'élément `el`. */
  function render(el, lang) {
    if (!el) return;
    var c = CONTENT[lang] || CONTENT.fr;
    var html = '<div class="privacy-card">' +
      "<h1 class=\"privacy-h1\">Conditions générales d'utilisation</h1>" +
      '<p class="privacy-updated">Dernière mise à jour : ' +
      escapeHtml(c.updatedOn) + '</p>' +
      '<div class="privacy-note">Cette page décrit le fonctionnement réel du ' +
      'service. Les emplacements marqués « À compléter » doivent être ' +
      "renseignés par l'éditeur avant publication : ils concernent l'identité " +
      'légale, les engagements contractuels, les tarifs et le droit ' +
      'applicable.</div>';

    c.sections.forEach(function (s) {
      html += '<section class="privacy-section">' +
        '<h2 class="privacy-h2">' + escapeHtml(s.title) + '</h2>' +
        s.blocks.map(renderBlock).join('') +
        '</section>';
    });

    html += '<p class="privacy-footer">Document décrivant le service tel ' +
      "qu'il est réellement mis en œuvre dans l'application. Il ne constitue " +
      "pas un avis juridique et n'a pas valeur d'engagement contractuel tant " +
      "que les emplacements « À compléter » n'ont pas été validés par " +
      "l'éditeur.</p>";
    html += '</div>';

    el.innerHTML = html;
  }

  /** Vrai si l'URL courante est la route publique /terms. */
  function isRoute(pathname) {
    var p = String(pathname || (global.location && global.location.pathname) || '');
    return p.replace(/\/+$/, '') === '/terms';
  }

  global.OmniSmsTerms = {
    content: CONTENT,
    render: render,
    isRoute: isRoute
  };
})(window);
