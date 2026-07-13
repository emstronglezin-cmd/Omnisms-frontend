#!/usr/bin/env node
// ============================================================
// AI Sales Agency — Script d'authentification Gmail
// Usage: node gmail/auth.js
// ============================================================
const { google } = require('googleapis');
const readline = require('readline');
const fs = require('fs');
const path = require('path');
const config = require('../config');

const SCOPES = [
  'https://www.googleapis.com/auth/gmail.send',
  'https://www.googleapis.com/auth/gmail.readonly',
  'https://www.googleapis.com/auth/gmail.modify',
];

const TOKEN_PATH = path.join(__dirname, 'token.json');

async function main() {
  console.log('\n🔐 === Configuration Gmail OAuth2 ===\n');

  const oAuth2Client = new google.auth.OAuth2(
    config.gmail.clientId,
    config.gmail.clientSecret,
    'urn:ietf:wg:oauth:2.0:oob' // Out-of-band pour CLI
  );

  // Générer l'URL d'autorisation
  const authUrl = oAuth2Client.generateAuthUrl({
    access_type: 'offline',
    scope: SCOPES,
    prompt: 'consent',
  });

  console.log('📌 ÉTAPES :');
  console.log('1. Ouvrez ce lien dans votre navigateur:');
  console.log('\n' + authUrl + '\n');
  console.log('2. Autorisez l\'accès à Gmail');
  console.log('3. Copiez le code affiché et collez-le ci-dessous\n');

  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  rl.question('Entrez le code d\'autorisation: ', async (code) => {
    rl.close();

    try {
      const { tokens } = await oAuth2Client.getToken(code.trim());
      oAuth2Client.setCredentials(tokens);

      // Sauvegarder le token
      fs.writeFileSync(TOKEN_PATH, JSON.stringify(tokens, null, 2));

      // Récupérer l'email
      const gmail = google.gmail({ version: 'v1', auth: oAuth2Client });
      const profile = await gmail.users.getProfile({ userId: 'me' });
      const email = profile.data.emailAddress;

      console.log('\n✅ === Authentification réussie! ===\n');
      console.log(`📧 Compte Gmail: ${email}`);
      console.log(`🔑 Token sauvegardé: ${TOKEN_PATH}`);
      console.log('\n📝 Ajoutez ces variables dans votre .env:');
      console.log('─'.repeat(50));
      console.log(`GMAIL_REFRESH_TOKEN=${tokens.refresh_token}`);
      console.log(`GMAIL_SENDER_EMAIL=${email}`);
      console.log('─'.repeat(50));
      console.log('\n🚀 Vous pouvez maintenant lancer: npm start\n');

    } catch (err) {
      console.error('❌ Erreur:', err.message);
      process.exit(1);
    }
  });
}

main();
