// ============================================================
// AI Sales Agency — Agent de Base (classe parente)
// ============================================================
const { createClient } = require('@supabase/supabase-js');
const config = require('../config');

class BaseAgent {
  constructor(role, nom) {
    this.role = role;
    this.nom = nom;
    this.supabase = null;
    this.agentData = null;
    this._initSupabase();
  }

  _initSupabase() {
    if (config.supabase.url && config.supabase.serviceKey) {
      this.supabase = createClient(config.supabase.url, config.supabase.serviceKey);
    } else {
      console.warn(`⚠️  [${this.nom}] Supabase non configuré — mode simulation`);
    }
  }

  // ============================================================
  // COMMUNICATION INTER-AGENTS (protocole interne)
  // ============================================================

  async sendMessage(toAgent, type, payload, leadId = null) {
    const message = {
      from: this.role,
      to: toAgent,
      type, // TASK | RESULT | ALERT | REQUEST | FEEDBACK
      payload,
      lead_id: leadId,
      timestamp: new Date().toISOString(),
    };

    this.log(`📤 Message → ${toAgent} [${type}]: ${JSON.stringify(payload).substring(0, 100)}...`);

    // Enregistrer dans la mémoire agent
    if (this.supabase && leadId) {
      await this.supabase.from('agent_memory').insert({
        agent_role: toAgent,
        lead_id: leadId,
        type: 'context',
        cle: `message_from_${this.role}_${Date.now()}`,
        valeur: message,
        importance: type === 'ALERT' ? 9 : 5,
      });
    }

    return message;
  }

  async readMemory(leadId, cle = null) {
    if (!this.supabase) return [];
    let query = this.supabase
      .from('agent_memory')
      .select('*')
      .eq('agent_role', this.role)
      .order('created_at', { ascending: false });

    if (leadId) query = query.eq('lead_id', leadId);
    if (cle) query = query.eq('cle', cle);

    const { data } = await query.limit(20);
    return data || [];
  }

  async writeMemory(leadId, cle, valeur, type = 'context', importance = 5) {
    if (!this.supabase) return null;

    const { data, error } = await this.supabase.from('agent_memory').upsert({
      agent_role: this.role,
      lead_id: leadId,
      type,
      cle,
      valeur: typeof valeur === 'object' ? valeur : { value: valeur },
      importance,
    }, { onConflict: 'agent_role,lead_id,cle' });

    return error ? null : data;
  }

  // ============================================================
  // SUPABASE HELPERS
  // ============================================================

  async getLead(leadId) {
    if (!this.supabase) return this._mockLead(leadId);
    const { data, error } = await this.supabase
      .from('leads')
      .select('*')
      .eq('id', leadId)
      .single();
    if (error) throw new Error(`Lead introuvable: ${error.message}`);
    return data;
  }

  async updateLead(leadId, updates) {
    if (!this.supabase) {
      this.log(`[MOCK] Update lead ${leadId}: ${JSON.stringify(updates)}`);
      return updates;
    }
    const { data, error } = await this.supabase
      .from('leads')
      .update({ ...updates, updated_at: new Date().toISOString() })
      .eq('id', leadId)
      .select()
      .single();
    if (error) throw new Error(`Erreur update lead: ${error.message}`);
    return data;
  }

  async logActivite(leadId, type, titre, description, donnees = {}) {
    if (!this.supabase) {
      this.log(`[ACTIVITE] ${titre}: ${description}`);
      return;
    }
    await this.supabase.from('activites').insert({
      lead_id: leadId,
      agent_role: this.role,
      type,
      titre,
      description,
      donnees,
      important: ['email_recu','vente_reussie'].includes(type),
    });
  }

  async logTransition(leadId, deStatut, versStatut, action, entree = {}, sortie = {}, succes = true) {
    if (!this.supabase) return;
    await this.supabase.from('pipeline_transitions').insert({
      lead_id: leadId,
      de_statut: deStatut,
      vers_statut: versStatut,
      de_agent: this.role,
      vers_agent: this._nextAgent(),
      agent_role: this.role,
      action,
      succes,
      donnees_entree: entree,
      donnees_sortie: sortie,
    });
  }

  _nextAgent() {
    const pipeline = ['prospecteur','analyste','strategist','commercial','support'];
    const idx = pipeline.indexOf(this.role);
    return idx >= 0 && idx < pipeline.length - 1 ? pipeline[idx + 1] : 'manager';
  }

  async getConfig(cle) {
    if (!this.supabase) return null;
    const { data } = await this.supabase
      .from('configuration')
      .select('valeur')
      .eq('cle', cle)
      .single();
    return data ? JSON.parse(JSON.stringify(data.valeur)) : null;
  }

  // ============================================================
  // LOGS
  // ============================================================

  log(message, level = 'info') {
    const timestamp = new Date().toISOString();
    const prefix = {
      info: '📌',
      success: '✅',
      warn: '⚠️ ',
      error: '❌',
      debug: '🔍',
    }[level] || '📌';
    console.log(`${prefix} [${timestamp}] [${this.nom}] ${message}`);
  }

  logSuccess(message) { this.log(message, 'success'); }
  logWarn(message) { this.log(message, 'warn'); }
  logError(message) { this.log(message, 'error'); }

  // ============================================================
  // MOCK (pour tests sans Supabase)
  // ============================================================

  _mockLead(id) {
    return {
      id: id || 'mock-' + Date.now(),
      entreprise: 'Restaurant La Bonne Fourchette',
      secteur: 'restaurant',
      contact_nom: 'Jean Dupont',
      contact_email: 'contact@labonnefourchette.fr',
      contact_phone: '06 12 34 56 78',
      ville: 'Lyon',
      source: 'google_maps',
      score: 0,
      statut: 'nouveau',
      site_web: null,
      google_maps_note: 4.2,
      google_maps_avis: 87,
      probleme_detecte: 'Aucun site web',
      nb_emails_envoyes: 0,
      nb_relances: 0,
      desabonne: false,
    };
  }
}

module.exports = BaseAgent;
