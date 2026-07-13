// ============================================================
// AI Sales Agency — ANALYSTE IA V2
// Rôle : Scorer les leads, qualifier, identifier opportunités
// ============================================================
const BaseAgent = require('./base_agent');
const config = require('../config');

class AnalysteAgent extends BaseAgent {
  constructor() {
    super('analyste', 'Analyste IA V2');
  }

  // ============================================================
  // SCORING PRINCIPAL
  // ============================================================

  async scorerLead(leadId) {
    const lead = await this.getLead(leadId);
    this.log(`📊 Scoring: ${lead.entreprise} (${lead.ville})`);

    const scoring = await this._calculerScore(lead);
    const qualification = this._qualifier(scoring.total, lead);

    // Mise à jour Supabase
    const updates = {
      score: scoring.total,
      score_detail: scoring.detail,
      probleme_detecte: scoring.probleme_detecte || lead.probleme_detecte,
      opportunite: scoring.opportunite || lead.opportunite,
      besoin_estime: scoring.besoin_estime,
      budget_estime: scoring.budget_estime,
      statut: qualification.statut,
      agent_actuel: qualification.statut === 'qualifie' ? 'strategist' : 'manager',
    };

    await this.updateLead(leadId, updates);
    await this.logActivite(
      leadId, 'score_calcule',
      `Score: ${scoring.total}/100 — ${qualification.statut}`,
      `${JSON.stringify(scoring.detail)}`
    );
    await this.logTransition(leadId, lead.statut, qualification.statut, 'scorer_lead', { lead_id: leadId }, { score: scoring.total, qualification });

    this.logSuccess(`Lead scoré: ${lead.entreprise} → ${scoring.total}/100 → ${qualification.statut}`);

    // Transmettre au Strategist si qualifié
    if (qualification.statut === 'qualifie') {
      await this.sendMessage('strategist', 'TASK', {
        action: 'creer_strategie',
        lead_id: leadId,
        score: scoring.total,
        probleme: scoring.probleme_detecte,
        opportunite: scoring.opportunite,
      }, leadId);
    }

    return { lead_id: leadId, score: scoring.total, statut: qualification.statut, scoring };
  }

  async scorerMultiple(leadIds) {
    this.log(`📊 Scoring batch: ${leadIds.length} leads`);
    const results = [];
    for (const id of leadIds) {
      try {
        const result = await this.scorerLead(id);
        results.push(result);
      } catch (err) {
        this.logError(`Erreur scoring ${id}: ${err.message}`);
        results.push({ lead_id: id, error: err.message });
      }
    }
    return results;
  }

  // ============================================================
  // ALGORITHME DE SCORING (100 points)
  // ============================================================

  async _calculerScore(lead) {
    const detail = {};
    let total = 0;
    let probleme_detecte = lead.probleme_detecte;
    let opportunite = lead.opportunite;

    // ─── 1. PRÉSENCE WEB (30 points) ───────────────────────────

    // Site web absent = opportunité maximale (30 pts)
    // Site présent mais vieux = 15 pts
    // Site présent et récent = 5 pts
    if (!lead.site_web) {
      detail.presence_web = 30;
      probleme_detecte = 'Aucun site web professionnel';
      opportunite = 'Création site web vitrine + référencement local';
    } else if (lead.site_age_annees && lead.site_age_annees > 3) {
      detail.presence_web = 20;
      probleme_detecte = `Site web obsolète (${lead.site_age_annees} ans)`;
      opportunite = 'Refonte site web moderne et responsive';
    } else if (!lead.site_mobile) {
      detail.presence_web = 18;
      probleme_detecte = 'Site web non responsive/mobile';
      opportunite = 'Modernisation site web mobile-first';
    } else {
      detail.presence_web = 8;
      opportunite = 'Optimisation SEO et performances';
    }
    total += detail.presence_web;

    // ─── 2. NOTES GOOGLE / RÉPUTATION (20 points) ──────────────

    if (lead.google_maps_note) {
      if (lead.google_maps_note >= 4.5) {
        // Très bien noté = clients potentiels = argent disponible
        detail.reputation = 20;
      } else if (lead.google_maps_note >= 4.0) {
        detail.reputation = 15;
      } else if (lead.google_maps_note >= 3.5) {
        detail.reputation = 10;
      } else {
        detail.reputation = 5;
      }

      // Bonus nombre d'avis
      if (lead.google_maps_avis >= 100) detail.reputation = Math.min(20, detail.reputation + 3);
      else if (lead.google_maps_avis >= 50) detail.reputation = Math.min(20, detail.reputation + 1);
    } else {
      detail.reputation = 8; // Pas de données Google
    }
    total += detail.reputation;

    // ─── 3. CONTACT DISPONIBLE (20 points) ─────────────────────

    let contactScore = 0;
    if (lead.contact_email) contactScore += 12;
    if (lead.contact_phone) contactScore += 5;
    if (lead.contact_nom) contactScore += 3;
    detail.contact = Math.min(20, contactScore);
    total += detail.contact;

    // ─── 4. SECTEUR ET BUDGET ESTIMÉ (15 points) ───────────────

    const secteursBudgets = {
      restaurant: { score: 14, budget: 1500, besoin: 'Site vitrine + menu + réservation en ligne' },
      hotel: { score: 15, budget: 3000, besoin: 'Site réservation + galerie + SEO' },
      pharmacie: { score: 14, budget: 2500, besoin: 'Site informatif + formulaire + référencement' },
      medecin: { score: 13, budget: 1800, besoin: 'Site professionnel + prise de RDV en ligne' },
      dentiste: { score: 13, budget: 2000, besoin: 'Site clinique + formulaire RDV' },
      avocat: { score: 15, budget: 2500, besoin: 'Site vitrine professionnel + blog juridique' },
      comptable: { score: 13, budget: 2000, besoin: 'Site cabinet + espace client' },
      agence_immobiliere: { score: 15, budget: 4000, besoin: 'Site annonces + CRM + SEO local' },
      artisan: { score: 12, budget: 1200, besoin: 'Site vitrine + galerie réalisations + devis' },
      coiffeur: { score: 11, budget: 1000, besoin: 'Site vitrine + réservation en ligne' },
      commerce: { score: 12, budget: 2000, besoin: 'Site e-commerce ou vitrine + SEO local' },
      plombier: { score: 13, budget: 1200, besoin: 'Site urgence + formulaire devis + SEO' },
      electricien: { score: 13, budget: 1200, besoin: 'Site vitrine + urgence + devis' },
    };

    const secteurData = secteursBudgets[lead.secteur] ||
      secteursBudgets[Object.keys(secteursBudgets).find(k => lead.secteur?.includes(k))] ||
      { score: 8, budget: 1500, besoin: 'Site professionnel' };

    detail.secteur = secteurData.score;
    total += detail.secteur;

    const besoin_estime = secteurData.besoin;
    const budget_estime = secteurData.budget * (1 + (lead.google_maps_avis || 0) / 1000);

    // ─── 5. URGENCE / OPPORTUNITÉ (15 points) ──────────────────

    let urgenceScore = 5; // Base

    // Concurrence locale sans site = urgence
    if (!lead.site_web && lead.google_maps_note >= 4.0) urgenceScore += 7;
    // Beaucoup d'avis = business actif = peut investir
    if ((lead.google_maps_avis || 0) > 50) urgenceScore += 3;

    detail.urgence = Math.min(15, urgenceScore);
    total += detail.urgence;

    this.log(`Score détaillé pour ${lead.entreprise}: web=${detail.presence_web}, réputation=${detail.reputation}, contact=${detail.contact}, secteur=${detail.secteur}, urgence=${detail.urgence} → TOTAL=${total}`);

    return {
      total: Math.min(100, total),
      detail,
      probleme_detecte,
      opportunite,
      besoin_estime,
      budget_estime: Math.round(budget_estime),
    };
  }

  // ============================================================
  // QUALIFICATION
  // ============================================================

  _qualifier(score, lead) {
    const scoreMin = config.limits.minScoreToContact;

    if (!lead.contact_email && !lead.contact_phone) {
      return {
        statut: 'non_qualifie',
        raison: 'Aucun moyen de contact disponible',
        recommandation: 'Rechercher les coordonnées avant de contacter',
      };
    }

    if (score >= scoreMin) {
      return {
        statut: 'qualifie',
        raison: `Score ${score}/100 ≥ seuil ${scoreMin}`,
        recommandation: 'Contacter immédiatement',
        priorite: score >= 75 ? 'haute' : score >= 60 ? 'normale' : 'basse',
      };
    }

    return {
      statut: 'non_qualifie',
      raison: `Score ${score}/100 < seuil ${scoreMin}`,
      recommandation: 'Prospect non prioritaire — mettre en liste d\'attente',
    };
  }
}

module.exports = AnalysteAgent;
