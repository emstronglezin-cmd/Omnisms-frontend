// ============================================================
// AI Sales Agency — COMMUNICATION STRATEGIST IA V1
// Rôle : Créer stratégies personnalisées + générer emails
// ============================================================
const BaseAgent = require('./base_agent');
const config = require('../config');

class StrategistAgent extends BaseAgent {
  constructor() {
    super('strategist', 'Communication Strategist IA V1');
  }

  // ============================================================
  // CRÉATION STRATÉGIE
  // ============================================================

  async creerStrategie(leadId) {
    const lead = await this.getLead(leadId);
    this.log(`✍️  Création stratégie pour: ${lead.entreprise} (${lead.secteur})`);

    // Analyser le profil
    const profil = this._analyserProfil(lead);

    // Générer l'email personnalisé
    const emailData = await this._genererEmail(lead, profil);

    // Sauvegarder la stratégie
    const strategie = await this._sauvegarderStrategie(leadId, profil, emailData);

    // MAJ lead avec stratégie
    await this.updateLead(leadId, {
      strategie_id: strategie?.id,
      message_personnalise: emailData.corps,
      angle_approche: profil.angle,
      agent_actuel: 'commercial',
    });

    await this.logActivite(
      leadId, 'note_ajoutee',
      `Stratégie créée: angle "${profil.angle}"`,
      `Sujet: ${emailData.sujet}`
    );

    // Transmettre au Commercial
    await this.sendMessage('commercial', 'TASK', {
      action: 'envoyer_email',
      lead_id: leadId,
      strategie_id: strategie?.id,
      sujet: emailData.sujet,
      corps: emailData.corps,
    }, leadId);

    this.logSuccess(`Stratégie prête pour ${lead.entreprise}: "${emailData.sujet}"`);
    return strategie;
  }

  // ============================================================
  // ANALYSE PROFIL PROSPECT
  // ============================================================

  _analyserProfil(lead) {
    // Déterminer l'angle d'approche selon le contexte
    let angle = 'creation_site_web';
    let ton = 'professionnel';
    let points_cles = [];
    let differenciateurs = [];

    // Aucun site web
    if (!lead.site_web) {
      angle = 'opportunite_manquee';
      points_cles = [
        '80% des consommateurs cherchent en ligne avant d\'acheter',
        'Vos concurrents ont déjà leur site web',
        'Vous perdez des clients chaque jour',
      ];
      differenciateurs = [
        'Site livré en 7 jours',
        'Référencement local inclus',
        'Devis gratuit en 24h',
      ];
    }
    // Site obsolète
    else if (lead.site_age_annees > 3 || lead.probleme_detecte?.includes('obsolète')) {
      angle = 'modernisation_urgente';
      points_cles = [
        'Un site daté pénalise votre référencement Google',
        '53% des visiteurs quittent un site non mobile',
        'Vos concurrents ont évolué',
      ];
      differenciateurs = [
        'Design moderne et responsive',
        'Optimisé pour le mobile',
        'Performances améliorées x3',
      ];
    }
    // Bonne réputation, peut investir
    else if ((lead.google_maps_note || 0) >= 4.2) {
      angle = 'amplification_succes';
      ton = 'amical';
      points_cles = [
        `Votre note ${lead.google_maps_note}/5 sur Google est excellente`,
        'Un site professionnel transformerait cette réputation en revenus',
        'Convertir vos avis en clients supplémentaires',
      ];
      differenciateurs = [
        'Intégration automatique de vos avis Google',
        'Système de réservation en ligne',
        'Optimisation SEO local',
      ];
    }

    // Adapter le ton au secteur
    if (['restaurant', 'coiffeur', 'sport'].includes(lead.secteur)) {
      ton = 'amical';
    } else if (['avocat', 'medecin', 'comptable'].includes(lead.secteur)) {
      ton = 'formel';
    }

    return {
      angle,
      ton,
      points_cles,
      differenciateurs,
      urgence: lead.score >= 75 ? 'haute' : 'normale',
      budget_suggere: lead.budget_estime || 1500,
    };
  }

  // ============================================================
  // GÉNÉRATION EMAIL PERSONNALISÉ
  // ============================================================

  async _genererEmail(lead, profil) {
    // Essayer OpenAI d'abord
    if (config.openai.apiKey) {
      try {
        return await this._genererEmailIA(lead, profil);
      } catch (err) {
        this.logWarn(`OpenAI indisponible: ${err.message} — utilisation template`);
      }
    }

    // Fallback: template ultra-personnalisé
    return this._genererEmailTemplate(lead, profil);
  }

  async _genererEmailIA(lead, profil) {
    const { Configuration, OpenAIApi } = require('openai');
    const openai = new OpenAIApi(new Configuration({ apiKey: config.openai.apiKey }));

    const prompt = `Tu es un expert en développement commercial pour une agence web.
Écris un email de prospection ULTRA-PERSONNALISÉ pour :

Entreprise: ${lead.entreprise}
Secteur: ${lead.secteur}
Ville: ${lead.ville}
Problème: ${lead.probleme_detecte}
Opportunité: ${lead.opportunite}
Note Google: ${lead.google_maps_note || 'N/A'}/5 (${lead.google_maps_avis || 0} avis)
Site web: ${lead.site_web || 'AUCUN'}
Contact: ${lead.contact_nom || 'le responsable'}

Angle: ${profil.angle}
Ton: ${profil.ton}
Points clés: ${profil.points_cles.join(', ')}

Règles STRICTES:
- Email court (150-200 mots maximum)
- Personnalisation spécifique à CETTE entreprise (cite le nom, la ville, le secteur)
- Mention d'un fait spécifique (note Google, absence de site, etc.)
- 1 seul call-to-action clair
- Pas de spam, pas de promesses folles
- Signature professionnelle
- Format JSON: {"sujet": "...", "corps": "...", "call_to_action": "..."}`;

    const response = await openai.createChatCompletion({
      model: config.openai.model,
      messages: [{ role: 'user', content: prompt }],
      temperature: 0.7,
      max_tokens: 600,
    });

    const content = response.data.choices[0].message.content;
    return JSON.parse(content);
  }

  _genererEmailTemplate(lead, profil) {
    const prenom = lead.contact_prenom || lead.contact_nom?.split(' ')[0] || 'Madame/Monsieur';
    const ville = lead.ville || 'votre ville';
    const entreprise = lead.entreprise;

    // Templates par angle
    const templates = {
      opportunite_manquee: {
        sujet: `${entreprise} : chaque jour sans site web, c'est des clients perdus`,
        corps: `Bonjour ${prenom},

En recherchant des entreprises de ${lead.secteur} à ${ville}, j'ai remarqué que ${entreprise} n'a pas encore de site web professionnel.

Saviez-vous que 81% des consommateurs vérifient en ligne avant de se déplacer ? Chaque jour, des clients potentiels cherchent "${lead.secteur} à ${ville}" sur Google — et ne trouvent pas ${entreprise}.

Votre concurrence, elle, est déjà visible en ligne.

Je serais ravi de vous montrer en 15 minutes comment un site professionnel peut changer la donne pour ${entreprise} — avec des exemples concrets dans votre secteur.

Seriez-vous disponible cette semaine pour un appel rapide ?`,
        call_to_action: 'Répondre pour planifier un appel de 15 minutes',
      },

      modernisation_urgente: {
        sujet: `${entreprise} : votre site web vous coûte-t-il des clients ?`,
        corps: `Bonjour ${prenom},

J'ai visité le site de ${entreprise} et j'ai remarqué qu'il mériterait une mise à jour pour correspondre aux standards actuels.

Aujourd'hui, Google pénalise les sites non optimisés pour mobile — et vos visiteurs sur smartphone représentent plus de 60% du trafic.

Nous avons récemment refait le site d'une entreprise similaire à ${ville} : +45% de demandes de contact en 3 mois.

Je peux vous préparer une analyse gratuite de votre site actuel, avec les points d'amélioration prioritaires.

Intéressé(e) par ce diagnostic offert ?`,
        call_to_action: 'Demander mon diagnostic gratuit',
      },

      amplification_succes: {
        sujet: `${entreprise} : votre note ${lead.google_maps_note}/5 mérite mieux qu'un simple profil Google`,
        corps: `Bonjour ${prenom},

En cherchant les meilleurs ${lead.secteur} à ${ville}, j'ai été impressionné par les avis de ${entreprise} — ${lead.google_maps_note}/5 avec ${lead.google_maps_avis} avis, c'est excellent !

Imaginez si ces clients satisfaits pouvaient vous trouver encore plus facilement, réserver directement en ligne, et partager votre site à leurs proches.

Un site professionnel bien référencé transformerait cette réputation en croissance continue.

Je serais curieux de vous montrer ce que nous avons fait pour des entreprises similaires dans la région.

15 minutes suffisent pour en discuter — êtes-vous disponible ?`,
        call_to_action: 'Voir des exemples de réalisations',
      },
    };

    const template = templates[profil.angle] || templates['opportunite_manquee'];

    // Ajouter la signature
    const signature = `\n\nCordialement,\n${config.gmail.senderName || 'L\'équipe AI Sales Agency'}\n📧 ${config.gmail.senderEmail || ''}\n🌐 Agence Web Professionnelle`;

    return {
      sujet: template.sujet,
      corps: template.corps + signature,
      call_to_action: template.call_to_action,
    };
  }

  // ============================================================
  // SAUVEGARDE STRATÉGIE
  // ============================================================

  async _sauvegarderStrategie(leadId, profil, emailData) {
    if (!this.supabase) {
      this.log(`[MOCK] Stratégie sauvegardée pour lead ${leadId}`);
      return { id: 'mock-strat-' + Date.now(), ...profil, ...emailData };
    }

    const { data, error } = await this.supabase.from('strategies').insert({
      lead_id: leadId,
      angle: profil.angle,
      ton: profil.ton,
      urgence: profil.urgence,
      sujet_email: emailData.sujet,
      corps_email: emailData.corps,
      call_to_action: emailData.call_to_action,
      points_cles: profil.points_cles,
      differenciateurs: profil.differenciateurs,
      statut: 'prete',
    }).select().single();

    if (error) throw new Error(`Erreur sauvegarde stratégie: ${error.message}`);
    return data;
  }
}

module.exports = StrategistAgent;
