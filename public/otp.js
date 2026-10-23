/* ============================================================================
 * OmniSMS — Vérification du numéro de téléphone par OTP (PWA)
 * ----------------------------------------------------------------------------
 * Contrat serveur RÉEL (backend `routes/otp.js` + `services/otpService.js`) —
 * aucun champ ni endpoint inventé ici :
 *
 *   POST /api/auth/send-otp    body { phone, userId? }
 *     200 → { success:true,  message, phone, devCode? }
 *     429 → { success:false, code:'OTP_COOLDOWN', cooldown }
 *     400 → { success:false, code:'VALIDATION_ERROR'|'OTP_SEND_FAILED' }
 *
 *   POST /api/auth/verify-otp  body { phone, code, userId? }
 *     200 → { success:true, token, phoneVerified:true, user }
 *     400 → { code:'OTP_INVALID', triesRemaining }
 *     410 → { code:'OTP_EXPIRED' }
 *     429 → { code:'OTP_MAX_TRIES' }
 *     404 → { code:'OTP_NOT_FOUND' }
 *
 * ⚠️ ÉTAT RÉEL DU BACKEND (vérifié le 21/10/2026) : `routes/otp.js` n'est
 * monté NULLE PART (`server.js` : « OTP routes supprimées ») et `register`
 * crée l'utilisateur avec `phoneVerified: true`.
 * Tant que ces endpoints répondent 404, ce module ÉCHOUE FERMÉ : aucune
 * vérification n'est simulée et aucune session n'est ouverte.
 *
 * Règles appliquées :
 *   • le code n'est jamais persisté (ni localStorage, ni sessionStorage,
 *     ni journal) — il ne quitte pas la fonction de soumission ;
 *   • la session n'est ouverte QUE si le serveur confirme et renvoie un
 *     jeton d'accès ;
 *   • un jeton d'attente éventuel est stocké à part, jamais comme jeton
 *     d'accès ;
 *   • une seule requête d'envoi / de vérification à la fois.
 * ==========================================================================*/
(function (root, factory) {
  var api = factory();
  if (typeof module === 'object' && module.exports) {
    module.exports = api;              // tests Node (`node --test`)
  } else {
    root.OmniSmsOtp = api;             // navigateur
  }
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

  /** Contrat serveur — valeurs relevées dans le code du backend. */
  var CONTRACT = {
    sendEndpoint: '/api/auth/send-otp',
    verifyEndpoint: '/api/auth/verify-otp',
    /** `OTP_LENGTH = 6` dans services/otpService.js (validation : 4 à 8). */
    codeLength: 6,
    /** `OTP_COOLDOWN_MS` = 60 s. */
    resendCooldownSeconds: 60,
    /** `OTP_TTL_MS` = 10 minutes. */
    validitySeconds: 600,
    /** `DEFAULT_PHONE_COUNTRY = 'BF'` côté serveur. */
    defaultCountryCode: '226',
    /** Clé de persistance de la vérification en attente. */
    pendingStorageKey: 'omnisms_pending_verification'
  };

  /** Natures d'échec — mappées depuis les codes du backend. */
  var FAILURE = {
    INVALID_CODE: 'INVALID_CODE',
    EXPIRED: 'EXPIRED',
    TOO_MANY_ATTEMPTS: 'TOO_MANY_ATTEMPTS',
    NO_PENDING_CODE: 'NO_PENDING_CODE',
    COOLDOWN: 'COOLDOWN',
    SERVICE_UNAVAILABLE: 'SERVICE_UNAVAILABLE',
    VALIDATION: 'VALIDATION',
    NETWORK: 'NETWORK',
    SERVER: 'SERVER',
    UNKNOWN: 'UNKNOWN'
  };

  /** Politique d'exigence (miroir de `OtpPolicy` côté Flutter). */
  var POLICY = {
    /** Suit le serveur : exigé si `requiresOtp` ou `phoneVerified === false`. */
    FOLLOW_SERVER: 'FOLLOW_SERVER',
    /** Exige l'OTP après création de compte, même si le serveur a renvoyé un
     *  jeton (ce jeton devient alors un jeton d'attente). */
    ALWAYS_AFTER_SIGNUP: 'ALWAYS_AFTER_SIGNUP',
    /** Jamais exigé (secours / incident). */
    DISABLED: 'DISABLED'
  };

  /* ── Numéro de téléphone ─────────────────────────────────────────────── */

  /** Miroir de `simpleNormalize()` (services/phoneNormalizer.js). */
  function normalizePhone(raw) {
    var input = String(raw == null ? '' : raw).trim();
    if (!input) return '';
    var p = input.replace(/[\s\-().]/g, '');
    if (p.indexOf('00') === 0) p = '+' + p.slice(2);
    if (p.charAt(0) !== '+') p = '+' + CONTRACT.defaultCountryCode + p;
    return p;
  }

  /** Valide au sens du serveur : E.164 (`^\+[1-9]\d{6,14}$`). */
  function isValidPhone(raw) {
    return /^\+[1-9]\d{6,14}$/.test(normalizePhone(raw));
  }

  /** Souplesse de la validation serveur d'avant normalisation. */
  function isAcceptablePhone(raw) {
    return /^\+?[0-9\s\-().]{7,20}$/.test(String(raw == null ? '' : raw).trim());
  }

  /** '+22670123456' → '+226701•••56' */
  function maskPhone(raw) {
    var n = normalizePhone(raw);
    if (n.length < 7) return n;
    return n.slice(0, n.length - 5) + '•••' + n.slice(-2);
  }

  /* ── Décision : le serveur exige-t-il la vérification ? ──────────────── */

  /**
   * @param {Object} data  Réponse de /register, /login ou /google/exchange
   * @param {Object} opts  { isSignup, policy }
   * @returns {boolean}
   */
  function serverRequiresVerification(data, opts) {
    opts = opts || {};
    var policy = opts.policy || POLICY.FOLLOW_SERVER;
    if (policy === POLICY.DISABLED) return false;

    var body = data || {};
    var explicit = body.requiresOtp === true;
    var user = body.user || {};
    var unverified = user.phoneVerified === false;

    if (policy === POLICY.ALWAYS_AFTER_SIGNUP && opts.isSignup) {
      // Pas de numéro ⇒ pas de vérification possible.
      return phoneFromAuthResponse(body) !== '';
    }
    return explicit || unverified;
  }

  function phoneFromAuthResponse(data) {
    var body = data || {};
    if (body.phone != null && String(body.phone).trim() !== '') {
      return String(body.phone).trim();
    }
    var user = body.user || {};
    return user.phone != null ? String(user.phone).trim() : '';
  }

  /* ── Client HTTP ─────────────────────────────────────────────────────── */

  /**
   * @param {Object} deps
   * @param {Function} deps.request  (path, body) => Promise<{ok, status, data}>
   * @param {number}  [deps.cooldownSeconds]
   */
  function createOtpClient(deps) {
    var request = deps.request;
    var sendInFlight = false;
    var verifyInFlight = false;

    function failure(kind, message, extra) {
      var out = { ok: false, failure: kind, message: message };
      if (extra) Object.keys(extra).forEach(function (k) { out[k] = extra[k]; });
      return out;
    }

    function firstFieldMessage(data) {
      if (data && Array.isArray(data.fields) && data.fields.length) {
        var f = data.fields[0];
        if (f && f.msg) return String(f.msg);
      }
      return null;
    }

    async function sendCode(args) {
      if (sendInFlight) {
        return failure(FAILURE.UNKNOWN, 'Une demande est déjà en cours.');
      }
      var phone = normalizePhone(args.phone);
      if (!isValidPhone(args.phone)) {
        return failure(
          FAILURE.VALIDATION,
          'Numéro de téléphone invalide. Utilisez le format international, par exemple +22670123456.'
        );
      }

      sendInFlight = true;
      try {
        var body = { phone: phone };
        if (args.userId) body.userId = args.userId;
        if (args.pendingToken) body.pendingToken = args.pendingToken;

        var res = await request(CONTRACT.sendEndpoint, body);
        var data = (res && res.data) || {};
        var code = data.code || '';

        if (res && res.ok && data.success === true) {
          return {
            ok: true,
            message: data.message || 'Code envoyé.',
            cooldownSeconds: CONTRACT.resendCooldownSeconds,
            devCode: data.devCode || null
          };
        }

        // 404 hors OTP_NOT_FOUND = route non montée côté serveur.
        if (res && res.status === 404 && code !== 'OTP_NOT_FOUND') {
          return failure(
            FAILURE.SERVICE_UNAVAILABLE,
            "Le service d'envoi de code est momentanément indisponible. Réessayez plus tard."
          );
        }

        if (code === 'OTP_COOLDOWN' || (res && res.status === 429)) {
          var cd = Number(data.cooldown) || CONTRACT.resendCooldownSeconds;
          return failure(
            FAILURE.COOLDOWN,
            'Patientez ' + cd + ' s avant de renvoyer un code.',
            { cooldownSeconds: cd }
          );
        }

        if (code === 'VALIDATION_ERROR') {
          return failure(
            FAILURE.VALIDATION,
            firstFieldMessage(data) || 'Numéro de téléphone refusé par le serveur.'
          );
        }

        if (res && res.status >= 500) {
          return failure(
            FAILURE.SERVER,
            "Le serveur n'a pas pu envoyer le code. Réessayez dans un instant."
          );
        }

        return failure(
          FAILURE.SERVER,
          data.error || data.message || 'Envoi du code impossible.'
        );
      } catch (e) {
        return failure(FAILURE.NETWORK, networkMessage(e));
      } finally {
        sendInFlight = false;
      }
    }

    async function verifyCode(args) {
      if (verifyInFlight) {
        return failure(FAILURE.UNKNOWN, 'Une vérification est déjà en cours.');
      }
      var phone = normalizePhone(args.phone);
      var code = String(args.code == null ? '' : args.code).trim();

      if (!code) {
        return failure(FAILURE.VALIDATION, 'Saisissez le code reçu par SMS.');
      }
      if (!/^\d{4,8}$/.test(code)) {
        return failure(
          FAILURE.VALIDATION,
          'Le code doit contenir uniquement des chiffres.'
        );
      }

      verifyInFlight = true;
      try {
        var body = { phone: phone, code: code };
        if (args.userId) body.userId = args.userId;
        if (args.pendingToken) body.pendingToken = args.pendingToken;

        var res = await request(CONTRACT.verifyEndpoint, body);
        var data = (res && res.data) || {};
        var errCode = data.code || '';

        // Succès : confirmation serveur ET jeton d'accès.
        if (res && res.ok && data.success === true && data.token) {
          return {
            ok: true,
            message: data.message || 'Numéro vérifié.',
            token: data.token,
            user: data.user || null
          };
        }

        if (errCode === 'OTP_INVALID') {
          var remaining = data.triesRemaining;
          var msg = 'Code incorrect.';
          if (typeof remaining === 'number' && remaining > 0) {
            msg += ' Il vous reste ' + remaining + ' essai' + (remaining > 1 ? 's' : '') + '.';
          }
          return failure(FAILURE.INVALID_CODE, msg, { triesRemaining: remaining });
        }
        if (errCode === 'OTP_EXPIRED') {
          return failure(FAILURE.EXPIRED, 'Code expiré. Demandez un nouveau code.');
        }
        if (errCode === 'OTP_MAX_TRIES') {
          return failure(
            FAILURE.TOO_MANY_ATTEMPTS,
            'Trop de tentatives. Demandez un nouveau code.'
          );
        }
        if (errCode === 'OTP_NOT_FOUND') {
          return failure(
            FAILURE.NO_PENDING_CODE,
            'Aucun code en attente pour ce numéro. Demandez un nouveau code.'
          );
        }
        if (errCode === 'VALIDATION_ERROR') {
          return failure(
            FAILURE.VALIDATION,
            firstFieldMessage(data) || 'Code refusé par le serveur.'
          );
        }
        if (res && res.status === 404) {
          return failure(
            FAILURE.SERVICE_UNAVAILABLE,
            'Le service de vérification est momentanément indisponible. Réessayez plus tard.'
          );
        }
        if (res && res.status >= 500) {
          return failure(
            FAILURE.SERVER,
            "Le serveur n'a pas pu vérifier le code. Réessayez dans un instant."
          );
        }
        // Réponse 200 mais sans jeton : échec fermé.
        return failure(
          FAILURE.SERVER,
          "Le serveur n'a pas confirmé la vérification. Réessayez."
        );
      } catch (e) {
        return failure(FAILURE.NETWORK, networkMessage(e));
      } finally {
        verifyInFlight = false;
      }
    }

    return {
      sendCode: sendCode,
      verifyCode: verifyCode,
      isSendInFlight: function () { return sendInFlight; },
      isVerifyInFlight: function () { return verifyInFlight; }
    };
  }

  function networkMessage(e) {
    var s = String((e && e.message) || e || '');
    if (/Failed host lookup|NetworkError|Failed to fetch/i.test(s)) {
      return 'Impossible de joindre le serveur. Vérifiez votre connexion internet.';
    }
    if (/SyntaxError|JSON/i.test(s)) {
      return 'Réponse inattendue du serveur. Réessayez.';
    }
    return 'Erreur réseau. Réessayez.';
  }

  /* ── Persistance de la vérification en attente ───────────────────────── */

  /**
   * Stocke UNIQUEMENT { phone, userId, pendingToken, origin, createdAt }.
   * Jamais le code saisi, jamais de jeton d'accès.
   */
  function createPendingStore(storage) {
    function read() {
      try {
        var raw = storage.getItem(CONTRACT.pendingStorageKey);
        if (!raw) return null;
        var parsed = JSON.parse(raw);
        if (!parsed || !parsed.phone) return null;
        return parsed;
      } catch (_) {
        return null;
      }
    }
    return {
      get: read,
      set: function (pending) {
        try {
          storage.setItem(CONTRACT.pendingStorageKey, JSON.stringify(pending));
        } catch (_) { /* stockage indisponible : parcours non repris, sans échec */ }
      },
      clear: function () {
        try { storage.removeItem(CONTRACT.pendingStorageKey); } catch (_) {}
      }
    };
  }

  /* ── Machine à états du parcours ─────────────────────────────────────── */

  /**
   * @param {Object} deps
   * @param {Object} deps.client         Client OTP
   * @param {Object} deps.store          Persistance de l'attente
   * @param {Function} [deps.now]        Horloge injectable (tests)
   * @param {Function} [deps.onUpdate]   Appelée à chaque changement d'état
   * @param {Function} [deps.onSession]  Reçoit { token, user } APRÈS
   *                                     confirmation serveur : c'est à elle
   *                                     d'ouvrir la session.
   */
  function createOtpFlow(deps) {
    var client = deps.client;
    var store = deps.store;
    var now = deps.now || function () { return Date.now(); };
    var onUpdate = deps.onUpdate || function () {};
    var onSession = deps.onSession || function () {};

    var pending = null;      // { phone, userId, pendingToken, origin }
    var sending = false;
    var verifying = false;
    var error = null;
    var failure = null;
    var cooldownUntil = 0;

    function emit() { onUpdate(snapshot()); }

    function snapshot() {
      return {
        pending: pending,
        sending: sending,
        verifying: verifying,
        error: error,
        failure: failure,
        resendWait: resendWait(),
        required: pending !== null
      };
    }

    function resendWait() {
      var left = cooldownUntil - now();
      return left > 0 ? Math.ceil(left / 1000) : 0;
    }

    /**
     * Analyse une réponse d'authentification. Si le serveur exige la
     * vérification, mémorise l'attente (et persiste) SANS ouvrir de session.
     * @returns {{required: boolean}}
     */
    function begin(authResponse, opts) {
      opts = opts || {};
      var required = serverRequiresVerification(authResponse, {
        isSignup: !!opts.isSignup,
        policy: opts.policy || POLICY.FOLLOW_SERVER
      });

      if (!required) return { required: false };

      pending = {
        phone: normalizePhone(phoneFromAuthResponse(authResponse)),
        userId: (authResponse && (authResponse.userId || (authResponse.user && authResponse.user.id))) || null,
        // Jeton D'ATTENTE : jamais utilisé comme jeton d'accès.
        pendingToken: (authResponse && authResponse.token) || null,
        origin: opts.origin || 'signup',
        createdAt: new Date().toISOString()
      };
      error = null;
      failure = null;
      store.set(pending);
      emit();
      return { required: true, pending: pending };
    }

    /** Reprise d'une vérification interrompue (rechargement, onglet fermé). */
    function restore() {
      var stored = store.get();
      if (!stored) return false;
      pending = stored;
      emit();
      return true;
    }

    async function resend() {
      if (!pending) return { ok: false, failure: FAILURE.UNKNOWN, message: 'Aucune vérification en cours.' };
      if (sending) return { ok: false, failure: FAILURE.UNKNOWN, message: 'Une demande est déjà en cours.' };

      sending = true;
      error = null;
      failure = null;
      emit();

      try {
        var result = await client.sendCode({
          phone: pending.phone,
          userId: pending.userId,
          pendingToken: pending.pendingToken
        });

        var seconds = (result && result.cooldownSeconds) || CONTRACT.resendCooldownSeconds;
        cooldownUntil = now() + seconds * 1000;

        if (!result.ok) {
          error = result.message;
          failure = result.failure;
        }
        sending = false;
        emit();
        return result;
      } catch (e) {
        sending = false;
        cooldownUntil = now() + CONTRACT.resendCooldownSeconds * 1000;
        error = networkMessage(e);
        failure = FAILURE.NETWORK;
        emit();
        return { ok: false, failure: FAILURE.NETWORK, message: error };
      }
    }

    /**
     * Soumet le code. La session n'est ouverte QUE si le serveur renvoie un
     * jeton d'accès.
     */
    async function verify(code) {
      if (!pending) {
        error = 'Aucune vérification en cours.';
        failure = FAILURE.UNKNOWN;
        emit();
        return false;
      }
      if (verifying) return false;        // anti double soumission

      if (!/^\d{4,8}$/.test(String(code == null ? '' : code).trim())) {
        error = 'Le code doit contenir uniquement des chiffres.';
        failure = FAILURE.VALIDATION;
        emit();
        return false;
      }

      verifying = true;
      error = null;
      failure = null;
      emit();

      try {
        var result = await client.verifyCode({
          phone: pending.phone,
          code: code,
          userId: pending.userId,
          pendingToken: pending.pendingToken
        });

        if (result.ok && result.token) {
          // ── Seule porte d'entrée de la session ──
          store.clear();
          pending = null;
          verifying = false;
          cooldownUntil = 0;
          emit();
          onSession({ token: result.token, user: result.user });
          return true;
        }

        error = result.message;
        failure = result.failure;
        verifying = false;
        emit();
        return false;
      } catch (e) {
        verifying = false;
        error = networkMessage(e);
        failure = FAILURE.NETWORK;
        emit();
        return false;
      }
    }

    function cancel() {
      store.clear();
      pending = null;
      error = null;
      failure = null;
      cooldownUntil = 0;
      emit();
    }

    function clearError() {
      error = null;
      failure = null;
      emit();
    }

    return {
      begin: begin,
      restore: restore,
      resend: resend,
      verify: verify,
      cancel: cancel,
      clearError: clearError,
      snapshot: snapshot,
      resendWait: resendWait,
      get pending() { return pending; }
    };
  }

  return {
    CONTRACT: CONTRACT,
    FAILURE: FAILURE,
    POLICY: POLICY,
    normalizePhone: normalizePhone,
    isValidPhone: isValidPhone,
    isAcceptablePhone: isAcceptablePhone,
    maskPhone: maskPhone,
    serverRequiresVerification: serverRequiresVerification,
    phoneFromAuthResponse: phoneFromAuthResponse,
    createOtpClient: createOtpClient,
    createPendingStore: createPendingStore,
    createOtpFlow: createOtpFlow
  };
});
