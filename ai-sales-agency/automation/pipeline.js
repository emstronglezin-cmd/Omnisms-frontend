// ============================================================
// AI Sales Agency — Pipeline Orchestrateur Principal
// Coordonne le flux: Manager → Prospecteur → Analyste → Strategist → Commercial → Support
// ============================================================
const ManagerAgent = require('../agents/manager');
const ProspecteurAgent = require('../agents/prospecteur');
const AnalysteAgent = require('../agents/analyste');
const StrategistAgent = require('../agents/strategist');
const CommercialAgent = require('../agents/commercial');
const SupportAgent = require('../agents/support');
const config = require('../config');

class Pipeline {
  constructor() {
    this.manager = new ManagerAgent();
    this.prospecteur = new ProspecteurAgent();
    this.analyste = new AnalysteAgent();
    this.strategist = new StrategistAgent();
    this.commercial = new CommercialAgent();
    this.support = new SupportAgent();

    this.running = false;
    this.stats = {
      started_at: null,
      leads_prospectes: 0,
      leads_scores: 0,
      strategies_creees: 0,
      emails_envoyes: 0,
      errors: [],
    };
  }

  // ============================================================
  // PREMIER TEST RÉEL — 10 PROSPECTS
  // ============================================================

  async lancerPremierTest(options = {}) {
    const {
      nombre = 10,
      ville = 'Lyon',
      secteurs = ['restaurant', 'commerce', 'artisan'],
      source = config.googleMaps.apiKey ? 'google_maps' : 'simulation',
    } = options;

    console.log('\n' + '═'.repeat(60));
    console.log('🚀 AI SALES AGENCY — PREMIER TEST RÉEL');
    console.log('═'.repeat(60));
    console.log(`📍 Ville: ${ville}`);
    console.log(`🏭 Secteurs: ${secteurs.join(', ')}`);
    console.log(`📊 Nombre cible: ${nombre} prospects`);
    console.log(`🔍 Source: ${source}`);
    console.log(`🧪 Mode test: ${config.app.testMode ? 'OUI (emails simulés)' : 'NON (vrais emails)'}`);
    console.log('═'.repeat(60) + '\n');

    this.running = true;
    this.stats.started_at = new Date();
    const rapport = { leads: [], etapes: [] };

    try {
      // ─── ÉTAPE 1 : PROSPECTION ──────────────────────────────
      console.log('📍 ÉTAPE 1/5 — Prospection...\n');
      const leadsParSecteur = Math.ceil(nombre / secteurs.length);
      let tousLesLeads = [];

      for (const secteur of secteurs) {
        const found = await this.prospecteur.prospecter({
          ville,
          secteur,
          nombre: leadsParSecteur,
          source,
        });
        tousLesLeads = [...tousLesLeads, ...found];
        this.stats.leads_prospectes += found.length;
        console.log(`  ✅ ${secteur}: ${found.length} leads trouvés`);
      }

      rapport.etapes.push({
        etape: 'prospection',
        status: 'success',
        nb: tousLesLeads.length,
        message: `${tousLesLeads.length} leads prospectés`,
      });

      console.log(`\n📊 Total prospecté: ${tousLesLeads.length} leads\n`);

      // ─── ÉTAPE 2 : SCORING / ANALYSE ──────────────────────
      console.log('📍 ÉTAPE 2/5 — Analyse et scoring...\n');
      let qualifies = [];

      for (const lead of tousLesLeads) {
        if (!lead.id) {
          console.log(`  ⚠️  Lead sans ID ignoré: ${lead.entreprise}`);
          continue;
        }

        try {
          const result = await this.analyste.scorerLead(lead.id);
          this.stats.leads_scores++;
          console.log(`  ${result.statut === 'qualifie' ? '✅' : '❌'} ${lead.entreprise}: ${result.score}/100 → ${result.statut}`);

          if (result.statut === 'qualifie') {
            qualifies.push({ ...lead, score: result.score, statut: 'qualifie' });
          }

          rapport.leads.push({
            entreprise: lead.entreprise,
            ville: lead.ville,
            secteur: lead.secteur,
            score: result.score,
            statut: result.statut,
            probleme: lead.probleme_detecte,
          });
        } catch (err) {
          console.log(`  ❌ Erreur scoring ${lead.entreprise}: ${err.message}`);
          this.stats.errors.push({ lead: lead.entreprise, erreur: err.message });
        }
      }

      rapport.etapes.push({
        etape: 'scoring',
        status: 'success',
        nb: qualifies.length,
        message: `${qualifies.length}/${tousLesLeads.length} leads qualifiés`,
      });

      console.log(`\n📊 Qualifiés: ${qualifies.length}/${tousLesLeads.length}\n`);

      // ─── ÉTAPE 3 : STRATÉGIES ─────────────────────────────
      console.log('📍 ÉTAPE 3/5 — Création stratégies...\n');

      for (const lead of qualifies) {
        try {
          const strategie = await this.strategist.creerStrategie(lead.id);
          this.stats.strategies_creees++;
          const leadUpdated = await this.analyste.getLead(lead.id);
          console.log(`  ✅ Stratégie créée: ${lead.entreprise}`);
          console.log(`     Sujet: "${leadUpdated.message_personnalise?.substring(0, 60)}..."`);
        } catch (err) {
          console.log(`  ❌ Erreur stratégie ${lead.entreprise}: ${err.message}`);
          this.stats.errors.push({ lead: lead.entreprise, erreur: err.message });
        }
      }

      rapport.etapes.push({
        etape: 'strategies',
        status: 'success',
        nb: this.stats.strategies_creees,
        message: `${this.stats.strategies_creees} stratégies créées`,
      });

      console.log(`\n📊 Stratégies: ${this.stats.strategies_creees}\n`);

      // ─── ÉTAPE 4 : ENVOI EMAILS ───────────────────────────
      console.log('📍 ÉTAPE 4/5 — Envoi emails...\n');

      for (const lead of qualifies) {
        try {
          const result = await this.commercial.envoyerEmail(lead.id);
          if (result.envoyé) {
            this.stats.emails_envoyes++;
            console.log(`  ✅ Email ${result.mode === 'simulation' ? '[SIMULÉ] ' : ''}envoyé: ${lead.entreprise} <${lead.contact_email}>`);
          } else {
            console.log(`  ⚠️  Email bloqué (${result.raison}): ${lead.entreprise}`);
          }
        } catch (err) {
          console.log(`  ❌ Erreur email ${lead.entreprise}: ${err.message}`);
          this.stats.errors.push({ lead: lead.entreprise, erreur: err.message });
        }
      }

      rapport.etapes.push({
        etape: 'emails',
        status: 'success',
        nb: this.stats.emails_envoyes,
        message: `${this.stats.emails_envoyes} emails envoyés`,
      });

      console.log(`\n📊 Emails envoyés: ${this.stats.emails_envoyes}\n`);

      // ─── ÉTAPE 5 : RAPPORT MANAGER ───────────────────────
      console.log('📍 ÉTAPE 5/5 — Rapport Manager...\n');
      const rapportManager = await this.manager.genererRapportQuotidien();

      rapport.rapport_manager = rapportManager;
      rapport.stats = this.stats;
      rapport.etapes.push({
        etape: 'rapport',
        status: 'success',
        message: 'Rapport généré',
      });

      // ─── RÉSUMÉ FINAL ────────────────────────────────────
      const duree = Math.round((Date.now() - this.stats.started_at.getTime()) / 1000);
      console.log('\n' + '═'.repeat(60));
      console.log('✅ PREMIER TEST TERMINÉ!');
      console.log('═'.repeat(60));
      console.log(`⏱️  Durée: ${duree}s`);
      console.log(`🔍 Leads prospectés: ${this.stats.leads_prospectes}`);
      console.log(`📊 Leads scorés: ${this.stats.leads_scores}`);
      console.log(`🎯 Leads qualifiés: ${qualifies.length}`);
      console.log(`✍️  Stratégies: ${this.stats.strategies_creees}`);
      console.log(`📧 Emails: ${this.stats.emails_envoyes} (mode: ${config.app.testMode ? 'TEST' : 'RÉEL'})`);
      console.log(`❌ Erreurs: ${this.stats.errors.length}`);
      console.log('═'.repeat(60) + '\n');

      if (config.app.testMode) {
        console.log('ℹ️  IMPORTANT: Les emails ont été SIMULÉS (TEST_MODE=true)');
        console.log('   Pour envoyer de vrais emails: TEST_MODE=false dans .env\n');
      }

      this.running = false;
      return rapport;

    } catch (err) {
      this.running = false;
      console.error(`❌ Erreur pipeline: ${err.message}`);
      throw err;
    }
  }

  // ============================================================
  // MODE AUTOMATIQUE (scheduler)
  // ============================================================

  async lancerModeAuto() {
    console.log('🤖 Mode automatique activé');
    console.log(`📧 Max emails/jour: ${config.limits.maxEmailsPerDay}`);
    console.log(`⏰ Délai relance: ${config.limits.minDelayBetweenContactsDays} jours\n`);

    // 1. Traiter les leads en attente
    await this._traiterLeadsEnAttente();

    // 2. Vérifier les relances
    await this.commercial.lancerRelances();

    // 3. Traiter les réponses Gmail
    await this.commercial.traiterReponses();

    // 4. Générer rapport
    const rapport = await this.manager.genererRapportQuotidien();

    return rapport;
  }

  async _traiterLeadsEnAttente() {
    if (!this.manager.supabase) return;

    // Récupérer leads nouveaux à scorer
    const { data: nouveaux } = await this.manager.supabase
      .from('leads')
      .select('id')
      .in('statut', ['nouveau', 'en_analyse'])
      .limit(20);

    if (nouveaux?.length > 0) {
      console.log(`📊 Scoring ${nouveaux.length} nouveaux leads...`);
      for (const lead of nouveaux) {
        await this.analyste.scorerLead(lead.id).catch(err =>
          console.error(`Erreur scoring ${lead.id}: ${err.message}`)
        );
      }
    }

    // Récupérer leads qualifiés sans stratégie
    const { data: sansStrategie } = await this.manager.supabase
      .from('leads')
      .select('id')
      .eq('statut', 'qualifie')
      .is('strategie_id', null)
      .limit(10);

    if (sansStrategie?.length > 0) {
      console.log(`✍️  Création stratégies pour ${sansStrategie.length} leads...`);
      for (const lead of sansStrategie) {
        await this.strategist.creerStrategie(lead.id).catch(err =>
          console.error(`Erreur stratégie ${lead.id}: ${err.message}`)
        );
      }
    }

    // Récupérer leads prêts pour email
    const { data: pourEmail } = await this.manager.supabase
      .from('leads')
      .select('*')
      .eq('statut', 'qualifie')
      .not('strategie_id', 'is', null)
      .eq('nb_emails_envoyes', 0)
      .limit(config.limits.maxEmailsPerDay);

    if (pourEmail?.length > 0) {
      console.log(`📧 Envoi emails: ${pourEmail.length} leads prêts...`);
      for (const lead of pourEmail) {
        await this.commercial.envoyerEmail(lead.id).catch(err =>
          console.error(`Erreur email ${lead.id}: ${err.message}`)
        );
      }
    }
  }

  // ============================================================
  // STATUT
  // ============================================================

  getStatus() {
    return {
      running: this.running,
      stats: this.stats,
      agents: {
        manager: 'actif',
        prospecteur: 'actif',
        analyste: 'actif',
        strategist: 'actif',
        commercial: 'actif',
        support: 'actif',
      },
      config: {
        testMode: config.app.testMode,
        maxEmailsPerDay: config.limits.maxEmailsPerDay,
        minDelayDays: config.limits.minDelayBetweenContactsDays,
        supabase: !!config.supabase.url,
        gmail: !!config.gmail.refreshToken,
        openai: !!config.openai.apiKey,
      },
    };
  }
}

module.exports = Pipeline;
