# OmniSMS iOS — Checklist de conformité App Store

Document de travail vérifiable. Chaque ligne porte un statut :
**✅ prêt** · **⚠️ à compléter** (dépend d'une information ou d'une action produit) · **❌ bloquant** (à traiter avant soumission).

Dernière mise à jour : 23 octobre 2026 — dépôt `main`, commits iOS en cours de préparation.
Environnement de préparation : Linux (aucun Mac, aucun Xcode) → rien n'a été compilé ni archivé ici.

---

## 1. Données et confidentialité

| # | Exigence | Statut | Détail |
|---|---|---|---|
| 1.1 | Politique de confidentialité accessible depuis l'app | ⚠️ | `ApiConfig.privacyPolicyUrl` est **vide** (aucune URL inventée). L'entrée « Politique de confidentialité » s'affiche automatiquement dès que la constante est renseignée en `https://`. **Action : fournir l'URL publique.** |
| 1.2 | Politique de confidentialité dans App Store Connect | ⚠️ | Même URL à coller dans le champ *App Privacy → Privacy Policy URL*. |
| 1.3 | Déclaration exacte des données collectées | ✅ | `ios/Runner/PrivacyInfo.xcprivacy` : téléphone, e-mail, nom, contacts, contenu utilisateur, identifiant, historique d'achat — tous en finalité « fonctionnement de l'app », non liés à l'identité, non utilisés pour le suivi. |
| 1.4 | API à motif requis déclarées | ✅ | Même fichier : `UserDefaults` (CA92.1), horodatage de fichiers (C617.1), temps de démarrage (35F9.1) et espace disque (E174.1) pour le SDK publicitaire lié. **À confirmer** par le rapport de confidentialité Xcode après le premier archivage. |
| 1.5 | Aucun suivi publicitaire | ✅ | `NSPrivacyTracking = false`, aucun domaine de suivi. Le SDK Start.io est lié mais **jamais initialisé** sur iOS (garde `Platform.isAndroid`). |
| 1.6 | Collecte minimale | ✅ | Aucun analytics, aucun SDK de mesure publicitaire actif, aucune collecte de localisation. |
| 1.7 | Suppression des données | ✅ | Suppression de compte depuis l'app (Paramètres → Supprimer mon compte) → `POST /api/account/delete` (scrub PII + audit côté serveur). |

## 2. Compte utilisateur

| # | Exigence | Statut | Détail |
|---|---|---|---|
| 2.1 | Création de compte dans l'app | ✅ | Inscription e-mail/téléphone + Google. |
| 2.2 | Suppression de compte dans l'app (règle 5.1.1.v) | ✅ | `Profil → Paramètres → Supprimer mon compte`, avec confirmation. |
| 2.3 | Connexion Google conservée | ✅ | Parcours inchangé ; retour via `omnisms://auth/google/callback`. |
| 2.4 | **Sign in with Apple proposé** (règle 4.8) | ❌ | Dès qu'une connexion tierce (Google) permet de créer le compte principal, Apple exige une option équivalente. **Le backend n'expose aucun endpoint Apple.** Voir §5. |
| 2.5 | Révocation des accès tiers | ❌ | Aucun écran pour révoquer l'accès Google Contacts accordé par l'utilisateur. Le backend ne propose pas non plus d'endpoint de révocation. |
| 2.6 | Session et jeton | ⚠️ | HTTPS/TLS partout (aucune exception ATS nécessaire). Le jeton est stocké dans `shared_preferences` (= `UserDefaults` sur iOS, non chiffré, inclus dans les sauvegardes). **Recommandation :** passer le jeton d'accès dans le trousseau iOS (`flutter_secure_storage`). Non bloquant mais attendu pour une messagerie. |

## 3. Permissions

| # | Exigence | Statut | Détail |
|---|---|---|---|
| 3.1 | Uniquement les permissions nécessaires | ✅ | 3 clés : contacts, micro, photothèque. Aucune clé caméra, localisation, suivi, calendrier ou musique (vérifié par test automatisé). |
| 3.2 | Descriptions exactes | ✅ | Libellés en français expliquant précisément l'usage (y compris le transfert des numéros au serveur pour l'appariement des contacts). |
| 3.3 | Demande au moment de l'usage | ✅ | Contacts : depuis l'écran Contacts. Micro : à l'enregistrement. Photothèque : au choix de la photo. |
| 3.4 | Aucune demande au démarrage sur iOS | ✅ | Correction apportée : `NotificationService.initialize()` ne demande plus rien au lancement (auparavant l'alerte système apparaissait au premier démarrage). Testé. |

## 4. Contenu généré par les utilisateurs (messagerie)

| # | Exigence | Statut | Détail |
|---|---|---|---|
| 4.1 | Blocage d'un utilisateur abusif (règle 1.2) | ❌ | Le backend expose `/block` et `/blocked`, mais **l'application n'offre aucun écran de blocage**. À ajouter avant soumission : c'est un motif classique de rejet pour une messagerie. |
| 4.2 | Signalement d'un contenu | ❌ | Aucune fonction de signalement, côté app comme côté backend. |
| 4.3 | Coordonnées du développeur accessibles | ⚠️ | À renseigner dans App Store Connect (champ *Support URL*) et, idéalement, dans l'écran Paramètres. |
| 4.4 | Classement d'âge | ⚠️ | À déclarer dans le questionnaire App Store Connect : messagerie avec contenu utilisateur → classement probable 12+ ou 17+ selon les réponses. |

## 5. Paiements et crédits

| # | Exigence | Statut | Détail |
|---|---|---|---|
| 5.1 | Nature de l'achat identifiée | ⚠️ | L'abonnement Premium (2 000 XOF via LeekPay, lien externe) **débloque des fonctions dans l'application**. |
| 5.2 | Règle applicable (3.1.1) | ❌ | Un bien numérique consommé dans l'app doit passer par l'achat intégré Apple (IAP). Conserver un paiement externe expose à un rejet, sauf si le service est consommé **hors** de l'app (à démontrer). |
| 5.3 | Intégration IAP | ⚠️ | Non réalisée : elle exige la configuration de produits dans App Store Connect **et** un endpoint backend de vérification des reçus. Aucune facturation n'a été activée et aucun lien de paiement n'a été modifié. |
| 5.4 | Crédits SMS | ⚠️ | Même analyse : si les crédits servent à envoyer des SMS depuis l'app, l'IAP s'applique. À trancher côté produit. |

## 6. Notifications

| # | Exigence | Statut | Détail |
|---|---|---|---|
| 6.1 | Permissions de notification | ✅ | Demandées uniquement depuis Paramètres → Notifications. |
| 6.2 | Notifications push | ❌ | **Aucune push** : ni FCM, ni APNs, côté app comme côté backend (`routes/notifications.js` ne gère que des préférences). Les messages reçus hors application ne sont pas signalés ; le backend bascule alors l'envoi vers les SMS. Ce comportement est **documenté dans le code** et ne prétend jamais que l'app reste connectée en arrière-plan. |
| 6.3 | APNs / FCM à prévoir | ⚠️ | Pour des notifications fiables : ajouter `firebase_messaging`, la capacité *Push Notifications*, une clé APNs dans Firebase, et un endpoint backend d'enregistrement de jeton. Projet distinct, non engagé ici. |

## 7. Fonctionnalités annoncées = fonctionnalités réelles

| # | Exigence | Statut | Détail |
|---|---|---|---|
| 7.1 | Publicités Start.io | ⚠️ | `YOUR_START_IO_APP_ID` est un **placeholder** : le service n'est pas configuré et donc jamais actif, sur Android comme sur iOS. Sur iOS, il est de plus désactivé par conception. À configurer ou à retirer avant soumission (une fonctionnalité morte peut être relevée en revue). |
| 7.2 | Envoi de SMS | ✅ | Aucune promesse d'envoi par la SIM : l'application envoie via le backend, qui route en interne ou via Infobip. Aucune API SMS Android n'est utilisée — donc rien à reproduire sur iOS, et aucun faux statut d'envoi. |
| 7.3 | Messagerie, groupes, audio, transcription | ✅ | Tout passe par le backend (HTTP/multipart) : identique sur iOS. |
| 7.4 | Compte de démonstration pour la revue | ⚠️ | **À fournir** : identifiants d'un compte de test fonctionnel + numéro de téléphone vérifiable. L'application exige une connexion : sans compte de démonstration, la revue est impossible. |
| 7.5 | Instructions de test | ⚠️ | À rédiger avec le compte de démonstration (parcours : connexion → envoi d'un message → import de contacts). |

## 8. Métadonnées App Store Connect

| # | Élément | Statut | Détail |
|---|---|---|---|
| 8.1 | Nom | ✅ | OmniSMS (`CFBundleDisplayName`, corrigé : c'était « Omni Smsnew »). |
| 8.2 | Identifiant de bundle | ✅ | `com.omnisms.app` (à réserver sur le compte Apple Developer). |
| 8.3 | Version / build | ✅ | 2.5.0 (build 1) — alignés sur `pubspec.yaml`. |
| 8.4 | Icône 1024×1024 | ✅ | Présente, sans canal alpha, dessin de marque (bulle cyan sur fond sombre). |
| 8.5 | Catégorie | ⚠️ | À choisir : *Réseaux sociaux* (principale) + *Productivité* (secondaire) suggérées. |
| 8.6 | Captures d'écran | ⚠️ | À produire sur simulateur iPhone 6,9" (obligatoire) + 6,5" — aucune capture ne peut être générée sans Mac. |
| 8.7 | Description et mots-clés | ⚠️ | À rédiger (non fournis). |
| 8.8 | URL de support | ⚠️ | À fournir (obligatoire). |
| 8.9 | URL de la politique de confidentialité | ⚠️ | À fournir (obligatoire) — voir §1.1. |
| 8.10 | Déclaration d'exportation de chiffrement | ✅ | `ITSAppUsesNonExemptEncryption = false` dans Info.plist (chiffrement standard HTTPS uniquement). |

## 9. Risques de rejet identifiés (par ordre de priorité)

1. **Sign in with Apple absent** (règle 4.8) — très probable si Google est laissé comme seule option de création de compte.
2. **Paiement externe pour un bien numérique** (règle 3.1.1) — rejet probable de l'écran d'abonnement LeekPay tel quel.
3. **Pas de blocage ni de signalement d'utilisateur** (règle 1.2) — motif classique pour une messagerie.
4. **Compte de démonstration absent** (règle 2.1) — rejet « nous n'avons pas pu nous connecter ».
5. **URL de politique de confidentialité manquante** (règle 5.1.1) — rejet automatique.
6. **Fonctionnalité publicitaire non configurée** — peut être relevée comme fonctionnalité non fonctionnelle.
7. **Retour OAuth Google non vérifié sur iOS** — à valider dès qu'un appareil est disponible (voir §10).

## 10. Étapes Apple Developer / App Store Connect restantes

1. Créer l'identifiant d'application (*App ID*) `com.omnisms.app` avec les capacités **Push Notifications** (si push retenu) et **Sign in with Apple** (si retenu).
2. Créer un client OAuth **iOS** dans Google Cloud Console (bundle ID `com.omnisms.app`, schéma `omnisms://auth/google/callback`) — cf. le rapport principal, § « Retour OAuth ».
3. Enregistrer l'appareil de test, générer certificat/profil de développement, renseigner l'équipe dans Xcode.
4. Créer la fiche App Store Connect, renseigner les métadonnées (§8) et le questionnaire de confidentialité.
5. Produire les captures et téléverser le build via Xcode → `flutter build ipa`.
6. Fournir le compte de démonstration et les instructions de test dans la zone « Notes de révision ».
