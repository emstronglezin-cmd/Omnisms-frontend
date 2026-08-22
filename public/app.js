// OmniSMS PWA v4.3.0 — Stabilisation Auth + Routage OmniSMS
// Architecture Conversations-First (WhatsApp)
// v4.3.0 : fix session expirée, routes publiques sans token, _loggedOut guard, E.164 normalisé

const API_BASE = 'https://omnisms-backend.onrender.com';

// ─── STATE ────────────────────────────────────────────────────────────────────
const State = {
  token:            localStorage.getItem('auth_token'),
  user:             JSON.parse(localStorage.getItem('user_data') || 'null'),
  currentTab:       'messages',
  conversations:    [],
  activeConvId:     null,
  activeConvMsgs:   [],
  activeConvInfo:   null,
  contacts:         [],
  groups:           [],
  pollTimer:        null,
  mediaRecorder:    null,
  audioChunks:      [],
  recordingTimer:   null,
  recordingSeconds: 0,
  isRecording:      false,
  // Anti-race : empêche les requêtes bg de rappeler logout après une déconnexion volontaire
  _loggedOut:       false,
};

// ─── API ──────────────────────────────────────────────────────────────────────
const API = {
  // Routes publiques qui n'ont JAMAIS besoin d'un token d'authentification.
  // Ces routes ne doivent PAS recevoir un ancien token invalide.
  _publicRoutes: ['/api/auth/login', '/api/auth/register', '/api/auth/google'],

  headers(isFormData = false, path = '') {
    const h = { 'Accept': 'application/json' };
    if (!isFormData) h['Content-Type'] = 'application/json';
    // Ne jamais envoyer le token sur les routes publiques d'auth
    const isPublic = this._publicRoutes.some(r => path.startsWith(r));
    if (State.token && !isPublic) h['Authorization'] = `Bearer ${State.token}`;
    return h;
  },

  // Gestion centralisée des 401 :
  // - Ne jamais déclencher logout si on est déjà déconnecté (_loggedOut)
  // - Ne jamais afficher "Session expirée" sur les écrans login/register
  _handle401(path) {
    if (State._loggedOut) return;   // Déjà déconnecté — ignorer les 401 résiduels
    const isPublic = this._publicRoutes.some(r => path.startsWith(r));
    if (isPublic) return;           // Route publique — jamais de logout automatique
    logout();
  },

  async get(path) {
    try {
      const r = await fetch(API_BASE + path, { headers: this.headers(false, path) });
      if (r.status === 401) { this._handle401(path); return null; }
      return r.ok ? r.json() : null;
    } catch { return null; }
  },
  async post(path, body) {
    try {
      const r = await fetch(API_BASE + path, {
        method: 'POST', headers: this.headers(false, path), body: JSON.stringify(body)
      });
      const data = await r.json().catch(() => ({}));
      if (r.status === 401) {
        this._handle401(path);
        // Retourner le message RÉEL du serveur, pas un message générique "Session expirée"
        // pour ne pas polluer les formulaires login/register
        return { ok: false, status: 401, data };
      }
      return { ok: r.ok, status: r.status, data };
    } catch(e) { return { ok: false, status: 0, data: { message: 'Erreur réseau — serveur en cours de démarrage...' } }; }
  },
  async postForm(path, formData) {
    try {
      const r = await fetch(API_BASE + path, {
        method: 'POST', headers: this.headers(true, path), body: formData
      });
      const data = await r.json().catch(() => ({}));
      if (r.status === 401) { this._handle401(path); return { ok: false, status: 401, data }; }
      return { ok: r.ok, status: r.status, data };
    } catch(e) { return { ok: false, status: 0, data: { message: 'Erreur réseau' } }; }
  },
  async put(path, body) {
    try {
      const r = await fetch(API_BASE + path, {
        method: 'PUT', headers: this.headers(false, path), body: JSON.stringify(body)
      });
      const data = await r.json().catch(() => ({}));
      if (r.status === 401) { this._handle401(path); return { ok: false, status: 401, data }; }
      return { ok: r.ok, status: r.status, data };
    } catch(e) { return { ok: false, status: 0, data: { message: 'Erreur réseau' } }; }
  },
  async delete(path) {
    try {
      const r = await fetch(API_BASE + path, { method: 'DELETE', headers: this.headers(false, path) });
      const data = await r.json().catch(() => ({}));
      if (r.status === 401) { this._handle401(path); return { ok: false, status: 401, data }; }
      return { ok: r.ok, status: r.status, data };
    } catch(e) { return { ok: false, data: { message: 'Erreur réseau' } }; }
  }
};

// ─── ROUTER ───────────────────────────────────────────────────────────────────
function showScreen(id) {
  document.querySelectorAll('.screen').forEach(s => s.classList.remove('active'));
  const el = document.getElementById(id);
  if (el) el.classList.add('active');
}

// ─── AUTH ─────────────────────────────────────────────────────────────────────
async function login(identifier, password) {
  setLoading('login-btn', true, 'Se connecter');
  const isPhone = /^[+\d\s\-()+]{7,20}$/.test(identifier.trim()) && !identifier.includes('@');
  const body = isPhone
    ? { phone: identifier.trim(), password }
    : { email: identifier.trim(), password };
  const res = await API.post('/api/auth/login', body);
  setLoading('login-btn', false, 'Se connecter');
  if (res.ok && res.data.token) {
    State.token = res.data.token;
    State.user  = res.data.user || { phone: identifier };
    localStorage.setItem('auth_token', State.token);
    localStorage.setItem('user_data', JSON.stringify(State.user));
    showError('login-error', '');
    // Si le compte n'a pas de téléphone (vieux compte Google/email), forcer l'ajout
    if (State.user.needsPhone || !State.user.phone) {
      initDashboard();
      // Afficher le panneau settings avec message d'avertissement
      setTimeout(() => {
        switchTab('settings');
        showToast('⚠️ Merci d\'ajouter votre numéro de téléphone dans Paramètres.');
      }, 800);
    } else {
      initDashboard();
    }
  } else {
    // Afficher le message d'erreur réel du serveur (jamais "Session expirée" ici)
    const errMsg = res.data?.error || res.data?.message || '';
    // Filtrer le message "Session expirée" qui n'a aucun sens sur la page de connexion
    const displayMsg = (errMsg && !errMsg.includes('Session expir') && !errMsg.includes('TOKEN_EXPIRED'))
      ? errMsg
      : 'Identifiants incorrects. Vérifiez votre téléphone/email et mot de passe.';
    showError('login-error', displayMsg);
  }
}

async function register(name, phone, email, password) {
  setLoading('register-btn', true, "S'inscrire");
  const usernameEl = document.getElementById('reg-username');
  const username   = usernameEl?.value?.trim() || '';
  // Username est maintenant obligatoire
  if (!username) {
    setLoading('register-btn', false, "S'inscrire");
    showError('register-error', "Le nom d'utilisateur est requis.");
    return;
  }
  if (!/^[a-zA-Z0-9_.-]{2,50}$/.test(username)) {
    setLoading('register-btn', false, "S'inscrire");
    showError('register-error', "Le nom d'utilisateur ne peut contenir que des lettres, chiffres, _ . - (2-50 caractères).");
    return;
  }
  const body = { name, phone, password, username };
  if (email && email.trim()) body.email = email.trim();
  const res = await API.post('/api/auth/register', body);
  setLoading('register-btn', false, "S'inscrire");
  if (res.ok && res.data.token) {
    State.token = res.data.token;
    State.user  = res.data.user || { name, phone };
    localStorage.setItem('auth_token', State.token);
    localStorage.setItem('user_data', JSON.stringify(State.user));
    showError('register-error', '');
    initDashboard();
  } else if (res.ok) {
    // Compte créé sans token direct (ne devrait plus arriver)
    showToast('Compte créé ! Connectez-vous.');
    showScreen('screen-login');
  } else {
    const regErrMsg = res.data?.error || res.data?.message || '';
    const regDisplay = (regErrMsg && !regErrMsg.includes('Session expir') && !regErrMsg.includes('TOKEN_EXPIRED'))
      ? regErrMsg
      : 'Erreur lors de la création du compte. Réessayez.';
    showError('register-error', regDisplay);
  }
}

function logout() {
  // Marquer comme déconnecté AVANT tout pour bloquer les requêtes résiduelles
  State._loggedOut = true;

  // Arrêter tous les timers et Socket.IO
  clearInterval(State.pollTimer);
  State.pollTimer = null;
  if (_socket) { try { _socket.disconnect(); } catch (_) {} _socket = null; }

  // Vider l'état en mémoire
  State.token          = null;
  State.user           = null;
  State.conversations  = [];
  State.contacts       = [];
  State.groups         = [];
  State.activeConvId   = null;
  State.activeConvMsgs = [];
  State.activeConvInfo = null;
  State.isRecording    = false;

  // Vider le stockage local
  localStorage.removeItem('auth_token');
  localStorage.removeItem('user_data');
  localStorage.removeItem('leekpay_pending');
  sessionStorage.clear();

  // Nettoyer les caches Service Worker pour forcer rechargement propre
  if ('caches' in window) {
    caches.keys().then(keys => keys.forEach(k => caches.delete(k))).catch(() => {});
  }

  // Réinitialiser les formulaires pour éviter tout résidu
  const loginErr    = document.getElementById('login-error');
  const registerErr = document.getElementById('register-error');
  if (loginErr)    { loginErr.textContent    = ''; loginErr.style.display    = 'none'; }
  if (registerErr) { registerErr.textContent = ''; registerErr.style.display = 'none'; }

  showScreen('screen-login');

  // Réarmer _loggedOut après un délai pour permettre une reconnexion immédiate
  // (les appels résiduels en vol arrivent dans les ~5s après logout)
  setTimeout(() => { State._loggedOut = false; }, 5000);
}

// ─── DASHBOARD ────────────────────────────────────────────────────────────────
function initDashboard() {
  if (!State.token) { showScreen('screen-login'); return; }
  // S'assurer que le flag déconnexion est réinitialisé à chaque connexion
  State._loggedOut = false;
  showScreen('screen-dashboard');
  renderUserInfo();
  switchTab('messages');
  startPolling();
  // Rafraîchir le profil depuis l'API pour synchroniser avatar, username, etc.
  refreshUserProfile();
  // Tenter connexion Socket.IO (dépend du chargement du script io)
  if (typeof io !== 'undefined') {
    initSocketIO();
  } else {
    // Charger socket.io dynamiquement
    const s = document.createElement('script');
    s.src = `${API_BASE}/socket.io/socket.io.js`;
    s.onload = () => initSocketIO();
    s.onerror = () => console.warn('[Socket.IO] Script non chargé — polling uniquement');
    document.head.appendChild(s);
  }
}

/**
 * Rafraîchit le profil utilisateur depuis GET /api/me
 * et met à jour State.user + localStorage + UI.
 * Appelé au démarrage du dashboard et après chaque saveProfile().
 */
async function refreshUserProfile() {
  // Ne pas tenter si déconnecté ou sans token
  if (!State.token || State._loggedOut) return;
  try {
    const data = await API.get('/api/me');
    // Vérifier à nouveau après la réponse (peut avoir été déconnecté entre-temps)
    if (!data || !State.token || State._loggedOut) return;
    // Merge: keep local data but overwrite with fresh server data
    State.user = { ...(State.user || {}), ...data };
    localStorage.setItem('user_data', JSON.stringify(State.user));
    renderUserInfo();
    // Si les paramètres sont ouverts, re-rendre pour afficher les nouvelles valeurs
    if (State.currentTab === 'settings') renderSettings();
  } catch (_) {
    // Silently fail — stale local data is acceptable
  }
}

function renderUserInfo() {
  const name = State.user?.name || State.user?.email || 'Utilisateur';
  const el = document.getElementById('user-name');
  if (el) el.textContent = name;
  const av = document.getElementById('user-avatar');
  if (av) {
    if (State.user?.avatar) {
      av.innerHTML = `<img src="${escHtml(State.user.avatar)}" style="width:100%;height:100%;border-radius:50%;object-fit:cover" alt="avatar">`;
    } else {
      av.textContent = getInitials(name);
    }
    av.title = name;
  }
}

// ─── NAVIGATION ──────────────────────────────────────────────────────────────
function switchTab(tab) {
  State.currentTab = tab;
  document.querySelectorAll('.nav-btn').forEach(b => {
    b.classList.toggle('active', b.dataset.tab === tab);
  });
  document.querySelectorAll('.tab-pane').forEach(p => {
    p.classList.toggle('active', p.id === `tab-${tab}`);
  });
  // silent=true si on a déjà des données en cache (évite le spinner à chaque clic)
  if (tab === 'messages')   loadConversations(State.conversations.length > 0);
  if (tab === 'contacts')   loadContacts();
  if (tab === 'groups')     loadGroups();
  if (tab === 'settings')   renderSettings();
}

// ─── POLLING TEMPS RÉEL (10s) + SOCKET.IO ────────────────────────────────────
let _socket = null;

function startPolling() {
  clearInterval(State.pollTimer);
  // Réduire le polling à 15s si Socket.IO est connecté, 10s sinon
  const interval = _socket?.connected ? 15000 : 10000;
  State.pollTimer = setInterval(() => {
    if (State.currentTab === 'messages') loadConversations(true);
    if (State.activeConvId)             loadActiveConvMessages(true);
  }, interval);
}

function initSocketIO() {
  // Socket.IO CDN — chargé dynamiquement
  if (typeof io === 'undefined') return;
  if (_socket && _socket.connected) return;

  try {
    _socket = io(API_BASE, {
      auth    : { token: State.token },
      transports: ['websocket', 'polling'],
      reconnection: true,
      reconnectionDelay: 3000,
      reconnectionAttempts: 5,
    });

    _socket.on('connect', () => {
      console.log('[Socket.IO] Connecté:', _socket.id);
      // Rejoindre sa room personnelle
      const uid = State.user?.id || State.user?._id;
      if (uid) _socket.emit('join', { userId: uid });
      // Réduire le polling maintenant que socket est actif
      startPolling();
    });

    _socket.on('disconnect', () => {
      console.log('[Socket.IO] Déconnecté — repli sur polling 10s');
      startPolling();
    });

    // Nouveau message reçu en temps réel
    _socket.on('new_message', (msg) => {
      if (!msg) return;
      // Rafraîchir les conversations
      loadConversations(true);
      // Si la conversation active est concernée, rafraîchir les messages
      if (State.activeConvId && (
        msg.conversationId === State.activeConvId ||
        msg.groupId === State.activeConvId
      )) {
        loadActiveConvMessages(true);
      }
    });

    _socket.on('message:receive', (msg) => {
      if (!msg) return;
      // Always refresh conversation list (updates lastMessage, découvre de nouvelles conversations)
      loadConversations(true);
      // P3 FIX: Vérifier si msg.conversationId correspond à la conversation active.
      // Aussi vérifier si l'un des participants (senderId/receiverId) correspond à activeConvInfo.contactId
      // pour les cas où State.activeConvId est encore provisoire (avant le premier sendMessage).
      const activeInfo = State.activeConvInfo;
      const myId = State.user?.id || State.user?._id || '';
      const convMatches = State.activeConvId && (
        msg.conversationId === State.activeConvId ||
        // Cas: conversationId mis à jour après résolution phone→UID
        (activeInfo?.contactId && (
          msg.conversationId === [myId, activeInfo.contactId].sort().join('-') ||
          msg.senderId === activeInfo.contactId ||
          msg.receiverId === activeInfo.contactId
        ))
      );

      if (convMatches) {
        // P0 FIX: mettre à jour l'activeConvId si le serveur a fourni un ID canonique
        if (msg.conversationId && msg.conversationId !== State.activeConvId) {
          State.activeConvId = msg.conversationId;
          if (State.activeConvInfo) State.activeConvInfo.conversationId = msg.conversationId;
        }
        const currentUserId = myId;
        const normalized = {
          ...msg,
          isMe     : (msg.senderId || msg.from) === currentUserId,
          content  : msg.content || msg.text || msg.message || msg.body || '',
          timestamp: msg.timestamp || msg.createdAt || new Date().toISOString(),
        };
        // Avoid duplicate (if already loaded via HTTP poll)
        const exists = State.activeConvMsgs.some(m => (m.id || m._id) === (msg.id || msg._id));
        if (!exists) {
          State.activeConvMsgs.push(normalized);
          renderMessages();
        }
      }
    });

    // Mise à jour de transcription en temps réel (Socket.IO)
    _socket.on('transcription:update', (data) => {
      if (!data?.messageId) return;
      const msg = State.activeConvMsgs.find(m => (m.id || m._id) === data.messageId);
      if (!msg) return;

      if (data.status === 'done' && data.text) {
        msg.transcription       = data.text;
        msg.transcriptionStatus = 'done';
        renderMessages();
        showToast('Transcription terminée ✓');
      } else if (data.status === 'processing') {
        msg.transcriptionStatus = 'processing';
        renderMessages();
      } else if (data.status === 'error') {
        msg.transcriptionStatus = 'error';
        msg.transcriptionError  = data.error;
        renderMessages();
        showToast('Transcription indisponible — ' + (data.error || 'erreur inconnue'));
      }
    });

    // SMS entrant (Cas 3)
    _socket.on('sms:inbound', (data) => {
      loadConversations(true);
      if (State.activeConvId && data.conversationId === State.activeConvId) {
        loadActiveConvMessages(true);
      }
    });

    // P4 FIX: Nouveau membre ajouté à un groupe (notifié en temps réel)
    _socket.on('group:added', (data) => {
      // Rafraîchir la liste des groupes pour voir le nouveau groupe
      loadGroups();
      if (data?.groupName) {
        showToast(`Vous avez été ajouté au groupe "${data.groupName}" ✓`);
      }
    });

    // Synchronisation contacts OmniSMS : un nouveau user vient de s'inscrire
    _socket.on('contact:omnisms', (data) => {
      // Rafraîchir les contacts pour mettre à jour le statut OmniSMS
      if (State.currentTab === 'contacts') loadContacts();
      // Mettre à jour le statut dans le cache local si le contact est déjà présent
      if (data?.phone && State.contacts.length > 0) {
        const found = State.contacts.find(c =>
          c.phone === data.phone ||
          c.phone?.replace(/\s/g, '') === data.phone?.replace(/\s/g, '')
        );
        if (found) {
          found.isOnOmniSms      = true;
          found.userId           = data.uid;
          found.registeredUserId = data.uid;
          if (!found.name && data.name) found.name = data.name;
          renderContacts(State.contacts);
        }
      }
    });

  } catch (err) {
    console.warn('[Socket.IO] Erreur init:', err.message);
  }
}

// ─── Extraire texte du lastMessage (fixe le bug [object Object]) ──────────────
function extractLastMessage(conv) {
  const lm = conv.lastMessage;
  if (!lm) return conv.lastMessageContent || '';
  if (typeof lm === 'string') return lm;
  if (typeof lm === 'object') {
    // C'est un objet message Firestore
    if (lm.type === 'audio') return '🎤 Message vocal';
    if (lm.type === 'image') return '📷 Photo';
    if (lm.type === 'file')  return '📎 Fichier';
    return lm.content || lm.text || lm.body || lm.message || '';
  }
  return String(lm);
}

// ─── MESSAGES — LISTE DES CONVERSATIONS ──────────────────────────────────────
async function loadConversations(silent = false) {
  // Ne rien faire si déconnecté ou sans token
  if (!State.token || State._loggedOut) return;

  // Si des conversations sont déjà en cache et qu'on est en mode silencieux,
  // afficher les données en cache d'abord pour une réponse instantanée
  if (silent && State.conversations.length > 0) {
    renderConversationList();
  }

  if (!silent && State.conversations.length === 0) {
    document.getElementById('conv-list').innerHTML =
      `<div class="loading-state"><div class="spinner"></div><p>Chargement des messages...</p></div>`;
  }

  const data = await API.get('/api/messages');
  if (!data) {
    if (!silent && State.conversations.length === 0) {
      document.getElementById('conv-list').innerHTML =
        `<div class="empty-state">
          <div class="empty-icon">⚠️</div>
          <p>Impossible de charger les messages</p>
          <button class="btn-primary" onclick="loadConversations()">Réessayer</button>
        </div>`;
    }
    return;
  }

  const rawList = Array.isArray(data) ? data : (data.conversations || data.messages || []);

  State.conversations = rawList.sort((a, b) => {
    const ta = a.lastMessageAt || a.lastMessageTime || a.updatedAt || a.createdAt || 0;
    const tb = b.lastMessageAt || b.lastMessageTime || b.updatedAt || b.createdAt || 0;
    return new Date(tb) - new Date(ta);
  });

  renderConversationList();
}

function renderConversationList() {
  const list = document.getElementById('conv-list');
  if (!list) return;

  if (State.conversations.length === 0) {
    list.innerHTML = `
      <div class="empty-state">
        <div class="empty-icon">💬</div>
        <h3>Aucune conversation</h3>
        <p>Ajoutez un contact et envoyez votre premier message.</p>
      </div>`;
    return;
  }

  list.innerHTML = State.conversations.map(conv => {
    const convId    = conv.id || conv.conversationId || conv._id;
    const isGroup   = conv.isGroup || false;
    const name      = isGroup
      ? (conv.groupName || conv.name || 'Groupe')
      : (conv.otherUserName || conv.contactName || conv.otherUserId || 'Contact');
    // FIX [object Object] : extraire le texte proprement
    const lastMsg   = extractLastMessage(conv);
    const unread    = conv.unreadCount || 0;
    const timestamp = conv.lastMessageAt || conv.lastMessageTime || conv.updatedAt || conv.createdAt;
    const timeStr   = timestamp ? formatRelativeTime(timestamp) : '';
    const otherUid  = conv.otherUserId || conv.contactId || '';
    const initials  = getInitials(name);
    const avatarBg  = isGroup ? '#1a3a5c' : '#1a4a3a';
    const otherAvatar = conv.otherUserAvatar || conv.avatar || null;

    const convAvatarHtml = otherAvatar && !isGroup
      ? `<div class="conv-avatar" style="background:${avatarBg};padding:0;overflow:hidden"><img src="${escHtml(otherAvatar)}" alt="${escHtml(name)}" style="width:100%;height:100%;object-fit:cover;border-radius:50%"></div>`
      : `<div class="conv-avatar" style="background:${avatarBg}"><span>${isGroup ? '👥' : initials}</span></div>`;

    return `
      <div class="conv-item ${unread > 0 ? 'conv-unread' : ''}"
           onclick="openConversation('${escHtml(convId)}', '${escHtml(otherUid)}', '${escHtml(name)}', ${isGroup})">
        ${convAvatarHtml}
        <div class="conv-content">
          <div class="conv-header">
            <span class="conv-name">${escHtml(name)}</span>
            ${timeStr ? `<span class="conv-time ${unread > 0 ? 'conv-time-unread' : ''}">${timeStr}</span>` : ''}
          </div>
          <div class="conv-footer">
            <span class="conv-last-msg">${escHtml(lastMsg || 'Démarrer une conversation')}</span>
            ${unread > 0 ? `<span class="conv-badge">${unread > 99 ? '99+' : unread}</span>` : ''}
          </div>
        </div>
      </div>`;
  }).join('');
}

// ─── CONVERSATION SCREEN ──────────────────────────────────────────────────────
function openConversation(conversationId, contactId, contactName, isGroup = false) {
  State.activeConvId   = conversationId;
  State.activeConvMsgs = [];
  State.activeConvInfo = { conversationId, contactId, contactName, isGroup };

  const conv = State.conversations.find(c => (c.id || c.conversationId || c._id) === conversationId);
  if (conv) conv.unreadCount = 0;

  const screen = document.getElementById('screen-conversation');
  if (!screen) return;

  document.getElementById('conv-screen-name').textContent  = contactName;
  document.getElementById('conv-screen-back').onclick = closeConversation;
  document.getElementById('conv-msg-input').value = '';

  showScreen('screen-conversation');
  loadActiveConvMessages();
}

async function loadActiveConvMessages(silent = false) {
  if (!State.activeConvId || !State.token || State._loggedOut) return;
  const convId = State.activeConvId;

  // Afficher les messages déjà en cache immédiatement (0ms de délai perçu)
  if (!silent && State.activeConvMsgs.length > 0) {
    renderMessages();
  } else if (!silent && State.activeConvMsgs.length === 0) {
    document.getElementById('conv-messages').innerHTML =
      `<div class="loading-state"><div class="spinner"></div></div>`;
  }

  const data = await API.get(`/api/messages/${convId}`);
  if (!data || State.activeConvId !== convId) return;

  const rawMsgs = Array.isArray(data) ? data : (data.messages || data.data || []);
  const currentUserId = State.user?.id || State.user?._id || '';

  State.activeConvMsgs = rawMsgs.map(m => ({
    ...m,
    isMe     : (m.senderId || m.from || m.userId) === currentUserId,
    content  : m.content || m.text || m.message || m.body || '',
    timestamp: m.timestamp || m.createdAt || m.sentAt || new Date().toISOString(),
  }));

  renderMessages();
}

function renderMessages() {
  const container = document.getElementById('conv-messages');
  if (!container) return;

  if (State.activeConvMsgs.length === 0) {
    container.innerHTML = `
      <div class="empty-state" style="height:100%">
        <div class="empty-icon">💬</div>
        <p>Aucun message. Envoyez le premier !</p>
      </div>`;
  } else {
    container.innerHTML = State.activeConvMsgs.map(m => {
      if (m.type === 'audio' && (m.audioUrl || m.url)) {
        return renderAudioMessage(m);
      }
      return `
        <div class="msg-bubble ${m.isMe ? 'msg-me' : 'msg-them'}">
          <div class="msg-content">${escHtml(m.content)}</div>
          <div class="msg-time">${formatTime(m.timestamp)}${m.isMe ? renderMsgStatus(m.status) : ''}</div>
        </div>`;
    }).join('');
  }

  container.scrollTop = container.scrollHeight;
}

function renderMsgStatus(status) {
  if (status === 'seen')      return ' <span style="color:#4fc3f7">✓✓</span>';
  if (status === 'delivered') return ' <span style="color:#aaa">✓✓</span>';
  if (status === 'sent')      return ' <span style="color:#aaa">✓</span>';
  return '';
}

function renderAudioMessage(m) {
  const rawUrl    = m.audioUrl || m.url || '';
  // P2 FIX: Si l'URL est relative (commence par '/'), la résoudre sur le backend Render.
  // Sinon (data:, https://, etc.) l'utiliser directement.
  // Les data URIs base64 (≤1.5MB) fonctionnent directement dans <audio src>.
  // Les fichiers disk (/uploads/audio/…) doivent être préfixés par l'URL du backend.
  const audioUrl  = (rawUrl && rawUrl.startsWith('/') && !rawUrl.startsWith('//'))
    ? (API_BASE + rawUrl)
    : rawUrl;
  const totalSecs = m.duration || 0;
  const durFmt    = m.durationFormatted || (totalSecs ? `${Math.floor(totalSecs/60)}:${String(Math.round(totalSecs%60)).padStart(2,'0')}` : '0:00');
  const msgId     = m.id || m._id || '';
  const transcript= m.transcription || '';
  const tStatus   = m.transcriptionStatus || 'pending';
  const safeId    = escHtml(msgId);
  const safeUrl   = escHtml(audioUrl);
  return `
    <div class="msg-bubble ${m.isMe ? 'msg-me' : 'msg-them'}" id="msg-${safeId}">
      <div class="msg-audio-player">
        <button class="audio-play-btn" id="playbtn-${safeId}" onclick="toggleAudioWA('${safeId}')" title="Lecture/Pause">&#9654;</button>
        <audio id="audio-${safeId}" src="${safeUrl}" preload="metadata"
               onended="onAudioEnded('${safeId}')"
               ontimeupdate="onAudioTimeUpdate('${safeId}')"
               onloadedmetadata="onAudioMeta('${safeId}')"></audio>
        <div class="audio-progress-wrap">
          <input type="range" class="audio-progress" id="prog-${safeId}" value="0" min="0" max="100" step="0.1"
                 oninput="seekAudio('${safeId}', this.value)">
          <div class="audio-times">
            <span id="cur-${safeId}">0:00</span>
            <span id="dur-${safeId}">${escHtml(durFmt)}</span>
          </div>
        </div>
        <div class="audio-actions">
          ${msgId && tStatus !== 'done' ? `<button class="btn-transcribe" id="transcbtn-${safeId}" onclick="requestTranscription('${safeId}')">&#128221;</button>` : ''}
          ${audioUrl ? `<a class="audio-download-btn" href="${safeUrl}" download title="Telecharger">&#8681;</a>` : ''}
        </div>
      </div>
      ${transcript
        ? `<div class="msg-transcript">&#128172; ${escHtml(transcript)}</div>`
        : tStatus === 'processing'
          ? `<div class="msg-transcript" style="opacity:.6">&#9203; Transcription en cours…</div>`
          : tStatus === 'error'
            ? `<div class="msg-transcript" style="opacity:.5;color:#e57373">&#9888; Transcription indisponible</div>`
            : ''
      }
      <div class="msg-time">${formatTime(m.timestamp)}${m.isMe ? renderMsgStatus(m.status) : ''}</div>
    </div>`;
}

function resetPlayBtn(audioId) {
  const audio = document.getElementById(audioId);
  if (audio) {
    audio.currentTime = 0;
    const btn = audio.previousElementSibling;
    if (btn) btn.textContent = '▶';
  }
}

// ─── WHATSAPP-STYLE AUDIO PLAYER ─────────────────────────────────────────────
function fmtAudioTime(s) {
  if (!s || isNaN(s)) return '0:00';
  return Math.floor(s/60)+':'+String(Math.floor(s%60)).padStart(2,'0');
}
function toggleAudioWA(id) {
  const audio = document.getElementById('audio-'+id);
  const btn   = document.getElementById('playbtn-'+id);
  if (!audio || !btn) return;
  if (audio.paused) {
    document.querySelectorAll('audio').forEach(a => { if (a !== audio) { a.pause(); a.currentTime=0; } });
    document.querySelectorAll('.audio-play-btn').forEach(b => { if (b.id !== 'playbtn-'+id) b.innerHTML='&#9654;'; });
    audio.play().catch(()=>{});
    btn.innerHTML = '&#9646;&#9646;';
  } else {
    audio.pause();
    btn.innerHTML = '&#9654;';
  }
}
function onAudioEnded(id) {
  const btn  = document.getElementById('playbtn-'+id);
  const prog = document.getElementById('prog-'+id);
  if (btn)  btn.innerHTML  = '&#9654;';
  if (prog) prog.value     = 0;
  const cur = document.getElementById('cur-'+id);
  if (cur)  cur.textContent = '0:00';
}
function onAudioTimeUpdate(id) {
  const audio = document.getElementById('audio-'+id);
  if (!audio || !audio.duration) return;
  const pct  = (audio.currentTime / audio.duration) * 100;
  const prog = document.getElementById('prog-'+id);
  if (prog) prog.value = pct;
  const cur  = document.getElementById('cur-'+id);
  if (cur)  cur.textContent = fmtAudioTime(audio.currentTime);
}
function onAudioMeta(id) {
  const audio = document.getElementById('audio-'+id);
  if (!audio) return;
  const dur = document.getElementById('dur-'+id);
  if (dur && audio.duration && !isNaN(audio.duration)) dur.textContent = fmtAudioTime(audio.duration);
}
function seekAudio(id, pct) {
  const audio = document.getElementById('audio-'+id);
  if (audio && audio.duration) audio.currentTime = (pct/100)*audio.duration;
}
// Legacy compat
function toggleAudio(audioId, btn) { toggleAudioWA(audioId.replace('audio-','')); }
function resetPlayBtn(audioId) { onAudioEnded(audioId.replace('audio-','')); }
async function requestTranscription(msgId) {
  if (!msgId) return;
  const btn = document.querySelector(`#transcbtn-${msgId}`);
  if (btn) { btn.textContent = '⏳'; btn.disabled = true; }

  // Afficher "Transcription en cours..." dans la bulle
  const msg = State.activeConvMsgs.find(m => (m.id || m._id) === msgId);
  if (msg) { msg.transcriptionStatus = 'processing'; renderMessages(); }

  // Lancer la transcription via audio.v2
  const res = await API.post(`/api/audio/transcribe/${msgId}`, { language: 'fr' });

  if (!res.ok) {
    showToast('Impossible de lancer la transcription.');
    if (msg) { msg.transcriptionStatus = 'pending'; renderMessages(); }
    const btn2 = document.querySelector(`#transcbtn-${msgId}`);
    if (btn2) { btn2.textContent = '📝'; btn2.disabled = false; }
    return;
  }

  showToast('Transcription en cours…');

  // Polling de résultat — max 40 tentatives × 3s = 120s max
  // Le Socket.IO peut aussi livrer le résultat en temps réel
  let attempts = 0;
  const MAX_ATTEMPTS = 40;   // 120s total
  const POLL_INTERVAL = 3000;

  const poll = setInterval(async () => {
    attempts++;

    // Timeout: arrêter après 120s
    if (attempts > MAX_ATTEMPTS) {
      clearInterval(poll);
      // Vérifier le statut final avant d'afficher une erreur
      const finalData = await API.get(`/api/audio/${msgId}`);
      if (finalData?.transcriptionStatus === 'error') {
        if (msg) { msg.transcriptionStatus = 'error'; renderMessages(); }
        showToast('Transcription indisponible (timeout 120s).');
      } else if (finalData?.transcriptionStatus !== 'done') {
        if (msg) { msg.transcriptionStatus = 'error'; renderMessages(); }
        showToast('Transcription indisponible.');
      }
      return;
    }

    // Vérifier le résultat
    let transcriptText = null;
    let isError = false;

    const audioData = await API.get(`/api/audio/${msgId}`);
    if (audioData?.transcriptionStatus === 'done' && audioData?.transcription) {
      transcriptText = audioData.transcription;
    } else if (audioData?.transcriptionStatus === 'error') {
      isError = true;
    }

    if (isError) {
      clearInterval(poll);
      if (msg) { msg.transcriptionStatus = 'error'; renderMessages(); }
      showToast('Transcription indisponible — ' + (audioData?.transcriptionError || 'erreur'));
      return;
    }

    if (transcriptText) {
      clearInterval(poll);
      // Mettre à jour le message en mémoire
      if (msg) {
        msg.transcription       = transcriptText;
        msg.transcriptionStatus = 'done';
      }
      renderMessages();
      showToast('Transcription terminée ✓');
    }
  }, POLL_INTERVAL);
}

async function sendMessage() {
  const input = document.getElementById('conv-msg-input');
  const text  = input.value.trim();
  if (!text || !State.activeConvInfo) return;

  const { conversationId, contactId, isGroup } = State.activeConvInfo;
  input.value = '';

  const optimisticMsg = {
    isMe: true, content: text, timestamp: new Date().toISOString(), _optimistic: true, status: 'sending',
  };
  State.activeConvMsgs.push(optimisticMsg);
  renderMessages();

  let res;
  if (isGroup) {
    res = await API.post(`/groups/${contactId}/messages`, { content: text });
  } else {
    res = await API.post('/api/messages/send', { receiverId: contactId, content: text });
  }

  if (res && res.ok) {
    // P0 FIX: Si le serveur a utilisé un conversationId différent (après résolution phone→UID),
    // mettre à jour State.activeConvId ET State.activeConvInfo avec l'ID canonique.
    const realMsg = res.data?.message || res.data;
    // Lire le conversationId canonique depuis la racine de la réponse OU depuis le message
    const serverConvId = res.data?.conversationId || realMsg?.conversationId;
    if (serverConvId && serverConvId !== State.activeConvId) {
      // Le backend a calculé un conversationId canonique différent du provisoire
      // Mettre à jour l'état pour que les futurs Socket.IO events soient correctement matchés
      State.activeConvId = serverConvId;
      if (State.activeConvInfo) State.activeConvInfo.conversationId = serverConvId;
    }

    if (realMsg && (realMsg.id || realMsg._id)) {
      const currentUserId = State.user?.id || State.user?._id || '';
      const normalized = {
        ...realMsg,
        isMe     : (realMsg.senderId || realMsg.from) === currentUserId,
        content  : realMsg.content || text,
        timestamp: realMsg.timestamp || realMsg.createdAt || new Date().toISOString(),
      };
      // Remplacer le message optimiste
      const optIdx = State.activeConvMsgs.findIndex(m => m._optimistic);
      if (optIdx >= 0) State.activeConvMsgs.splice(optIdx, 1, normalized);
      else State.activeConvMsgs.push(normalized);
      renderMessages();
    } else {
      // Fallback: supprimer l'optimiste et recharger
      State.activeConvMsgs = State.activeConvMsgs.filter(m => !m._optimistic);
    }
    const activeId = State.activeConvId;
    const conv = State.conversations.find(c => (c.id || c.conversationId || c._id) === activeId);
    if (conv) {
      conv.lastMessage    = text;
      conv.lastMessageAt  = new Date().toISOString();
    }
    setTimeout(() => loadActiveConvMessages(true), 500);
  } else {
    State.activeConvMsgs = State.activeConvMsgs.filter(m => !m._optimistic);
    renderMessages();
    showToast('Échec de l\'envoi. Réessayez.');
  }
}

function closeConversation() {
  State.activeConvId   = null;
  State.activeConvInfo = null;
  State.activeConvMsgs = [];
  if (State.isRecording) stopRecording(false);
  showScreen('screen-dashboard');
  if (State.currentTab === 'messages') renderConversationList();
}

// ─── VOICE MESSAGES ───────────────────────────────────────────────────────────
async function startRecording() {
  if (State.isRecording) { stopRecording(true); return; }

  if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
    showToast('Enregistrement audio non supporté sur cet appareil.');
    return;
  }

  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    State.audioChunks = [];
    State.isRecording = true;

    const options = { mimeType: 'audio/webm;codecs=opus' };
    if (!MediaRecorder.isTypeSupported(options.mimeType)) {
      delete options.mimeType; // fallback
    }
    State.mediaRecorder = new MediaRecorder(stream, options);

    State.mediaRecorder.ondataavailable = e => {
      if (e.data && e.data.size > 0) State.audioChunks.push(e.data);
    };

    State.mediaRecorder.onstop = () => {
      stream.getTracks().forEach(t => t.stop());
    };

    State.mediaRecorder.start(250);

    // Update mic button
    const micBtn = document.getElementById('mic-btn');
    if (micBtn) { micBtn.textContent = '⏹'; micBtn.classList.add('recording'); }

    // Timer
    State.recordingSeconds = 0;
    const timerEl = document.getElementById('recording-timer');
    if (timerEl) timerEl.style.display = 'inline';
    State.recordingTimer = setInterval(() => {
      State.recordingSeconds++;
      if (timerEl) timerEl.textContent = formatRecordingTime(State.recordingSeconds);
      if (State.recordingSeconds >= 300) stopRecording(true); // max 5 min
    }, 1000);

  } catch(err) {
    State.isRecording = false;
    showToast('Impossible d\'accéder au microphone : ' + (err.message || err.name));
  }
}

function formatRecordingTime(secs) {
  const m = Math.floor(secs / 60);
  const s = secs % 60;
  return `${m}:${String(s).padStart(2, '0')}`;
}

function stopRecording(send = true) {
  clearInterval(State.recordingTimer);
  State.isRecording = false;

  const micBtn  = document.getElementById('mic-btn');
  const timerEl = document.getElementById('recording-timer');
  if (micBtn)  { micBtn.textContent = '🎤'; micBtn.classList.remove('recording'); }
  if (timerEl) { timerEl.style.display = 'none'; timerEl.textContent = '0:00'; }

  if (!State.mediaRecorder) return;

  State.mediaRecorder.onstop = async () => {
    const stream = State.mediaRecorder.stream;
    if (stream) stream.getTracks().forEach(t => t.stop());

    if (send && State.audioChunks.length > 0) {
      await uploadVoiceMessage();
    }
    State.audioChunks  = [];
    State.mediaRecorder = null;
  };

  try {
    if (State.mediaRecorder.state !== 'inactive') State.mediaRecorder.stop();
  } catch (_) {}
}

async function uploadVoiceMessage() {
  if (!State.activeConvInfo || State.audioChunks.length === 0) return;

  showToast('Envoi du message vocal...');
  const mimeType = State.audioChunks[0]?.type || 'audio/webm';
  const ext      = mimeType.includes('ogg') ? 'ogg' : mimeType.includes('mp4') ? 'mp4' : 'webm';
  const blob     = new Blob(State.audioChunks, { type: mimeType });
  const formData = new FormData();
  formData.append('audio', blob, `voice_${Date.now()}.${ext}`);

  const uploadRes = await API.postForm('/api/audio/upload', formData);

  if (!uploadRes.ok) {
    showToast('Échec de l\'upload audio.');
    return;
  }

  const { id: audioId, url: rawAudioUrl, duration, durationFormatted } = uploadRes.data;
  // P2 FIX: Résoudre l'URL audio immédiatement après l'upload pour la bulle optimiste
  // Si l'URL est relative (/uploads/audio/...), préfixer avec API_BASE
  const audioUrl = (rawAudioUrl && rawAudioUrl.startsWith('/') && !rawAudioUrl.startsWith('//'))
    ? (API_BASE + rawAudioUrl)
    : (rawAudioUrl || '');

  // Injecter immédiatement une bulle optimiste dans la conversation
  const currentUserId = State.user?.id || State.user?._id || '';
  const tempMsgId = `temp-audio-${Date.now()}`;
  const optimisticAudio = {
    id               : tempMsgId,
    _optimistic      : true,
    senderId         : currentUserId,
    isMe             : true,
    type             : 'audio',
    audioUrl         : audioUrl,
    url              : audioUrl,
    duration         : duration || null,
    durationFormatted: durationFormatted || null,
    content          : null,
    status           : 'sending',
    transcriptionStatus: 'pending',
    timestamp        : new Date().toISOString(),
    createdAt        : new Date().toISOString(),
  };
  State.activeConvMsgs.push(optimisticAudio);
  renderMessages();

  // Envoyer comme message in-app
  const { contactId, isGroup, conversationId } = State.activeConvInfo;
  let res;
  if (isGroup) {
    res = await API.post(`/groups/${contactId}/messages`, {
      content: '', type: 'audio', audioUrl, duration,
    });
  } else {
    // P2 FIX: Envoyer le rawAudioUrl (URL originale depuis le serveur) au backend,
    // pas l'URL préfixée par API_BASE (le backend stocke l'URL relative ou la data URI).
    res = await API.post('/api/messages/send', {
      receiverId: contactId, content: '', type: 'audio', audioUrl: rawAudioUrl || audioUrl, duration,
    });
  }

  if (res?.ok) {
    // P0 FIX: Mettre à jour le conversationId si le serveur en retourne un différent
    const serverConvId = res.data?.conversationId || res.data?.message?.conversationId;
    if (serverConvId && serverConvId !== State.activeConvId) {
      State.activeConvId = serverConvId;
      if (State.activeConvInfo) State.activeConvInfo.conversationId = serverConvId;
    }
    // Remplacer le message optimiste par le vrai message
    const realMsg = res.data?.message || res.data;
    const optIdx = State.activeConvMsgs.findIndex(m => m.id === tempMsgId);
    if (optIdx >= 0 && realMsg && (realMsg.id || realMsg._id)) {
      const normalized = {
        ...realMsg,
        isMe             : true,
        audioUrl         : audioUrl,   // Garder l'URL préfixée par API_BASE pour le player local
        url              : audioUrl,
        type             : 'audio',
        duration         : duration || null,
        durationFormatted: durationFormatted || null,
        status           : 'sent',
        timestamp        : realMsg.createdAt || new Date().toISOString(),
      };
      State.activeConvMsgs.splice(optIdx, 1, normalized);
    } else if (optIdx >= 0) {
      // Mettre à jour le statut du message optimiste
      State.activeConvMsgs[optIdx].status = 'sent';
      State.activeConvMsgs[optIdx]._optimistic = false;
    }
    renderMessages();
    showToast('Message vocal envoyé !');
    // Rafraîchir en arrière-plan pour s'assurer de la synchronisation
    setTimeout(() => loadActiveConvMessages(true), 1000);
  } else {
    // Supprimer le message optimiste en cas d'erreur
    State.activeConvMsgs = State.activeConvMsgs.filter(m => m.id !== tempMsgId);
    renderMessages();
    showToast('Message vocal uploadé mais envoi échoué.');
  }
}

// ─── CONTACTS ─────────────────────────────────────────────────────────────────
async function loadContacts() {
  document.getElementById('contacts-list').innerHTML =
    `<div class="loading-state"><div class="spinner"></div><p>Chargement...</p></div>`;

  const data = await API.get('/api/contacts');
  State.contacts = Array.isArray(data) ? data : (data?.contacts || []);
  renderContacts(State.contacts);
}

function renderContacts(contacts) {
  const list = document.getElementById('contacts-list');
  if (!list) return;

  if (contacts.length === 0) {
    list.innerHTML = `
      <div class="empty-state">
        <div class="empty-icon">👤</div>
        <h3>Aucun contact</h3>
        <p>Ajoutez votre premier contact ou importez vos contacts.</p>
      </div>`;
    return;
  }

  const omniContacts = contacts.filter(c => c.isOnOmniSms || c.userId || c.registeredUserId);
  const smsContacts  = contacts.filter(c => !c.isOnOmniSms && !c.userId && !c.registeredUserId);

  function contactItem(c) {
    const name  = c.name || c.displayName || c.phone || 'Contact';
    const phone = c.phone || c.phoneNumber || '';
    const uid   = c.userId || c.registeredUserId || '';
    const avatar= c.avatar || null;
    const isOmni = !!(c.isOnOmniSms || uid);
    // v3.3 : TOUS les contacts sont ouverts — le frontend ne bloque jamais
    // Si OmniSMS → ouvrir par uid, sinon → ouvrir par téléphone (backend décide du canal)
    const onclick = isOmni
      ? `openContactConversation('${escHtml(uid)}', '${escHtml(name)}')`
      : `openContactByPhone('${escHtml(phone)}', '${escHtml(name)}')`;
    const avatarHtml = avatar
      ? `<div class="contact-avatar contact-avatar-img"><img src="${escHtml(avatar)}" alt="${escHtml(name)}" style="width:100%;height:100%;border-radius:50%;object-fit:cover"></div>`
      : `<div class="contact-avatar">${getInitials(name)}</div>`;
    return `
      <div class="contact-item ${isOmni ? '' : 'contact-sms-only'}" onclick="${onclick}">
        ${avatarHtml}
        <div class="contact-info">
          <div class="contact-name">${escHtml(name)}</div>
          <div class="contact-phone">${escHtml(phone)}</div>
        </div>
        <div class="contact-actions">
          ${isOmni ? '<span class="badge-registered">OmniSMS</span>' : '<span class="badge-sms">SMS</span>'}
          <button class="btn-icon" onclick="event.stopPropagation();confirmDeleteContact('${escHtml(phone)}','${escHtml(name)}')" title="Supprimer">🗑️</button>
        </div>
      </div>`;
  }

  let html = '';
  if (omniContacts.length > 0) {
    html += `<div class="contacts-section-header">OmniSMS — ${omniContacts.length} utilisateur(s)</div>`;
    html += omniContacts.map(contactItem).join('');
  }
  if (smsContacts.length > 0) {
    html += `<div class="contacts-section-header contacts-section-sms">SMS — ${smsContacts.length} contact(s)</div>`;
    html += smsContacts.map(contactItem).join('');
  }

  list.innerHTML = html;
}

function openContactConversation(otherUserId, contactName) {
  if (!otherUserId || otherUserId === 'null' || otherUserId === 'undefined') {
    // Fallback : si on n'a pas d'uid, ouvrir par téléphone (montré comme SMS)
    showToast('Ouverture de la conversation...');
    return;
  }
  const myId = State.user?.id || State.user?._id || '';
  const parts = [myId, otherUserId].sort();
  const conversationId = parts.join('-');
  openConversation(conversationId, otherUserId, contactName, false);
}

// v4.4 — P0 FIX: Résoudre phone→UID avant de construire le conversationId.
// Le conversationId DOIT toujours être sort([UID_A, UID_B]).join('-').
// Utiliser /api/contacts/check/:phone pour obtenir l'UID réel de B.
// Si B n'est pas sur OmniSMS : utiliser Infobip SMS (contactId = phone E.164).
async function openContactByPhone(phone, contactName) {
  if (!phone) { showToast('Numéro de téléphone manquant'); return; }

  const myId = State.user?.id || State.user?._id || '';
  const normalizedPhone = phone.replace(/\s/g, '');

  // Tenter de résoudre le numéro vers un UID OmniSMS
  try {
    const checkData = await API.get(`/api/contacts/check/${encodeURIComponent(normalizedPhone)}`);
    if (checkData && checkData.isRegistered && checkData.uid) {
      // B est sur OmniSMS → conversationId déterministe à partir des UIDs
      const uid = checkData.uid;
      const conversationId = [myId, uid].sort().join('-');
      openConversation(conversationId, uid, contactName || checkData.name || phone, false);
      return;
    }
  } catch (_) {
    // Silencieux — continuer vers le fallback SMS
  }

  // B n'est pas sur OmniSMS (ou erreur réseau) → SMS Infobip
  // Le backend décidera du canal. contactId = numéro de téléphone.
  // conversationId sera l'ID externe (ext-{ownerUid}-{e164}) côté backend.
  // Ici on utilise un ID provisoire ; le vrai sera mis à jour depuis la liste des conversations.
  const conversationId = [myId, normalizedPhone].sort().join('-');
  openConversation(conversationId, normalizedPhone, contactName || phone, false);
}

function searchContacts(q) {
  const filtered = State.contacts.filter(c => {
    const name  = (c.name || c.displayName || '').toLowerCase();
    const phone = (c.phone || c.phoneNumber || '').toLowerCase();
    return name.includes(q.toLowerCase()) || phone.includes(q.toLowerCase());
  });
  renderContacts(filtered);
}

async function addContact(name, phone) {
  if (!name || !phone) { showToast('Nom et téléphone requis'); return; }
  setLoading('add-contact-btn', true, 'Ajouter');
  const res = await API.post('/api/contacts/add', { name, phone });
  setLoading('add-contact-btn', false, 'Ajouter');
  if (res.ok) {
    closeModal('modal-add-contact');
    document.getElementById('contact-name').value  = '';
    document.getElementById('contact-phone').value = '';
    showToast('Contact ajouté !');
    loadContacts();
  } else {
    showToast(res.data.message || 'Erreur lors de l\'ajout');
  }
}

async function confirmDeleteContact(phone, name) {
  if (!confirm(`Supprimer ${name} ?`)) return;
  const res = await API.delete(`/api/contacts/${encodeURIComponent(phone)}`);
  if (res.ok) { showToast('Contact supprimé'); loadContacts(); }
  else         showToast('Erreur lors de la suppression');
}

// ─── CONTACT PICKER (fallback silencieux vers VCF) ───────────────────────────
async function importWithContactPicker() {
  if ('contacts' in navigator && 'ContactsManager' in window) {
    try {
      const props    = ['name', 'tel'];
      const selected = await navigator.contacts.select(props, { multiple: true });
      const contacts = selected.map(c => ({
        name:  c.name?.[0] || 'Contact',
        phone: c.tel?.[0]  || '',
      })).filter(c => c.phone);
      if (contacts.length === 0) { showToast('Aucun contact sélectionné'); return; }
      await syncContacts(contacts);
    } catch(e) {
      if (e.name !== 'AbortError') {
        // Fallback silencieux vers VCF — pas de message d'erreur
        triggerVcfImport();
      }
    }
  } else {
    // Fallback silencieux : proposer l'import VCF sans toast d'erreur
    triggerVcfImport();
  }
}

function triggerVcfImport() {
  const vcfInput = document.getElementById('vcf-import-input');
  if (vcfInput) vcfInput.click();
}

// ─── VCF IMPORT ───────────────────────────────────────────────────────────────
function parseVCF(text) {
  const contacts = [];
  const unfolded = text.replace(/\r\n[ \t]/g, '').replace(/\r\n/g, '\n');
  const vcards   = unfolded.split(/BEGIN:VCARD/i).slice(1);

  for (const card of vcards) {
    let name  = '';
    let phone = '';
    const lines = card.split('\n');
    for (const line of lines) {
      const l = line.trim();
      if (!l || l.toUpperCase() === 'END:VCARD') continue;
      const fnMatch = l.match(/^FN(?:;[^:]*)?:(.*)/i);
      if (fnMatch) { name = fnMatch[1].trim().replace(/\\,/g, ','); continue; }
      const nMatch = l.match(/^N(?:;[^:]*)?:(.*)/i);
      if (nMatch && !name) {
        const parts = nMatch[1].split(';');
        const last  = (parts[0] || '').trim();
        const first = (parts[1] || '').trim();
        name = [first, last].filter(Boolean).join(' ');
        continue;
      }
      const telMatch = l.match(/^TEL(?:;[^:]*)?:(.*)/i);
      if (telMatch && !phone) {
        phone = telMatch[1].trim().replace(/\s+/g, '');
      }
    }
    if (phone) contacts.push({ name: name || phone, phone });
  }
  return contacts;
}

function handleVCFFile(file) {
  if (!file) return;
  const reader = new FileReader();
  reader.onload = async e => {
    const contacts = parseVCF(e.target.result);
    if (contacts.length === 0) { showToast('Aucun contact trouvé dans le fichier VCF'); return; }
    showToast(`${contacts.length} contact(s) trouvé(s) — synchronisation...`);
    await syncContacts(contacts);
  };
  reader.readAsText(file);
}

async function syncContacts(contacts) {
  if (!contacts.length) return;
  showToast('Synchronisation en cours...');

  const res = await API.post('/api/contacts/sync', { contacts, country: 'BF' });
  if (res.ok) {
    const d = res.data;
    const omni = d.registeredOnOmniSms || 0;
    const sms  = d.smsOnly || 0;
    showToast(`✓ ${omni} OmniSMS · ${sms} SMS uniquement`);
    if (d.contacts && d.contacts.length > 0) {
      State.contacts = d.contacts;
      renderContacts(State.contacts);
    } else {
      loadContacts();
    }
  } else {
    let added = 0;
    for (const c of contacts) {
      const r = await API.post('/api/contacts/add', { name: c.name, phone: c.phone });
      if (r.ok) added++;
    }
    showToast(`${added} contact(s) synchronisé(s)`);
    loadContacts();
  }
}

// ─── GROUPES ──────────────────────────────────────────────────────────────────
async function loadGroups() {
  document.getElementById('groups-list').innerHTML =
    `<div class="loading-state"><div class="spinner"></div><p>Chargement...</p></div>`;

  const data = await API.get('/groups');
  State.groups = Array.isArray(data) ? data : (data?.groups || []);
  renderGroups();
}

function renderGroups() {
  const list = document.getElementById('groups-list');
  if (!list) return;

  if (State.groups.length === 0) {
    list.innerHTML = `
      <div class="empty-state">
        <div class="empty-icon">👥</div>
        <h3>Aucun groupe</h3>
        <p>Créez votre premier groupe.</p>
      </div>`;
    return;
  }

  const myId = State.user?.id || State.user?._id || '';
  list.innerHTML = State.groups.map(g => {
    const gid     = g.id || g._id;
    const name    = g.name || 'Groupe';
    const members = g.members?.length || g.memberCount || 0;
    const isOwner = g.ownerId === myId;
    const img     = g.image || g.icon || null;
    return `
      <div class="conv-item" onclick="openGroupConversation('${escHtml(gid)}', '${escHtml(name)}')">
        <div class="conv-avatar" style="background:#1a3a5c">
          ${img ? `<img src="${escHtml(img)}" style="width:100%;height:100%;border-radius:50%;object-fit:cover">` : '<span>👥</span>'}
        </div>
        <div class="conv-content">
          <div class="conv-header">
            <span class="conv-name">${escHtml(name)}</span>
            ${isOwner ? `<button class="btn-icon" style="font-size:14px" onclick="event.stopPropagation();openEditGroupModal('${escHtml(gid)}','${escHtml(name)}','${escHtml(g.description||'')}','${escHtml(img||'')}')">✏️</button>` : ''}
          </div>
          <div class="conv-footer">
            <span class="conv-last-msg">${members} membre(s)${g.description ? ' · ' + escHtml(g.description) : ''}</span>
          </div>
        </div>
      </div>`;
  }).join('');
}

function openEditGroupModal(gid, name, description, image) {
  // Remplir le modal d'édition
  const el = document.getElementById('edit-group-id');
  if (el) el.value = gid;
  const nameEl = document.getElementById('edit-group-name');
  if (nameEl) nameEl.value = name;
  const descEl = document.getElementById('edit-group-desc');
  if (descEl) descEl.value = description || '';
  const imgEl = document.getElementById('edit-group-image');
  if (imgEl) imgEl.value = image || '';
  // Réinitialiser la preview photo
  const preview = document.getElementById('edit-group-photo-preview');
  if (preview) {
    if (image && image.startsWith('http')) {
      preview.innerHTML = `<img src="${escHtml(image)}" style="width:100%;height:100%;object-fit:cover;border-radius:50%" alt="photo">`;
    } else {
      preview.innerHTML = '👥';
    }
  }
  // Réinitialiser le fichier sélectionné
  const photoInput = document.getElementById('edit-group-photo-input');
  if (photoInput) photoInput.value = '';
  // P4 FIX: Réinitialiser le champ d'ajout de membre
  const addInput = document.getElementById('edit-group-add-member-input');
  if (addInput) addInput.value = '';
  const addResult = document.getElementById('edit-group-add-member-result');
  if (addResult) addResult.textContent = '';
  openModal('modal-edit-group');
}

// P4 — Ajouter un membre au groupe depuis le modal d'édition
// Accepte : numéro de téléphone, @username, ou UID direct
async function addMemberFromEditModal() {
  const gid      = document.getElementById('edit-group-id')?.value;
  const input    = document.getElementById('edit-group-add-member-input');
  const resultEl = document.getElementById('edit-group-add-member-result');
  const btn      = document.getElementById('edit-group-add-member-btn');
  const identifier = input?.value?.trim();

  if (!gid || !identifier) {
    if (resultEl) { resultEl.style.color = 'var(--accent)'; resultEl.textContent = 'Saisissez un numéro, @username ou UID.'; }
    return;
  }

  if (btn) { btn.disabled = true; btn.textContent = '⏳'; }
  if (resultEl) { resultEl.style.color = 'var(--text-secondary)'; resultEl.textContent = 'Recherche…'; }

  try {
    // Appel backend : POST /groups/:id/members avec identifier générique
    // Le backend résout phone/username/UID via userResolver
    const res = await API.post(`/groups/${gid}/members`, { identifier });

    if (res.ok) {
      if (resultEl) { resultEl.style.color = '#4caf50'; resultEl.textContent = '✓ Membre ajouté avec succès.'; }
      if (input) input.value = '';
      // Rafraîchir la liste des groupes en arrière-plan
      loadGroups();
    } else {
      const errMsg = res.data?.error || res.data?.message || 'Erreur lors de l\'ajout.';
      if (resultEl) { resultEl.style.color = 'var(--accent)'; resultEl.textContent = errMsg; }
    }
  } catch(e) {
    if (resultEl) { resultEl.style.color = 'var(--accent)'; resultEl.textContent = 'Erreur réseau. Réessayez.'; }
  } finally {
    if (btn) { btn.disabled = false; btn.textContent = '+ Ajouter'; }
  }
}

function previewGroupPhoto(input) {
  const file = input?.files?.[0];
  if (!file) return;
  const preview = document.getElementById('edit-group-photo-preview');
  if (preview) {
    const reader = new FileReader();
    reader.onload = (e) => {
      preview.innerHTML = `<img src="${e.target.result}" style="width:100%;height:100%;object-fit:cover;border-radius:50%" alt="preview">`;
    };
    reader.readAsDataURL(file);
  }
}

async function saveGroupEdits() {
  const gid  = document.getElementById('edit-group-id')?.value;
  const name = document.getElementById('edit-group-name')?.value?.trim();
  const desc = document.getElementById('edit-group-desc')?.value?.trim();
  const img  = document.getElementById('edit-group-image')?.value?.trim();
  const photoFile = document.getElementById('edit-group-photo-input')?.files?.[0];

  if (!gid) return;

  // Si une photo a été sélectionnée, l'uploader en premier
  if (photoFile) {
    showToast('Compression et upload de la photo...');
    let uploadBlob;
    try { uploadBlob = await compressImageForAvatar(photoFile); } catch (_) { uploadBlob = photoFile; }
    const formData = new FormData();
    formData.append('image', uploadBlob, 'group.jpg');   // backend attend 'image'
    const uploadRes = await API.postForm(`/groups/${gid}/avatar`, formData);
    if (!uploadRes.ok) {
      showToast(uploadRes.data?.error || "Échec de l'upload de la photo");
      return;
    }
    // La photo est sauvegardée — continuer pour mettre à jour les autres champs
  }

  const body = {};
  if (name) body.name = name;
  if (desc !== undefined) body.description = desc;
  if (img)  body.image = img;

  // Mettre à jour le groupe si des champs texte ont changé
  if (Object.keys(body).length > 0) {
    const res = await API.put(`/groups/${gid}`, body);
    if (!res.ok) {
      showToast(res.data?.error || 'Erreur lors de la mise à jour');
      return;
    }
  }

  closeModal('modal-edit-group');
  showToast('Groupe mis à jour ✓');
  loadGroups();
}

function openGroupConversation(groupId, groupName) {
  openConversation(groupId, groupId, groupName, true);
}

async function createGroup(name, description) {
  if (!name.trim()) { showToast('Nom du groupe requis'); return; }
  const checked = document.querySelectorAll('#group-member-list input[type=checkbox]:checked');
  const memberIds = Array.from(checked).map(c => c.value);
  if (memberIds.length === 0) { showToast('Sélectionnez au moins un membre'); return; }

  setLoading('create-group-btn', true, 'Créer');
  const res = await API.post('/groups', { name: name.trim(), description: description.trim(), members: memberIds });
  setLoading('create-group-btn', false, 'Créer');

  if (res.ok) {
    closeModal('modal-create-group');
    showToast('Groupe créé !');
    const group = res.data.group || res.data;
    const gid   = group?.id || group?._id;
    const gname = group?.name || name;
    await loadGroups();
    if (gid) openGroupConversation(gid, gname);
  } else {
    showToast(res.data.message || 'Erreur lors de la création');
  }
}

function openCreateGroupModal() {
  const registeredContacts = State.contacts.filter(c => c.userId || c.registeredUserId);
  const container = document.getElementById('group-member-list');
  if (container) {
    if (registeredContacts.length === 0) {
      container.innerHTML = '<p class="text-muted">Aucun contact enregistré sur OmniSMS</p>';
    } else {
      container.innerHTML = registeredContacts.map(c => {
        const uid  = c.userId || c.registeredUserId;
        const name = c.name || c.displayName || c.phone;
        return `<label class="member-checkbox"><input type="checkbox" value="${escHtml(uid)}"><span>${escHtml(name)}</span></label>`;
      }).join('');
    }
  }
  openModal('modal-create-group');
}

// ─── GROUPS MEMBER MANAGEMENT ────────────────────────────────────────────────
async function openGroupMembersModal(gid, gname) {
  // Try the dedicated /members endpoint first (returns enriched member data)
  let group = null;
  const membersRes = await API.get('/groups/' + gid + '/members');
  if (membersRes && membersRes.members) {
    // New endpoint: { id, name, ownerId, members: [{uid, name, avatar, isOwner}] }
    group = membersRes;
  } else {
    // Fallback to group list
    const listData = await API.get('/groups');
    const groups = Array.isArray(listData) ? listData : (listData?.groups || []);
    const found = groups.find(g => (g.id || g._id) === gid);
    if (found) {
      // Convert plain member UIDs to member objects
      group = {
        ...found,
        members: (found.members || []).map(uid => ({ uid, name: uid, isOwner: uid === found.ownerId })),
      };
    }
  }

  const myId    = State.user?.id || State.user?._id || '';
  const isOwner = group?.ownerId === myId;
  // Support both old (array of UIDs) and new (array of objects) member formats
  const rawMembers = group?.members || [];
  const members = rawMembers.map(m => {
    if (typeof m === 'string') return { uid: m, name: m, isOwner: m === group?.ownerId };
    return m;
  });

  // Build member list from contacts cache (for name enrichment fallback)
  const contactMap = {};
  State.contacts.forEach(c=>{ if(c.userId||c.registeredUserId) contactMap[c.userId||c.registeredUserId]={name:c.name||c.phone,phone:c.phone}; });

  let html = `<h4 style="margin-bottom:12px">Membres — ${escHtml(gname)}</h4>`;
  html += members.map(m => {
    const uid  = m.uid;
    const info = contactMap[uid] || {};
    // Prefer: member object name > contact cache name > truncated UID
    const displayName = uid === myId
      ? (State.user?.name || 'Moi')
      : (m.name && m.name !== uid ? m.name : (info.name || uid.slice(-8)));
    const isAdmin = m.isOwner || uid === group?.ownerId;
    const avatarHtml = m.avatar
      ? `<div class="member-avatar-sm" style="padding:0;overflow:hidden"><img src="${escHtml(m.avatar)}" style="width:100%;height:100%;object-fit:cover;border-radius:50%"></div>`
      : `<div class="member-avatar-sm">${getInitials(displayName)}</div>`;
    return `<div class="member-list-item">
      <div class="member-info">
        ${avatarHtml}
        <div><div class="member-name">${escHtml(displayName)}</div><div class="member-role">${isAdmin?'Admin':''}</div></div>
      </div>
      ${isOwner && uid !== myId ? `<div class="member-actions">
        <button class="btn-admin-transfer" onclick="transferAdmin('${escHtml(gid)}','${escHtml(uid)}','${escHtml(displayName)}')">Admin</button>
        <button class="btn-remove-member"  onclick="removeMember('${escHtml(gid)}','${escHtml(uid)}','${escHtml(displayName)}')">Retirer</button>
      </div>` : ''}
    </div>`;
  }).join('');

  if (isOwner) {
    // Add member section — members is now array of objects with uid field
    const memberUids = members.map(m => m.uid);
    const notInGroup = State.contacts.filter(c=>{
      const cuid=c.userId||c.registeredUserId; return cuid && !memberUids.includes(cuid);
    });
    if (notInGroup.length > 0) {
      html += `<hr style="margin:12px 0;border-color:var(--border)"><h5 style="margin-bottom:8px">Ajouter un membre</h5>`;
      html += notInGroup.map(c=>{
        const cuid=c.userId||c.registeredUserId;
        const nm=c.name||c.phone;
        return `<div class="member-list-item">
          <div class="member-info"><div class="member-avatar-sm">${getInitials(nm)}</div><div class="member-name">${escHtml(nm)}</div></div>
          <button class="btn-admin-transfer" onclick="addMember('${escHtml(gid)}','${escHtml(cuid)}','${escHtml(nm)}')">+ Ajouter</button>
        </div>`;
      }).join('');
    }
  }

  const modal = document.getElementById('modal-group-members');
  if (modal) {
    const body = modal.querySelector('.modal-body') || modal;
    body.innerHTML = html;
    openModal('modal-group-members');
  } else {
    // Fallback: use edit group modal
    const el = document.getElementById('edit-group-id');
    if (el) {
      const content2 = document.getElementById('modal-edit-group');
      if (content2) content2.querySelector('.modal-body').innerHTML = html;
    }
    showToast('Membres: ' + members.length + ' | ' + gname);
  }
}

async function addMember(gid, uid, name) {
  const res = await API.post('/groups/'+gid+'/members', { members:[uid] });
  if (res.ok) { showToast(name+' ajouté(e) ✓'); loadGroups(); closeModal('modal-group-members'); }
  else         showToast(res.data?.error||'Erreur ajout membre');
}

async function removeMember(gid, uid, name) {
  if (!confirm('Retirer '+name+' du groupe ?')) return;
  const res = await API.delete('/groups/'+gid+'/members/'+uid);
  if (res.ok) { showToast(name+' retiré(e) ✓'); loadGroups(); closeModal('modal-group-members'); }
  else         showToast(res.data?.error||'Erreur suppression membre');
}

async function transferAdmin(gid, uid, name) {
  if (!confirm('Transférer l\'admin à '+name+' ?')) return;
  const res = await API.put('/groups/'+gid+'/admin', { newOwner: uid });
  if (res.ok) { showToast('Admin transféré à '+name+' ✓'); loadGroups(); closeModal('modal-group-members'); }
  else         showToast(res.data?.error||'Erreur transfert admin');
}

// ─── PARAMÈTRES ───────────────────────────────────────────────────────────────
function renderSettings() {
  const name     = State.user?.name     || '';
  const email    = State.user?.email    || '';
  const phone    = State.user?.phone    || '';
  const username = State.user?.username || '';
  const avatar   = State.user?.avatar   || null;

  const el = document.getElementById('settings-content');
  if (!el) return;

  el.innerHTML = `
    <div class="settings-card">
      <div class="settings-avatar-wrapper" onclick="document.getElementById('avatar-upload-input').click()">
        ${avatar
          ? `<img src="${escHtml(avatar)}" class="settings-avatar-img" alt="Photo de profil">`
          : `<div class="settings-avatar">${getInitials(name || email)}</div>`
        }
        <div class="settings-avatar-overlay">📷</div>
      </div>
      <input id="avatar-upload-input" type="file" accept="image/*" style="display:none"
             onchange="uploadAvatar(this.files[0])">
      <h3>${escHtml(name || email)}</h3>
      ${username ? `<p class="text-muted">@${escHtml(username)}</p>` : ''}
      ${phone ? `<p class="text-muted">${escHtml(phone)}</p>` : '<p class="text-muted" style="color:var(--accent)">⚠️ Téléphone non renseigné</p>'}
    </div>

    <div class="settings-section">
      <h4>Modifier le profil</h4>
      <div class="form-group">
        <label class="form-label">Nom</label>
        <input id="settings-name" type="text" class="form-input" value="${escHtml(name)}" placeholder="Votre nom">
      </div>
      <div class="form-group">
        <label class="form-label">Nom d'utilisateur</label>
        <input id="settings-username" type="text" class="form-input" value="${escHtml(username)}" placeholder="@monpseudo">
      </div>
      <div class="form-group">
        <label class="form-label">Téléphone <span style="color:var(--accent)">*</span></label>
        <input id="settings-phone" type="tel" class="form-input" value="${escHtml(phone)}" placeholder="+22670123456">
      </div>
      <div class="form-group">
        <label class="form-label">Email</label>
        <input id="settings-email" type="email" class="form-input" value="${escHtml(email)}" placeholder="votre@email.com">
      </div>
      <div class="form-group">
        <label class="form-label">Nouveau mot de passe (laisser vide pour ne pas changer)</label>
        <input id="settings-password" type="password" class="form-input" placeholder="••••••••" minlength="8">
      </div>
      <button class="btn-primary" style="width:100%;margin-top:12px" onclick="saveProfile()">
        ✅ Mettre à jour
      </button>
    </div>

    <div class="settings-section">
      <h4>Abonnement</h4>
      <div class="subscribe-banner" onclick="handleSubscription()" id="subscribe-banner">
        <div class="subscribe-banner-icon">💎</div>
        <div class="subscribe-banner-text">
          <div class="subscribe-banner-title">Passer à Premium</div>
          <div class="subscribe-banner-sub">SMS illimités, vocaux, transcriptions</div>
        </div>
        <button class="btn-subscribe" onclick="event.stopPropagation();handleSubscription()">S'abonner</button>
      </div>
    </div>

    <div class="settings-section">
      <h4>Compte</h4>
      <button class="btn-primary" style="width:100%;margin-bottom:10px;background:transparent;border:1px solid var(--border);color:var(--text-primary)" onclick="logout()">
        🚪 Se déconnecter
      </button>
      <button class="btn-primary" style="width:100%;background:rgba(239,68,68,0.15);border:1px solid rgba(239,68,68,0.4);color:#ef4444" onclick="deleteAccount()">
        🗑️ Supprimer mon compte
      </button>
    </div>
    <div class="settings-section">
      <h4>Application</h4>
      <div class="settings-row">
        <span>📱 Version</span>
        <span class="text-muted">4.3.0</span>
      </div>
    </div>`;

  loadPremiumStatus(State.user?.id || State.user?._id);
}

async function saveProfile() {
  const name     = document.getElementById('settings-name')?.value?.trim();
  const email    = document.getElementById('settings-email')?.value?.trim();
  const phone    = document.getElementById('settings-phone')?.value?.trim();
  const password = document.getElementById('settings-password')?.value;
  const username = document.getElementById('settings-username')?.value?.trim();

  const body = {};
  if (name)     body.name     = name;
  if (email)    body.email    = email;
  if (phone)    body.phone    = phone;
  if (username) body.username = username;
  if (password && password.length >= 8) body.password = password;

  if (Object.keys(body).length === 0) { showToast('Aucune modification'); return; }

  const saveBtn = document.querySelector('[onclick="saveProfile()"]');
  if (saveBtn) { saveBtn.disabled = true; saveBtn.textContent = 'Mise à jour...'; }

  const res = await API.put('/api/me/profile', body);

  if (saveBtn) { saveBtn.disabled = false; saveBtn.textContent = '✅ Mettre à jour'; }

  if (res.ok) {
    // Si le backend renvoie l'utilisateur mis à jour, l'utiliser directement
    if (res.data?.user) {
      State.user = { ...(State.user || {}), ...res.data.user };
    } else {
      // Fallback: mettre à jour le state local immédiatement
      if (name)     State.user.name     = name;
      if (email)    State.user.email    = email;
      if (phone)    State.user.phone    = phone;
      if (username) State.user.username = username;
    }
    localStorage.setItem('user_data', JSON.stringify(State.user));
    renderUserInfo();
    renderSettings();
    showToast('Profil mis à jour ✓');
    // Rafraîchir depuis le serveur pour confirmer la persistance
    await refreshUserProfile();
  } else {
    const errCode = res.data?.code;
    if (errCode === 'USERNAME_EXISTS') {
      showToast(`❌ Nom d'utilisateur déjà utilisé — choisissez-en un autre`);
    } else if (errCode === 'INVALID_USERNAME') {
      showToast('❌ Nom d\'utilisateur invalide (lettres, chiffres, _ . - seulement)');
    } else {
      showToast(res.data?.error || 'Erreur lors de la sauvegarde');
    }
  }
}

async function deleteAccount() {
  const confirmed = confirm(
    '⚠️ Supprimer définitivement votre compte ?\n\n' +
    'Cette action est irréversible. Votre compte sera désactivé et vos données anonymisées.\n\n' +
    'Cliquez OK pour confirmer la suppression.'
  );
  if (!confirmed) return;

  // Double confirmation
  const confirmed2 = confirm('Êtes-vous absolument sûr(e) ? Cette action ne peut pas être annulée.');
  if (!confirmed2) return;

  const res = await API.delete('/api/me');
  if (res.ok) {
    showToast('Compte supprimé. Au revoir !');
    setTimeout(() => logout(), 1500);
  } else {
    showToast(res.data?.error || 'Erreur lors de la suppression du compte');
  }
}

/**
 * Compresse une image via canvas (max 400×400, JPEG 0.75).
 * Retourne un Blob JPEG compressé.
 */
function compressImageForAvatar(file) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    const url = URL.createObjectURL(file);
    img.onload = () => {
      URL.revokeObjectURL(url);
      const MAX = 400;
      let w = img.naturalWidth, h = img.naturalHeight;
      if (w > MAX || h > MAX) {
        if (w > h) { h = Math.round(h * MAX / w); w = MAX; }
        else       { w = Math.round(w * MAX / h); h = MAX; }
      }
      const canvas = document.createElement('canvas');
      canvas.width = w; canvas.height = h;
      canvas.getContext('2d').drawImage(img, 0, 0, w, h);
      canvas.toBlob(blob => {
        if (blob) resolve(blob);
        else      reject(new Error('Compression échouée'));
      }, 'image/jpeg', 0.75);
    };
    img.onerror = () => { URL.revokeObjectURL(url); reject(new Error('Lecture image impossible')); };
    img.src = url;
  });
}

async function uploadAvatar(file) {
  if (!file) return;
  showToast('Compression et upload de la photo...');

  let uploadBlob;
  try {
    uploadBlob = await compressImageForAvatar(file);
  } catch (_) {
    uploadBlob = file; // Fallback: envoyer original si compression échoue
  }

  const formData = new FormData();
  formData.append('avatar', uploadBlob, 'avatar.jpg');
  const res = await API.postForm('/api/me/avatar', formData);
  if (res.ok && res.data.avatarUrl) {
    State.user.avatar = res.data.avatarUrl;
    localStorage.setItem('user_data', JSON.stringify(State.user));
    renderUserInfo();
    renderSettings();
    showToast('Photo de profil mise à jour ✓');
    // Resynchroniser depuis le serveur pour confirmer la persistance
    await refreshUserProfile();
  } else {
    showToast(res.data?.error || 'Échec de l\'upload');
  }
}

async function loadPremiumStatus(userId) {
  if (!userId) return;
  const data = await API.get(`/api/payment/user-status?userId=${userId}`);
  if (data?.isSubscribed || data?.premium) {
    const banner = document.getElementById('subscribe-banner');
    if (banner) {
      banner.innerHTML = `
        <div class="subscribe-banner-icon">💎</div>
        <div class="subscribe-banner-text">
          <div class="subscribe-banner-title">Abonnement Premium</div>
          <div class="subscribe-banner-sub" style="color:var(--accent)">ACTIF ✓</div>
        </div>`;
      banner.style.cursor = 'default';
    }
  }
}

async function handleSubscription() {
  const userId = State.user?.id || State.user?._id;
  if (!userId) { showToast('Connectez-vous pour accéder au paiement'); return; }

  showToast('Redirection vers le paiement...');
  const res = await API.post('/api/payment/leekpay', {
    userId,
    email   : State.user?.email  || undefined,
    name    : State.user?.name   || undefined,
    phone   : State.user?.phone  || undefined,
    amount  : 2000,
    currency: 'XOF',
  });

  if (res.ok) {
    // data.payment_url est le champ officiel LeekPay
    // checkout_url / checkoutUrl sont des alias de compatibilité
    const url = res.data?.payment_url
             || res.data?.checkout_url
             || res.data?.checkoutUrl
             || res.data?.paymentUrl;
    const checkoutId = res.data?.checkout_id || res.data?.checkoutId;

    if (url) {
      // Stocker checkoutId pour le polling de retour
      if (checkoutId) localStorage.setItem('leekpay_pending', JSON.stringify({ checkoutId, userId, ts: Date.now() }));
      window.open(url, '_blank') || (window.location.href = url);
      // Lancer le polling : si le webhook n'est pas reçu, on poll manuellement
      if (checkoutId) startLeekPayPolling(checkoutId, userId);
    } else {
      showToast('URL de paiement manquante — contactez le support');
    }
  } else {
    if (res.data?.code === 'ALREADY_SUBSCRIBED') {
      showToast('Vous êtes déjà abonné OmniSMS Premium ✨');
    } else if (res.data?.code === 'LEEKPAY_NOT_CONFIGURED') {
      showToast('Service de paiement temporairement indisponible');
    } else {
      showToast(res.data?.error || res.data?.message || 'Erreur lors du paiement');
    }
  }
}

// ─── LEEKPAY POLLING ─────────────────────────────────────────────────────────
// Polling officiel GET /api/v1/checkout/:id jusqu'à status = "paid"
// Utilisé en fallback si le webhook n'est pas reçu dans les 30s
function startLeekPayPolling(checkoutId, userId, maxAttempts = 15) {
  let attempts = 0;
  showToast('Paiement en attente — ne fermez pas la page...');

  const poll = async () => {
    attempts++;
    if (attempts > maxAttempts) {
      showToast('Délai expiré — si vous avez payé, votre compte sera activé sous 24h.');
      localStorage.removeItem('leekpay_pending');
      return;
    }

    try {
      const res = await API.post(`/api/payment/poll/${encodeURIComponent(checkoutId)}`, { userId });
      if (res.ok) {
        if (res.data?.isPaid || res.data?.status === 'paid') {
          localStorage.removeItem('leekpay_pending');
          showToast('✅ Paiement confirmé ! Abonnement Premium activé.', 6000);
          // Rafraîchir le profil utilisateur
          if (State.user) { State.user.isSubscribed = true; State.user.premium = true; }
          localStorage.setItem('user_data', JSON.stringify(State.user));
          renderSettings();
          return;
        }
        if (['failed', 'cancelled', 'expired'].includes(res.data?.status)) {
          localStorage.removeItem('leekpay_pending');
          showToast('Paiement annulé ou échoué.');
          return;
        }
      }
    } catch (_) {}

    // Continuer le polling
    setTimeout(poll, 10000);  // toutes les 10s
  };

  setTimeout(poll, 15000);  // premier check après 15s
}

// Reprendre un polling en cours au chargement de la page (retour du paiement)
(function resumeLeekPayPolling() {
  try {
    const pending = JSON.parse(localStorage.getItem('leekpay_pending') || 'null');
    if (!pending) return;
    const age = Date.now() - (pending.ts || 0);
    // Ignorer si plus de 30 minutes
    if (age > 30 * 60 * 1000) { localStorage.removeItem('leekpay_pending'); return; }
    // Reprendre le polling
    setTimeout(() => startLeekPayPolling(pending.checkoutId, pending.userId, 10), 3000);
  } catch (_) {
    localStorage.removeItem('leekpay_pending');
  }
})();

// ─── MODALS ───────────────────────────────────────────────────────────────────
function openModal(id)  {
  const m = document.getElementById(id);
  if (m) { m.style.display = 'flex'; m.classList.add('active'); }
}
function closeModal(id) {
  const m = document.getElementById(id);
  if (m) { m.style.display = 'none'; m.classList.remove('active'); }
}

document.addEventListener('click', e => {
  if (e.target.classList.contains('modal')) closeModal(e.target.id);
});

// ─── UTILS ────────────────────────────────────────────────────────────────────
function escHtml(s) {
  if (s == null) return '';
  return String(s)
    .replace(/&/g,'&amp;')
    .replace(/</g,'&lt;')
    .replace(/>/g,'&gt;')
    .replace(/"/g,'&quot;')
    .replace(/'/g,'&#39;');
}

function getInitials(name) {
  if (!name) return '?';
  const parts = String(name).trim().split(/\s+/);
  if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
  return String(name)[0].toUpperCase();
}

function formatTime(ts) {
  if (!ts) return '';
  const d = new Date(ts);
  if (isNaN(d)) return '';
  return d.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
}

function formatRelativeTime(ts) {
  if (!ts) return '';
  let d;
  // Handle Firestore Timestamp objects
  if (ts && typeof ts === 'object' && ts._seconds) {
    d = new Date(ts._seconds * 1000);
  } else {
    d = new Date(ts);
  }
  if (isNaN(d)) return '';
  const now  = new Date();
  const diff = now - d;
  const sameDay = d.toDateString() === now.toDateString();
  if (sameDay) {
    return d.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
  }
  if (diff < 7 * 24 * 3600 * 1000) {
    const days = ['Dim','Lun','Mar','Mer','Jeu','Ven','Sam'];
    return days[d.getDay()];
  }
  return d.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit' });
}

function showError(id, msg) {
  const el = document.getElementById(id);
  if (el) { el.textContent = msg; el.style.display = msg ? 'block' : 'none'; }
}

function setLoading(btnId, loading, label) {
  const btn = document.getElementById(btnId);
  if (!btn) return;
  btn.disabled    = loading;
  btn.textContent = loading ? 'Chargement...' : label;
}

function showToast(msg, duration = 3000) {
  const t = document.getElementById('toast');
  if (!t) return;
  t.textContent   = msg;
  t.style.opacity = '1';
  t.style.display = 'block';
  clearTimeout(t._timer);
  t._timer = setTimeout(() => { t.style.opacity = '0'; setTimeout(() => t.style.display = 'none', 300); }, duration);
}

// ─── INIT ─────────────────────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('/sw.js').catch(() => {});
  }

  if (State.token && State.user) {
    initDashboard();
  } else {
    showScreen('screen-login');
  }

  setTimeout(() => {
    if (document.getElementById('screen-splash')?.classList.contains('active')) {
      showScreen(State.token && State.user ? 'screen-dashboard' : 'screen-login');
    }
  }, 1200);
});
