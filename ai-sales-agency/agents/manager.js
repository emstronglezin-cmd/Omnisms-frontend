// ============================================================
// AI Sales Agency — MANAGER IA V4
// Rôle : Orchestrateur central, rapports, monitoring
// ============================================================
const BaseAgent = require('./base_agent');
const config = require('../config');

class ManagerAgent extends BaseAgent {
  constructor() {
    super('manager', 'Manager IA V4');
  }

  // ============================================================
  // ORCHESTRATION PRINCIPALE
  // ============================================================

  async orchestrate(leads = []) {
    this.log(`🚀 Orchestration démarrée — ${leads.length} leads dans le pipeline`);
    const results = { traites: 0, erreurs: 0, actions: [] };

    for (const lead of leads) {
      try {
        const action = await this.decidirProchainAction(lead);
        results.actions.push({ lead_id: lead.id, action });
        results.traites++;
      } catch (err) {
        this.logError(`Erreur lead ${lead.id}: ${err.message}`);
        results.erreurs++;
      }
    }

    this.logSuccess(`Orchestration terminée: ${results.traites} traités, ${results.erreurs} erreurs`);
    return results;
  }

  async decidirProchainAction(lead) {
    const decision = {
      lead_id: lead.id,
      agent: null,
      action: null,
      priorite: 5,
      raison: '',
    };

    switch (lead.statut) {
      case 'nouveau':
      case 'en_analyse':
        decision.agent = 'analyste';
        decision.action = 'scorer_lead';
        decision.raison = 'Lead nouveau, besoin d\'analyse';
        break;

      case 'qualifie':
        if (!lead.strategie_id) {
          decision.agent = 'strategist';
          decision.action = 'creer_strategie';
          decision.raison = 'Lead qualifié sans stratégie';
        } else if (lead.nb_emails_envoyes === 0) {
          decision.agent = 'commercial';
          decision.action = 'envoyer_premier_email';
          decision.raison = 'Lead qualifié, stratégie prête, aucun email envoyé';
          decision.priorite = 8;
        } else {
          decision.agent = 'commercial';
          decision.action = 'verifier_suivi';
          decision.raison = 'Lead qualifié, email envoyé, vérifier réponse';
        }
        break;

      case 'contacte':
        if (this._joursDepuis(lead.dernier_contact) >= 7 && lead.nb_relances < 1) {
          decision.agent = 'commercial';
          decision.action = 'envoyer_relance';
          decision.priorite = 7;
          decision.raison = 'Pas de réponse depuis 7 jours, relance possible';
        } else {
          decision.action = 'attendre';
          decision.raison = 'En attente réponse ou délai relance non atteint';
        }
        break;

      case 'en_discussion':
        decision.agent = 'commercial';
        decision.action = 'gerer_discussion';
        decision.priorite = 9;
        decision.raison = 'Lead en discussion active';
        break;

      case 'gagne':
        decision.agent = 'support';
        decision.action = 'onboarder_client';
        decision.priorite = 10;
        decision.raison = 'Vente gagnée, transférer au Support';
        break;

      default:
        decision.action = 'aucune';
        decision.raison = `Statut ${lead.statut} ne nécessite pas d'action`;
    }

    this.log(`Décision pour ${lead.entreprise} (${lead.statut}): ${decision.action} → ${decision.agent || 'N/A'}`);
    return decision;
  }

  // ============================================================
  // RAPPORT QUOTIDIEN
  // ============================================================

  async genererRapportQuotidien() {
    this.log('📊 Génération rapport quotidien...');

    const kpi = await this._getKPIAujourdhui();
    const alertes = await this._detecterAlertes();
    const recommandations = await this._genererRecommandations(kpi, alertes);

    const rapport = {
      date: new Date().toISOString().split('T')[0],
      agent: this.nom,
      kpi,
      alertes,
      recommandations,
      resume: this._genererResume(kpi, alertes),
    };

    this.log(`📋 Rapport généré: ${rapport.resume}`);

    // Sauvegarder dans Supabase
    if (this.supabase) {
      await this.supabase.from('kpi_quotidiens').upsert({
        date: rapport.date,
        rapport_manager: rapport.resume,
        alertes: alertes,
        recommandations: recommandations,
      }, { onConflict: 'date' });
    }

    return rapport;
  }

  async _getKPIAujourdhui() {
    if (!this.supabase) {
      return {
        leads_trouves: 5, leads_qualifies: 3, emails_envoyes: 4,
        emails_recus: 1, ventes_signees: 0, revenu_jour: 0,
      };
    }

    const { data } = await this.supabase
      .from('kpi_quotidiens')
      .select('*')
      .eq('date', new Date().toISOString().split('T')[0])
      .single();

    if (!data) return {};

    // Enrichir avec stats globales
    const [leadsCount, emailsCount, ventesCount] = await Promise.all([
      this.supabase.from('leads').select('id', { count: 'exact', head: true }),
      this.supabase.from('emails').select('id', { count: 'exact', head: true }).eq('direction', 'envoye').eq('statut', 'envoye'),
      this.supabase.from('ventes').select('id', { count: 'exact', head: true }).eq('statut', 'gagnee'),
    ]);

    return {
      ...data,
      total_leads: leadsCount.count || 0,
      total_emails: emailsCount.count || 0,
      total_ventes: ventesCount.count || 0,
    };
  }

  async _detecterAlertes() {
    const alertes = [];

    if (!this.supabase) return alertes;

    // Leads bloqués depuis > 3 jours
    const { data: blockedLeads } = await this.supabase
      .from('leads')
      .select('id, entreprise, statut, updated_at')
      .in('statut', ['nouveau', 'en_analyse', 'qualifie'])
      .lt('updated_at', new Date(Date.now() - 3 * 86400000).toISOString())
      .limit(5);

    if (blockedLeads?.length > 0) {
      alertes.push({
        type: 'leads_bloques',
        severite: 'warning',
        message: `${blockedLeads.length} leads bloqués depuis plus de 3 jours`,
        leads: blockedLeads.map(l => l.entreprise),
      });
    }

    // Quota email presque atteint
    const { count: emailsAujourdhui } = await this.supabase
      .from('emails')
      .select('id', { count: 'exact', head: true })
      .eq('direction', 'envoye')
      .eq('statut', 'envoye')
      .gte('envoye_at', new Date().toISOString().split('T')[0]);

    const maxEmailsJour = config.limits.maxEmailsPerDay;
    if (emailsAujourdhui >= maxEmailsJour * 0.8) {
      alertes.push({
        type: 'quota_email_critique',
        severite: emailsAujourdhui >= maxEmailsJour ? 'error' : 'warning',
        message: `Quota email: ${emailsAujourdhui}/${maxEmailsJour} utilisés aujourd'hui`,
      });
    }

    // Tickets urgents non résolus
    const { data: ticketsUrgents } = await this.supabase
      .from('tickets')
      .select('id, titre')
      .eq('priorite', 'urgente')
      .in('statut', ['ouvert', 'en_cours'])
      .limit(3);

    if (ticketsUrgents?.length > 0) {
      alertes.push({
        type: 'tickets_urgents',
        severite: 'error',
        message: `${ticketsUrgents.length} tickets urgents non résolus`,
        tickets: ticketsUrgents.map(t => t.titre),
      });
    }

    return alertes;
  }

  async _genererRecommandations(kpi, alertes) {
    const recs = [];

    if (kpi.leads_trouves === 0) {
      recs.push({ action: 'lancer_prospection', priorite: 'haute', message: 'Aucun lead trouvé aujourd\'hui — lancer la prospection' });
    }

    if (kpi.leads_qualifies > 0 && kpi.emails_envoyes === 0) {
      recs.push({ action: 'envoyer_emails', priorite: 'haute', message: `${kpi.leads_qualifies} leads qualifiés en attente d'email` });
    }

    if (kpi.taux_reponse < 10 && kpi.emails_envoyes > 5) {
      recs.push({ action: 'revoir_copywriting', priorite: 'moyenne', message: 'Taux de réponse faible — améliorer les emails' });
    }

    return recs;
  }

  _genererResume(kpi, alertes) {
    const date = new Date().toLocaleDateString('fr-FR');
    return `📊 Rapport Manager IA V4 — ${date}
🎯 Leads: ${kpi.leads_trouves || 0} trouvés, ${kpi.leads_qualifies || 0} qualifiés
📧 Emails: ${kpi.emails_envoyes || 0} envoyés, ${kpi.emails_recus || 0} réponses
💰 Ventes: ${kpi.ventes_signees || 0} signées, ${kpi.revenu_jour || 0}€ CA
⚠️  Alertes: ${alertes.length}
${alertes.map(a => `  - ${a.message}`).join('\n')}`;
  }

  // ============================================================
  // CRÉATION CLIENT APRÈS VENTE
  // ============================================================

  async creerClient(leadId, venteData) {
    const lead = await this.getLead(leadId);
    this.log(`👤 Création client pour ${lead.entreprise}`);

    if (!this.supabase) {
      this.log(`[MOCK] Client créé pour ${lead.entreprise}`);
      return { id: 'mock-client-' + Date.now(), ...lead };
    }

    const { data: client, error } = await this.supabase.from('clients').insert({
      lead_id: leadId,
      entreprise: lead.entreprise,
      secteur: lead.secteur,
      contact_nom: lead.contact_nom,
      contact_email: lead.contact_email,
      contact_phone: lead.contact_phone,
      valeur_contrat: venteData?.montant_ttc,
      date_signature: new Date().toISOString().split('T')[0],
      type_projet: venteData?.type_produit || 'Site web professionnel',
      statut: 'actif',
    }).select().single();

    if (error) throw new Error(`Erreur création client: ${error.message}`);

    await this.logActivite(leadId, 'contrat_signe', `🎉 Nouveau client: ${lead.entreprise}`, `Contrat signé — ${venteData?.montant_ttc}€`);
    this.logSuccess(`Client créé: ${lead.entreprise}`);
    return client;
  }

  // ============================================================
  // HELPERS
  // ============================================================

  _joursDepuis(date) {
    if (!date) return 999;
    return Math.floor((Date.now() - new Date(date).getTime()) / 86400000);
  }
}

module.exports = ManagerAgent;
