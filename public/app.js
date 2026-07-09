// OmniSMS PWA - Application principale
const API_BASE = 'https://omnisms-backend.onrender.com';
const WS_URL = 'wss://omnisms-backend.onrender.com/ws';

// ─── STATE ───────────────────────────────────────────────────────────────────
const State = {
  token: localStorage.getItem('auth_token'),
  user: JSON.parse(localStorage.getItem('user_data') || 'null'),
  currentTab: 'messages',
  contacts: [],
  conversations: {},
  activeConversation: null,
  groups: [],
  ws: null,
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
      return r.ok ? r.json() : null;
    } catch { return null; }
  },
  async post(path, body) {
    try {
      const r = await fetch(API_BASE + path, {
        method: 'POST', headers: this.headers(), body: JSON.stringify(body)
      });
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
  if (State.ws) State.ws.close();
  localStorage.removeItem('auth_token');
  localStorage.removeItem('user_data');
  showScreen('screen-login');
}

// ─── DASHBOARD ───────────────────────────────────────────────────────────────
function initDashboard() {
  showScreen('screen-dashboard');
  renderUserInfo();
  switchTab('messages');
  connectWebSocket();
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

  // Hide conversation panel when switching tabs
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

  const data = await API.get('/api/messages/conversations');
  
  if (!data || !data.conversations?.length) {
    container.innerHTML = `
      <div class="empty-state">
        <div class="empty-icon">💬</div>
        <p>Aucune conversation</p>
        <span>Envoyez un message à un contact</span>
      </div>`;
    return;
  }

  container.innerHTML = data.conversations.map(conv => `
    <div class="conversation-item" onclick="openConversation('${conv.contactId}', '${escHtml(conv.contactName || conv.contactPhone)}')">
      <div class="avatar">${getInitials(conv.contactName || conv.contactPhone)}</div>
      <div class="conv-info">
        <div class="conv-header">
          <span class="conv-name">${escHtml(conv.contactName || conv.contactPhone)}</span>
          <span class="conv-time">${formatTime(conv.lastMessageTime)}</span>
        </div>
        <div class="conv-preview">${escHtml(conv.lastMessage || '')}</div>
      </div>
      ${conv.unreadCount > 0 ? `<div class="badge">${conv.unreadCount}</div>` : ''}
    </div>
  `).join('');
}

async function openConversation(contactId, contactName) {
  State.activeConversation = { id: contactId, name: contactName };
  
  const panel = document.getElementById('conversation-panel');
  panel.classList.add('open');
  document.getElementById('conv-title').textContent = contactName;
  document.getElementById('conv-messages').innerHTML = `<div class="loading-state"><div class="spinner"></div></div>`;

  const data = await API.get(`/api/messages/${contactId}`);
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
  const isMe = m.senderId === State.user?.id || m.sender === 'me';
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
    openConversation(State.activeConversation.id, State.activeConversation.name);
  } else {
    showToast('Erreur envoi: ' + (res.data.message || 'Erreur'));
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
  State.contacts = data?.contacts || data || [];

  if (!State.contacts.length) {
    container.innerHTML = `
      <div class="empty-state">
        <div class="empty-icon">👥</div>
        <p>Aucun contact</p>
        <span>Ajoutez des contacts pour commencer</span>
      </div>`;
    return;
  }

  renderContacts(State.contacts);
}

function renderContacts(contacts) {
  const container = document.getElementById('contacts-list');
  container.innerHTML = contacts.map(c => `
    <div class="contact-item" onclick="openConversation('${c.id}', '${escHtml(c.name || c.phone)}'); switchTab('messages')">
      <div class="avatar">${getInitials(c.name || c.phone)}</div>
      <div class="contact-info">
        <div class="contact-name">${escHtml(c.name || c.phone)}</div>
        <div class="contact-phone">${escHtml(c.phone || '')}</div>
      </div>
      <button class="icon-btn" onclick="event.stopPropagation(); openAddContactModal('${c.id}')">
        <svg viewBox="0 0 24 24" fill="currentColor"><path d="M6.99 11C6.44 11 6 11.45 6 12s.44 1 .99 1H11v4.99c0 .55.45.99 1 .99s1-.44 1-.99V13h4.99c.55 0 .99-.45.99-1s-.44-1-.99-1H13V7.01c0-.55-.45-.99-1-.99s-1 .44-1 .99V11H6.99z"/></svg>
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

async function addContact(name, phone) {
  const res = await API.post('/api/contacts', { name, phone });
  if (res.ok) {
    closeModal('modal-add-contact');
    showToast('Contact ajouté !');
    loadContacts();
  } else {
    showError('contact-error', res.data.message || 'Erreur');
  }
}

// ─── GROUPS ───────────────────────────────────────────────────────────────────
async function loadGroups() {
  const container = document.getElementById('groups-list');
  container.innerHTML = `<div class="loading-state"><div class="spinner"></div><p>Chargement...</p></div>`;

  const data = await API.get('/api/groups');
  State.groups = data?.groups || data || [];

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
        <div class="group-meta">${g.memberCount || g.members?.length || 0} membres</div>
      </div>
      <button class="btn-primary btn-sm" onclick="openGroupSend('${g.id}', '${escHtml(g.name)}')">
        Envoyer
      </button>
    </div>
  `).join('');
}

async function createGroup(name, description) {
  const res = await API.post('/api/groups', { name, description, members: [] });
  if (res.ok) {
    closeModal('modal-create-group');
    showToast('Groupe créé !');
    loadGroups();
  } else {
    showError('group-error', res.data.message || 'Erreur');
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

  const res = await API.post(`/api/groups/${groupId}/send`, { message: text });
  if (res.ok) {
    closeModal('modal-group-send');
    document.getElementById('group-send-text').value = '';
    showToast('Message envoyé au groupe !');
  } else {
    showToast('Erreur: ' + (res.data.message || 'Erreur envoi groupe'));
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
  const planEl = document.getElementById('settings-plan');
  if (planEl) planEl.textContent = u?.plan || 'Gratuit';
}

// ─── WEBSOCKET ─────────────────────────────────────────────────────────────────
function connectWebSocket() {
  if (!State.token) return;
  try {
    State.ws = new WebSocket(`${WS_URL}?token=${State.token}`);
    State.ws.onmessage = (e) => {
      try {
        const msg = JSON.parse(e.data);
        if (msg.type === 'new_message' && State.activeConversation?.id === msg.senderId) {
          openConversation(State.activeConversation.id, State.activeConversation.name);
        }
        if (msg.type === 'new_message') {
          showToast(`📩 ${msg.senderName || 'Nouveau message'}`);
        }
      } catch {}
    };
    State.ws.onerror = () => {};
    State.ws.onclose = () => setTimeout(connectWebSocket, 5000);
  } catch {}
}

// ─── MODALS ──────────────────────────────────────────────────────────────────
function openModal(id) {
  document.getElementById(id)?.classList.add('open');
}
function closeModal(id) {
  document.getElementById(id)?.classList.remove('open');
  // Clear errors
  document.querySelectorAll(`#${id} .field-error`).forEach(e => e.textContent = '');
}

// ─── UTILS ───────────────────────────────────────────────────────────────────
function escHtml(s) {
  return String(s || '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
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
  toastTimeout = setTimeout(() => t.classList.remove('show'), 3000);
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
  }, 1800);

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

  // Add contact form
  document.getElementById('add-contact-form')?.addEventListener('submit', e => {
    e.preventDefault();
    const name = document.getElementById('contact-name').value.trim();
    const phone = document.getElementById('contact-phone').value.trim();
    addContact(name, phone);
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
      .catch(() => {}); // ignore erreurs SW
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
