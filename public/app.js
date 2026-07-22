// OmniSMS PWA v2.5.0 - Application principale
const API_BASE = 'https://omnisms-backend.onrender.com';
const WS_URL   = 'https://omnisms-backend.onrender.com'; // Socket.IO URL (sans /ws)

// ─── STATE ───────────────────────────────────────────────────────────────────
const State = {
  token: localStorage.getItem('auth_token'),
  user: JSON.parse(localStorage.getItem('user_data') || 'null'),
  currentTab: 'messages',
  contacts: [],
  conversations: {},
  activeConversation: null,
  groups: [],
  socket: null,
  isLoading: false,
};

// ─── API ─────────────────────────────────────────────────────────────────────
const API = {
  headers() {
    const h = { 'Content-Type': 'application/json', 'Accept': 'application/json' };
    if (State.token) h['Authorization'] = `Bearer ${State.token}`;
    return h;
  },
  async get(path) {
    try {
      const r = await fetch(API_BASE + path, { headers: this.headers() });
      if (r.status === 401) { logout(); return null; }
      return r.ok ? r.json() : null;
    } catch { return null; }
  },
  async post(path, body) {
    try {
      const r = await fetch(API_BASE + path, {
        method: 'POST', headers: this.headers(), body: JSON.stringify(body)
      });
      if (r.status === 401) { logout(); return { ok: false, data: { message: 'Session expirée' } }; }
      return { ok: r.ok, status: r.status, data: await r.json().catch(() => ({})) };
    } catch(e) { return { ok: false, data: { message: 'Erreur réseau — serveur en cours de démarrage...' } }; }
  },
  async delete(path) {
    try {
      const r = await fetch(API_BASE + path, { method: 'DELETE', headers: this.headers() });
      return { ok: r.ok, status: r.status, data: await r.json().catch(() => ({})) };
    } catch(e) { return { ok: false, data: { message: 'Erreur réseau' } }; }
  }
};

// ─── ROUTER ──────────────────────────────────────────────────────────────────
function showScreen(id) {
  document.querySelectorAll('.screen').forEach(s => s.classList.remove('active'));
  const el = document.getElementById(id);
  if (el) el.classList.add('active');
}

// ─── AUTH ─────────────────────────────────────────────────────────────────────
async function login(email, password) {
  setLoading('login-btn', true, 'Se connecter');
  const res = await API.post('/api/auth/login', { email, password });
  setLoading('login-btn', false, 'Se connecter');

  if (res.ok && res.data.token) {
    State.token = res.data.token;
    State.user = res.data.user || { email };
    localStorage.setItem('auth_token', State.token);
    localStorage.setItem('user_data', JSON.stringify(State.user));
    showError('login-error', '');
    initDashboard();
  } else {
    showError('login-error', res.data.message || 'Email ou mot de passe incorrect');
  }
}

async function register(name, email, password) {
  setLoading('register-btn', true, 'S\'inscrire');
  const res = await API.post('/api/auth/register', { name, email, password });
  setLoading('register-btn', false, 'S\'inscrire');

  if (res.ok) {
    if (res.data.token) {
      State.token = res.data.token;
      State.user = res.data.user || { name, email };
      localStorage.setItem('auth_token', State.token);
      localStorage.setItem('user_data', JSON.stringify(State.user));
      initDashboard();
    } else {
      showError('register-error', '');
      showScreen('screen-login');
      showToast('Compte créé ! Connectez-vous.');
    }
  } else {
    showError('register-error', res.data.message || 'Erreur lors de l\'inscription');
  }
}

function logout() {
  State.token = null;
  State.user = null;
  State.contacts = [];
  State.conversations = {};
  if (State.socket) { try { State.socket.disconnect(); } catch(_) {} }
  State.socket = null;
  localStorage.removeItem('auth_token');
  localStorage.removeItem('user_data');
  showScreen('screen-login');
}

// ─── DASHBOARD ───────────────────────────────────────────────────────────────
function initDashboard() {
  showScreen('screen-dashboard');
  renderUserInfo();
  switchTab('messages');
  connectSocket();
}

function renderUserInfo() {
  const u = State.user;
  const name = u?.name || u?.email || 'Utilisateur';
  const initials = name.split(' ').map(w => w[0]).join('').toUpperCase().slice(0,2);
  document.querySelectorAll('.user-name').forEach(el => el.textContent = name);
  document.querySelectorAll('.user-initials').forEach(el => el.textContent = initials);
  document.querySelectorAll('.user-email').forEach(el => el.textContent = u?.email || '');
}

function switchTab(tab) {
  State.currentTab = tab;
  State.activeConversation = null;

  document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
  document.querySelector(`[data-tab="${tab}"]`)?.classList.add('active');

  document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
  document.getElementById(`tab-${tab}`)?.classList.add('active');

  document.getElementById('conversation-panel')?.classList.remove('open');

  if (tab === 'messages') loadConversations();
  else if (tab === 'contacts') loadContacts();
  else if (tab === 'groups') loadGroups();
  else if (tab === 'settings') renderSettings();
}

// ─── MESSAGES ─────────────────────────────────────────────────────────────────
async function loadConversations() {
  const container = document.getElementById('conversations-list');
  container.innerHTML = `<div class="loading-state"><div class="spinner"></div><p>Chargement...</p></div>`;

  // FIX: correct endpoint is GET /api/messages (not /api/messages/conversations)
  const data = await API.get('/api/messages');

  if (!data || !data.conversations?.length) {
    container.innerHTML = `
      <div class="empty-state">
        <div class="empty-icon">💬</div>
        <p>Aucune conversation</p>
        <span>Envoyez un message à un contact</span>
      </div>`;
    return;
  }

  container.innerHTML = data.conversations.map(conv => {
    const otherId   = conv.otherUserId || conv.id;
    const otherName = conv.contactName || conv.contactPhone || otherId;
    const lastMsg   = conv.lastMessage?.content || conv.lastMessage?.text || '';
    const lastTime  = conv.lastMessage?.createdAt || conv.lastMessageTime || '';
    return `
    <div class="conversation-item" onclick="openConversation('${escHtml(otherId)}', '${escHtml(otherName)}', '${escHtml(conv.id || '')}')">
      <div class="avatar">${getInitials(otherName)}</div>
      <div class="conv-info">
        <div class="conv-header">
          <span class="conv-name">${escHtml(otherName)}</span>
          <span class="conv-time">${formatTime(lastTime)}</span>
        </div>
        <div class="conv-preview">${escHtml(lastMsg)}</div>
      </div>
      ${conv.unreadCount > 0 ? `<div class="badge">${conv.unreadCount}</div>` : ''}
    </div>`;
  }).join('');
}

async function openConversation(contactId, contactName, conversationId) {
  State.activeConversation = { id: contactId, name: contactName, convId: conversationId };

  const panel = document.getElementById('conversation-panel');
  panel.classList.add('open');
  document.getElementById('conv-title').textContent = contactName;
  const avatarEl = document.getElementById('conv-avatar');
  if (avatarEl) avatarEl.textContent = getInitials(contactName);
  document.getElementById('conv-messages').innerHTML = `<div class="loading-state"><div class="spinner"></div></div>`;

  // Use conversationId if available, otherwise contactId
  const idToFetch = conversationId || contactId;
  const data = await API.get(`/api/messages/${idToFetch}`);
  const messages = data?.messages || [];

  const container = document.getElementById('conv-messages');
  if (!messages.length) {
    container.innerHTML = `<div class="empty-state"><p>Aucun message</p><span>Envoyez le premier message !</span></div>`;
  } else {
    container.innerHTML = messages.map(m => renderMessage(m)).join('');
    container.scrollTop = container.scrollHeight;
  }
}

function renderMessage(m) {
  const myId = State.user?.uid || State.user?.id || '';
  const isMe = m.senderId === myId || m.sender === 'me';
  return `
    <div class="message ${isMe ? 'message-out' : 'message-in'}">
      <div class="bubble">${escHtml(m.content || m.text || '')}</div>
      <div class="msg-time">${formatTime(m.createdAt || m.timestamp)}</div>
    </div>`;
}

async function sendMessage() {
  const input = document.getElementById('message-input');
  const text = input.value.trim();
  if (!text || !State.activeConversation) return;

  input.value = '';
  const res = await API.post('/api/messages/send', {
    receiverId: State.activeConversation.id,
    content: text,
    type: 'text'
  });

  if (res.ok) {
    openConversation(
      State.activeConversation.id,
      State.activeConversation.name,
      State.activeConversation.convId
    );
  } else {
    showToast('Erreur envoi: ' + (res.data.message || 'Erreur'));
    input.value = text; // restore text on error
  }
}

function closeConversation() {
  State.activeConversation = null;
  document.getElementById('conversation-panel')?.classList.remove('open');
}

// ─── CONTACTS ─────────────────────────────────────────────────────────────────
async function loadContacts() {
  const container = document.getElementById('contacts-list');
  container.innerHTML = `<div class="loading-state"><div class="spinner"></div><p>Chargement...</p></div>`;

  const data = await API.get('/api/contacts');
  State.contacts = data?.contacts || [];

  if (!State.contacts.length) {
    container.innerHTML = `
      <div class="empty-state">
        <div class="empty-icon">👥</div>
        <p>Aucun contact</p>
        <span>Importez ou ajoutez vos contacts</span>
      </div>`;
    return;
  }

  renderContacts(State.contacts);
}

function renderContacts(contacts) {
  const container = document.getElementById('contacts-list');
  container.innerHTML = contacts.map(c => `
    <div class="contact-item" onclick="openConversation('${escHtml(c.phone || c.id)}', '${escHtml(c.name || c.phone)}', ''); switchTab('messages')">
      <div class="avatar">${getInitials(c.name || c.phone)}</div>
      <div class="contact-info">
        <div class="contact-name">${escHtml(c.name || c.phone)}</div>
        <div class="contact-phone">${escHtml(c.phone || '')}</div>
      </div>
      <button class="icon-btn" onclick="event.stopPropagation(); confirmDeleteContact('${escHtml(c.phone || '')}', '${escHtml(c.name || c.phone)}')" title="Supprimer">
        <svg viewBox="0 0 24 24" fill="currentColor"><path d="M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z"/></svg>
      </button>
    </div>
  `).join('');
}

function searchContacts(q) {
  if (!q) { renderContacts(State.contacts); return; }
  const filtered = State.contacts.filter(c =>
    (c.name || '').toLowerCase().includes(q.toLowerCase()) ||
    (c.phone || '').includes(q)
  );
  renderContacts(filtered);
}

// FIX BUG 1: correct endpoint POST /api/contacts/add (was /api/contacts)
async function addContact(name, phone) {
  if (!name || !phone) {
    showError('contact-error', 'Nom et téléphone requis');
    return;
  }
  const btn = document.getElementById('add-contact-submit');
  if (btn) { btn.disabled = true; btn.innerHTML = '<div class="spinner spinner-sm"></div>'; }

  // FIX: use correct endpoint /api/contacts/add with country field
  const res = await API.post('/api/contacts/add', { name, phone, country: 'BF' });

  if (btn) { btn.disabled = false; btn.textContent = 'Ajouter'; }

  if (res.ok) {
    closeModal('modal-add-contact');
    // Clear form fields
    const nameEl = document.getElementById('contact-name');
    const phoneEl = document.getElementById('contact-phone');
    if (nameEl) nameEl.value = '';
    if (phoneEl) phoneEl.value = '';
    showToast('✅ Contact ajouté !');
    loadContacts();
  } else {
    showError('contact-error', res.data.message || res.data.error || 'Erreur lors de l\'ajout');
  }
}

async function confirmDeleteContact(phone, name) {
  if (!confirm(`Supprimer le contact "${name}" ?`)) return;
  const encodedPhone = encodeURIComponent(phone);
  const res = await API.delete(`/api/contacts/${encodedPhone}`);
  if (res.ok) {
    showToast('Contact supprimé');
    loadContacts();
  } else {
    showToast('Erreur: ' + (res.data.message || 'Impossible de supprimer'));
  }
}

// ─── CONTACT PICKER API ────────────────────────────────────────────────────────
async function importWithContactPicker() {
  // Check if Contact Picker API is available (Chrome Android / some browsers)
  if (!('contacts' in navigator) || !('ContactsManager' in window)) {
    showToast('Contact Picker non disponible — importez un fichier VCF');
    document.getElementById('vcf-import-input')?.click();
    return;
  }

  try {
    const props = ['name', 'tel'];
    const opts  = { multiple: true };
    const picked = await navigator.contacts.select(props, opts);

    if (!picked || picked.length === 0) {
      showToast('Aucun contact sélectionné');
      return;
    }

    const contacts = picked.flatMap(p => {
      const name = (p.name && p.name[0]) || 'Contact';
      return (p.tel || []).map(tel => ({ name, phone: tel }));
    }).filter(c => c.phone);

    if (!contacts.length) {
      showToast('Aucun numéro trouvé dans la sélection');
      return;
    }

    await syncContacts(contacts);
  } catch (err) {
    showToast('Erreur Contact Picker: ' + (err.message || 'Annulé'));
  }
}

// ─── VCF IMPORT ────────────────────────────────────────────────────────────────
function parseVCF(text) {
  const contacts = [];
  const vcards = text.split(/BEGIN:VCARD/i).filter(v => v.trim());

  vcards.forEach(vcard => {
    let name  = '';
    let phones = [];

    vcard.split('\n').forEach(line => {
      line = line.trim();
      if (!line) return;

      // Nom
      if (line.startsWith('FN:')) {
        name = line.slice(3).trim();
      } else if (line.startsWith('N:') && !name) {
        const parts = line.slice(2).split(';');
        name = [parts[1], parts[0]].filter(Boolean).join(' ').trim();
      }

      // Téléphone — TEL;... ou TEL:
      if (/^TEL/i.test(line)) {
        const colonIdx = line.indexOf(':');
        if (colonIdx !== -1) {
          const tel = line.slice(colonIdx + 1).trim()
            .replace(/[\s\-\(\)\.]/g, '');
          if (tel) phones.push(tel);
        }
      }
    });

    phones.forEach(phone => {
      if (phone) contacts.push({ name: name || 'Contact', phone });
    });
  });

  return contacts;
}

function handleVCFFile(file) {
  if (!file) return;
  if (!file.name.toLowerCase().endsWith('.vcf') && file.type !== 'text/vcard') {
    showToast('Fichier VCF requis (.vcf)');
    return;
  }

  const reader = new FileReader();
  reader.onload = async (e) => {
    const text = e.target.result;
    const contacts = parseVCF(text);

    if (!contacts.length) {
      showToast('Aucun contact trouvé dans le fichier VCF');
      return;
    }

    showToast(`📂 ${contacts.length} contact(s) trouvé(s) — synchronisation...`);
    await syncContacts(contacts);
  };
  reader.readAsText(file);
}

// ─── CONTACT SYNC ──────────────────────────────────────────────────────────────
async function syncContacts(contacts) {
  if (!State.token) {
    showToast('Connectez-vous pour synchroniser vos contacts');
    return;
  }

  const res = await API.post('/api/contacts/sync', { contacts, country: 'BF' });

  if (res.ok) {
    const total = res.data.total || contacts.length;
    const found = res.data.registeredOnOmniSms || 0;
    showToast(`✅ ${total} contact(s) synchronisé(s) — ${found} sur OmniSMS`);
    closeModal('modal-add-contact');
    loadContacts();
  } else {
    showToast('Erreur sync: ' + (res.data.message || res.data.error || 'Erreur'));
  }
}

// ─── GROUPS ───────────────────────────────────────────────────────────────────
async function loadGroups() {
  const container = document.getElementById('groups-list');
  container.innerHTML = `<div class="loading-state"><div class="spinner"></div><p>Chargement...</p></div>`;

  // FIX BUG 3: correct endpoint /groups (not /api/groups)
  const data = await API.get('/groups');
  // Backend returns array directly (not {groups:[]})
  State.groups = Array.isArray(data) ? data : (data?.groups || []);

  if (!State.groups.length) {
    container.innerHTML = `
      <div class="empty-state">
        <div class="empty-icon">👥</div>
        <p>Aucun groupe</p>
        <span>Créez un groupe pour envoyer des SMS en masse</span>
      </div>`;
    return;
  }

  container.innerHTML = State.groups.map(g => `
    <div class="group-item">
      <div class="avatar group-avatar">${getInitials(g.name)}</div>
      <div class="group-info">
        <div class="group-name">${escHtml(g.name)}</div>
        <div class="group-meta">${(g.members?.length || 0)} membres</div>
      </div>
      <button class="btn-primary btn-sm" onclick="openGroupSend('${escHtml(g.id)}', '${escHtml(g.name)}')">
        Envoyer
      </button>
    </div>
  `).join('');
}

async function createGroup(name, description) {
  if (!name) { showError('group-error', 'Nom requis'); return; }
  const btn = document.getElementById('create-group-submit');
  if (btn) { btn.disabled = true; btn.innerHTML = '<div class="spinner spinner-sm"></div>'; }

  // FIX: correct endpoint /groups (not /api/groups)
  const res = await API.post('/groups', { name, description, members: [] });

  if (btn) { btn.disabled = false; btn.textContent = 'Créer'; }

  if (res.ok) {
    closeModal('modal-create-group');
    const nameEl = document.getElementById('group-name');
    const descEl = document.getElementById('group-desc');
    if (nameEl) nameEl.value = '';
    if (descEl) descEl.value = '';
    showToast('✅ Groupe créé !');
    loadGroups();
  } else {
    showError('group-error', res.data.message || res.data.error || 'Erreur création groupe');
  }
}

async function openGroupSend(groupId, groupName) {
  document.getElementById('group-send-title').textContent = `Envoyer à "${groupName}"`;
  document.getElementById('group-send-id').value = groupId;
  openModal('modal-group-send');
}

async function sendGroupMessage() {
  const groupId = document.getElementById('group-send-id').value;
  const text = document.getElementById('group-send-text').value.trim();
  if (!text) return;

  // FIX: backend group send is POST /groups/:id/messages (not /api/groups/:id/send)
  const res = await API.post(`/groups/${groupId}/messages`, { content: text });
  if (res.ok) {
    closeModal('modal-group-send');
    document.getElementById('group-send-text').value = '';
    showToast('✅ Message envoyé au groupe !');
  } else {
    showToast('Erreur: ' + (res.data.message || res.data.error || 'Erreur envoi groupe'));
  }
}

// ─── SETTINGS ─────────────────────────────────────────────────────────────────
function renderSettings() {
  const u = State.user;
  const name = u?.name || u?.email || 'Non défini';
  document.querySelectorAll('.user-name').forEach(el => el.textContent = name);
  document.querySelectorAll('.user-email').forEach(el => el.textContent = u?.email || '');
  document.querySelectorAll('.user-initials').forEach(el => {
    el.textContent = name.split(' ').map(w=>w[0]).join('').toUpperCase().slice(0,2);
  });

  // Load premium status
  if (u?.uid || u?.id) {
    loadPremiumStatus(u.uid || u.id);
  }
}

async function loadPremiumStatus(userId) {
  const planEl = document.getElementById('settings-plan');
  const subsBtn = document.getElementById('subscription-btn');

  const data = await API.get(`/api/payment/user-status?userId=${encodeURIComponent(userId)}`);
  const isPremium = data?.premium || data?.isSubscribed || false;

  if (planEl) planEl.textContent = isPremium ? 'Premium ⭐' : 'Gratuit';
  if (subsBtn) subsBtn.textContent = isPremium ? 'Gérer mon abonnement' : 'S\'abonner au Premium';
}

// FIX BUG 4: Payment handler — calls POST /api/payment/leekpay → opens checkout URL
async function handleSubscription() {
  const u = State.user;
  if (!u) { showToast('Connectez-vous d\'abord'); return; }
  if (!State.token) { showToast('Session expirée — reconnectez-vous'); return; }

  const btn = document.getElementById('subscription-btn');
  const origText = btn?.textContent || 'S\'abonner';
  if (btn) { btn.disabled = true; btn.innerHTML = '<div class="spinner spinner-sm"></div> Chargement...'; }

  const body = {
    userId  : u.uid || u.id || u.email,
    amount  : 2000,
    currency: 'XOF',
    email   : u.email || '',
    name    : u.name  || u.email || '',
  };

  const res = await API.post('/api/payment/leekpay', body);

  if (btn) { btn.disabled = false; btn.textContent = origText; }

  if (res.ok && res.data.checkout_url) {
    showToast('Redirection vers la page de paiement...');
    window.open(res.data.checkout_url, '_blank');
  } else if (res.data?.code === 'LEEKPAY_NOT_CONFIGURED') {
    showToast('Paiement non configuré — contactez le support');
  } else {
    showToast('Erreur paiement: ' + (res.data?.message || res.data?.error || 'Réessayez'));
  }
}

// ─── SOCKET.IO (real-time) ────────────────────────────────────────────────────
function connectSocket() {
  if (!State.token) return;

  // Dynamically load Socket.IO client if not already loaded
  if (typeof io === 'undefined') {
    const script = document.createElement('script');
    script.src = 'https://cdn.socket.io/4.7.5/socket.io.min.js';
    script.onload = () => initSocket();
    script.onerror = () => {}; // non-blocking
    document.head.appendChild(script);
  } else {
    initSocket();
  }
}

function initSocket() {
  if (!State.token || typeof io === 'undefined') return;
  if (State.socket?.connected) return;

  try {
    State.socket = io(WS_URL, {
      auth: { token: State.token },
      transports: ['websocket', 'polling'],
      reconnection: true,
      reconnectionDelay: 3000,
      timeout: 20000,
    });

    State.socket.on('connect', () => {
      // Socket connected
    });

    State.socket.on('message:receive', (msg) => {
      if (State.activeConversation &&
          (msg.senderId === State.activeConversation.id ||
           msg.conversationId === State.activeConversation.convId)) {
        openConversation(
          State.activeConversation.id,
          State.activeConversation.name,
          State.activeConversation.convId
        );
      }
      showToast(`📩 Nouveau message`);
      if (State.currentTab === 'messages') loadConversations();
    });

    State.socket.on('new_message', (msg) => {
      showToast(`📩 ${msg.senderName || 'Nouveau message'}`);
      if (State.currentTab === 'messages') loadConversations();
    });

    State.socket.on('transcription:update', (data) => {
      showToast(`🎤 Transcription terminée`);
    });

    State.socket.on('disconnect', () => {});
    State.socket.on('connect_error', () => {});
  } catch (_) {}
}

// ─── MODALS ──────────────────────────────────────────────────────────────────
function openModal(id) {
  document.getElementById(id)?.classList.add('open');
}
function closeModal(id) {
  document.getElementById(id)?.classList.remove('open');
  document.querySelectorAll(`#${id} .field-error`).forEach(e => e.textContent = '');
}

// ─── UTILS ───────────────────────────────────────────────────────────────────
function escHtml(s) {
  return String(s || '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');
}
function getInitials(name) {
  return String(name || '?').split(' ').map(w => w[0]).join('').toUpperCase().slice(0, 2) || '?';
}
function formatTime(ts) {
  if (!ts) return '';
  const d = new Date(ts);
  if (isNaN(d)) return '';
  const now = new Date();
  const diff = (now - d) / 1000;
  if (diff < 60) return 'À l\'instant';
  if (diff < 3600) return `${Math.floor(diff/60)}min`;
  if (diff < 86400) return d.toLocaleTimeString('fr', { hour: '2-digit', minute: '2-digit' });
  return d.toLocaleDateString('fr', { day: '2-digit', month: '2-digit' });
}
function showError(id, msg) {
  const el = document.getElementById(id);
  if (el) el.textContent = msg;
}
function setLoading(btnId, loading, label) {
  const btn = document.getElementById(btnId);
  if (!btn) return;
  btn.disabled = loading;
  btn.innerHTML = loading
    ? `<div class="spinner spinner-sm"></div>`
    : label;
}
let toastTimeout;
function showToast(msg) {
  const t = document.getElementById('toast');
  if (!t) return;
  t.textContent = msg;
  t.classList.add('show');
  clearTimeout(toastTimeout);
  toastTimeout = setTimeout(() => t.classList.remove('show'), 3500);
}

// ─── INIT ─────────────────────────────────────────────────────────────────────
window.addEventListener('DOMContentLoaded', () => {
  // Splash → auth check
  setTimeout(() => {
    if (State.token && State.user) {
      initDashboard();
    } else {
      showScreen('screen-login');
    }
  }, 1500);

  // Login form
  document.getElementById('login-form')?.addEventListener('submit', e => {
    e.preventDefault();
    const email = document.getElementById('login-email').value.trim();
    const pass = document.getElementById('login-pass').value;
    if (!email || !pass) return;
    login(email, pass);
  });

  // Register form
  document.getElementById('register-form')?.addEventListener('submit', e => {
    e.preventDefault();
    const name = document.getElementById('reg-name').value.trim();
    const email = document.getElementById('reg-email').value.trim();
    const pass = document.getElementById('reg-pass').value;
    if (!name || !email || !pass) return;
    register(name, email, pass);
  });

  // Message input — send on Enter
  document.getElementById('message-input')?.addEventListener('keydown', e => {
    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendMessage(); }
  });

  // Contact search
  document.getElementById('contact-search')?.addEventListener('input', e => {
    searchContacts(e.target.value);
  });

  // Add contact form — manual add
  document.getElementById('add-contact-form')?.addEventListener('submit', e => {
    e.preventDefault();
    const name = document.getElementById('contact-name').value.trim();
    const phone = document.getElementById('contact-phone').value.trim();
    addContact(name, phone);
  });

  // VCF file input handler
  document.getElementById('vcf-import-input')?.addEventListener('change', e => {
    const file = e.target.files?.[0];
    if (file) {
      handleVCFFile(file);
      e.target.value = ''; // reset so same file can be imported again
    }
  });

  // Create group form
  document.getElementById('create-group-form')?.addEventListener('submit', e => {
    e.preventDefault();
    const name = document.getElementById('group-name').value.trim();
    const desc = document.getElementById('group-desc').value.trim();
    createGroup(name, desc);
  });

  // Group send form
  document.getElementById('group-send-form')?.addEventListener('submit', e => {
    e.preventDefault();
    sendGroupMessage();
  });

  // Close modals on backdrop click
  document.querySelectorAll('.modal').forEach(m => {
    m.addEventListener('click', e => {
      if (e.target === m) closeModal(m.id);
    });
  });

  // Service Worker registration
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('/sw.js', { scope: '/' })
      .catch(() => {});
  }

  // PWA install
  let deferredPrompt;
  window.addEventListener('beforeinstallprompt', e => {
    e.preventDefault();
    deferredPrompt = e;
    document.getElementById('install-btn')?.style.setProperty('display', 'flex');
  });
  document.getElementById('install-btn')?.addEventListener('click', async () => {
    if (!deferredPrompt) return;
    deferredPrompt.prompt();
    await deferredPrompt.userChoice;
    deferredPrompt = null;
  });
});
