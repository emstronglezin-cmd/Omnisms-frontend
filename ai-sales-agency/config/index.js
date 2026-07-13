// ============================================================
// AI Sales Agency — Configuration centrale
// ============================================================
require('dotenv').config();

module.exports = {
  // Supabase
  supabase: {
    url: process.env.SUPABASE_URL || '',
    anonKey: process.env.SUPABASE_ANON_KEY || '',
    serviceKey: process.env.SUPABASE_SERVICE_KEY || '',
  },

  // OpenAI
  openai: {
    apiKey: process.env.OPENAI_API_KEY || '',
    model: process.env.OPENAI_MODEL || 'gpt-4',
    temperature: parseFloat(process.env.OPENAI_TEMPERATURE || '0.7'),
  },

  // Gmail OAuth2
  gmail: {
    clientId: process.env.GMAIL_CLIENT_ID || '475402628150-s14rvu5g56h96nvagnhnr5j41bm9fq9l.apps.googleusercontent.com',
    clientSecret: process.env.GMAIL_CLIENT_SECRET || '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',
    redirectUri: process.env.GMAIL_REDIRECT_URI || 'http://localhost:3001/auth/gmail/callback',
    refreshToken: process.env.GMAIL_REFRESH_TOKEN || '',
    senderEmail: process.env.GMAIL_SENDER_EMAIL || '',
    senderName: process.env.GMAIL_SENDER_NAME || 'AI Sales Agency',
  },

  // Google Maps API
  googleMaps: {
    apiKey: process.env.GOOGLE_MAPS_API_KEY || '',
  },

  // Application
  app: {
    port: parseInt(process.env.PORT || '3001'),
    env: process.env.NODE_ENV || 'development',
    testMode: process.env.TEST_MODE !== 'false', // true par défaut
    logLevel: process.env.LOG_LEVEL || 'info',
  },

  // Limites email
  limits: {
    maxEmailsPerDay: parseInt(process.env.MAX_EMAILS_PER_DAY || '10'),
    minDelayBetweenContactsDays: parseInt(process.env.MIN_DELAY_DAYS || '7'),
    maxRelances: parseInt(process.env.MAX_RELANCES || '1'),
    minScoreToContact: parseInt(process.env.MIN_SCORE || '50'),
    maxLeadsPerDay: parseInt(process.env.MAX_LEADS_PER_DAY || '50'),
  },

  // Business
  business: {
    services: ['Création site web', 'Refonte site web', 'E-commerce', 'Application mobile', 'SEO/Référencement'],
    prixMin: 500,
    prixMax: 10000,
    secteursCibles: ['restaurant', 'commerce', 'artisan', 'coiffeur', 'boulangerie', 'plombier', 'electricien', 'maçon', 'peintre', 'menuisier', 'jardinier', 'nettoyage', 'transport', 'hotel', 'pharmacie', 'medecin', 'dentiste', 'avocat', 'comptable', 'agence_immobiliere'],
  },
};
