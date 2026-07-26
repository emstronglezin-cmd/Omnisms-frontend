// OmniSMS PWA v3.0 — Architecture Conversations-First (WhatsApp)
// Correspond exactement à l'architecture Flutter v3 (commit a322984)
// Tab 0 = MessagesListPage (GET /api/messages)
// ConversationScreen utilise conversationId (uid1-uid2) + contactId pour l'envoi
// Navigation 4 onglets : Messages | Contacts | Groupes | Paramètres

const API_BASE = 'https://omnisms-backend.onrender.com';

// ─── STATE ────────────────────────────────────────────────────────────────────
const State = {
  token:            localStorage.getItem('auth_token'),
  user:             JSON.parse(localStorage.getItem('user_data') || 'null'),
  currentTab:       'messages',
  conversations:    [],          // ConversationModel[]  (GET /api/messages)
  activeConvId:     null,        // conversationId ouvert
  activeConvMsgs:   [],          // messages de la conv active
  activeConvInfo:   null,        // { conversationId, contactId, contactName, isGroup }
  contacts:         [],
  groups:           [],
  pollTimer:        null,        // 15s polling timer
};

// ─── API ──────────────────────────────────────────────────────────────────────
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

// ─── ROUTER ───────────────────────────────────────────────────────────────────
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
    State.user  = res.data.user || { email };
    localStorage.setItem('auth_token', State.token);
    localStorage.setItem('user_data', JSON.stringify(State.user));
    showError('login-error', '');
    initDashboard();
  } else {
    showError('login-error', res.data.message || 'Email ou mot de passe incorrect');
  }
}

async function register(name, email, password) {
  setLoading('register-btn', true, "S'inscrire");
  const res = await API.post('/api/auth/register', { name, email, password });
  setLoading('register-btn', false, "S'inscrire");
  if (res.ok) {
    if (res.data.token) {
      State.token = res.data.token;
      State.user  = res.data.user || { name, email };
      localStorage.setItem('auth_token', State.token);
      localStorage.setItem('user_data', JSON.stringify(State.user));
      initDashboard();
    } else {
      showError('register-error', '');
      showToast('Compte créé ! Connectez-vous.');
      showScreen('screen-login');
    }
  } else {
    showError('register-error', res.data.message || 'Erreur lors de la création du compte');
  }
}

function logout() {
  clearInterval(State.pollTimer);
  State.token  = null;
  State.user   = null;
  State.conversations = [];
  State.contacts = [];
  State.groups   = [];
  localStorage.removeItem('auth_token');
  localStorage.removeItem('user_data');
  showScreen('screen-login');
}

// ─── DASHBOARD ────────────────────────────────────────────────────────────────
function initDashboard() {
  if (!State.token) { showScreen('screen-login'); return; }
  showScreen('screen-dashboard');
  renderUserInfo();
  switchTab('messages');          // V3 : onglet Messages en premier
  startPolling();
}

function renderUserInfo() {
  const name = State.user?.name || State.user?.email || 'Utilisateur';
  const el = document.getElementById('user-name');
  if (el) el.textContent = name;
  const av = document.getElementById('user-avatar');
  if (av) av.textContent = getInitials(name);
}

// ─── NAVIGATION 4 ONGLETS (Messages | Contacts | Groupes | Paramètres) ────────
function switchTab(tab) {
  State.currentTab = tab;

  // Mettre à jour les boutons de navigation
  document.querySelectorAll('.nav-btn').forEach(b => {
    b.classList.toggle('active', b.dataset.tab === tab);
  });

  // Afficher le bon panneau
  document.querySelectorAll('.tab-pane').forEach(p => {
    p.classList.toggle('active', p.id === `tab-${tab}`);
  });

  // Charger les données selon l'onglet
  if (tab === 'messages')   loadConversations();
  if (tab === 'contacts')   loadContacts();
  if (tab === 'groups')     loadGroups();
  if (tab === 'settings')   renderSettings();
}

// ─── POLLING TEMPS RÉEL (15s) ────────────────────────────────────────────────
function startPolling() {
  clearInterval(State.pollTimer);
  State.pollTimer = setInterval(() => {
    if (State.currentTab === 'messages') loadConversations(true);
    if (State.activeConvId)             loadActiveConvMessages(true);
  }, 15000);
}

// ─── MESSAGES — LISTE DES CONVERSATIONS (MessagesListPage V3) ─────────────────
// GET /api/messages → liste des conversations triées newest-first
async function loadConversations(silent = false) {
  if (!silent) {
    document.getElementById('conv-list').innerHTML =
      `<div class="loading-state"><div class="spinner"></div><p>Chargement des messages...</p></div>`;
  }

  const data = await API.get('/api/messages');

  if (!data) {
    if (!silent) {
      document.getElementById('conv-list').innerHTML =
        `<div class="empty-state">
          <div class="empty-icon">⚠️</div>
          <p>Impossible de charger les messages</p>
          <button class="btn-primary" onclick="loadConversations()">Réessayer</button>
        </div>`;
    }
    return;
  }

  // Normaliser : le backend peut retourner un tableau ou { conversations: [] }
  const rawList = Array.isArray(data) ? data : (data.conversations || data.messages || []);

  // Trier newest-first
  State.conversations = rawList.sort((a, b) => {
    const ta = a.lastMessageTime || a.updatedAt || a.createdAt || 0;
    const tb = b.lastMessageTime || b.updatedAt || b.createdAt || 0;
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
    const convId     = conv.id || conv.conversationId || conv._id;
    const isGroup    = conv.isGroup || false;
    const name       = isGroup ? (conv.groupName || conv.name || 'Groupe') : (conv.otherUserName || conv.contactName || 'Contact');
    const lastMsg    = conv.lastMessage || conv.lastMessageContent || '';
    const unread     = conv.unreadCount || 0;
    const timestamp  = conv.lastMessageTime || conv.updatedAt || conv.createdAt;
    const timeStr    = timestamp ? formatRelativeTime(timestamp) : '';
    const otherUid   = conv.otherUserId || conv.contactId || '';
    const initials   = getInitials(name);
    const avatarBg   = isGroup ? '#1a3a5c' : '#1a4a3a';
    const avatarTxt  = isGroup ? '👥' : initials;

    return `
      <div class="conv-item ${unread > 0 ? 'conv-unread' : ''}"
           onclick="openConversation('${escHtml(convId)}', '${escHtml(otherUid)}', '${escHtml(name)}', ${isGroup})">
        <div class="conv-avatar" style="background:${avatarBg}">${isGroup ? '<span>👥</span>' : `<span>${initials}</span>`}</div>
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

// ─── CONVERSATION SCREEN (ConversationScreen V3) ──────────────────────────────
// conversationId = uid1-uid2 (trié) pour privé, groupId pour groupe
// contactId = otherUserId pour POST /api/messages/send (receiverId)
function openConversation(conversationId, contactId, contactName, isGroup = false) {
  State.activeConvId   = conversationId;
  State.activeConvMsgs = [];
  State.activeConvInfo = { conversationId, contactId, contactName, isGroup };

  // Marquer comme lu dans la liste
  const conv = State.conversations.find(c => (c.id || c.conversationId || c._id) === conversationId);
  if (conv) conv.unreadCount = 0;

  // Afficher l'écran conversation
  const screen = document.getElementById('screen-conversation');
  if (!screen) return;

  document.getElementById('conv-screen-name').textContent  = contactName;
  document.getElementById('conv-screen-back').onclick = closeConversation;
  document.getElementById('conv-msg-input').value = '';

  showScreen('screen-conversation');
  loadActiveConvMessages();
}

async function loadActiveConvMessages(silent = false) {
  if (!State.activeConvId) return;
  const convId = State.activeConvId;

  if (!silent) {
    document.getElementById('conv-messages').innerHTML =
      `<div class="loading-state"><div class="spinner"></div></div>`;
  }

  // GET /api/messages/:conversationId
  const data = await API.get(`/api/messages/${convId}`);
  if (!data || State.activeConvId !== convId) return; // navigation changed

  const rawMsgs = Array.isArray(data) ? data : (data.messages || data.data || []);
  const currentUserId = State.user?.id || State.user?._id || '';

  State.activeConvMsgs = rawMsgs.map(m => ({
    ...m,
    isMe: (m.senderId || m.from || m.userId) === currentUserId,
    content: m.content || m.text || m.message || m.body || '',
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
    container.innerHTML = State.activeConvMsgs.map(m => `
      <div class="msg-bubble ${m.isMe ? 'msg-me' : 'msg-them'}">
        <div class="msg-content">${escHtml(m.content)}</div>
        <div class="msg-time">${formatTime(m.timestamp)}</div>
      </div>`).join('');
  }

  // Scroll to bottom
  container.scrollTop = container.scrollHeight;
}

async function sendMessage() {
  const input = document.getElementById('conv-msg-input');
  const text  = input.value.trim();
  if (!text || !State.activeConvInfo) return;

  const { conversationId, contactId, isGroup } = State.activeConvInfo;
  input.value = '';

  // Affichage optimiste
  const optimisticMsg = {
    isMe: true,
    content: text,
    timestamp: new Date().toISOString(),
    _optimistic: true,
  };
  State.activeConvMsgs.push(optimisticMsg);
  renderMessages();

  let res;
  if (isGroup) {
    // POST /groups/:groupId/messages
    res = await API.post(`/groups/${contactId}/messages`, { content: text });
  } else {
    // POST /api/messages/send  { receiverId, content }
    res = await API.post('/api/messages/send', {
      receiverId: contactId,
      content:    text,
    });
  }

  if (res && res.ok) {
    // Mettre à jour la liste des conversations
    const conv = State.conversations.find(c => (c.id || c.conversationId || c._id) === conversationId);
    if (conv) {
      conv.lastMessage = text;
      conv.lastMessageTime = new Date().toISOString();
    }
    // Recharger les messages en arrière-plan
    setTimeout(() => loadActiveConvMessages(true), 500);
  } else {
    // Retirer le message optimiste en cas d'erreur
    State.activeConvMsgs = State.activeConvMsgs.filter(m => !m._optimistic);
    renderMessages();
    showToast('Échec de l\'envoi. Réessayez.');
  }
}

function closeConversation() {
  State.activeConvId   = null;
  State.activeConvInfo = null;
  State.activeConvMsgs = [];
  showScreen('screen-dashboard');
  if (State.currentTab === 'messages') renderConversationList();
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
        <p>Ajoutez votre premier contact.</p>
      </div>`;
    return;
  }

  list.innerHTML = contacts.map(c => {
    const name = c.name || c.displayName || c.phone || 'Contact';
    const phone = c.phone || c.phoneNumber || '';
    const uid   = c.userId || c.registeredUserId || '';
    return `
      <div class="contact-item" onclick="openContactConversation('${escHtml(uid || phone)}', '${escHtml(name)}')">
        <div class="contact-avatar">${getInitials(name)}</div>
        <div class="contact-info">
          <div class="contact-name">${escHtml(name)}</div>
          <div class="contact-phone">${escHtml(phone)}</div>
        </div>
        <div class="contact-actions">
          ${uid ? '<span class="badge-registered">OmniSMS</span>' : ''}
          <button class="btn-icon" onclick="event.stopPropagation();confirmDeleteContact('${escHtml(phone)}','${escHtml(name)}')" title="Supprimer">🗑️</button>
        </div>
      </div>`;
  }).join('');
}

// Ouvrir une conversation depuis un contact (V3 : calcul du conversationId)
function openContactConversation(otherUserId, contactName) {
  if (!otherUserId || otherUserId === 'null' || otherUserId === 'undefined') {
    showToast('Contact non enregistré sur OmniSMS');
    return;
  }
  const myId = State.user?.id || State.user?._id || '';
  // conversationId = [uid1, uid2].sort().join('-')  — même logique que le backend
  const parts = [myId, otherUserId].sort();
  const conversationId = parts.join('-');
  openConversation(conversationId, otherUserId, contactName, false);
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
  const res = await API.post('/api/contacts', { name, phone });
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

// ─── CONTACT PICKER API ───────────────────────────────────────────────────────
async function importWithContactPicker() {
  if (!('contacts' in navigator && 'ContactsManager' in window)) {
    showToast('Contact Picker non supporté — utilisez l\'import VCF');
    return;
  }
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
    if (e.name !== 'AbortError') showToast('Erreur Contact Picker');
  }
}

// ─── VCF IMPORT ───────────────────────────────────────────────────────────────
function parseVCF(text) {
  const contacts = [];
  // Unfold (RFC 6350 — lignes qui commencent par espace/tab)
  const unfolded = text.replace(/\r\n[ \t]/g, '').replace(/\r\n/g, '\n');
  const vcards   = unfolded.split(/BEGIN:VCARD/i).slice(1);

  for (const card of vcards) {
    let name  = '';
    let phone = '';
    const lines = card.split('\n');
    for (const line of lines) {
      const l = line.trim();
      if (!l || l.toUpperCase() === 'END:VCARD') continue;
      // FN:Nom Prénom
      const fnMatch = l.match(/^FN(?:;[^:]*)?:(.*)/i);
      if (fnMatch) { name = fnMatch[1].trim().replace(/\\,/g, ','); continue; }
      // N:Nom;Prénom;;;
      const nMatch = l.match(/^N(?:;[^:]*)?:(.*)/i);
      if (nMatch && !name) {
        const parts = nMatch[1].split(';');
        const last  = (parts[0] || '').trim();
        const first = (parts[1] || '').trim();
        name = [first, last].filter(Boolean).join(' ');
        continue;
      }
      // TEL:+33600000000
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
  let added = 0;
  for (const c of contacts) {
    const res = await API.post('/api/contacts', { name: c.name, phone: c.phone });
    if (res.ok) added++;
  }
  showToast(`${added} contact(s) synchronisé(s)`);
  loadContacts();
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

  list.innerHTML = State.groups.map(g => {
    const gid  = g.id || g._id;
    const name = g.name || 'Groupe';
    const members = g.members?.length || g.memberCount || 0;
    return `
      <div class="conv-item" onclick="openGroupConversation('${escHtml(gid)}', '${escHtml(name)}')">
        <div class="conv-avatar" style="background:#1a3a5c"><span>👥</span></div>
        <div class="conv-content">
          <div class="conv-header">
            <span class="conv-name">${escHtml(name)}</span>
          </div>
          <div class="conv-footer">
            <span class="conv-last-msg">${members} membre(s)${g.description ? ' · ' + escHtml(g.description) : ''}</span>
          </div>
        </div>
      </div>`;
  }).join('');
}

// Ouvrir conversation groupe (V3 : conversationId = groupId)
function openGroupConversation(groupId, groupName) {
  openConversation(groupId, groupId, groupName, true);
}

async function createGroup(name, description) {
  if (!name.trim()) { showToast('Nom du groupe requis'); return; }

  // Récupérer les membres sélectionnés
  const checked = document.querySelectorAll('#group-member-list input[type=checkbox]:checked');
  const memberIds = Array.from(checked).map(c => c.value);
  if (memberIds.length === 0) { showToast('Sélectionnez au moins un membre'); return; }

  setLoading('create-group-btn', true, 'Créer');
  const res = await API.post('/groups', {
    name:        name.trim(),
    description: description.trim(),
    members:     memberIds,
  });
  setLoading('create-group-btn', false, 'Créer');

  if (res.ok) {
    closeModal('modal-create-group');
    showToast('Groupe créé !');
    const group = res.data.group || res.data;
    const gid   = group?.id || group?._id;
    const gname = group?.name || name;
    await loadGroups();

    // V3 : ouvrir immédiatement la conversation groupe
    if (gid) openGroupConversation(gid, gname);
  } else {
    showToast(res.data.message || 'Erreur lors de la création');
  }
}

function openCreateGroupModal() {
  // Peupler la liste des membres avec les contacts enregistrés sur OmniSMS
  const registeredContacts = State.contacts.filter(c => c.userId || c.registeredUserId);
  const container = document.getElementById('group-member-list');
  if (container) {
    if (registeredContacts.length === 0) {
      container.innerHTML = '<p class="text-muted">Aucun contact enregistré sur OmniSMS</p>';
    } else {
      container.innerHTML = registeredContacts.map(c => {
        const uid  = c.userId || c.registeredUserId;
        const name = c.name || c.displayName || c.phone;
        return `
          <label class="member-checkbox">
            <input type="checkbox" value="${escHtml(uid)}">
            <span>${escHtml(name)}</span>
          </label>`;
      }).join('');
    }
  }
  openModal('modal-create-group');
}

// ─── PARAMÈTRES ───────────────────────────────────────────────────────────────
function renderSettings() {
  const name  = State.user?.name  || '';
  const email = State.user?.email || '';
  const phone = State.user?.phone || '';

  const el = document.getElementById('settings-content');
  if (!el) return;
  el.innerHTML = `
    <div class="settings-card">
      <div class="settings-avatar">${getInitials(name || email)}</div>
      <h3>${escHtml(name || email)}</h3>
      <p class="text-muted">${escHtml(email)}</p>
      ${phone ? `<p class="text-muted">${escHtml(phone)}</p>` : ''}
    </div>
    <div class="settings-section">
      <h4>Compte</h4>
      <div class="settings-row" onclick="handleSubscription()">
        <span>💎 Abonnement Premium</span>
        <span class="settings-arrow">›</span>
      </div>
      <div class="settings-row" onclick="logout()">
        <span>🚪 Déconnexion</span>
        <span class="settings-arrow">›</span>
      </div>
    </div>
    <div class="settings-section">
      <h4>Application</h4>
      <div class="settings-row">
        <span>📱 Version</span>
        <span class="text-muted">3.0.0</span>
      </div>
    </div>`;

  loadPremiumStatus(State.user?.id || State.user?._id);
}

async function loadPremiumStatus(userId) {
  if (!userId) return;
  const data = await API.get(`/api/payment/user-status?userId=${userId}`);
  if (data?.isPremium) {
    showToast('Statut : Premium ✨');
  }
}

async function handleSubscription() {
  setLoading('subscription-btn', true, 'Chargement...');
  const res = await API.post('/api/payment/leekpay', {
    userId:      State.user?.id || State.user?._id,
    userEmail:   State.user?.email,
    amount:      5,
    currency:    'EUR',
    description: 'Abonnement OmniSMS Premium',
    returnUrl:   window.location.href,
  });
  setLoading('subscription-btn', false, "S'abonner au Premium");
  if (res.ok && res.data.paymentUrl) {
    window.location.href = res.data.paymentUrl;
  } else {
    showToast(res.data?.message || 'Erreur lors du paiement');
  }
}

// ─── MODALS ───────────────────────────────────────────────────────────────────
function openModal(id)  {
  const m = document.getElementById(id);
  if (m) { m.style.display = 'flex'; m.classList.add('active'); }
}
function closeModal(id) {
  const m = document.getElementById(id);
  if (m) { m.style.display = 'none'; m.classList.remove('active'); }
}

// Fermer modal en cliquant sur le fond
document.addEventListener('click', e => {
  if (e.target.classList.contains('modal')) closeModal(e.target.id);
});

// ─── UTILS ────────────────────────────────────────────────────────────────────
function escHtml(s) {
  if (s == null) return '';
  return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

function getInitials(name) {
  if (!name) return '?';
  const parts = name.trim().split(/\s+/);
  if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
  return name[0].toUpperCase();
}

function formatTime(ts) {
  if (!ts) return '';
  const d = new Date(ts);
  if (isNaN(d)) return '';
  return d.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
}

function formatRelativeTime(ts) {
  if (!ts) return '';
  const d   = new Date(ts);
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
  btn.disabled   = loading;
  btn.textContent = loading ? 'Chargement...' : label;
}

function showToast(msg, duration = 3000) {
  const t = document.getElementById('toast');
  if (!t) return;
  t.textContent  = msg;
  t.style.opacity = '1';
  t.style.display = 'block';
  clearTimeout(t._timer);
  t._timer = setTimeout(() => { t.style.opacity = '0'; setTimeout(() => t.style.display = 'none', 300); }, duration);
}

// ─── INIT ─────────────────────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
  // Enregistrement du Service Worker
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('/sw.js').catch(() => {});
  }

  // Restaurer session
  if (State.token && State.user) {
    initDashboard();
  } else {
    showScreen('screen-login');
  }

  // Gestion splash
  setTimeout(() => {
    if (document.getElementById('screen-splash')?.classList.contains('active')) {
      showScreen(State.token && State.user ? 'screen-dashboard' : 'screen-login');
    }
  }, 1200);
});
