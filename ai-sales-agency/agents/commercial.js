// ============================================================
// AI Sales Agency — COMMERCIAL IA V1
// Rôle : Envoi emails Gmail, suivi réponses, relances
// ============================================================
const BaseAgent = require('./base_agent');
const config = require('../config');

class CommercialAgent extends BaseAgent {
  constructor() {
    super('commercial', 'Commercial IA V1');
    this.gmailClient = null;
  }

  async _initGmail() {
    if (this.gmailClient) return this.gmailClient;
    try {
      const { GmailService } = require('../gmail/gmail_service');
      this.gmailClient = new GmailService();
      await this.gmailClient.init();
      return this.gmailClient;
    } catch (err) {
      this.logWarn(`Gmail non initialisé: ${err.message}`);
      return null;
    }
  }

  // ============================================================
  // ENVOI EMAIL
  // ============================================================

  async envoyerEmail(leadId, strategieId = null) {
    const lead = await this.getLead(leadId);
    this.log(`📧 Envoi email: ${lead.entreprise} <${lead.contact_email}>`);

    // Vérification anti-spam
    const canSend = await this._verifierLimites(lead);
    if (!canSend.peut_envoyer) {
      this.logWarn(`Email bloqué pour ${lead.entreprise}: ${canSend.raison}`);
      return { envoyé: false, raison: canSend.raison };
    }

    // Récupérer la stratégie/contenu
    const emailContent = await this._recupererContenu(leadId, strategieId, lead);

    // Mode test : ne pas envoyer réellement
    if (config.app.testMode) {
      return await this._simulerEnvoi(lead, emailContent);
    }

    // Envoi réel via Gmail
    return await this._envoyerViaGmail(lead, emailContent);
  }

  async _verifierLimites(lead) {
    // Vérification via fonction SQL Supabase
    if (this.supabase) {
      const { data } = await this.supabase.rpc('can_send_email', { p_lead_id: lead.id });
      if (data) return data;
    }

    // Vérification locale
    if (lead.desabonne) return { peut_envoyer: false, raison: 'desabonne' };
    if (!lead.contact_email) return { peut_envoyer: false, raison: 'email_manquant' };
    if (['perdu', 'invalide', 'gagne'].includes(lead.statut)) {
      return { peut_envoyer: false, raison: `statut_${lead.statut}` };
    }
    if (lead.nb_relances >= config.limits.maxRelances && lead.nb_emails_envoyes > 0) {
      return { peut_envoyer: false, raison: 'max_relances_atteint' };
    }

    // Vérifier délai
    if (lead.dernier_contact) {
      const joursDepuis = (Date.now() - new Date(lead.dernier_contact).getTime()) / 86400000;
      if (joursDepuis < config.limits.minDelayBetweenContactsDays) {
        return {
          peut_envoyer: false,
          raison: 'delai_non_respecte',
          jours_restants: Math.ceil(config.limits.minDelayBetweenContactsDays - joursDepuis),
        };
      }
    }

    // Quota journalier
    if (this.supabase) {
      const { count } = await this.supabase
        .from('emails')
        .select('id', { count: 'exact', head: true })
        .eq('direction', 'envoye')
        .eq('statut', 'envoye')
        .gte('envoye_at', new Date().toISOString().split('T')[0]);

      if ((count || 0) >= config.limits.maxEmailsPerDay) {
        return { peut_envoyer: false, raison: 'quota_journalier_atteint', quota: config.limits.maxEmailsPerDay };
      }
    }

    return { peut_envoyer: true };
  }

  async _recupererContenu(leadId, strategieId, lead) {
    // Essayer de récupérer la stratégie
    if (strategieId && this.supabase) {
      const { data: strat } = await this.supabase
        .from('strategies')
        .select('*')
        .eq('id', strategieId)
        .single();

      if (strat) {
        return {
          sujet: strat.sujet_email,
          corps: strat.corps_email,
          strategieId: strat.id,
        };
      }
    }

    // Récupérer depuis le lead directement
    if (lead.message_personnalise) {
      return {
        sujet: `Développez ${lead.entreprise} avec un site web professionnel`,
        corps: lead.message_personnalise,
        strategieId: null,
      };
    }

    // Fallback: générer un email basique
    return {
      sujet: `${lead.entreprise} — Solution web pour développer votre activité à ${lead.ville}`,
      corps: this._emailFallback(lead),
      strategieId: null,
    };
  }

  _emailFallback(lead) {
    return `Bonjour,

Je me permets de vous contacter concernant ${lead.entreprise}.

En cherchant des professionnels de ${lead.secteur || 'votre secteur'} à ${lead.ville || 'votre ville'}, j'ai remarqué que vous pourriez bénéficier d'une présence web améliorée.

Seriez-vous disponible pour échanger 15 minutes sur ce sujet ?

Cordialement,
${config.gmail.senderName || 'L\'équipe Web'}`;
  }

  // ============================================================
  // ENVOI RÉEL VIA GMAIL
  // ============================================================

  async _envoyerViaGmail(lead, emailContent) {
    const gmail = await this._initGmail();

    if (!gmail) {
      this.logWarn('Gmail non disponible — simulation envoi');
      return await this._simulerEnvoi(lead, emailContent);
    }

    try {
      const result = await gmail.sendEmail({
        to: lead.contact_email,
        subject: emailContent.sujet,
        html: this._wrapHtml(emailContent.corps),
        text: emailContent.corps,
      });

      // Sauvegarder l'email dans Supabase
      const emailRecord = await this._sauvegarderEmail(lead, emailContent, result, 'envoye');

      await this.logActivite(lead.id, 'email_envoye', `Email envoyé: ${emailContent.sujet}`, `À: ${lead.contact_email}`);
      this.logSuccess(`Email envoyé à ${lead.contact_email} (Thread: ${result.threadId})`);

      return { envoyé: true, email_id: emailRecord?.id, thread_id: result.threadId };
    } catch (err) {
      this.logError(`Erreur envoi Gmail: ${err.message}`);
      await this._sauvegarderEmail(lead, emailContent, null, 'echec');
      return { envoyé: false, raison: err.message };
    }
  }

  async _simulerEnvoi(lead, emailContent) {
    this.log(`[TEST MODE] 📧 EMAIL SIMULÉ à ${lead.contact_email}`);
    this.log(`  Sujet: ${emailContent.sujet}`);
    this.log(`  Corps: ${emailContent.corps.substring(0, 100)}...`);

    // Sauvegarder quand même en base (statut 'envoye' en mode test)
    const emailRecord = await this._sauvegarderEmail(lead, emailContent, {
      messageId: 'test-' + Date.now(),
      threadId: 'thread-test-' + Date.now(),
    }, 'envoye');

    return { envoyé: true, mode: 'simulation', email_id: emailRecord?.id };
  }

  async _sauvegarderEmail(lead, emailContent, result, statut) {
    if (!this.supabase) return null;

    const { data, error } = await this.supabase.from('emails').insert({
      lead_id: lead.id,
      strategie_id: emailContent.strategieId,
      direction: 'envoye',
      de: config.gmail.senderEmail || 'noreply@ai-sales.local',
      a: lead.contact_email,
      sujet: emailContent.sujet,
      corps_texte: emailContent.corps,
      corps_html: this._wrapHtml(emailContent.corps),
      statut,
      envoye_at: new Date().toISOString(),
      gmail_message_id: result?.messageId || result?.id,
      gmail_thread_id: result?.threadId,
      est_relance: (lead.nb_emails_envoyes || 0) > 0,
      numero_relance: lead.nb_emails_envoyes || 0,
    }).select().single();

    return error ? null : data;
  }

  // ============================================================
  // TRAITER LES RÉPONSES GMAIL
  // ============================================================

  async traiterReponses() {
    this.log('📬 Vérification des réponses Gmail...');
    const gmail = await this._initGmail();

    let nouvelles = [];

    if (!gmail || config.app.testMode) {
      this.log('[TEST MODE] Simulation: 0 nouvelle réponse');
      return { traitees: 0, nouvelles: [] };
    }

    try {
      nouvelles = await gmail.getUnreadReplies();
      this.log(`${nouvelles.length} nouvelle(s) réponse(s) trouvée(s)`);

      for (const reply of nouvelles) {
        await this._traiterUneReponse(reply);
      }
    } catch (err) {
      this.logError(`Erreur lecture réponses: ${err.message}`);
    }

    return { traitees: nouvelles.length, nouvelles };
  }

  async _traiterUneReponse(reply) {
    // Trouver le lead correspondant par email
    if (!this.supabase) return;

    const { data: lead } = await this.supabase
      .from('leads')
      .select('*')
      .eq('contact_email', reply.from)
      .neq('statut', 'invalide')
      .single();

    if (!lead) {
      this.log(`Email non associé à un lead: ${reply.from}`);
      return;
    }

    // Analyser l'intention de la réponse
    const analyse = this._analyserReponse(reply.body || reply.snippet);

    // Sauvegarder la réponse
    await this.supabase.from('emails').insert({
      lead_id: lead.id,
      direction: 'recu',
      de: reply.from,
      a: config.gmail.senderEmail,
      sujet: reply.subject,
      corps_texte: reply.body,
      statut: 'repondu',
      gmail_message_id: reply.id,
      gmail_thread_id: reply.threadId,
      intention: analyse.intention,
      sentiment: analyse.sentiment,
      analyse_reponse: analyse,
    });

    // Mettre à jour le statut du lead selon l'intention
    const nouvStatus = {
      interesse: 'en_discussion',
      demande_info: 'en_discussion',
      refus: 'perdu',
      absence: 'contacte', // Gardons ouvert
    }[analyse.intention] || lead.statut;

    await this.updateLead(lead.id, { statut: nouvStatus });

    this.logSuccess(`Réponse traitée de ${reply.from}: intention=${analyse.intention}, nouveau statut=${nouvStatus}`);

    // Alerter le Manager si prospect intéressé
    if (analyse.intention === 'interesse') {
      await this.sendMessage('manager', 'ALERT', {
        type: 'prospect_interesse',
        lead_id: lead.id,
        entreprise: lead.entreprise,
        message: 'Prospect intéressé — action requise!',
      }, lead.id);
    }
  }

  _analyserReponse(texte) {
    if (!texte) return { intention: 'absence', sentiment: 'neutre' };

    const t = texte.toLowerCase();

    // Mots clés positifs
    const motesPositifs = ['intéressé', 'interesse', 'oui', 'pourquoi pas', 'en effet', 'bonne idée', 'appel', 'rdv', 'rendez-vous', 'disponible', 'démo', 'demo', 'infos', 'plus d\'infos', 'devis', 'prix'];
    const motesNegatifs = ['non merci', 'pas intéressé', 'pas interesse', 'ne pas', 'sans suite', 'retire', 'supprimer', 'désabonner', 'unsubscribe', 'arrêter', 'stop'];
    const motesAbsence = ['absent', 'vacances', 'congé', 'hors du bureau', 'out of office', 'je serai de retour'];

    if (motesAbsence.some(m => t.includes(m))) {
      return { intention: 'absence', sentiment: 'neutre', action_requise: 'relancer_apres_retour' };
    }

    if (motesNegatifs.some(m => t.includes(m))) {
      return { intention: 'refus', sentiment: 'negatif', action_requise: 'fermer_lead' };
    }

    if (motesPositifs.some(m => t.includes(m))) {
      return { intention: 'interesse', sentiment: 'positif', action_requise: 'planifier_rdv', score_engagement: 85 };
    }

    // Par défaut: demande d'info
    return { intention: 'demande_info', sentiment: 'neutre', action_requise: 'repondre_questions' };
  }

  // ============================================================
  // RELANCES AUTOMATIQUES
  // ============================================================

  async lancerRelances() {
    this.log('🔄 Vérification relances nécessaires...');
    if (!this.supabase) return { relancees: 0 };

    const delai = config.limits.minDelayBetweenContactsDays;
    const dateLimit = new Date(Date.now() - delai * 86400000).toISOString();

    const { data: aRelancer } = await this.supabase
      .from('leads')
      .select('*')
      .eq('statut', 'contacte')
      .lt('dernier_contact', dateLimit)
      .lt('nb_relances', config.limits.maxRelances)
      .eq('desabonne', false)
      .not('contact_email', 'is', null)
      .limit(config.limits.maxEmailsPerDay);

    if (!aRelancer?.length) {
      this.log('Aucune relance nécessaire');
      return { relancees: 0 };
    }

    this.log(`${aRelancer.length} relance(s) à effectuer`);
    let relancees = 0;

    for (const lead of aRelancer) {
      try {
        const result = await this.envoyerEmail(lead.id);
        if (result.envoyé) relancees++;
      } catch (err) {
        this.logError(`Erreur relance ${lead.entreprise}: ${err.message}`);
      }
    }

    this.logSuccess(`Relances effectuées: ${relancees}/${aRelancer.length}`);
    return { relancees };
  }

  // ============================================================
  // HELPERS
  // ============================================================

  _wrapHtml(texte) {
    return `<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><style>
  body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; }
  p { margin: 0 0 15px; }
  .signature { border-top: 1px solid #eee; margin-top: 20px; padding-top: 15px; font-size: 13px; color: #666; }
</style></head>
<body>
${texte.split('\n').map(line => `<p>${line || '&nbsp;'}</p>`).join('')}
</body>
</html>`;
  }
}

module.exports = CommercialAgent;
