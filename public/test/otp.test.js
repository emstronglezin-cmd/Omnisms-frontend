/**
 * Tests du parcours OTP de la PWA — `node --test public/test/otp.test.js`
 *
 * Aucune dépendance externe : le module `public/otp.js` est chargé tel quel
 * et le transport HTTP est simulé, ce qui permet de vérifier les règles de
 * sécurité sans toucher au backend réel.
 */
'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const Otp = require('../otp.js');
const { CONTRACT, FAILURE, POLICY } = Otp;

/* ── Faux transport ───────────────────────────────────────────────────── */
function fakeRequest(handler) {
  const calls = [];
  const fn = async (path, body) => {
    calls.push({ path, body });
    return handler(path, body, calls.length);
  };
  fn.calls = calls;
  return fn;
}

function ok(status, data) {
  return { ok: status >= 200 && status < 300, status, data };
}

/* ── Stockage mémoire ─────────────────────────────────────────────────── */
function memoryStorage() {
  const map = new Map();
  return {
    getItem: (k) => (map.has(k) ? map.get(k) : null),
    setItem: (k, v) => map.set(k, String(v)),
    removeItem: (k) => map.delete(k),
    _map: map,
  };
}

/* ═══════════════════════════════════════════════════════════════════════ */
test('normalisation des numéros (miroir du serveur)', () => {
  assert.equal(Otp.normalizePhone('+226 70 12 34 56'), '+22670123456');
  assert.equal(Otp.normalizePhone('0022670123456'), '+22670123456');
  assert.equal(Otp.normalizePhone('70123456'), '+22670123456');
  assert.equal(Otp.normalizePhone('(+226) 70-12-34-56'), '+22670123456');
  assert.equal(Otp.normalizePhone(''), '');
});

test('validité E.164', () => {
  assert.equal(Otp.isValidPhone('+22670123456'), true);
  assert.equal(Otp.isValidPhone('+226'), false);
  assert.equal(Otp.isValidPhone('bonjour'), false);
});

test('masquage du numéro affiché', () => {
  assert.equal(Otp.maskPhone('+22670123456'), '+226701•••56');
});

/* ═══════════════════════════════════════════════════════════════════════ */
test('décision serveur : requiresOtp: true → vérification exigée', () => {
  assert.equal(
    Otp.serverRequiresVerification(
      { requiresOtp: true, user: { phone: '+22670123456' } },
      { isSignup: true }
    ),
    true
  );
});

test('décision serveur : phoneVerified: false → vérification exigée', () => {
  assert.equal(
    Otp.serverRequiresVerification(
      { token: 'x', user: { phoneVerified: false } },
      { isSignup: false }
    ),
    true
  );
});

test('décision serveur : compte déjà vérifié → rien à faire', () => {
  assert.equal(
    Otp.serverRequiresVerification(
      { token: 'x', user: { phoneVerified: true } },
      { isSignup: false }
    ),
    false
  );
});

test('décision serveur : champ absent = vérifié (règle serveur)', () => {
  assert.equal(
    Otp.serverRequiresVerification(
      { token: 'x', user: { phone: '+22670123456' } },
      { isSignup: false }
    ),
    false,
    'le backend applique `phoneVerified !== false`'
  );
});

test('décision serveur : politique désactivée → jamais exigé', () => {
  assert.equal(
    Otp.serverRequiresVerification(
      { requiresOtp: true },
      { isSignup: true, policy: POLICY.DISABLED }
    ),
    false
  );
});

/* ═══════════════════════════════════════════════════════════════════════ */
test('envoi : succès, numéro normalisé dans la requête', async () => {
  const request = fakeRequest(() => ok(200, { success: true, message: 'Code envoyé.' }));
  const client = Otp.createOtpClient({ request });

  const res = await client.sendCode({ phone: '+226 70 12 34 56' });

  assert.equal(res.ok, true);
  assert.equal(request.calls.length, 1);
  assert.equal(request.calls[0].path, CONTRACT.sendEndpoint);
  assert.equal(request.calls[0].body.phone, '+22670123456');
});

test('envoi : numéro invalide → aucun appel réseau', async () => {
  const request = fakeRequest(() => ok(200, { success: true }));
  const client = Otp.createOtpClient({ request });

  const res = await client.sendCode({ phone: 'pas-un-numero' });

  assert.equal(res.ok, false);
  assert.equal(res.failure, FAILURE.VALIDATION);
  assert.equal(request.calls.length, 0);
});

test('envoi : OTP_COOLDOWN → durée serveur respectée', async () => {
  const client = Otp.createOtpClient({
    request: fakeRequest(() =>
      ok(429, {
        success: false,
        error: 'Attendez 42 secondes.',
        code: 'OTP_COOLDOWN',
        cooldown: 42,
      })
    ),
  });

  const res = await client.sendCode({ phone: '+22670123456' });

  assert.equal(res.failure, FAILURE.COOLDOWN);
  assert.equal(res.cooldownSeconds, 42);
  assert.match(res.message, /42 s/);
});

test('envoi : endpoint absent (404) → service indisponible', async () => {
  const client = Otp.createOtpClient({
    request: fakeRequest(() => ok(404, { error: 'Route not found.', code: 'NOT_FOUND' })),
  });

  const res = await client.sendCode({ phone: '+22670123456' });

  assert.equal(res.failure, FAILURE.SERVICE_UNAVAILABLE);
});

test('envoi : erreur réseau mappée', async () => {
  const client = Otp.createOtpClient({
    request: fakeRequest(() => { throw new Error('Failed host lookup'); }),
  });

  const res = await client.sendCode({ phone: '+22670123456' });

  assert.equal(res.failure, FAILURE.NETWORK);
  assert.match(res.message, /connexion internet/);
});

test('envoi : un seul appel concurrent', async () => {
  let started = 0;
  const client = Otp.createOtpClient({
    request: fakeRequest(async () => {
      started++;
      await new Promise((r) => setTimeout(r, 30));
      return ok(200, { success: true });
    }),
  });

  const [a, b] = await Promise.all([
    client.sendCode({ phone: '+22670123456' }),
    client.sendCode({ phone: '+22670123456' }),
  ]);

  assert.equal(a.ok, true);
  assert.equal(b.ok, false);
  assert.equal(started, 1);
});

/* ═══════════════════════════════════════════════════════════════════════ */
test('vérification : succès → jeton d’accès renvoyé', async () => {
  const request = fakeRequest(() =>
    ok(200, {
      success: true,
      token: 'jwt.verifie',
      phoneVerified: true,
      user: { id: 'uid-1', phone: '+22670123456', phoneVerified: true },
    })
  );
  const client = Otp.createOtpClient({ request });

  const res = await client.verifyCode({ phone: '+22670123456', code: '123456' });

  assert.equal(res.ok, true);
  assert.equal(res.token, 'jwt.verifie');
  assert.equal(request.calls[0].body.code, '123456');
});

test('vérification : 200 sans jeton → échec fermé', async () => {
  const client = Otp.createOtpClient({
    request: fakeRequest(() => ok(200, { success: true, message: 'ok' })),
  });

  const res = await client.verifyCode({ phone: '+22670123456', code: '123456' });

  assert.equal(res.ok, false, 'sans jeton serveur, pas de session');
  assert.equal(res.token, undefined);
});

test('vérification : code incorrect avec essais restants', async () => {
  const client = Otp.createOtpClient({
    request: fakeRequest(() =>
      ok(400, {
        success: false,
        error: 'Code OTP incorrect.',
        code: 'OTP_INVALID',
        triesRemaining: 2,
      })
    ),
  });

  const res = await client.verifyCode({ phone: '+22670123456', code: '000000' });

  assert.equal(res.failure, FAILURE.INVALID_CODE);
  assert.equal(res.triesRemaining, 2);
  assert.match(res.message, /2 essais/);
});

test('vérification : code expiré (410)', async () => {
  const client = Otp.createOtpClient({
    request: fakeRequest(() =>
      ok(410, { success: false, code: 'OTP_EXPIRED', error: 'expiré' })
    ),
  });

  const res = await client.verifyCode({ phone: '+22670123456', code: '123456' });

  assert.equal(res.failure, FAILURE.EXPIRED);
});

test('vérification : trop de tentatives (429)', async () => {
  const client = Otp.createOtpClient({
    request: fakeRequest(() =>
      ok(429, { success: false, code: 'OTP_MAX_TRIES', error: 'trop' })
    ),
  });

  const res = await client.verifyCode({ phone: '+22670123456', code: '123456' });

  assert.equal(res.failure, FAILURE.TOO_MANY_ATTEMPTS);
});

test('vérification : aucun code en attente (404 OTP_NOT_FOUND)', async () => {
  const client = Otp.createOtpClient({
    request: fakeRequest(() =>
      ok(404, { success: false, code: 'OTP_NOT_FOUND', error: 'aucun' })
    ),
  });

  const res = await client.verifyCode({ phone: '+22670123456', code: '123456' });

  assert.equal(res.failure, FAILURE.NO_PENDING_CODE);
});

test('vérification : route non montée (404 générique)', async () => {
  const client = Otp.createOtpClient({
    request: fakeRequest(() => ok(404, { error: 'Route not found.', code: 'NOT_FOUND' })),
  });

  const res = await client.verifyCode({ phone: '+22670123456', code: '123456' });

  assert.equal(res.failure, FAILURE.SERVICE_UNAVAILABLE);
});

test('vérification : erreur serveur (500)', async () => {
  const client = Otp.createOtpClient({
    request: fakeRequest(() => ok(500, { error: 'Erreur serveur.', code: 'SERVER_ERROR' })),
  });

  const res = await client.verifyCode({ phone: '+22670123456', code: '123456' });

  assert.equal(res.failure, FAILURE.SERVER);
});

test('vérification : code malformé refusé localement', async () => {
  const request = fakeRequest(() => ok(200, { success: true, token: 'x' }));
  const client = Otp.createOtpClient({ request });

  const res = await client.verifyCode({ phone: '+22670123456', code: '12ab' });

  assert.equal(res.failure, FAILURE.VALIDATION);
  assert.equal(request.calls.length, 0);
});

/* ═══════════════════════════════════════════════════════════════════════ */
function buildFlow(handler, opts = {}) {
  const request = fakeRequest(handler);
  const client = Otp.createOtpClient({ request });
  const store = Otp.createPendingStore(memoryStorage());
  const sessions = [];
  const flow = Otp.createOtpFlow({
    client,
    store,
    now: opts.now,
    onSession: (s) => sessions.push(s),
  });
  return { flow, request, store, sessions };
}

test('parcours : inscription exigeant l’OTP → attente mémorisée, aucune session', () => {
  const { flow, store, sessions } = buildFlow(() =>
    ok(200, { success: true, token: 'jwt.verifie' })
  );

  const res = flow.begin(
    { requiresOtp: true, userId: 'uid-1', phone: '+226 70 12 34 56', token: 'jeton-attente' },
    { isSignup: true, origin: 'signup' }
  );

  assert.equal(res.required, true);
  assert.equal(flow.pending.phone, '+22670123456');
  assert.equal(flow.pending.pendingToken, 'jeton-attente');
  assert.equal(sessions.length, 0, 'aucune session ouverte à ce stade');
  assert.ok(store.get(), 'l’attente doit être persistée');
  assert.equal(store.get().phone, '+22670123456');
});

test('parcours : compte déjà vérifié → aucune vérification demandée', () => {
  const { flow } = buildFlow(() => ok(200, {}));

  const res = flow.begin(
    { token: 'jwt', user: { id: 'u1', phoneVerified: true } },
    { isSignup: false }
  );

  assert.equal(res.required, false);
  assert.equal(flow.pending, null);
});

test('parcours : renvoi respecte le délai serveur', async () => {
  const { flow } = buildFlow(() => ok(200, { success: true, message: 'Code envoyé.' }));

  flow.begin({ requiresOtp: true, phone: '+22670123456' }, { isSignup: true });
  await flow.resend();

  // 60 s par défaut (CONTRACT.resendCooldownSeconds).
  assert.equal(flow.resendWait(), 60);
});

test('parcours : vérification confirmée → session ouverte une seule fois', async () => {
  const { flow, store, sessions } = buildFlow(() =>
    ok(200, { success: true, token: 'jwt.verifie', user: { id: 'uid-1', phoneVerified: true } })
  );

  flow.begin({ requiresOtp: true, phone: '+22670123456', userId: 'uid-1' }, { isSignup: true });
  const okVerify = await flow.verify('123456');

  assert.equal(okVerify, true);
  assert.deepEqual(sessions, [{ token: 'jwt.verifie', user: { id: 'uid-1', phoneVerified: true } }]);
  assert.equal(flow.pending, null);
  assert.equal(store.get(), null, 'l’attente doit être purgée après vérification');
});

test('parcours : vérification refusée → toujours en attente, aucune session', async () => {
  const { flow, sessions, store } = buildFlow(() =>
    ok(410, { success: false, code: 'OTP_EXPIRED', error: 'expiré' })
  );

  flow.begin({ requiresOtp: true, phone: '+22670123456' }, { isSignup: true });
  const okVerify = await flow.verify('123456');

  assert.equal(okVerify, false);
  assert.equal(sessions.length, 0, 'aucune session sans confirmation serveur');
  assert.ok(flow.pending, 'la vérification reste en attente');
  assert.ok(store.get(), 'l’attente reste persistée');
  assert.equal(flow.snapshot().failure, FAILURE.EXPIRED);
});

test('parcours : service indisponible → message clair, pas de session', async () => {
  const { flow, sessions } = buildFlow(() =>
    ok(404, { error: 'Route not found.', code: 'NOT_FOUND' })
  );

  flow.begin({ requiresOtp: true, phone: '+22670123456' }, { isSignup: true });
  await flow.resend();
  const okVerify = await flow.verify('123456');

  assert.equal(okVerify, false);
  assert.equal(flow.snapshot().failure, FAILURE.SERVICE_UNAVAILABLE);
  assert.equal(sessions.length, 0);
});

test('parcours : double soumission du code → un seul appel', async () => {
  let verifyCalls = 0;
  const { flow } = buildFlow(async (path) => {
    if (path === CONTRACT.verifyEndpoint) verifyCalls++;
    await new Promise((r) => setTimeout(r, 30));
    return ok(200, { success: true, token: 'jwt.verifie', user: { id: 'u' } });
  });

  flow.begin({ requiresOtp: true, phone: '+22670123456' }, { isSignup: true });
  await Promise.all([flow.verify('123456'), flow.verify('123456')]);

  assert.equal(verifyCalls, 1);
});

test('parcours : reprise après interruption (rechargement)', () => {
  const { flow, store } = buildFlow(() => ok(200, {}));
  store.set({ phone: '+22670123456', userId: 'uid-9', origin: 'signup' });

  assert.equal(flow.restore(), true);
  assert.equal(flow.pending.phone, '+22670123456');
});

test('parcours : abandon → attente purgée, aucune session', () => {
  const { flow, store, sessions } = buildFlow(() => ok(200, {}));

  flow.begin({ requiresOtp: true, phone: '+22670123456' }, { isSignup: true });
  flow.cancel();

  assert.equal(flow.pending, null);
  assert.equal(store.get(), null);
  assert.equal(sessions.length, 0);
});

test('contrat : valeurs conformes au backend', () => {
  assert.equal(CONTRACT.sendEndpoint, '/api/auth/send-otp');
  assert.equal(CONTRACT.verifyEndpoint, '/api/auth/verify-otp');
  assert.equal(CONTRACT.codeLength, 6, 'OTP_LENGTH = 6 côté serveur');
  assert.equal(CONTRACT.resendCooldownSeconds, 60, 'OTP_COOLDOWN_MS = 60 s');
  assert.equal(CONTRACT.validitySeconds, 600, 'OTP_TTL_MS = 10 min');
});

test('persistance : le code OTP n’est jamais stocké', () => {
  const storage = memoryStorage();
  const store = Otp.createPendingStore(storage);

  store.set({ phone: '+22670123456', userId: 'u1', pendingToken: 'jeton-attente' });
  const raw = storage.getItem(CONTRACT.pendingStorageKey);

  assert.ok(raw);
  const parsed = JSON.parse(raw);
  // Seules les données d'attente sont persistées — jamais le code saisi.
  assert.deepEqual(Object.keys(parsed).sort(), ['pendingToken', 'phone', 'userId']);
  assert.equal('code' in parsed, false, 'aucun code OTP ne doit être persisté');
  assert.equal(/987654/.test(raw), false, 'aucun code ne doit apparaître');
});
