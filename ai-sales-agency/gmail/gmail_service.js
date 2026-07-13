// ============================================================
// AI Sales Agency — Gmail OAuth2 Service
// Credentials: client_id fourni par l'utilisateur
// ============================================================
const { google } = require('googleapis');
const fs = require('fs');
const path = require('path');
const readline = require('readline');
const config = require('../config');

const SCOPES = [
  'https://www.googleapis.com/auth/gmail.send',
  'https://www.googleapis.com/auth/gmail.readonly',
  'https://www.googleapis.com/auth/gmail.modify',
];

const TOKEN_PATH = path.join(__dirname, 'token.json');
const CREDENTIALS_PATH = path.join(__dirname, 'credentials.json');

class GmailService {
  constructor() {
    this.auth = null;
    this.gmail = null;
    this.userEmail = null;
  }

  // ============================================================
  // INITIALISATION
  // ============================================================

  async init() {
    const auth = await this._getAuth();
    this.auth = auth;
    this.gmail = google.gmail({ version: 'v1', auth });

    // Récupérer l'email de l'utilisateur
    try {
      const profile = await this.gmail.users.getProfile({ userId: 'me' });
      this.userEmail = profile.data.emailAddress;
      console.log(`✅ Gmail connecté: ${this.userEmail}`);
    } catch (err) {
      console.warn(`⚠️  Impossible de récupérer le profil Gmail: ${err.message}`);
    }

    return this;
  }

  async _getAuth() {
    const oAuth2Client = new google.auth.OAuth2(
      config.gmail.clientId,
      config.gmail.clientSecret,
      config.gmail.redirectUri
    );

    // 1. Essayer le refresh token depuis .env
    if (config.gmail.refreshToken) {
      oAuth2Client.setCredentials({
        refresh_token: config.gmail.refreshToken,
      });
      return oAuth2Client;
    }

    // 2. Essayer le fichier token.json
    if (fs.existsSync(TOKEN_PATH)) {
      const token = JSON.parse(fs.readFileSync(TOKEN_PATH, 'utf8'));
      oAuth2Client.setCredentials(token);

      // Auto-refresh si expiré
      oAuth2Client.on('tokens', (tokens) => {
        if (tokens.refresh_token) {
          const saved = { ...token, ...tokens };
          fs.writeFileSync(TOKEN_PATH, JSON.stringify(saved));
        }
      });

      return oAuth2Client;
    }

    throw new Error('Pas de token Gmail — exécuter: node gmail/auth.js');
  }

  // ============================================================
  // ENVOI EMAIL
  // ============================================================

  async sendEmail({ to, subject, html, text, cc, bcc, replyTo }) {
    if (!this.gmail) await this.init();

    const from = `${config.gmail.senderName} <${this.userEmail || config.gmail.senderEmail}>`;

    // Construction du message RFC 2822
    const messageParts = [
      `From: ${from}`,
      `To: ${to}`,
      cc ? `Cc: ${Array.isArray(cc) ? cc.join(', ') : cc}` : null,
      bcc ? `Bcc: ${Array.isArray(bcc) ? bcc.join(', ') : bcc}` : null,
      replyTo ? `Reply-To: ${replyTo}` : null,
      `Subject: ${this._encodeSubject(subject)}`,
      `MIME-Version: 1.0`,
      `Content-Type: multipart/alternative; boundary="boundary_${Date.now()}"`,
      '',
      `--boundary_${Date.now()}`,
      `Content-Type: text/plain; charset=UTF-8`,
      '',
      text || this._htmlToText(html),
      '',
      `--boundary_${Date.now()}`,
      `Content-Type: text/html; charset=UTF-8`,
      '',
      html || `<p>${text}</p>`,
      '',
      `--boundary_${Date.now()}--`,
    ].filter(Boolean).join('\n');

    const encodedMessage = Buffer.from(messageParts)
      .toString('base64')
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/, '');

    const response = await this.gmail.users.messages.send({
      userId: 'me',
      requestBody: { raw: encodedMessage },
    });

    return {
      id: response.data.id,
      threadId: response.data.threadId,
      messageId: response.data.id,
    };
  }

  // ============================================================
  // LECTURE RÉPONSES
  // ============================================================

  async getUnreadReplies(maxResults = 20) {
    if (!this.gmail) await this.init();

    const response = await this.gmail.users.messages.list({
      userId: 'me',
      q: 'is:unread in:inbox',
      maxResults,
    });

    const messages = response.data.messages || [];
    const replies = [];

    for (const msg of messages) {
      try {
        const detail = await this.gmail.users.messages.get({
          userId: 'me',
          id: msg.id,
          format: 'full',
        });

        const parsed = this._parseMessage(detail.data);
        if (parsed.from && !parsed.from.includes(config.gmail.senderEmail)) {
          replies.push(parsed);
          // Marquer comme lu
          await this.markAsRead(msg.id);
        }
      } catch (err) {
        console.warn(`Erreur lecture message ${msg.id}: ${err.message}`);
      }
    }

    return replies;
  }

  async markAsRead(messageId) {
    if (!this.gmail) return;
    await this.gmail.users.messages.modify({
      userId: 'me',
      id: messageId,
      requestBody: { removeLabelIds: ['UNREAD'] },
    });
  }

  async getThread(threadId) {
    if (!this.gmail) await this.init();
    const response = await this.gmail.users.threads.get({
      userId: 'me',
      id: threadId,
    });
    return response.data;
  }

  // ============================================================
  // HELPERS
  // ============================================================

  _parseMessage(message) {
    const headers = message.payload.headers || [];
    const getHeader = (name) => headers.find(h => h.name.toLowerCase() === name.toLowerCase())?.value || '';

    const from = getHeader('From');
    const fromEmail = from.match(/<([^>]+)>/)?.[1] || from;

    return {
      id: message.id,
      threadId: message.threadId,
      from: fromEmail,
      fromFull: from,
      subject: getHeader('Subject'),
      date: getHeader('Date'),
      inReplyTo: getHeader('In-Reply-To'),
      snippet: message.snippet,
      body: this._getBody(message.payload),
    };
  }

  _getBody(payload) {
    if (payload.body?.data) {
      return Buffer.from(payload.body.data, 'base64').toString('utf8');
    }

    if (payload.parts) {
      // Priorité: text/plain
      const textPart = payload.parts.find(p => p.mimeType === 'text/plain');
      if (textPart?.body?.data) {
        return Buffer.from(textPart.body.data, 'base64').toString('utf8');
      }

      // Fallback: text/html
      const htmlPart = payload.parts.find(p => p.mimeType === 'text/html');
      if (htmlPart?.body?.data) {
        return Buffer.from(htmlPart.body.data, 'base64').toString('utf8').replace(/<[^>]*>/g, ' ');
      }

      // Récursif
      for (const part of payload.parts) {
        if (part.parts) {
          const body = this._getBody(part);
          if (body) return body;
        }
      }
    }

    return '';
  }

  _encodeSubject(subject) {
    // Encoder les caractères non-ASCII
    if (/[^\x00-\x7F]/.test(subject)) {
      return `=?UTF-8?B?${Buffer.from(subject).toString('base64')}?=`;
    }
    return subject;
  }

  _htmlToText(html) {
    return (html || '').replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
  }
}

// ============================================================
// ROUTE OAUTH2 (Express)
// ============================================================

function setupGmailOAuthRoutes(app) {
  // Démarrer l'authentification
  app.get('/auth/gmail', (req, res) => {
    const oAuth2Client = new google.auth.OAuth2(
      config.gmail.clientId,
      config.gmail.clientSecret,
      config.gmail.redirectUri
    );

    const authUrl = oAuth2Client.generateAuthUrl({
      access_type: 'offline',
      scope: SCOPES,
      prompt: 'consent',
    });

    res.redirect(authUrl);
  });

  // Callback OAuth2
  app.get('/auth/gmail/callback', async (req, res) => {
    const { code } = req.query;

    if (!code) {
      return res.status(400).json({ error: 'Code manquant' });
    }

    try {
      const oAuth2Client = new google.auth.OAuth2(
        config.gmail.clientId,
        config.gmail.clientSecret,
        config.gmail.redirectUri
      );

      const { tokens } = await oAuth2Client.getToken(code);
      oAuth2Client.setCredentials(tokens);

      // Sauvegarder le token
      fs.writeFileSync(TOKEN_PATH, JSON.stringify(tokens));

      // Récupérer le profil
      const gmail = google.gmail({ version: 'v1', auth: oAuth2Client });
      const profile = await gmail.users.getProfile({ userId: 'me' });
      const email = profile.data.emailAddress;

      console.log(`✅ Gmail autorisé: ${email}`);
      console.log(`🔑 Refresh token: ${tokens.refresh_token}`);
      console.log(`→ Ajoutez dans .env: GMAIL_REFRESH_TOKEN=${tokens.refresh_token}`);
      console.log(`→ Ajoutez dans .env: GMAIL_SENDER_EMAIL=${email}`);

      res.send(`
        <html><body style="font-family:Arial;text-align:center;padding:50px;">
          <h1 style="color:green;">✅ Gmail connecté!</h1>
          <p><strong>Email:</strong> ${email}</p>
          <p>Ajoutez dans votre fichier .env :</p>
          <pre style="background:#f0f0f0;padding:20px;text-align:left;display:inline-block;">
GMAIL_REFRESH_TOKEN=${tokens.refresh_token}
GMAIL_SENDER_EMAIL=${email}
          </pre>
          <br><a href="/dashboard">→ Aller au Dashboard</a>
        </body></html>
      `);
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  // Statut Gmail
  app.get('/api/gmail/status', async (req, res) => {
    try {
      const service = new GmailService();
      await service.init();
      res.json({ connected: true, email: service.userEmail });
    } catch (err) {
      res.json({ connected: false, error: err.message });
    }
  });
}

// Sauvegarder les credentials par défaut
function initCredentials() {
  const credPath = CREDENTIALS_PATH;
  if (!fs.existsSync(credPath)) {
    const creds = {
      installed: {
        client_id: config.gmail.clientId,
        client_secret: config.gmail.clientSecret,
        redirect_uris: [config.gmail.redirectUri],
        auth_uri: 'https://accounts.google.com/o/oauth2/auth',
        token_uri: 'https://oauth2.googleapis.com/token',
      },
    };
    fs.writeFileSync(credPath, JSON.stringify(creds, null, 2));
    console.log(`✅ credentials.json créé: ${credPath}`);
  }
}

initCredentials();

module.exports = { GmailService, setupGmailOAuthRoutes };
