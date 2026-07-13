-- ============================================================
-- AI SALES AGENCY — SUPABASE SCHEMA COMPLET V5
-- À exécuter dans Supabase SQL Editor
-- ============================================================

-- ============================================================
-- EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "unaccent";

-- ============================================================
-- TABLE 1 : leads
-- ============================================================
CREATE TABLE IF NOT EXISTS leads (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Identification
  entreprise        TEXT NOT NULL,
  secteur           TEXT,
  sous_secteur      TEXT,
  taille            TEXT CHECK (taille IN ('micro','petite','moyenne','grande')),
  siret             TEXT,

  -- Contact
  contact_nom       TEXT,
  contact_prenom    TEXT,
  contact_email     TEXT,
  contact_phone     TEXT,
  contact_poste     TEXT,
  contact_linkedin  TEXT,

  -- Localisation
  adresse           TEXT,
  ville             TEXT,
  departement       TEXT,
  pays              TEXT DEFAULT 'France',
  latitude          DOUBLE PRECISION,
  longitude         DOUBLE PRECISION,

  -- Source prospection
  source            TEXT CHECK (source IN ('google_maps','linkedin','facebook','instagram','twitter','manuel','referral','autre')),
  source_url        TEXT,
  source_detail     TEXT,

  -- Qualification
  score             INTEGER DEFAULT 0 CHECK (score >= 0 AND score <= 100),
  score_detail      JSONB DEFAULT '{}',
  probleme_detecte  TEXT,
  opportunite       TEXT,
  besoin_estime     TEXT,
  budget_estime     DECIMAL(10,2),

  -- Présence web
  site_web          TEXT,
  site_age_annees   INTEGER,
  site_mobile       BOOLEAN,
  site_ssl          BOOLEAN,
  google_maps_note  DECIMAL(3,1),
  google_maps_avis  INTEGER,
  reseaux_sociaux   JSONB DEFAULT '{}',

  -- Pipeline
  statut            TEXT NOT NULL DEFAULT 'nouveau' CHECK (statut IN (
    'nouveau','en_analyse','qualifie','non_qualifie',
    'contacte','en_discussion','proposition','negociation',
    'gagne','perdu','invalide','desabonne'
  )),
  etape_pipeline    INTEGER DEFAULT 0,
  agent_actuel      TEXT DEFAULT 'prospecteur',

  -- Stratégie
  strategie_id      UUID,
  message_personnalise TEXT,
  angle_approche    TEXT,

  -- Anti-spam
  dernier_contact   TIMESTAMPTZ,
  nb_contacts       INTEGER DEFAULT 0,
  nb_emails_envoyes INTEGER DEFAULT 0,
  nb_relances       INTEGER DEFAULT 0,
  desabonne         BOOLEAN DEFAULT FALSE,
  desabonne_at      TIMESTAMPTZ,

  -- Meta
  notes             TEXT,
  tags              TEXT[] DEFAULT '{}',
  metadata          JSONB DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_leads_statut ON leads(statut);
CREATE INDEX IF NOT EXISTS idx_leads_score ON leads(score DESC);
CREATE INDEX IF NOT EXISTS idx_leads_source ON leads(source);
CREATE INDEX IF NOT EXISTS idx_leads_contact_email ON leads(contact_email);
CREATE INDEX IF NOT EXISTS idx_leads_ville ON leads(ville);
CREATE INDEX IF NOT EXISTS idx_leads_created_at ON leads(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_leads_agent_actuel ON leads(agent_actuel);
CREATE INDEX IF NOT EXISTS idx_leads_search ON leads USING gin(
  (to_tsvector('french', coalesce(entreprise,'') || ' ' || coalesce(contact_nom,'') || ' ' || coalesce(ville,'')))
);

-- ============================================================
-- TABLE 2 : clients
-- ============================================================
CREATE TABLE IF NOT EXISTS clients (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  lead_id         UUID REFERENCES leads(id) ON DELETE SET NULL,

  -- Identification
  entreprise      TEXT NOT NULL,
  secteur         TEXT,
  siret           TEXT,

  -- Contact principal
  contact_nom     TEXT,
  contact_email   TEXT NOT NULL,
  contact_phone   TEXT,
  contact_poste   TEXT,

  -- Contrat
  statut          TEXT NOT NULL DEFAULT 'actif' CHECK (statut IN ('actif','pause','termine','resilie')),
  date_signature  DATE,
  date_debut      DATE,
  date_fin        DATE,

  -- Financier
  valeur_contrat  DECIMAL(10,2),
  mensualite      DECIMAL(10,2),
  devise          TEXT DEFAULT 'EUR',
  mode_paiement   TEXT,

  -- Projet
  type_projet     TEXT,
  description     TEXT,
  livrables       JSONB DEFAULT '[]',
  avancement      INTEGER DEFAULT 0 CHECK (avancement >= 0 AND avancement <= 100),

  -- Support
  agent_support   UUID,
  satisfaction    INTEGER CHECK (satisfaction >= 1 AND satisfaction <= 5),

  -- Meta
  notes           TEXT,
  tags            TEXT[] DEFAULT '{}',
  metadata        JSONB DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_clients_statut ON clients(statut);
CREATE INDEX IF NOT EXISTS idx_clients_contact_email ON clients(contact_email);
CREATE INDEX IF NOT EXISTS idx_clients_lead_id ON clients(lead_id);

-- ============================================================
-- TABLE 3 : agents
-- ============================================================
CREATE TABLE IF NOT EXISTS agents (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  nom             TEXT NOT NULL UNIQUE,
  version         TEXT NOT NULL DEFAULT 'V1',
  role            TEXT NOT NULL CHECK (role IN (
    'manager','prospecteur','analyste','strategist','commercial','support'
  )),
  description     TEXT,

  -- Configuration
  actif           BOOLEAN DEFAULT TRUE,
  priorite        INTEGER DEFAULT 5,
  modele_ia       TEXT DEFAULT 'gpt-4',
  temperature     DECIMAL(3,2) DEFAULT 0.7,
  max_tokens      INTEGER DEFAULT 2000,
  system_prompt   TEXT,

  -- Capacités
  capacites       TEXT[] DEFAULT '{}',
  outils          TEXT[] DEFAULT '{}',

  -- Limites
  max_tasks_par_heure INTEGER DEFAULT 100,
  max_tasks_par_jour  INTEGER DEFAULT 1000,

  -- Statistiques
  tasks_today     INTEGER DEFAULT 0,
  tasks_total     INTEGER DEFAULT 0,
  succes_total    INTEGER DEFAULT 0,
  erreurs_total   INTEGER DEFAULT 0,
  derniere_action TIMESTAMPTZ,

  -- Configuration avancée
  config          JSONB DEFAULT '{}'
);

-- Insérer les 6 agents par défaut
INSERT INTO agents (nom, version, role, description, system_prompt, capacites, outils, priorite) VALUES
(
  'Manager IA', 'V4', 'manager',
  'Orchestrateur central — coordonne tous les agents, génère rapports quotidiens, détecte anomalies',
  'Tu es le Manager IA V4 d''une agence commerciale IA. Tu coordonnes 5 agents spécialisés. Tu dois : 1) Orchestrer le pipeline de vente, 2) Détecter les blocages, 3) Générer des rapports quotidiens, 4) Prendre des décisions stratégiques, 5) Optimiser les performances globales.',
  ARRAY['orchestration','reporting','decision','monitoring','alerting'],
  ARRAY['supabase','notifications','analytics'],
  1
),
(
  'Prospecteur IA', 'V3', 'prospecteur',
  'Trouve des prospects via Google Maps, LinkedIn et réseaux sociaux. Détecte les entreprises sans site web ou avec mauvaise présence digitale.',
  'Tu es le Prospecteur IA V3. Ta mission : trouver des PME et entreprises qui ont besoin d''un site web professionnel ou d''améliorer leur présence digitale. Tu analyses : site web absent/obsolète, mauvaises notes Google, peu d''avis, présence sociale faible.',
  ARRAY['google_maps_scraping','linkedin_search','web_analysis','scoring_initial'],
  ARRAY['google_maps_api','linkedin_api','web_crawler','serp_api'],
  2
),
(
  'Analyste IA', 'V2', 'analyste',
  'Analyse et qualifie les leads, calcule le score de potentiel, identifie le problème principal et l''opportunité business.',
  'Tu es l''Analyste IA V2. Tu évalues chaque lead sur 100 points selon : présence web (30pts), potentiel marché (20pts), accessibilité contact (20pts), budget estimé (15pts), urgence besoin (15pts). Tu identifies le problème principal et l''opportunité commerciale.',
  ARRAY['lead_scoring','web_audit','market_analysis','opportunity_detection'],
  ARRAY['web_analyzer','pagespeed_api','whois','semrush'],
  3
),
(
  'Communication Strategist IA', 'V1', 'strategist',
  'Crée la stratégie de communication personnalisée pour chaque prospect. Génère le message initial et le sujet d''email parfait.',
  'Tu es le Communication Strategist IA V1. Tu crées des stratégies de communication ultra-personnalisées. Pour chaque prospect tu dois : analyser le secteur, identifier le bon angle d''approche, choisir le bon timing, rédiger un email qui résonne avec leurs besoins spécifiques.',
  ARRAY['copywriting','personalization','email_strategy','subject_optimization'],
  ARRAY['openai_gpt4','tone_analyzer','competitor_research'],
  4
),
(
  'Commercial IA', 'V1', 'commercial',
  'Envoie les emails via Gmail OAuth2, gère les relances, suit les réponses et qualifie les intentions d''achat.',
  'Tu es le Commercial IA V1. Tu envoies les emails commerciaux personnalisés via Gmail, tu surveilles les réponses, tu analyses les intentions et tu décides des prochaines actions : relance, proposition, transfert au support.',
  ARRAY['email_sending','reply_analysis','follow_up','intent_detection','crm_update'],
  ARRAY['gmail_oauth2','email_parser','intent_classifier'],
  5
),
(
  'Support IA', 'V1', 'support',
  'Gère les clients convertis, répond aux questions, coordonne les projets et assure la satisfaction client.',
  'Tu es le Support IA V1. Tu prends en charge les nouveaux clients après la signature. Tu gères : onboarding, questions techniques, suivi de projet, satisfaction client, upsell opportunités.',
  ARRAY['client_onboarding','ticket_management','project_tracking','satisfaction_monitoring'],
  ARRAY['supabase','email','project_management'],
  6
)
ON CONFLICT (nom) DO UPDATE SET
  version = EXCLUDED.version,
  description = EXCLUDED.description,
  updated_at = NOW();

-- ============================================================
-- TABLE 4 : agent_memory
-- ============================================================
CREATE TABLE IF NOT EXISTS agent_memory (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  agent_role  TEXT NOT NULL CHECK (agent_role IN ('manager','prospecteur','analyste','strategist','commercial','support')),
  lead_id     UUID REFERENCES leads(id) ON DELETE CASCADE,
  client_id   UUID REFERENCES clients(id) ON DELETE CASCADE,

  -- Type de mémoire
  type        TEXT NOT NULL CHECK (type IN ('context','decision','observation','learning','instruction')),
  cle         TEXT NOT NULL,
  valeur      JSONB NOT NULL,

  -- Expiration
  expire_at   TIMESTAMPTZ,
  permanent   BOOLEAN DEFAULT FALSE,

  -- Importance
  importance  INTEGER DEFAULT 5 CHECK (importance >= 1 AND importance <= 10),

  -- Meta
  metadata    JSONB DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_memory_agent ON agent_memory(agent_role);
CREATE INDEX IF NOT EXISTS idx_memory_lead ON agent_memory(lead_id);
CREATE INDEX IF NOT EXISTS idx_memory_type ON agent_memory(type);
CREATE INDEX IF NOT EXISTS idx_memory_cle ON agent_memory(cle);

-- ============================================================
-- TABLE 5 : workflows
-- ============================================================
CREATE TABLE IF NOT EXISTS workflows (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  nom             TEXT NOT NULL,
  description     TEXT,
  actif           BOOLEAN DEFAULT TRUE,
  version         INTEGER DEFAULT 1,

  -- Déclencheur
  trigger_type    TEXT NOT NULL CHECK (trigger_type IN (
    'nouveau_lead','lead_qualifie','email_envoye',
    'reponse_recue','vente_reussie','manuel','schedule'
  )),
  trigger_config  JSONB DEFAULT '{}',

  -- Pipeline
  etapes          JSONB NOT NULL DEFAULT '[]',
  -- Structure: [{"ordre": 1, "agent": "prospecteur", "action": "analyser", "config": {}}]

  -- Statistiques
  nb_executions   INTEGER DEFAULT 0,
  nb_succes       INTEGER DEFAULT 0,
  nb_erreurs      INTEGER DEFAULT 0,
  derniere_exec   TIMESTAMPTZ,

  -- Config
  timeout_minutes INTEGER DEFAULT 30,
  retry_max       INTEGER DEFAULT 3,
  config          JSONB DEFAULT '{}'
);

-- Workflows par défaut
INSERT INTO workflows (nom, description, trigger_type, etapes) VALUES
(
  'Pipeline Principal',
  'Workflow complet : Prospecteur → Analyste → Strategist → Commercial',
  'nouveau_lead',
  '[
    {"ordre": 1, "agent": "prospecteur", "action": "enrichir_lead", "timeout": 300},
    {"ordre": 2, "agent": "analyste", "action": "scorer_lead", "timeout": 300},
    {"ordre": 3, "agent": "strategist", "action": "creer_strategie", "timeout": 300, "condition": {"score_min": 50}},
    {"ordre": 4, "agent": "commercial", "action": "envoyer_email", "timeout": 120, "condition": {"score_min": 50}}
  ]'
),
(
  'Relance Automatique',
  'Relance les prospects sans réponse après 7 jours',
  'schedule',
  '[
    {"ordre": 1, "agent": "commercial", "action": "verifier_reponses", "timeout": 120},
    {"ordre": 2, "agent": "commercial", "action": "envoyer_relance", "timeout": 120}
  ]'
),
(
  'Conversion Client',
  'Converti un lead gagné en client et transfère au Support IA',
  'vente_reussie',
  '[
    {"ordre": 1, "agent": "manager", "action": "creer_client", "timeout": 60},
    {"ordre": 2, "agent": "support", "action": "onboarder_client", "timeout": 300}
  ]'
)
ON CONFLICT DO NOTHING;

-- ============================================================
-- TABLE 6 : pipeline_transitions
-- ============================================================
CREATE TABLE IF NOT EXISTS pipeline_transitions (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  lead_id         UUID NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
  workflow_id     UUID REFERENCES workflows(id) ON DELETE SET NULL,

  -- Transition
  de_statut       TEXT,
  vers_statut     TEXT NOT NULL,
  de_agent        TEXT,
  vers_agent      TEXT,

  -- Agent exécutant
  agent_role      TEXT NOT NULL,
  action          TEXT NOT NULL,

  -- Résultat
  succes          BOOLEAN DEFAULT TRUE,
  donnees_entree  JSONB DEFAULT '{}',
  donnees_sortie  JSONB DEFAULT '{}',
  erreur          TEXT,

  -- Durée
  duree_ms        INTEGER,

  -- Meta
  notes           TEXT,
  metadata        JSONB DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_transitions_lead ON pipeline_transitions(lead_id);
CREATE INDEX IF NOT EXISTS idx_transitions_created ON pipeline_transitions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transitions_agent ON pipeline_transitions(agent_role);

-- ============================================================
-- TABLE 7 : strategies
-- ============================================================
CREATE TABLE IF NOT EXISTS strategies (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  lead_id         UUID NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
  agent_id        UUID REFERENCES agents(id) ON DELETE SET NULL,

  -- Stratégie
  angle           TEXT NOT NULL,
  ton             TEXT DEFAULT 'professionnel' CHECK (ton IN ('formel','professionnel','decontracte','amical')),
  urgence         TEXT DEFAULT 'normale' CHECK (urgence IN ('basse','normale','haute','urgente')),

  -- Message
  sujet_email     TEXT NOT NULL,
  corps_email     TEXT NOT NULL,
  call_to_action  TEXT,
  ps_email        TEXT,

  -- Personnalisation
  points_cles     TEXT[] DEFAULT '{}',
  differenciateurs TEXT[] DEFAULT '{}',
  objections_anticipees JSONB DEFAULT '[]',

  -- Statut
  statut          TEXT DEFAULT 'prete' CHECK (statut IN ('brouillon','prete','envoyee','archivee')),
  envoyee_at      TIMESTAMPTZ,
  score_qualite   INTEGER,

  -- Meta
  metadata        JSONB DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_strategies_lead ON strategies(lead_id);
CREATE INDEX IF NOT EXISTS idx_strategies_statut ON strategies(statut);

-- ============================================================
-- TABLE 8 : emails
-- ============================================================
CREATE TABLE IF NOT EXISTS emails (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  lead_id         UUID NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
  strategie_id    UUID REFERENCES strategies(id) ON DELETE SET NULL,

  -- Direction
  direction       TEXT NOT NULL CHECK (direction IN ('envoye','recu')),
  est_relance     BOOLEAN DEFAULT FALSE,
  numero_relance  INTEGER DEFAULT 0,

  -- Gmail
  gmail_message_id TEXT,
  gmail_thread_id  TEXT,

  -- Expéditeur / Destinataire
  de              TEXT NOT NULL,
  a               TEXT NOT NULL,
  cc              TEXT[],
  bcc             TEXT[],

  -- Contenu
  sujet           TEXT NOT NULL,
  corps_html      TEXT,
  corps_texte     TEXT,
  pieces_jointes  JSONB DEFAULT '[]',

  -- Statut envoi
  statut          TEXT DEFAULT 'brouillon' CHECK (statut IN (
    'brouillon','en_attente','envoye','echec',
    'ouvert','clique','repondu','non_delivre','spam'
  )),
  envoye_at       TIMESTAMPTZ,
  ouvert_at       TIMESTAMPTZ,
  clique_at       TIMESTAMPTZ,
  repondu_at      TIMESTAMPTZ,

  -- Analyse réponse
  analyse_reponse JSONB DEFAULT '{}',
  -- Structure: {"intention": "interesse", "sentiment": "positif", "action_requise": "rdv", "score_engagement": 85}
  intention       TEXT CHECK (intention IN ('interesse','demande_info','refus','absence','autre')),
  sentiment       TEXT CHECK (sentiment IN ('positif','neutre','negatif')),

  -- Anti-spam
  score_spam      INTEGER DEFAULT 0,

  -- Meta
  metadata        JSONB DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_emails_lead ON emails(lead_id);
CREATE INDEX IF NOT EXISTS idx_emails_direction ON emails(direction);
CREATE INDEX IF NOT EXISTS idx_emails_statut ON emails(statut);
CREATE INDEX IF NOT EXISTS idx_emails_envoye_at ON emails(envoye_at DESC);
CREATE INDEX IF NOT EXISTS idx_emails_gmail_thread ON emails(gmail_thread_id);

-- ============================================================
-- TABLE 9 : activites
-- ============================================================
CREATE TABLE IF NOT EXISTS activites (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  lead_id     UUID REFERENCES leads(id) ON DELETE CASCADE,
  client_id   UUID REFERENCES clients(id) ON DELETE CASCADE,
  email_id    UUID REFERENCES emails(id) ON DELETE SET NULL,
  agent_role  TEXT,

  -- Activité
  type        TEXT NOT NULL CHECK (type IN (
    'creation_lead','modification_statut','email_envoye',
    'email_recu','appel','rdv_planifie','rdv_effectue',
    'proposition_envoyee','contrat_signe','note_ajoutee',
    'tag_ajoute','score_calcule','alerte','rapport','autre'
  )),
  titre       TEXT NOT NULL,
  description TEXT,
  donnees     JSONB DEFAULT '{}',

  -- Visibilité
  important   BOOLEAN DEFAULT FALSE,
  visible     BOOLEAN DEFAULT TRUE
);

CREATE INDEX IF NOT EXISTS idx_activites_lead ON activites(lead_id);
CREATE INDEX IF NOT EXISTS idx_activites_created ON activites(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activites_type ON activites(type);

-- ============================================================
-- TABLE 10 : ventes
-- ============================================================
CREATE TABLE IF NOT EXISTS ventes (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  lead_id         UUID REFERENCES leads(id) ON DELETE SET NULL,
  client_id       UUID REFERENCES clients(id) ON DELETE SET NULL,

  -- Vente
  reference       TEXT UNIQUE,
  titre           TEXT NOT NULL,
  description     TEXT,
  type_produit    TEXT,

  -- Financier
  montant_ht      DECIMAL(10,2) NOT NULL,
  taux_tva        DECIMAL(5,2) DEFAULT 20.0,
  montant_ttc     DECIMAL(10,2) GENERATED ALWAYS AS (montant_ht * (1 + taux_tva/100)) STORED,
  devise          TEXT DEFAULT 'EUR',

  -- Statut
  statut          TEXT NOT NULL DEFAULT 'proposition' CHECK (statut IN (
    'proposition','negociation','gagnee','perdue','annulee'
  )),
  probabilite     INTEGER DEFAULT 50 CHECK (probabilite >= 0 AND probabilite <= 100),

  -- Dates
  date_proposition DATE,
  date_signature   DATE,
  date_debut       DATE,
  date_fin         DATE,

  -- Paiement
  mode_paiement   TEXT,
  echeancier      JSONB DEFAULT '[]',

  -- Source
  agent_id        UUID REFERENCES agents(id) ON DELETE SET NULL,

  -- Meta
  notes           TEXT,
  metadata        JSONB DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_ventes_statut ON ventes(statut);
CREATE INDEX IF NOT EXISTS idx_ventes_created ON ventes(created_at DESC);

-- Auto-generate référence
CREATE SEQUENCE IF NOT EXISTS ventes_reference_seq START 1000;

-- ============================================================
-- TABLE 11 : tickets
-- ============================================================
CREATE TABLE IF NOT EXISTS tickets (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  client_id       UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  vente_id        UUID REFERENCES ventes(id) ON DELETE SET NULL,
  agent_id        UUID REFERENCES agents(id) ON DELETE SET NULL,

  -- Ticket
  reference       TEXT UNIQUE,
  titre           TEXT NOT NULL,
  description     TEXT,
  type            TEXT DEFAULT 'question' CHECK (type IN (
    'question','bug','feature','livraison','paiement','plainte','autre'
  )),

  -- Priorité et statut
  priorite        TEXT DEFAULT 'normale' CHECK (priorite IN ('basse','normale','haute','urgente')),
  statut          TEXT DEFAULT 'ouvert' CHECK (statut IN ('ouvert','en_cours','en_attente','resolu','ferme')),

  -- Dates
  date_echeance   TIMESTAMPTZ,
  resolu_at       TIMESTAMPTZ,

  -- Satisfaction
  satisfaction    INTEGER CHECK (satisfaction >= 1 AND satisfaction <= 5),
  commentaire_satisfaction TEXT,

  -- Meta
  messages        JSONB DEFAULT '[]',
  metadata        JSONB DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_tickets_client ON tickets(client_id);
CREATE INDEX IF NOT EXISTS idx_tickets_statut ON tickets(statut);
CREATE INDEX IF NOT EXISTS idx_tickets_priorite ON tickets(priorite);

CREATE SEQUENCE IF NOT EXISTS tickets_reference_seq START 5000;

-- ============================================================
-- TABLE 12 : kpi_quotidiens
-- ============================================================
CREATE TABLE IF NOT EXISTS kpi_quotidiens (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  date                  DATE NOT NULL UNIQUE DEFAULT CURRENT_DATE,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Prospection
  leads_trouves         INTEGER DEFAULT 0,
  leads_qualifies       INTEGER DEFAULT 0,
  leads_non_qualifies   INTEGER DEFAULT 0,
  score_moyen           DECIMAL(5,2) DEFAULT 0,

  -- Emails
  emails_envoyes        INTEGER DEFAULT 0,
  emails_recus          INTEGER DEFAULT 0,
  emails_ouverts        INTEGER DEFAULT 0,
  emails_cliques        INTEGER DEFAULT 0,
  taux_ouverture        DECIMAL(5,2) DEFAULT 0,
  taux_reponse          DECIMAL(5,2) DEFAULT 0,

  -- Réponses
  reponses_interessees  INTEGER DEFAULT 0,
  reponses_info         INTEGER DEFAULT 0,
  reponses_refus        INTEGER DEFAULT 0,
  reponses_absence      INTEGER DEFAULT 0,

  -- Conversions
  rdv_planifies         INTEGER DEFAULT 0,
  propositions_envoyees INTEGER DEFAULT 0,
  ventes_signees        INTEGER DEFAULT 0,
  revenu_jour           DECIMAL(10,2) DEFAULT 0,

  -- Performance agents
  performance_agents    JSONB DEFAULT '{}',

  -- Rapport Manager
  rapport_manager       TEXT,
  alertes               JSONB DEFAULT '[]',
  recommandations       JSONB DEFAULT '[]',

  -- Meta
  metadata              JSONB DEFAULT '{}'
);

-- ============================================================
-- TABLE 13 : configuration
-- ============================================================
CREATE TABLE IF NOT EXISTS configuration (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  cle         TEXT NOT NULL UNIQUE,
  valeur      JSONB NOT NULL,
  description TEXT,
  type        TEXT DEFAULT 'general' CHECK (type IN ('general','email','prospecting','agents','security','limits')),
  modifiable  BOOLEAN DEFAULT TRUE
);

-- Configuration par défaut
INSERT INTO configuration (cle, valeur, description, type) VALUES
-- Limites email
('email.max_par_jour',        '10',                       'Max emails envoyés par jour',                    'limits'),
('email.delai_relance_jours', '7',                        'Délai minimum en jours avant relance',           'limits'),
('email.max_relances',        '1',                        'Nombre maximum de relances par prospect',        'limits'),
('email.heure_debut',         '"08:00"',                  'Heure de début d''envoi emails',                 'email'),
('email.heure_fin',           '"18:00"',                  'Heure de fin d''envoi emails',                   'email'),
('email.jours_envoi',         '[1,2,3,4,5]',              'Jours d''envoi (1=lundi, 7=dimanche)',           'email'),

-- Prospection
('prospecting.score_min',     '50',                       'Score minimum pour contacter un prospect',       'prospecting'),
('prospecting.sources',       '["google_maps","linkedin"]','Sources actives pour la prospection',           'prospecting'),
('prospecting.secteurs_cibles','["restaurant","commerce","artisan","service","pme"]','Secteurs cibles',   'prospecting'),
('prospecting.zones_geo',     '["France"]',               'Zones géographiques ciblées',                   'prospecting'),
('prospecting.max_leads_jour','50',                       'Max leads prospectés par jour',                  'limits'),

-- Agents
('agents.mode_auto',          'true',                     'Mode automatique activé',                        'agents'),
('agents.modele_ia',          '"gpt-4"',                  'Modèle IA utilisé par défaut',                  'agents'),
('agents.rapport_heure',      '"23:00"',                  'Heure du rapport quotidien Manager',             'agents'),

-- Gmail
('gmail.expediteur',          '""',                       'Adresse email expéditrice',                     'email'),
('gmail.nom_expediteur',      '"AI Sales Agency"',         'Nom affiché de l''expéditeur',                  'email'),
('gmail.signature',           '""',                       'Signature email HTML',                          'email'),

-- Business
('business.services',         '["site_web","refonte","seo","application_mobile","e-commerce"]','Services proposés','general'),
('business.prix_mini',        '500',                      'Prix minimum d''un projet',                     'general'),
('business.prix_maxi',        '10000',                    'Prix maximum d''un projet',                     'general'),

-- Sécurité
('security.auto_sales_mode',  'false',                    'Mode vente automatique (nécessite validation)',  'security'),
('security.test_mode',        'true',                     'Mode test (emails envoyés en simulation)',       'security')

ON CONFLICT (cle) DO NOTHING;

-- ============================================================
-- TRIGGERS ET FONCTIONS
-- ============================================================

-- Fonction mise à jour updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Appliquer sur toutes les tables
DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['leads','clients','agents','agent_memory','workflows','strategies','emails','ventes','tickets','kpi_quotidiens','configuration']
  LOOP
    EXECUTE format('
      DROP TRIGGER IF EXISTS trg_updated_at_%1$s ON %1$s;
      CREATE TRIGGER trg_updated_at_%1$s
        BEFORE UPDATE ON %1$s
        FOR EACH ROW EXECUTE FUNCTION update_updated_at();
    ', t);
  END LOOP;
END $$;

-- ============================================================
-- TRIGGER : Nouveau lead → créer activité + initialiser pipeline
-- ============================================================
CREATE OR REPLACE FUNCTION on_nouveau_lead()
RETURNS TRIGGER AS $$
BEGIN
  -- Créer activité
  INSERT INTO activites (lead_id, agent_role, type, titre, description, important)
  VALUES (
    NEW.id, 'prospecteur', 'creation_lead',
    'Nouveau lead : ' || NEW.entreprise,
    'Source: ' || COALESCE(NEW.source, 'manuel') || ' | Ville: ' || COALESCE(NEW.ville, '?'),
    TRUE
  );

  -- Créer transition initiale
  INSERT INTO pipeline_transitions (lead_id, vers_statut, vers_agent, agent_role, action, succes)
  VALUES (NEW.id, 'nouveau', 'analyste', 'prospecteur', 'creation_lead', TRUE);

  -- Mettre à jour KPI du jour
  INSERT INTO kpi_quotidiens (date, leads_trouves)
  VALUES (CURRENT_DATE, 1)
  ON CONFLICT (date) DO UPDATE
    SET leads_trouves = kpi_quotidiens.leads_trouves + 1,
        updated_at = NOW();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_nouveau_lead ON leads;
CREATE TRIGGER trg_nouveau_lead
  AFTER INSERT ON leads
  FOR EACH ROW EXECUTE FUNCTION on_nouveau_lead();

-- ============================================================
-- TRIGGER : Changement statut lead → tracer pipeline
-- ============================================================
CREATE OR REPLACE FUNCTION on_lead_statut_change()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.statut IS DISTINCT FROM NEW.statut THEN
    -- Tracer la transition
    INSERT INTO pipeline_transitions (lead_id, de_statut, vers_statut, de_agent, vers_agent, agent_role, action)
    VALUES (
      NEW.id, OLD.statut, NEW.statut,
      OLD.agent_actuel, NEW.agent_actuel,
      COALESCE(NEW.agent_actuel, 'manager'), 'changement_statut'
    );

    -- Créer activité
    INSERT INTO activites (lead_id, agent_role, type, titre, description)
    VALUES (
      NEW.id,
      COALESCE(NEW.agent_actuel, 'manager'),
      'modification_statut',
      'Statut : ' || OLD.statut || ' → ' || NEW.statut,
      'Lead: ' || NEW.entreprise
    );

    -- KPI : si qualifié
    IF NEW.statut = 'qualifie' AND OLD.statut != 'qualifie' THEN
      INSERT INTO kpi_quotidiens (date, leads_qualifies)
      VALUES (CURRENT_DATE, 1)
      ON CONFLICT (date) DO UPDATE
        SET leads_qualifies = kpi_quotidiens.leads_qualifies + 1,
            updated_at = NOW();
    END IF;

    -- KPI : si non qualifié
    IF NEW.statut = 'non_qualifie' AND OLD.statut != 'non_qualifie' THEN
      INSERT INTO kpi_quotidiens (date, leads_non_qualifies)
      VALUES (CURRENT_DATE, 1)
      ON CONFLICT (date) DO UPDATE
        SET leads_non_qualifies = kpi_quotidiens.leads_non_qualifies + 1,
            updated_at = NOW();
    END IF;

    -- KPI : si vente gagnée
    IF NEW.statut = 'gagne' AND OLD.statut != 'gagne' THEN
      INSERT INTO kpi_quotidiens (date, ventes_signees)
      VALUES (CURRENT_DATE, 1)
      ON CONFLICT (date) DO UPDATE
        SET ventes_signees = kpi_quotidiens.ventes_signees + 1,
            updated_at = NOW();
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_lead_statut ON leads;
CREATE TRIGGER trg_lead_statut
  AFTER UPDATE ON leads
  FOR EACH ROW EXECUTE FUNCTION on_lead_statut_change();

-- ============================================================
-- TRIGGER : Email envoyé → MAJ stats
-- ============================================================
CREATE OR REPLACE FUNCTION on_email_envoye()
RETURNS TRIGGER AS $$
BEGIN
  -- Nouveau email envoyé
  IF NEW.direction = 'envoye' AND NEW.statut = 'envoye' AND
     (OLD.statut IS NULL OR OLD.statut != 'envoye') THEN

    -- Incrémenter compteurs sur le lead
    UPDATE leads SET
      nb_emails_envoyes = nb_emails_envoyes + 1,
      nb_contacts = nb_contacts + 1,
      dernier_contact = NOW(),
      nb_relances = CASE WHEN NEW.est_relance THEN nb_relances + 1 ELSE nb_relances END,
      statut = CASE WHEN statut = 'qualifie' THEN 'contacte' ELSE statut END,
      updated_at = NOW()
    WHERE id = NEW.lead_id;

    -- Créer activité
    INSERT INTO activites (lead_id, email_id, agent_role, type, titre, description)
    VALUES (
      NEW.lead_id, NEW.id, 'commercial', 'email_envoye',
      'Email envoyé : ' || NEW.sujet,
      'À : ' || NEW.a || CASE WHEN NEW.est_relance THEN ' (RELANCE ' || NEW.numero_relance || ')' ELSE '' END
    );

    -- KPI
    INSERT INTO kpi_quotidiens (date, emails_envoyes)
    VALUES (CURRENT_DATE, 1)
    ON CONFLICT (date) DO UPDATE
      SET emails_envoyes = kpi_quotidiens.emails_envoyes + 1,
          updated_at = NOW();
  END IF;

  -- Email reçu (réponse)
  IF NEW.direction = 'recu' AND (OLD.direction IS NULL OR OLD.direction != 'recu') THEN
    -- MAJ statut lead
    UPDATE leads SET
      statut = CASE
        WHEN NEW.intention = 'refuse' THEN 'perdu'
        WHEN NEW.intention = 'interesse' THEN 'en_discussion'
        ELSE statut
      END,
      updated_at = NOW()
    WHERE id = NEW.lead_id;

    -- Créer activité
    INSERT INTO activites (lead_id, email_id, agent_role, type, titre, description, important)
    VALUES (
      NEW.lead_id, NEW.id, 'commercial', 'email_recu',
      'Réponse reçue : ' || NEW.sujet,
      'De : ' || NEW.de || ' | Intention : ' || COALESCE(NEW.intention::TEXT, '?'),
      TRUE
    );

    -- KPI
    INSERT INTO kpi_quotidiens (date, emails_recus)
    VALUES (CURRENT_DATE, 1)
    ON CONFLICT (date) DO UPDATE
      SET emails_recus = kpi_quotidiens.emails_recus + 1,
          updated_at = NOW();
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_email_envoye ON emails;
CREATE TRIGGER trg_email_envoye
  AFTER INSERT OR UPDATE ON emails
  FOR EACH ROW EXECUTE FUNCTION on_email_envoye();

-- ============================================================
-- TRIGGER : Vente gagnée → créer client automatiquement
-- ============================================================
CREATE OR REPLACE FUNCTION on_vente_gagnee()
RETURNS TRIGGER AS $$
DECLARE
  v_lead RECORD;
  v_client_id UUID;
BEGIN
  IF NEW.statut = 'gagnee' AND (OLD.statut IS NULL OR OLD.statut != 'gagnee') THEN
    -- Récupérer infos lead
    SELECT * INTO v_lead FROM leads WHERE id = NEW.lead_id;

    -- Créer client si lead trouvé
    IF FOUND AND v_lead.contact_email IS NOT NULL THEN
      INSERT INTO clients (
        lead_id, entreprise, secteur, contact_nom, contact_email,
        contact_phone, valeur_contrat, mensualite, date_signature,
        type_projet, statut
      ) VALUES (
        NEW.lead_id,
        v_lead.entreprise,
        v_lead.secteur,
        v_lead.contact_nom,
        v_lead.contact_email,
        v_lead.contact_phone,
        NEW.montant_ttc,
        NEW.montant_ttc / 12,
        CURRENT_DATE,
        NEW.type_produit,
        'actif'
      )
      ON CONFLICT DO NOTHING
      RETURNING id INTO v_client_id;

      -- MAJ lead
      UPDATE leads SET statut = 'gagne', updated_at = NOW() WHERE id = NEW.lead_id;

      -- Update vente avec client
      NEW.client_id = v_client_id;

      -- KPI revenus
      INSERT INTO kpi_quotidiens (date, revenu_jour, ventes_signees)
      VALUES (CURRENT_DATE, NEW.montant_ttc, 1)
      ON CONFLICT (date) DO UPDATE
        SET revenu_jour = kpi_quotidiens.revenu_jour + NEW.montant_ttc,
            ventes_signees = kpi_quotidiens.ventes_signees + 1,
            updated_at = NOW();
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_vente_gagnee ON ventes;
CREATE TRIGGER trg_vente_gagnee
  BEFORE UPDATE ON ventes
  FOR EACH ROW EXECUTE FUNCTION on_vente_gagnee();

-- ============================================================
-- TRIGGER : Référence auto ventes
-- ============================================================
CREATE OR REPLACE FUNCTION gen_vente_reference()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.reference IS NULL THEN
    NEW.reference = 'VT-' || TO_CHAR(NOW(), 'YYYY') || '-' || LPAD(nextval('ventes_reference_seq')::TEXT, 4, '0');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_vente_reference ON ventes;
CREATE TRIGGER trg_vente_reference
  BEFORE INSERT ON ventes
  FOR EACH ROW EXECUTE FUNCTION gen_vente_reference();

-- ============================================================
-- TRIGGER : Référence auto tickets
-- ============================================================
CREATE OR REPLACE FUNCTION gen_ticket_reference()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.reference IS NULL THEN
    NEW.reference = 'TK-' || TO_CHAR(NOW(), 'YYYY') || '-' || LPAD(nextval('tickets_reference_seq')::TEXT, 4, '0');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_ticket_reference ON tickets;
CREATE TRIGGER trg_ticket_reference
  BEFORE INSERT ON tickets
  FOR EACH ROW EXECUTE FUNCTION gen_ticket_reference();

-- ============================================================
-- FONCTION : Vérifier limites anti-spam
-- ============================================================
CREATE OR REPLACE FUNCTION can_send_email(p_lead_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_lead RECORD;
  v_emails_today INTEGER;
  v_config_max_jour INTEGER;
  v_config_delai INTEGER;
  v_config_max_relances INTEGER;
  v_jours_depuis_contact NUMERIC;
BEGIN
  -- Récupérer config
  SELECT (valeur::TEXT)::INTEGER INTO v_config_max_jour
  FROM configuration WHERE cle = 'email.max_par_jour';
  v_config_max_jour := COALESCE(v_config_max_jour, 10);

  SELECT (valeur::TEXT)::INTEGER INTO v_config_delai
  FROM configuration WHERE cle = 'email.delai_relance_jours';
  v_config_delai := COALESCE(v_config_delai, 7);

  SELECT (valeur::TEXT)::INTEGER INTO v_config_max_relances
  FROM configuration WHERE cle = 'email.max_relances';
  v_config_max_relances := COALESCE(v_config_max_relances, 1);

  -- Récupérer lead
  SELECT * INTO v_lead FROM leads WHERE id = p_lead_id;
  IF NOT FOUND THEN
    RETURN '{"peut_envoyer": false, "raison": "lead_introuvable"}'::JSONB;
  END IF;

  -- Désabonné ?
  IF v_lead.desabonne THEN
    RETURN '{"peut_envoyer": false, "raison": "desabonne"}'::JSONB;
  END IF;

  -- Perdu/Invalide ?
  IF v_lead.statut IN ('perdu', 'invalide', 'gagne') THEN
    RETURN jsonb_build_object('peut_envoyer', FALSE, 'raison', 'statut_' || v_lead.statut);
  END IF;

  -- Email manquant ?
  IF v_lead.contact_email IS NULL THEN
    RETURN '{"peut_envoyer": false, "raison": "email_manquant"}'::JSONB;
  END IF;

  -- Max relances atteint ?
  IF v_lead.nb_relances >= v_config_max_relances AND v_lead.nb_emails_envoyes > 0 THEN
    RETURN jsonb_build_object('peut_envoyer', FALSE, 'raison', 'max_relances', 'nb_relances', v_lead.nb_relances);
  END IF;

  -- Délai relance respecté ?
  IF v_lead.dernier_contact IS NOT NULL THEN
    v_jours_depuis_contact := EXTRACT(EPOCH FROM (NOW() - v_lead.dernier_contact)) / 86400;
    IF v_jours_depuis_contact < v_config_delai THEN
      RETURN jsonb_build_object(
        'peut_envoyer', FALSE,
        'raison', 'delai_non_respecte',
        'jours_restants', CEIL(v_config_delai - v_jours_depuis_contact)
      );
    END IF;
  END IF;

  -- Quota journalier ?
  SELECT COUNT(*) INTO v_emails_today
  FROM emails
  WHERE direction = 'envoye'
    AND statut = 'envoye'
    AND DATE(envoye_at) = CURRENT_DATE;

  IF v_emails_today >= v_config_max_jour THEN
    RETURN jsonb_build_object('peut_envoyer', FALSE, 'raison', 'quota_journalier', 'envoyes_aujourd_hui', v_emails_today);
  END IF;

  -- OK !
  RETURN jsonb_build_object(
    'peut_envoyer', TRUE,
    'nb_emails_envoyes', v_lead.nb_emails_envoyes,
    'envoyes_aujourd_hui', v_emails_today,
    'quota_restant', v_config_max_jour - v_emails_today
  );
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- FONCTION : Rapport KPI quotidien
-- ============================================================
CREATE OR REPLACE FUNCTION get_kpi_dashboard()
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'leads', jsonb_build_object(
      'total', (SELECT COUNT(*) FROM leads),
      'nouveaux_7j', (SELECT COUNT(*) FROM leads WHERE created_at > NOW() - INTERVAL '7 days'),
      'qualifies', (SELECT COUNT(*) FROM leads WHERE statut = 'qualifie'),
      'contactes', (SELECT COUNT(*) FROM leads WHERE statut IN ('contacte','en_discussion','proposition')),
      'gagnes', (SELECT COUNT(*) FROM leads WHERE statut = 'gagne'),
      'perdus', (SELECT COUNT(*) FROM leads WHERE statut = 'perdu'),
      'score_moyen', (SELECT ROUND(AVG(score)::NUMERIC, 1) FROM leads WHERE statut != 'invalide')
    ),
    'emails', jsonb_build_object(
      'envoyes_total', (SELECT COUNT(*) FROM emails WHERE direction = 'envoye' AND statut = 'envoye'),
      'envoyes_7j', (SELECT COUNT(*) FROM emails WHERE direction = 'envoye' AND statut = 'envoye' AND created_at > NOW() - INTERVAL '7 days'),
      'recus_total', (SELECT COUNT(*) FROM emails WHERE direction = 'recu'),
      'taux_reponse', CASE WHEN (SELECT COUNT(*) FROM emails WHERE direction = 'envoye' AND statut = 'envoye') > 0
        THEN ROUND(((SELECT COUNT(*) FROM emails WHERE direction = 'recu')::NUMERIC /
                    (SELECT COUNT(*) FROM emails WHERE direction = 'envoye' AND statut = 'envoye')) * 100, 1)
        ELSE 0 END
    ),
    'ventes', jsonb_build_object(
      'total', (SELECT COUNT(*) FROM ventes WHERE statut = 'gagnee'),
      'ca_total', (SELECT COALESCE(SUM(montant_ttc), 0) FROM ventes WHERE statut = 'gagnee'),
      'en_cours', (SELECT COUNT(*) FROM ventes WHERE statut IN ('proposition','negociation')),
      'ca_pipeline', (SELECT COALESCE(SUM(montant_ttc * probabilite / 100), 0) FROM ventes WHERE statut IN ('proposition','negociation'))
    ),
    'clients', jsonb_build_object(
      'total', (SELECT COUNT(*) FROM clients WHERE statut = 'actif'),
      'satisfaction_moyenne', (SELECT ROUND(AVG(satisfaction)::NUMERIC, 1) FROM clients WHERE satisfaction IS NOT NULL)
    ),
    'kpi_aujourd_hui', (SELECT to_jsonb(k.*) FROM kpi_quotidiens k WHERE date = CURRENT_DATE LIMIT 1)
  ) INTO v_result;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================

-- Activer RLS sur toutes les tables
ALTER TABLE leads              ENABLE ROW LEVEL SECURITY;
ALTER TABLE clients            ENABLE ROW LEVEL SECURITY;
ALTER TABLE agents             ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_memory       ENABLE ROW LEVEL SECURITY;
ALTER TABLE workflows          ENABLE ROW LEVEL SECURITY;
ALTER TABLE pipeline_transitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE strategies         ENABLE ROW LEVEL SECURITY;
ALTER TABLE emails             ENABLE ROW LEVEL SECURITY;
ALTER TABLE activites          ENABLE ROW LEVEL SECURITY;
ALTER TABLE ventes             ENABLE ROW LEVEL SECURITY;
ALTER TABLE tickets            ENABLE ROW LEVEL SECURITY;
ALTER TABLE kpi_quotidiens     ENABLE ROW LEVEL SECURITY;
ALTER TABLE configuration      ENABLE ROW LEVEL SECURITY;

-- Policies : accès total pour les rôles authentifiés (service_role bypass RLS automatiquement)
-- Pour le client anon (dashboard public), lecture seulement sur les KPIs

-- Leads : lecture/écriture pour authenticated
DROP POLICY IF EXISTS leads_auth ON leads;
CREATE POLICY leads_auth ON leads
  FOR ALL TO authenticated USING (TRUE) WITH CHECK (TRUE);

DROP POLICY IF EXISTS leads_service ON leads;
CREATE POLICY leads_service ON leads
  FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);

-- Répliquer pour toutes les tables
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['clients','agents','agent_memory','workflows','pipeline_transitions',
                            'strategies','emails','activites','ventes','tickets',
                            'kpi_quotidiens','configuration']
  LOOP
    EXECUTE format('
      DROP POLICY IF EXISTS %1$s_auth ON %1$s;
      CREATE POLICY %1$s_auth ON %1$s FOR ALL TO authenticated USING (TRUE) WITH CHECK (TRUE);
      DROP POLICY IF EXISTS %1$s_service ON %1$s;
      CREATE POLICY %1$s_service ON %1$s FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);
    ', t);
  END LOOP;
END $$;

-- KPI : lecture publique pour dashboard
DROP POLICY IF EXISTS kpi_anon_read ON kpi_quotidiens;
CREATE POLICY kpi_anon_read ON kpi_quotidiens
  FOR SELECT TO anon USING (TRUE);

-- Configuration : lecture publique (sauf secrets)
DROP POLICY IF EXISTS config_anon_read ON configuration;
CREATE POLICY config_anon_read ON configuration
  FOR SELECT TO anon USING (type != 'security');

-- ============================================================
-- VUES UTILES
-- ============================================================

-- Vue leads avec dernière activité
CREATE OR REPLACE VIEW v_leads_complet AS
SELECT
  l.*,
  (SELECT titre FROM activites a WHERE a.lead_id = l.id ORDER BY a.created_at DESC LIMIT 1) AS derniere_activite,
  (SELECT created_at FROM activites a WHERE a.lead_id = l.id ORDER BY a.created_at DESC LIMIT 1) AS derniere_activite_at,
  (SELECT COUNT(*) FROM emails e WHERE e.lead_id = l.id AND e.direction = 'envoye') AS total_emails_envoyes,
  (SELECT COUNT(*) FROM emails e WHERE e.lead_id = l.id AND e.direction = 'recu') AS total_reponses
FROM leads l;

-- Vue pipeline summary
CREATE OR REPLACE VIEW v_pipeline_summary AS
SELECT
  statut,
  COUNT(*) AS nb_leads,
  ROUND(AVG(score)::NUMERIC, 1) AS score_moyen,
  COUNT(CASE WHEN contact_email IS NOT NULL THEN 1 END) AS avec_email
FROM leads
WHERE statut NOT IN ('invalide','desabonne')
GROUP BY statut
ORDER BY
  CASE statut
    WHEN 'nouveau' THEN 1
    WHEN 'en_analyse' THEN 2
    WHEN 'qualifie' THEN 3
    WHEN 'contacte' THEN 4
    WHEN 'en_discussion' THEN 5
    WHEN 'proposition' THEN 6
    WHEN 'negociation' THEN 7
    WHEN 'gagne' THEN 8
    WHEN 'perdu' THEN 9
    WHEN 'non_qualifie' THEN 10
    ELSE 99
  END;

-- ============================================================
-- VÉRIFICATION FINALE
-- ============================================================
SELECT
  schemaname,
  tablename,
  tableowner
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('leads','clients','agents','agent_memory','workflows',
                    'pipeline_transitions','strategies','emails','activites',
                    'ventes','tickets','kpi_quotidiens','configuration')
ORDER BY tablename;

-- Message de succès
SELECT '✅ AI Sales Agency Schema V5 — Installation complète!' AS status,
       COUNT(*) || ' tables créées' AS tables
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('leads','clients','agents','agent_memory','workflows',
                    'pipeline_transitions','strategies','emails','activites',
                    'ventes','tickets','kpi_quotidiens','configuration');
