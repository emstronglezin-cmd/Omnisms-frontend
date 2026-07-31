// OmniSMS PWA v3.2.1 — Session 7 — Stabilisation définitive
// Architecture Conversations-First (WhatsApp)
// Corrections : Redis MemoryStore, LeekPay officiel, payment_url, polling fallback

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
};

// ─── API ──────────────────────────────────────────────────────────────────────
const API = {
  headers(isFormData = false) {
    const h = { 'Accept': 'application/json' };
    if (!isFormData) h['Content-Type'] = 'application/json';
    if (State.token)  h['Authorization'] = `Bearer ${State.token}`;
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
      const data = await r.json().catch(() => ({}));
      if (r.status === 401) { logout(); return { ok: false, status: 401, data: { message: 'Session expirée' } }; }
      return { ok: r.ok, status: r.status, data };
    } catch(e) { return { ok: false, status: 0, data: { message: 'Erreur réseau — serveur en cours de démarrage...' } }; }
  },
  async postForm(path, formData) {
    try {
      const r = await fetch(API_BASE + path, {
        method: 'POST', headers: this.headers(true), body: formData
      });
      const data = await r.json().catch(() => ({}));
      if (r.status === 401) { logout(); return { ok: false, status: 401, data: {} }; }
      return { ok: r.ok, status: r.status, data };
    } catch(e) { return { ok: false, status: 0, data: { message: 'Erreur réseau' } }; }
  },
  async put(path, body) {
    try {
      const r = await fetch(API_BASE + path, {
        method: 'PUT', headers: this.headers(), body: JSON.stringify(body)
      });
      const data = await r.json().catch(() => ({}));
      return { ok: r.ok, status: r.status, data };
    } catch(e) { return { ok: false, status: 0, data: { message: 'Erreur réseau' } }; }
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
    initDashboard();
  } else {
    showError('login-error', res.data?.error || res.data?.message || 'Identifiants incorrects');
  }
}

async function register(name, phone, email, password) {
  setLoading('register-btn', true, "S'inscrire");
  const body = { name, phone, password };
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
    showError('register-error', res.data?.error || res.data?.message || 'Erreur lors de la création du compte');
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
  switchTab('messages');
  startPolling();
}

function renderUserInfo() {
  const name = State.user?.name || State.user?.email || 'Utilisateur';
  const el = document.getElementById('user-name');
  if (el) el.textContent = name;
  const av = document.getElementById('user-avatar');
  if (av) {
    if (State.user?.avatar) {
      av.innerHTML = `<img src="${escHtml(State.user.avatar)}" style="width:100%;height:100%;border-radius:50%;object-fit:cover">`;
    } else {
      av.textContent = getInitials(name);
    }
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
  if (tab === 'messages')   loadConversations();
  if (tab === 'contacts')   loadContacts();
  if (tab === 'groups')     loadGroups();
  if (tab === 'settings')   renderSettings();
}

// ─── POLLING TEMPS RÉEL (10s) ────────────────────────────────────────────────
function startPolling() {
  clearInterval(State.pollTimer);
  State.pollTimer = setInterval(() => {
    if (State.currentTab === 'messages') loadConversations(true);
    if (State.activeConvId)             loadActiveConvMessages(true);
  }, 10000);
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

    return `
      <div class="conv-item ${unread > 0 ? 'conv-unread' : ''}"
           onclick="openConversation('${escHtml(convId)}', '${escHtml(otherUid)}', '${escHtml(name)}', ${isGroup})">
        <div class="conv-avatar" style="background:${avatarBg}"><span>${isGroup ? '👥' : initials}</span></div>
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
  if (!State.activeConvId) return;
  const convId = State.activeConvId;

  if (!silent) {
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
  const audioUrl = m.audioUrl || m.url || '';
  const duration = m.durationFormatted || (m.duration ? `${Math.floor(m.duration/60)}:${String(Math.round(m.duration%60)).padStart(2,'0')}` : '');
  const msgId    = m.id || m._id || '';
  const transcript = m.transcription || '';
  const tStatus    = m.transcriptionStatus || 'pending';

  return `
    <div class="msg-bubble ${m.isMe ? 'msg-me' : 'msg-them'}" id="msg-${escHtml(msgId)}">
      <div class="msg-audio-player">
        <button class="audio-play-btn" onclick="toggleAudio('audio-${escHtml(msgId)}', this)" title="Lecture">▶</button>
        <audio id="audio-${escHtml(msgId)}" src="${escHtml(audioUrl)}" preload="metadata"
               onended="resetPlayBtn('audio-${escHtml(msgId)}')"></audio>
        <div class="audio-info">
          <span class="audio-duration">${escHtml(duration)}</span>
          <span class="audio-label">Message vocal</span>
        </div>
        ${msgId && tStatus !== 'done' ? `<button class="btn-transcribe" onclick="requestTranscription('${escHtml(msgId)}')" title="Transcrire">📝 Transcrire</button>` : ''}
      </div>
      ${transcript ? `<div class="msg-transcript">${escHtml(transcript)}</div>` : ''}
      <div class="msg-time">${formatTime(m.timestamp)}${m.isMe ? renderMsgStatus(m.status) : ''}</div>
    </div>`;
}

function toggleAudio(audioId, btn) {
  const audio = document.getElementById(audioId);
  if (!audio) return;
  if (audio.paused) {
    // Stopper tous les autres audios
    document.querySelectorAll('audio').forEach(a => { if (a !== audio) { a.pause(); a.currentTime = 0; } });
    document.querySelectorAll('.audio-play-btn').forEach(b => { if (b !== btn) b.textContent = '▶'; });
    audio.play().catch(() => {});
    btn.textContent = '⏸';
  } else {
    audio.pause();
    btn.textContent = '▶';
  }
}

function resetPlayBtn(audioId) {
  const audio = document.getElementById(audioId);
  if (audio) {
    audio.currentTime = 0;
    const btn = audio.previousElementSibling;
    if (btn) btn.textContent = '▶';
  }
}

async function requestTranscription(msgId) {
  if (!msgId) return;
  const btn = document.querySelector(`#msg-${msgId} .btn-transcribe`);
  if (btn) { btn.textContent = '⏳...'; btn.disabled = true; }

  // Try audio.v2 endpoint first, then transcription.v2
  let res = await API.post(`/api/audio/transcribe/${msgId}`, {});
  if (!res.ok) res = await API.post(`/api/transcription`, { audioId: msgId });

  if (res.ok) {
    showToast('Transcription lancée — résultat dans quelques secondes.');
    // Poll for result
    let attempts = 0;
    const poll = setInterval(async () => {
      attempts++;
      if (attempts > 20) { clearInterval(poll); return; }
      const statusData = await API.get(`/api/audio/${msgId}`);
      if (statusData?.transcriptionStatus === 'done' && statusData?.transcription) {
        clearInterval(poll);
        const el = document.querySelector(`#msg-${msgId} .msg-transcript`);
        if (el) {
          el.textContent = statusData.transcription;
        } else {
          const bubble = document.getElementById(`msg-${msgId}`);
          if (bubble) {
            const div = document.createElement('div');
            div.className = 'msg-transcript';
            div.textContent = statusData.transcription;
            bubble.insertBefore(div, bubble.querySelector('.msg-time'));
          }
        }
        if (btn) btn.style.display = 'none';
      }
    }, 3000);
  } else {
    showToast('Impossible de lancer la transcription.');
    if (btn) { btn.textContent = '📝 Transcrire'; btn.disabled = false; }
  }
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
    const conv = State.conversations.find(c => (c.id || c.conversationId || c._id) === conversationId);
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

  const { id: audioId, url: audioUrl, duration, durationFormatted } = uploadRes.data;

  // Envoyer comme message in-app
  const { contactId, isGroup, conversationId } = State.activeConvInfo;
  let res;
  if (isGroup) {
    res = await API.post(`/groups/${contactId}/messages`, {
      content: '', type: 'audio', audioUrl, duration,
    });
  } else {
    res = await API.post('/api/messages/send', {
      receiverId: contactId, content: '', type: 'audio', audioUrl, duration,
    });
  }

  if (res?.ok) {
    showToast('Message vocal envoyé !');
    setTimeout(() => loadActiveConvMessages(true), 500);
  } else {
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
    const isOmni = !!(c.isOnOmniSms || uid);
    const onclick = isOmni
      ? `openContactConversation('${escHtml(uid)}', '${escHtml(name)}')`
      : `showToast('${escHtml(name)} n\\'utilise pas OmniSMS — SMS envoyé automatiquement')`;
    return `
      <div class="contact-item ${isOmni ? '' : 'contact-sms-only'}" onclick="${onclick}">
        <div class="contact-avatar">${getInitials(name)}</div>
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
    showToast('Contact non enregistré sur OmniSMS');
    return;
  }
  const myId = State.user?.id || State.user?._id || '';
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

  list.innerHTML = State.groups.map(g => {
    const gid  = g.id || g._id;
    const name = g.name || 'Groupe';
    const members = g.members?.length || g.memberCount || 0;
    return `
      <div class="conv-item" onclick="openGroupConversation('${escHtml(gid)}', '${escHtml(name)}')">
        <div class="conv-avatar" style="background:#1a3a5c"><span>👥</span></div>
        <div class="conv-content">
          <div class="conv-header"><span class="conv-name">${escHtml(name)}</span></div>
          <div class="conv-footer">
            <span class="conv-last-msg">${members} membre(s)${g.description ? ' · ' + escHtml(g.description) : ''}</span>
          </div>
        </div>
      </div>`;
  }).join('');
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

// ─── PARAMÈTRES ───────────────────────────────────────────────────────────────
function renderSettings() {
  const name  = State.user?.name  || '';
  const email = State.user?.email || '';
  const phone = State.user?.phone || '';
  const avatar = State.user?.avatar || null;

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
      <p class="text-muted">${escHtml(email)}</p>
      ${phone ? `<p class="text-muted">${escHtml(phone)}</p>` : ''}
    </div>

    <div class="settings-section">
      <h4>Modifier le profil</h4>
      <div class="form-group">
        <label class="form-label">Nom</label>
        <input id="settings-name" type="text" class="form-input" value="${escHtml(name)}" placeholder="Votre nom">
      </div>
      <div class="form-group">
        <label class="form-label">Email</label>
        <input id="settings-email" type="email" class="form-input" value="${escHtml(email)}" placeholder="votre@email.com">
      </div>
      <div class="form-group">
        <label class="form-label">Téléphone</label>
        <input id="settings-phone" type="tel" class="form-input" value="${escHtml(phone)}" placeholder="+22670123456">
      </div>
      <div class="form-group">
        <label class="form-label">Nouveau mot de passe (laisser vide pour ne pas changer)</label>
        <input id="settings-password" type="password" class="form-input" placeholder="••••••••" minlength="8">
      </div>
      <button class="btn-primary" style="width:100%;margin-top:12px" onclick="saveProfile()">
        💾 Sauvegarder
      </button>
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
        <span class="text-muted">3.2.1</span>
      </div>
    </div>`;

  loadPremiumStatus(State.user?.id || State.user?._id);
}

async function saveProfile() {
  const name     = document.getElementById('settings-name')?.value?.trim();
  const email    = document.getElementById('settings-email')?.value?.trim();
  const phone    = document.getElementById('settings-phone')?.value?.trim();
  const password = document.getElementById('settings-password')?.value;

  const body = {};
  if (name)     body.name     = name;
  if (email)    body.email    = email;
  if (phone)    body.phone    = phone;
  if (password && password.length >= 8) body.password = password;

  if (Object.keys(body).length === 0) { showToast('Aucune modification'); return; }

  const res = await API.put('/api/me/profile', body);
  if (res.ok) {
    // Mettre à jour le state local
    if (name)  State.user.name  = name;
    if (email) State.user.email = email;
    if (phone) State.user.phone = phone;
    localStorage.setItem('user_data', JSON.stringify(State.user));
    renderUserInfo();
    showToast('Profil mis à jour ✓');
  } else {
    showToast(res.data?.error || 'Erreur lors de la sauvegarde');
  }
}

async function uploadAvatar(file) {
  if (!file) return;
  showToast('Upload de la photo...');
  const formData = new FormData();
  formData.append('avatar', file);
  const res = await API.postForm('/api/me/avatar', formData);
  if (res.ok && res.data.avatarUrl) {
    State.user.avatar = res.data.avatarUrl;
    localStorage.setItem('user_data', JSON.stringify(State.user));
    renderUserInfo();
    renderSettings();
    showToast('Photo de profil mise à jour ✓');
  } else {
    showToast(res.data?.error || 'Échec de l\'upload');
  }
}

async function loadPremiumStatus(userId) {
  if (!userId) return;
  const data = await API.get(`/api/payment/user-status?userId=${userId}`);
  if (data?.isSubscribed || data?.premium) {
    const el = document.getElementById('settings-content');
    if (el) {
      const premiumRow = el.querySelector('[onclick="handleSubscription()"]');
      if (premiumRow) premiumRow.innerHTML = '<span>💎 Abonnement Premium</span><span style="color:var(--accent);font-size:12px">ACTIF ✓</span>';
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
