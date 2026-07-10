/*
 * AuroraAuth — client-side account system for the static Aurora site.
 *
 * IMPORTANT SCOPE NOTE
 * This is a front-end-only flow: accounts live in the visitor's own
 * browser (localStorage), passwords are salted + hashed with WebCrypto
 * before storage, and sessions are local. It provides a complete,
 * polished sign-up / login / reset / dashboard experience, but it is
 * NOT server-enforced security — a static site has no server. For real
 * multi-device accounts, connect a backend (Supabase, Clerk, Auth.js…)
 * and swap the storage calls in this one file.
 */
(function () {
  'use strict';

  const USERS_KEY = 'aurora-users.v1';
  const SESSION_KEY = 'aurora-session';

  function storageOK() {
    try {
      localStorage.setItem('__aurora_probe__', '1');
      localStorage.removeItem('__aurora_probe__');
      return true;
    } catch { return false; }
  }

  function loadUsers() {
    try { return JSON.parse(localStorage.getItem(USERS_KEY) || '[]'); }
    catch { return []; }
  }
  function saveUsers(users) {
    localStorage.setItem(USERS_KEY, JSON.stringify(users));
  }

  async function hash(password, salt) {
    const data = new TextEncoder().encode(salt + ':' + password);
    const digest = await crypto.subtle.digest('SHA-256', data);
    return [...new Uint8Array(digest)].map(b => b.toString(16).padStart(2, '0')).join('');
  }

  const normEmail = e => String(e || '').trim().toLowerCase();
  const validEmail = e => /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(e);

  async function signup({ name, email, password }) {
    if (!storageOK()) throw new Error('This browser is blocking storage — accounts need it to work.');
    name = String(name || '').trim();
    email = normEmail(email);
    if (!name) throw new Error('Please enter your name.');
    if (!validEmail(email)) throw new Error('That email address doesn’t look right.');
    if ((password || '').length < 8) throw new Error('Password must be at least 8 characters.');
    const users = loadUsers();
    if (users.some(u => u.email === email)) throw new Error('An account with this email already exists — try logging in.');
    const salt = crypto.randomUUID();
    users.push({
      name, email, salt,
      hash: await hash(password, salt),
      createdAt: Date.now()
    });
    saveUsers(users);
    startSession({ name, email });
    return { name, email };
  }

  async function login(email, password) {
    if (!storageOK()) throw new Error('This browser is blocking storage — accounts need it to work.');
    email = normEmail(email);
    const user = loadUsers().find(u => u.email === email);
    if (!user) throw new Error('No account found for that email.');
    const attempt = await hash(password || '', user.salt);
    if (attempt !== user.hash) throw new Error('Incorrect password. You can reset it below.');
    startSession({ name: user.name, email: user.email });
    return { name: user.name, email: user.email };
  }

  function startSession(user) {
    localStorage.setItem(SESSION_KEY, JSON.stringify({ ...user, ts: Date.now() }));
  }

  function current() {
    try { return JSON.parse(localStorage.getItem(SESSION_KEY) || 'null'); }
    catch { return null; }
  }

  function logout() {
    try { localStorage.removeItem(SESSION_KEY); } catch {}
  }

  /** Redirect to login when signed out. Call at the top of protected pages. */
  function requireAuth(nextPage) {
    if (!storageOK()) return null; // nothing to protect without storage
    const session = current();
    if (!session) {
      location.replace('login.html?next=' + encodeURIComponent(nextPage || 'dashboard.html'));
      return null;
    }
    return session;
  }

  /*
   * Password reset. A static site can't send email, so the reset code is
   * shown on screen (in production this is where the email service call
   * goes). Codes are single-use and expire after 15 minutes.
   */
  function requestReset(email) {
    email = normEmail(email);
    const users = loadUsers();
    const user = users.find(u => u.email === email);
    if (!user) throw new Error('No account found for that email.');
    const code = String(Math.floor(100000 + Math.random() * 900000));
    user.resetCode = code;
    user.resetExpires = Date.now() + 15 * 60 * 1000;
    saveUsers(users);
    return code;
  }

  async function applyReset(email, code, newPassword) {
    email = normEmail(email);
    const users = loadUsers();
    const user = users.find(u => u.email === email);
    if (!user || !user.resetCode) throw new Error('Request a reset code first.');
    if (Date.now() > user.resetExpires) throw new Error('That code expired — request a new one.');
    if (String(code).trim() !== user.resetCode) throw new Error('That code doesn’t match.');
    if ((newPassword || '').length < 8) throw new Error('New password must be at least 8 characters.');
    user.salt = crypto.randomUUID();
    user.hash = await hash(newPassword, user.salt);
    delete user.resetCode;
    delete user.resetExpires;
    saveUsers(users);
    return true;
  }

  window.AuroraAuth = {
    signup, login, logout, current, requireAuth,
    requestReset, applyReset, storageOK
  };
})();
