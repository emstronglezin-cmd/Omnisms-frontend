// ============================================================
// AI Sales Agency — Serveur Express Principal
// ============================================================
const express = require('express');
const cors = require('cors');
const path = require('path');
const config = require('./config');
const Pipeline = require('./automation/pipeline');
const { GmailService, setupGmailOAuthRoutes } = require('./gmail/gmail_service');
const { createClient } = require('@supabase/supabase-js');

const app = express();
const pipeline = new Pipeline();

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'dashboard')));

// Supabase client
let supabase = null;
if (config.supabase.url && config.supabase.serviceKey) {
  supabase = createClient(config.supabase.url, config.supabase.serviceKey);
  console.log('✅ Supabase connecté');
}

// ============================================================
// ROUTES API
// ============================================================

// Statut global
app.get('/api/status', (req, res) => {
  res.json({
    status: 'ok',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    pipeline: pipeline.getStatus(),
    config: {
      testMode: config.app.testMode,
      maxEmailsPerDay: config.limits.maxEmailsPerDay,
      minDelayDays: config.limits.minDelayBetweenContactsDays,
      supabase: !!config.supabase.url,
      gmail: !!config.gmail.refreshToken,
      openai: !!config.openai.apiKey,
      googleMaps: !!config.googleMaps.apiKey,
    },
  });
});

// ─── KPI DASHBOARD ─────────────────────────────────────────
app.get('/api/kpi', async (req, res) => {
  try {
    if (!supabase) {
      return res.json(getMockKPI());
    }
    const { data } = await supabase.rpc('get_kpi_dashboard');
    res.json(data || getMockKPI());
  } catch (err) {
    res.json(getMockKPI());
  }
});

// ─── LEADS ─────────────────────────────────────────────────
app.get('/api/leads', async (req, res) => {
  try {
    if (!supabase) return res.json([]);
    const { limit = 100, statut, source } = req.query;
    let query = supabase.from('leads').select('*').order('created_at', { ascending: false }).limit(parseInt(limit));
    if (statut) query = query.eq('statut', statut);
    if (source) query = query.eq('source', source);
    const { data, error } = await query;
    if (error) throw error;
    res.json(data || []);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/leads', async (req, res) => {
  try {
    const leadData = req.body;
    const saved = await pipeline.prospecteur.sauvegarderLead(leadData);
    // Auto-scorer si possible
    if (saved.id) {
      const scored = await pipeline.analyste.scorerLead(saved.id);
      return res.json({ ...saved, score: scored.score, statut: scored.statut });
    }
    res.json(saved);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/leads/:id/score', async (req, res) => {
  try {
    const result = await pipeline.analyste.scorerLead(req.params.id);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/leads/:id/email', async (req, res) => {
  try {
    const result = await pipeline.commercial.envoyerEmail(req.params.id);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── PIPELINE ──────────────────────────────────────────────
app.get('/api/pipeline', async (req, res) => {
  try {
    if (!supabase) return res.json({});

    const statuts = ['nouveau', 'en_analyse', 'qualifie', 'contacte', 'en_discussion', 'proposition', 'negociation', 'gagne', 'perdu'];
    const result = {};

    for (const statut of statuts) {
      const { data } = await supabase.from('leads').select('id, entreprise, ville, score').eq('statut', statut).limit(20);
      result[statut] = data || [];
    }

    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Premier test réel
app.post('/api/pipeline/test', async (req, res) => {
  try {
    if (pipeline.running) {
      return res.status(409).json({ error: 'Pipeline déjà en cours' });
    }
    const options = req.body || {};
    // Exécuter en arrière-plan
    pipeline.lancerPremierTest(options).catch(err => console.error('Pipeline error:', err));
    res.json({ message: 'Test lancé en arrière-plan', status: 'running' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/pipeline/status', (req, res) => {
  res.json(pipeline.getStatus());
});

// ─── PROSPECTION ───────────────────────────────────────────
app.post('/api/prospection', async (req, res) => {
  try {
    const { ville = 'Lyon', secteur = 'restaurant', nombre = 10 } = req.body;
    const leads = await pipeline.prospecteur.prospecter({ ville, secteur, nombre });
    res.json({ leads, total: leads.length });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── EMAILS ────────────────────────────────────────────────
app.get('/api/emails', async (req, res) => {
  try {
    if (!supabase) return res.json([]);
    const { direction, limit = 50 } = req.query;
    let query = supabase
      .from('emails')
      .select(`*, leads(entreprise)`)
      .order('created_at', { ascending: false })
      .limit(parseInt(limit));
    if (direction) query = query.eq('direction', direction);
    const { data, error } = await query;
    if (error) throw error;
    // Aplatir
    res.json((data || []).map(e => ({ ...e, lead_entreprise: e.leads?.entreprise })));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── RELANCES ──────────────────────────────────────────────
app.post('/api/relances', async (req, res) => {
  try {
    const result = await pipeline.commercial.lancerRelances();
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── RÉPONSES ──────────────────────────────────────────────
app.post('/api/reponses', async (req, res) => {
  try {
    const result = await pipeline.commercial.traiterReponses();
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── RAPPORT ───────────────────────────────────────────────
app.post('/api/rapport', async (req, res) => {
  try {
    const rapport = await pipeline.manager.genererRapportQuotidien();
    res.json(rapport);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── ACTIVITES ─────────────────────────────────────────────
app.get('/api/activites', async (req, res) => {
  try {
    if (!supabase) return res.json([]);
    const { limit = 20 } = req.query;
    const { data } = await supabase
      .from('activites')
      .select(`*, leads(entreprise)`)
      .order('created_at', { ascending: false })
      .limit(parseInt(limit));
    res.json((data || []).map(a => ({ ...a, entreprise: a.leads?.entreprise })));
  } catch (err) {
    res.json([]);
  }
});

// ─── AGENTS STATS ──────────────────────────────────────────
app.get('/api/agents/stats', async (req, res) => {
  try {
    if (!supabase) return res.json({});
    const { data } = await supabase.from('agents').select('role, tasks_total, succes_total, erreurs_total, derniere_action');
    const stats = {};
    (data || []).forEach(a => {
      stats[a.role] = {
        tasks_total: a.tasks_total,
        taux_succes: a.tasks_total > 0 ? Math.round((a.succes_total / a.tasks_total) * 100) : 100,
        derniere_action: a.derniere_action,
        progression: Math.min(100, (a.tasks_total || 0) + 50),
      };
    });
    res.json(stats);
  } catch (err) {
    res.json({});
  }
});

// ─── CONFIG ────────────────────────────────────────────────
app.post('/api/config', async (req, res) => {
  try {
    if (!supabase) return res.json({ success: true, mode: 'mock' });
    const { maxEmailsPerDay, delaiRelance, maxRelances, scoreMin } = req.body;
    const updates = [
      { cle: 'email.max_par_jour', valeur: maxEmailsPerDay.toString() },
      { cle: 'email.delai_relance_jours', valeur: delaiRelance.toString() },
      { cle: 'email.max_relances', valeur: maxRelances.toString() },
      { cle: 'prospecting.score_min', valeur: scoreMin.toString() },
    ];
    for (const u of updates) {
      await supabase.from('configuration').update({ valeur: u.valeur }).eq('cle', u.cle);
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── GMAIL OAUTH ───────────────────────────────────────────
setupGmailOAuthRoutes(app);

// ─── DASHBOARD (SPA) ───────────────────────────────────────
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'dashboard', 'index.html'));
});

app.get('/dashboard', (req, res) => {
  res.redirect('/');
});

// ============================================================
// MOCK DATA (quand Supabase non configuré)
// ============================================================

function getMockKPI() {
  return {
    leads: { total: 0, nouveaux_7j: 0, qualifies: 0, contactes: 0, gagnes: 0, perdus: 0, score_moyen: 0 },
    emails: { envoyes_total: 0, envoyes_7j: 0, recus_total: 0, taux_reponse: 0 },
    ventes: { total: 0, ca_total: 0, en_cours: 0, ca_pipeline: 0 },
    clients: { total: 0, satisfaction_moyenne: null },
    kpi_aujourd_hui: null,
    alertes: config.supabase.url ? [] : [{
      type: 'supabase_missing',
      severite: 'warning',
      message: '⚠️ Supabase non configuré — Ajoutez SUPABASE_URL et SUPABASE_SERVICE_KEY dans .env',
    }],
  };
}

// ============================================================
// DÉMARRAGE
// ============================================================
const PORT = config.app.port;
app.listen(PORT, '0.0.0.0', () => {
  console.log('\n' + '═'.repeat(60));
  console.log('🤖 AI SALES AGENCY — Serveur démarré!');
  console.log('═'.repeat(60));
  console.log(`🌐 Dashboard: http://localhost:${PORT}`);
  console.log(`📊 API: http://localhost:${PORT}/api/status`);
  console.log(`🔐 Gmail Auth: http://localhost:${PORT}/auth/gmail`);
  console.log('─'.repeat(60));
  console.log(`📧 Max emails/jour: ${config.limits.maxEmailsPerDay}`);
  console.log(`⏰ Délai relance: ${config.limits.minDelayBetweenContactsDays} jours`);
  console.log(`🧪 Mode test: ${config.app.testMode}`);
  console.log(`🗄️  Supabase: ${config.supabase.url ? '✅ Configuré' : '❌ Non configuré'}`);
  console.log(`📧 Gmail: ${config.gmail.refreshToken ? '✅ Configuré' : '❌ Non configuré (run: node gmail/auth.js)'}`);
  console.log(`🤖 OpenAI: ${config.openai.apiKey ? '✅ Configuré' : '⚠️ Non configuré (templates actifs)'}`);
  console.log('═'.repeat(60) + '\n');
});

module.exports = app;
