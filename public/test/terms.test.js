/**
 * Tests de la page publique /terms de la PWA : `node --test public/test/terms.test.js`
 *
 * Le module `public/terms.js` est chargé tel quel (il s'attache à `window`).
 * Aucun serveur, aucun réseau : on vérifie le routage et le rendu, et surtout
 * qu'aucune mention juridique n'est inventée (identité de l'éditeur, tarifs
 * contractuels, responsabilité, droit applicable restent « À compléter »).
 */
'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

// Le module navigateur attend `window` : on le simule minimalement.
global.window = global;
require('../terms.js');
const terms = global.window.OmniSmsTerms;

/* ── Routage ──────────────────────────────────────────────────────────── */
test('isRoute reconnaît /terms (avec ou sans slash final)', () => {
  assert.equal(terms.isRoute('/terms'), true);
  assert.equal(terms.isRoute('/terms/'), true);
});

test('isRoute refuse les autres chemins', () => {
  assert.equal(terms.isRoute('/'), false);
  assert.equal(terms.isRoute('/privacy'), false);
  assert.equal(terms.isRoute('/terms-of-service'), false);
  assert.equal(terms.isRoute(''), false);
});

/* ── Rendu ────────────────────────────────────────────────────────────── */
function fakeEl() {
  return { innerHTML: '' };
}

test('le rendu produit une page complète', () => {
  const el = fakeEl();
  terms.render(el, 'fr');
  const html = el.innerHTML;

  assert.match(html, /Conditions générales d'utilisation/);
  assert.match(html, /Dernière mise à jour/);
  for (const titre of [
    'Objet de ce document',
    'Éditeur du service',
    'Le service',
    'Compte et accès',
    'Suppression du compte',
    'Abonnement Premium',
    'Limites techniques connues',
    'Données personnelles',
    'Propriété intellectuelle',
    'Droit applicable et litiges',
    'Modifications de ces conditions',
  ]) {
    assert.ok(html.includes(titre), `section absente : ${titre}`);
  }
});

test('le rendu échappe le HTML (pas d’injection)', () => {
  const el = fakeEl();
  terms.render(el, 'fr');
  assert.doesNotMatch(el.innerHTML, /<script/i);
});

test('rendu sans élément : aucun plantage', () => {
  assert.doesNotThrow(() => terms.render(null, 'fr'));
});

test('contenu structuré par blocs connus', () => {
  const types = new Set(['p', 'ul', 'note', 'todo']);
  terms.content.fr.sections.forEach((s) => {
    assert.ok(s.title && s.blocks.length > 0);
    s.blocks.forEach((b) => assert.ok(types.has(b.type), `type ${b.type}`));
  });
});

/* ── Aucune mention juridique inventée ────────────────────────────────── */
test('aucune adresse e-mail inventée dans le contenu', () => {
  assert.doesNotMatch(JSON.stringify(terms.content.fr), /[\w.+-]+@[a-z0-9-]+\.[a-z]{2,}/i);
});

test('aucune identité légale ni juridiction inventée', () => {
  const texte = JSON.stringify(terms.content.fr).toLowerCase();
  for (const interdit of ['sarl', 'sas ', 'capital social', 'tribunal de commerce', 'loi burkinab']) {
    assert.ok(!texte.includes(interdit), `mention inventée : ${interdit}`);
  }
});

test('le montant annoncé correspond au code de l’application', () => {
  // lib/screens/subscription_screen.dart envoie amount: 2000, currency: XOF.
  const texte = JSON.stringify(terms.content.fr);
  assert.ok(texte.includes('2 000 FCFA'));
  assert.ok(texte.includes('XOF'));
});

test('la redirection de paiement n’est jamais présentée comme une preuve', () => {
  const texte = JSON.stringify(terms.content.fr).toLowerCase();
  assert.ok(texte.includes('ne vaut pas activation'));
  assert.ok(texte.includes('annulé, refusé ou expiré'));
});

test('aucune promesse de notification à distance non implémentée', () => {
  const texte = JSON.stringify(terms.content.fr).toLowerCase();
  assert.ok(texte.includes("n'est pas encore active"));
  assert.ok(!texte.includes('99,9'));
});

test('les emplacements à compléter sont présents et marqués', () => {
  const todos = terms.content.fr.sections
    .flatMap((s) => s.blocks)
    .filter((b) => b.type === 'todo');
  // Éditeur, hébergeur, usage abusif, tarifs, responsabilité, propriété
  // intellectuelle, droit applicable, information des modifications.
  assert.ok(todos.length >= 8, `emplacements trouvés : ${todos.length}`);
  todos.forEach((t) => assert.match(t.text.toUpperCase(), /COMPLÉTER/));
});

test('le contenu reste cohérent avec la page de confidentialité', () => {
  require('../privacy.js');
  const privacy = global.window.OmniSmsPrivacy;
  const texteTerms = JSON.stringify(terms.content.fr).toLowerCase();
  const textePrivacy = JSON.stringify(privacy.content.fr).toLowerCase();
  // Le délai de suppression annoncé doit être le même des deux côtés.
  assert.ok(texteTerms.includes('30 jours'));
  assert.ok(textePrivacy.includes('30 jours'));
  // Aucune publicité : affirmation identique sur les deux pages.
  assert.ok(texteTerms.includes('aucune publicité'));
  assert.ok(textePrivacy.includes('aucune régie publicitaire'));
});
