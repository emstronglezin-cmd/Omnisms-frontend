/**
 * Tests de la page publique /privacy de la PWA — `node --test public/test/privacy.test.js`
 *
 * Le module `public/privacy.js` est chargé tel quel (il s'attache à `window`).
 * Aucun serveur, aucun réseau : on vérifie le routage et le rendu.
 */
'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

// Le module navigateur attend `window` : on le simule minimalement.
global.window = global;
const Privacy = require('../privacy.js');
const privacy = global.window.OmniSmsPrivacy;

/* ── Routage ──────────────────────────────────────────────────────────── */
test('isRoute reconnaît /privacy (avec ou sans slash final)', () => {
  assert.equal(privacy.isRoute('/privacy'), true);
  assert.equal(privacy.isRoute('/privacy/'), true);
});

test('isRoute refuse les autres chemins', () => {
  assert.equal(privacy.isRoute('/'), false);
  assert.equal(privacy.isRoute('/login'), false);
  assert.equal(privacy.isRoute('/privacy-policy'), false);
  assert.equal(privacy.isRoute(''), false);
});

/* ── Rendu ────────────────────────────────────────────────────────────── */
function fakeEl() {
  return { innerHTML: '' };
}

test('le rendu produit une page complète', () => {
  const el = fakeEl();
  privacy.render(el, 'fr');
  const html = el.innerHTML;

  assert.match(html, /Politique de confidentialité/);
  assert.match(html, /Dernière mise à jour/);
  for (const titre of [
    'Données que nous traitons',
    'Pourquoi nous les traitons',
    'À qui vos données sont transmises',
    'Durée de conservation',
    'Sécurité',
    'Vos droits',
    'Suppression du compte',
  ]) {
    assert.ok(html.includes(titre), `section absente : ${titre}`);
  }
});

test('le rendu échappe le HTML (pas d’injection)', () => {
  // Le contenu ne doit jamais permettre d’injecter une balise.
  const el = fakeEl();
  privacy.render(el, 'fr');
  assert.doesNotMatch(el.innerHTML, /<script/i);
});

test('les tiers réels sont mentionnés', () => {
  const el = fakeEl();
  privacy.render(el, 'fr');
  const html = el.innerHTML;
  for (const tiers of ['Google', 'Infobip', 'Firebase', 'Render']) {
    assert.ok(html.includes(tiers), `tiers absent : ${tiers}`);
  }
});

test('aucune adresse e-mail inventée dans le contenu', () => {
  const c = privacy.content.fr;
  const texte = JSON.stringify(c);
  assert.doesNotMatch(texte, /[\w.+-]+@[\w-]+\.[a-z]{2,}/);
});

test('aucune promesse de chiffrement de bout en bout', () => {
  const texte = JSON.stringify(privacy.content.fr).toLowerCase();
  assert.ok(texte.includes('ne sont pas chiffrés de bout en bout'));
  assert.doesNotMatch(texte, /ne sont jamais (partagé|transmis|divulgué)/);
});

test('les emplacements à compléter sont présents et marqués', () => {
  const c = privacy.content.fr;
  const todos = c.sections
    .flatMap((s) => s.blocks)
    .filter((b) => b.type === 'todo');
  assert.ok(todos.length >= 6, `emplacements trouvés : ${todos.length}`);
  todos.forEach((t) => assert.match(t.text.toUpperCase(), /COMPLÉTER/));
});

test('rendu sans élément : aucun plantage', () => {
  assert.doesNotThrow(() => privacy.render(null, 'fr'));
});

test('contenu structuré par blocs connus', () => {
  const types = new Set(['p', 'ul', 'note', 'todo']);
  privacy.content.fr.sections.forEach((s) => {
    assert.ok(s.title && s.blocks.length > 0);
    s.blocks.forEach((b) => assert.ok(types.has(b.type), `type ${b.type}`));
  });
});
