// ============================================================
// AI Sales Agency — PROSPECTEUR IA V3
// Rôle : Trouver des leads via Google Maps, LinkedIn, réseaux sociaux
// ============================================================
const BaseAgent = require('./base_agent');
const config = require('../config');
const https = require('https');

class ProspecteurAgent extends BaseAgent {
  constructor() {
    super('prospecteur', 'Prospecteur IA V3');
  }

  // ============================================================
  // PROSPECTION PRINCIPALE
  // ============================================================

  async prospecter(options = {}) {
    const {
      ville = 'Lyon',
      secteur = 'restaurant',
      nombre = 10,
      source = 'google_maps',
    } = options;

    this.log(`🔍 Prospection: ${nombre} leads — ${secteur} à ${ville} via ${source}`);
    let leads = [];

    switch (source) {
      case 'google_maps':
        leads = await this.prospecteurGoogleMaps(ville, secteur, nombre);
        break;
      case 'linkedin':
        leads = await this.prospecteurLinkedIn(ville, secteur, nombre);
        break;
      case 'simulation':
      default:
        leads = await this._simulerLeads(ville, secteur, nombre);
    }

    // Enrichir et sauvegarder
    const results = [];
    for (const leadData of leads) {
      try {
        const saved = await this.sauvegarderLead(leadData);
        results.push(saved);
        this.logSuccess(`Lead sauvegardé: ${leadData.entreprise}`);
      } catch (err) {
        this.logError(`Erreur sauvegarde ${leadData.entreprise}: ${err.message}`);
      }
    }

    this.log(`✅ Prospection terminée: ${results.length}/${leads.length} leads sauvegardés`);
    return results;
  }

  // ============================================================
  // GOOGLE MAPS API
  // ============================================================

  async prospecteurGoogleMaps(ville, secteur, nombre) {
    if (!config.googleMaps.apiKey) {
      this.logWarn('Google Maps API Key manquante — simulation activée');
      return this._simulerLeads(ville, secteur, nombre);
    }

    const leads = [];
    const query = encodeURIComponent(`${secteur} ${ville}`);
    const url = `https://maps.googleapis.com/maps/api/place/textsearch/json?query=${query}&key=${config.googleMaps.apiKey}&language=fr&region=fr`;

    try {
      const data = await this._httpGet(url);
      const results = data.results || [];

      for (const place of results.slice(0, nombre)) {
        const details = await this._getPlaceDetails(place.place_id);

        const hasWebsite = !!(details.website);
        const hasGoodRating = place.rating >= 4.0;
        const hasEnoughReviews = (place.user_ratings_total || 0) >= 10;

        // Déterminer le problème détecté
        let probleme = null;
        let opportunite = null;

        if (!hasWebsite) {
          probleme = 'Aucun site web';
          opportunite = 'Création site web professionnel';
        } else if (hasWebsite && !hasGoodRating) {
          probleme = 'Site web existant mais mauvaise réputation Google';
          opportunite = 'Refonte site web + stratégie avis clients';
        } else if (hasWebsite) {
          probleme = 'Site web potentiellement obsolète';
          opportunite = 'Audit + modernisation site web';
        }

        leads.push({
          entreprise: place.name,
          secteur: secteur,
          adresse: place.formatted_address,
          ville: ville,
          source: 'google_maps',
          source_url: `https://maps.google.com/?place_id=${place.place_id}`,
          site_web: details.website || null,
          contact_phone: details.formatted_phone_number || null,
          google_maps_note: place.rating || null,
          google_maps_avis: place.user_ratings_total || 0,
          probleme_detecte: probleme,
          opportunite: opportunite,
          latitude: place.geometry?.location?.lat,
          longitude: place.geometry?.location?.lng,
          metadata: {
            place_id: place.place_id,
            types: place.types,
            business_status: place.business_status,
          },
        });
      }
    } catch (err) {
      this.logError(`Erreur Google Maps: ${err.message}`);
      return this._simulerLeads(ville, secteur, nombre);
    }

    return leads;
  }

  async _getPlaceDetails(placeId) {
    if (!config.googleMaps.apiKey) return {};
    const url = `https://maps.googleapis.com/maps/api/place/details/json?place_id=${placeId}&fields=website,formatted_phone_number,opening_hours&key=${config.googleMaps.apiKey}&language=fr`;
    try {
      const data = await this._httpGet(url);
      return data.result || {};
    } catch {
      return {};
    }
  }

  // ============================================================
  // LINKEDIN (Simulation — API LinkedIn très restrictive)
  // ============================================================

  async prospecteurLinkedIn(ville, secteur, nombre) {
    this.logWarn('LinkedIn API non disponible en mode standard — utilisation simulation enrichie');
    const leads = await this._simulerLeads(ville, secteur, nombre);
    // Marquer comme LinkedIn
    return leads.map(l => ({
      ...l,
      source: 'linkedin',
      source_url: `https://linkedin.com/search/results/companies/?keywords=${encodeURIComponent(l.entreprise)}`,
      contact_linkedin: `https://linkedin.com/in/${l.contact_nom?.toLowerCase().replace(' ', '-') || 'contact'}`,
    }));
  }

  // ============================================================
  // ANALYSE SITE WEB
  // ============================================================

  async analyserSiteWeb(url) {
    if (!url) return { existe: false, age_estime: null, mobile: false, ssl: false };

    const result = {
      existe: false,
      ssl: url.startsWith('https'),
      mobile: false,
      age_estime: null,
      score_performance: null,
    };

    try {
      const response = await this._httpGet(url, { timeout: 5000 });
      result.existe = true;

      // Vérifier responsive basique
      const html = JSON.stringify(response);
      result.mobile = html.includes('viewport') || html.includes('responsive');
    } catch {
      result.existe = false;
    }

    return result;
  }

  // ============================================================
  // SAUVEGARDE LEADS
  // ============================================================

  async sauvegarderLead(leadData) {
    // Vérifier les doublons par email ou nom entreprise + ville
    if (this.supabase) {
      const { data: existing } = await this.supabase
        .from('leads')
        .select('id, entreprise')
        .or(
          leadData.contact_email
            ? `contact_email.eq.${leadData.contact_email},and(entreprise.ilike.${leadData.entreprise},ville.ilike.${leadData.ville || ''})`
            : `entreprise.ilike.${leadData.entreprise}`
        )
        .limit(1);

      if (existing?.length > 0) {
        this.log(`⏭️  Doublon ignoré: ${leadData.entreprise}`);
        return existing[0];
      }

      const { data, error } = await this.supabase
        .from('leads')
        .insert({
          ...leadData,
          statut: 'nouveau',
          agent_actuel: 'analyste',
        })
        .select()
        .single();

      if (error) throw new Error(error.message);
      return data;
    }

    // Mode simulation
    this.log(`[MOCK] Lead sauvegardé: ${leadData.entreprise}`);
    return { id: 'mock-' + Date.now(), ...leadData, statut: 'nouveau' };
  }

  // ============================================================
  // SIMULATION (pour test sans API)
  // ============================================================

  async _simulerLeads(ville, secteur, nombre) {
    const entreprises = {
      restaurant: ['Restaurant Le Gaulois', 'La Table d\'Auguste', 'Brasserie du Pont', 'Pizza Roma', 'Le Bistrot Lyonnais', 'Sushi Garden', 'Burger & Co', 'La Crêperie Bretonne', 'L\'Auberge Provençale', 'Le Petit Chef', 'Le Jardin d\'Éden', 'Chez Marcel'],
      commerce: ['Boutique Mode & Style', 'Librairie du Quartier', 'Sport 2000 Local', 'Fleuriste Les Roses', 'Bijouterie Prestige', 'Papeterie du Centre', 'Fromagerie Artisanale', 'Cave à Vins', 'Maroquinerie Luxe', 'Optique Vision'],
      artisan: ['Plomberie Rapid', 'Électricité Pro', 'Menuiserie Dupont', 'Peinture Leblanc', 'Maçonnerie Martin', 'Chauffage Expert', 'Couverture Toiture', 'Carrelage Design', 'Serrurerie 24h', 'Climatisation Pro'],
      coiffeur: ['Salon Élégance', 'Hair Studio', 'Coiff & Style', 'L\'Atelier du Cheveu', 'Barbershop Kings', 'Beauty Hair', 'Salon Prestige', 'Coiffure Nature'],
    };

    const nomsDisponibles = entreprises[secteur] || entreprises['restaurant'];
    const contactsNoms = ['Jean Dupont', 'Marie Martin', 'Pierre Bernard', 'Sophie Leclerc', 'Antoine Moreau', 'Claire Petit', 'Nicolas Roux', 'Julie Simon', 'François Michel', 'Isabelle Robert'];
    const domaines = ['gmail.com', 'orange.fr', 'free.fr', 'yahoo.fr', 'hotmail.fr'];

    const leads = [];
    const count = Math.min(nombre, nomsDisponibles.length);

    for (let i = 0; i < count; i++) {
      const nomEntreprise = nomsDisponibles[i];
      const contactNom = contactsNoms[i % contactsNoms.length];
      const [prenom, ...nomParts] = contactNom.split(' ');
      const nomFamille = nomParts.join(' ');
      const email = `${prenom.toLowerCase()}.${nomFamille.toLowerCase()}@${domaines[i % domaines.length]}`;

      const hasWebsite = Math.random() > 0.6; // 40% sans site web
      const note = (3.5 + Math.random() * 1.5).toFixed(1);
      const avis = Math.floor(20 + Math.random() * 200);

      leads.push({
        entreprise: nomEntreprise,
        secteur: secteur,
        ville: ville,
        pays: 'France',
        contact_nom: contactNom,
        contact_prenom: prenom,
        contact_email: email,
        contact_phone: `0${Math.floor(6 + Math.random() * 2)} ${Math.floor(10 + Math.random() * 90)} ${Math.floor(10 + Math.random() * 90)} ${Math.floor(10 + Math.random() * 90)} ${Math.floor(10 + Math.random() * 90)}`,
        source: 'google_maps',
        source_detail: `Recherche "${secteur} ${ville}"`,
        site_web: hasWebsite ? `https://www.${nomEntreprise.toLowerCase().replace(/[^a-z0-9]/g, '').substring(0, 15)}.fr` : null,
        google_maps_note: parseFloat(note),
        google_maps_avis: avis,
        probleme_detecte: hasWebsite
          ? (Math.random() > 0.5 ? 'Site web obsolète (>5 ans)' : 'Mauvaise présence digitale')
          : 'Aucun site web professionnel',
        opportunite: hasWebsite
          ? 'Refonte site web + référencement local'
          : 'Création site web vitrine professionnel',
        taille: 'micro',
        statut: 'nouveau',
        metadata: {
          simule: true,
          date_simulation: new Date().toISOString(),
        },
      });
    }

    return leads;
  }

  // ============================================================
  // HTTP HELPER
  // ============================================================

  _httpGet(url, options = {}) {
    return new Promise((resolve, reject) => {
      const timeout = options.timeout || 10000;
      const req = https.get(url, { timeout }, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          try {
            resolve(JSON.parse(data));
          } catch {
            resolve(data);
          }
        });
      });
      req.on('error', reject);
      req.on('timeout', () => { req.destroy(); reject(new Error('Timeout')); });
    });
  }
}

module.exports = ProspecteurAgent;
