/*
 * AuroraData — the single persistence seam for HTMLStudio.
 *
 * Phase 1 of the backend migration (see docs/BACKEND_MIGRATION_PLAN.md):
 * every read/write of app data goes through this module instead of touching
 * localStorage directly. Today it is a synchronous localStorage adapter, so
 * behaviour is byte-for-byte identical to before. Phase 2/3 will add a
 * 'remote' adapter (Supabase) selected by `mode` — at which point only this
 * file changes, and the rest of the app is already storage-agnostic.
 *
 * Scope note: the tiny pre-paint theme/guard reads inlined in each page's
 * <head> intentionally still touch localStorage directly — they must run
 * before any external script to avoid a flash of the wrong theme, so they
 * cannot depend on this module. Everything else routes through here.
 */
(function () {
  'use strict';

  var available = true;
  try {
    localStorage.setItem('__aurora_probe__', '1');
    localStorage.removeItem('__aurora_probe__');
  } catch (e) { available = false; }

  // The only adapter in Phase 1. Phase 2/3 adds a remote adapter with the
  // same shape and swaps it in based on `AuroraData.mode`.
  var localAdapter = {
    get: function (key) {
      if (!available) return null;
      try { return localStorage.getItem(key); } catch (e) { return null; }
    },
    set: function (key, val) {
      if (!available) return false;
      try { localStorage.setItem(key, val); return true; }
      catch (e) { available = false; return false; }
    },
    remove: function (key) {
      if (!available) return;
      try { localStorage.removeItem(key); } catch (e) {}
    }
  };

  window.AuroraData = {
    mode: 'local',          // 'local' | 'remote'  (remote arrives in Phase 2/3)
    available: available,
    adapter: localAdapter,

    // --- Raw string key/value ---
    get: function (key) { return this.adapter.get(key); },
    set: function (key, val) { return this.adapter.set(key, val); },
    remove: function (key) { this.adapter.remove(key); },

    // --- JSON convenience (used by the editor store and by auth.js) ---
    getJSON: function (key, fallback) {
      var raw = this.get(key);
      if (raw == null) return fallback;
      try { return JSON.parse(raw); } catch (e) { return fallback; }
    },
    setJSON: function (key, val) { return this.set(key, JSON.stringify(val)); }
  };
})();
