// ============================================================
// AI Sales Agency — SUPPORT IA V1
// Rôle : Gestion clients, tickets, satisfaction, onboarding
// ============================================================
const BaseAgent = require('./base_agent');
const config = require('../config');

class SupportAgent extends BaseAgent {
  constructor() {
    super('support', 'Support IA V1');
  }

  // ============================================================
  // ONBOARDING CLIENT
  // ============================================================

  async onboarderClient(clientId) {
    this.log(`👋 Onboarding client: ${clientId}`);

    if (!this.supabase) {
      this.log('[MOCK] Onboarding simulé');
      return { success: true, mode: 'simulation' };
    }

    const { data: client } = await this.supabase
      .from('clients')
      .select('*')
      .eq('id', clientId)
      .single();

    if (!client) {
      throw new Error(`Client introuvable: ${clientId}`);
    }

    // Créer ticket d'onboarding
    const { data: ticket } = await this.supabase.from('tickets').insert({
      client_id: clientId,
      titre: `Onboarding — ${client.entreprise}`,
      description: 'Bienvenue! Voici les prochaines étapes de votre projet.',
      type: 'livraison',
      priorite: 'haute',
      statut: 'en_cours',
      messages: [
        {
          role: 'support',
          message: this._messageOnboarding(client),
          timestamp: new Date().toISOString(),
        }
      ],
    }).select().single();

    // Email de bienvenue
    const gmail = await this._getGmail();
    if (gmail && !config.app.testMode) {
      await gmail.sendEmail({
        to: client.contact_email,
        subject: `Bienvenue chez nous, ${client.contact_nom || client.entreprise}! 🎉`,
        html: this._emailBienvenue(client),
      });
    } else {
      this.log(`[MOCK] Email bienvenue simulé pour ${client.contact_email}`);
    }

    // Créer activité
    if (client.lead_id) {
      await this.logActivite(client.lead_id, 'autre', `Onboarding démarré: ${client.entreprise}`, `Ticket #${ticket?.reference}`);
    }

    this.logSuccess(`Onboarding démarré pour ${client.entreprise} (ticket ${ticket?.reference})`);
    return { success: true, client, ticket };
  }

  // ============================================================
  // GESTION TICKETS
  // ============================================================

  async creerTicket(clientId, data) {
    if (!this.supabase) return null;

    const { data: ticket } = await this.supabase.from('tickets').insert({
      client_id: clientId,
      titre: data.titre,
      description: data.description,
      type: data.type || 'question',
      priorite: data.priorite || 'normale',
      statut: 'ouvert',
      messages: [{ role: 'client', message: data.description, timestamp: new Date().toISOString() }],
    }).select().single();

    this.log(`🎫 Ticket créé: ${ticket?.reference} — ${data.titre}`);
    return ticket;
  }

  async repondreTicket(ticketId, message) {
    if (!this.supabase) return null;

    const { data: ticket } = await this.supabase
      .from('tickets')
      .select('*')
      .eq('id', ticketId)
      .single();

    if (!ticket) throw new Error('Ticket introuvable');

    const messages = ticket.messages || [];
    messages.push({
      role: 'support',
      agent: this.nom,
      message: message,
      timestamp: new Date().toISOString(),
    });

    await this.supabase.from('tickets').update({
      messages,
      statut: 'en_cours',
      updated_at: new Date().toISOString(),
    }).eq('id', ticketId);

    this.log(`💬 Réponse ajoutée au ticket ${ticket.reference}`);
    return { success: true };
  }

  async fermerTicket(ticketId, satisfaction = null, commentaire = null) {
    if (!this.supabase) return null;

    await this.supabase.from('tickets').update({
      statut: 'resolu',
      resolu_at: new Date().toISOString(),
      satisfaction,
      commentaire_satisfaction: commentaire,
      updated_at: new Date().toISOString(),
    }).eq('id', ticketId);

    this.logSuccess(`✅ Ticket ${ticketId} résolu (satisfaction: ${satisfaction || 'N/A'}/5)`);
  }

  // ============================================================
  // RAPPORT SUPPORT
  // ============================================================

  async genererRapportSupport() {
    if (!this.supabase) return null;

    const [ticketsOuverts, satisfaction, clients] = await Promise.all([
      this.supabase.from('tickets').select('id', { count: 'exact', head: true }).in('statut', ['ouvert', 'en_cours']),
      this.supabase.from('tickets').select('satisfaction').not('satisfaction', 'is', null),
      this.supabase.from('clients').select('id', { count: 'exact', head: true }).eq('statut', 'actif'),
    ]);

    const satisfactionMoyenne = satisfaction.data?.length
      ? satisfaction.data.reduce((sum, t) => sum + t.satisfaction, 0) / satisfaction.data.length
      : null;

    return {
      tickets_ouverts: ticketsOuverts.count || 0,
      satisfaction_moyenne: satisfactionMoyenne ? Math.round(satisfactionMoyenne * 10) / 10 : null,
      clients_actifs: clients.count || 0,
      generé_à: new Date().toISOString(),
    };
  }

  // ============================================================
  // HELPERS
  // ============================================================

  _messageOnboarding(client) {
    return `Bonjour ${client.contact_nom || client.entreprise},

Nous sommes ravis de vous accueillir ! Voici ce qui va se passer maintenant :

📋 PROCHAINES ÉTAPES :
1. Notre équipe vous contactera sous 24h pour un premier appel de lancement
2. Nous vous enverrons un questionnaire pour bien comprendre vos besoins
3. Vous recevrez une maquette dans les 72h suivant l'appel
4. Validation et mise en production en 7 jours

🎯 VOTRE POINT DE CONTACT : ${config.gmail.senderName}
📧 ${config.gmail.senderEmail}

N'hésitez pas à nous contacter pour toute question !`;
  }

  _emailBienvenue(client) {
    return `<!DOCTYPE html><html><body style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;">
<h2 style="color:#2563eb;">🎉 Bienvenue, ${client.contact_nom || client.entreprise}!</h2>
<p>Nous sommes ravis de vous compter parmi nos clients.</p>
<div style="background:#f0f9ff;padding:20px;border-radius:8px;margin:20px 0;">
<h3>Votre projet: ${client.type_projet || 'Site web professionnel'}</h3>
<p><strong>Valeur:</strong> ${client.valeur_contrat}€ TTC</p>
<p><strong>Démarrage:</strong> ${new Date().toLocaleDateString('fr-FR')}</p>
</div>
<h3>Prochaines étapes :</h3>
<ol>
<li>Appel de lancement (sous 24h)</li>
<li>Questionnaire de besoins</li>
<li>Maquettes (72h)</li>
<li>Mise en ligne (7 jours)</li>
</ol>
<p>Votre contact: <strong>${config.gmail.senderName}</strong> — ${config.gmail.senderEmail}</p>
</body></html>`;
  }

  async _getGmail() {
    try {
      const { GmailService } = require('../gmail/gmail_service');
      const gmail = new GmailService();
      await gmail.init();
      return gmail;
    } catch {
      return null;
    }
  }
}

module.exports = SupportAgent;
