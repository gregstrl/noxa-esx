/* ============================================================
 * NOXA FA — Panel Gestion Serveur · BRIDGE NUI <-> ESX
 * ------------------------------------------------------------
 * Le LAYOUT / VISUEL (template du bundle) est fige : on n'y touche pas.
 * Ce pont est charge AVANT le bundler ; il pose des hooks sur `window`
 * qui survivent au remplacement du DOM par le bundler. Il :
 *
 *   1. redirige les fetch du bundle (resource codee EN DUR a
 *      « noxa_manage ») vers la VRAIE ressource (GetParentResourceName) ;
 *   2. intercepte window.MDATA pour y injecter le snapshot ESX live
 *      (jobs / items / vehicules reels) sans toucher au layout ;
 *   3. remonte proprement l'app React si les donnees arrivent APRES
 *      le 1er rendu (les listes sont seedees une seule fois via
 *      useState — un remontage force le re-seed depuis MDATA) ;
 *   4. relaie les actions save/close vers le client.lua (autorite
 *      serveur : superadmin verifie cote serveur).
 * ============================================================ */
(function () {
  var RES = (function () {
    try { return GetParentResourceName(); } catch (e) {}
    return 'noxa_gestion';
  })();
  var BUNDLE_RES = 'noxa_manage'; // nom code en dur dans le bundle React
  var PREFIX = 'https://' + BUNDLE_RES + '/';

  var LIVE = null;       // dernier snapshot ESX recu du serveur
  var mockMDATA = null;  // valeur posee par le script « mock data » du bundle
  var rootInfo = null;   // { el, element, root } capture pour remontage
  var _ReactDOM;

  // --- 1. Redirection des fetch du bundle vers la vraie ressource ---
  var origFetch = window.fetch ? window.fetch.bind(window) : null;
  window.fetch = function (url, opts) {
    try {
      if (typeof url === 'string' && url.indexOf(PREFIX) === 0) {
        url = 'https://' + RES + '/' + url.slice(PREFIX.length);
      }
    } catch (e) {}
    return origFetch ? origFetch(url, opts) : Promise.reject(new Error('no fetch'));
  };

  // POST direct vers un RegisterNUICallback du client.lua.
  function nui(cb, body) {
    if (!origFetch) return Promise.resolve(null);
    return origFetch('https://' + RES + '/' + cb, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(body || {})
    }).then(function (r) { return r.json().catch(function () { return null; }); })
      .catch(function () { return null; });
  }

  // --- 2. Fusion mock + snapshot ESX live ---
  // On ne remplace QUE les cles fournies par le serveur (jobs/items/
  // vehicules/scalaires) ; le reste (itemCats, locTypes, locations,
  // jobIds...) garde les valeurs du bundle pour que l'editeur reste utilisable.
  function merged() {
    if (!mockMDATA) return LIVE;
    if (!LIVE) return mockMDATA;
    var out = {};
    for (var k in mockMDATA) out[k] = mockMDATA[k];
    for (var j in LIVE) { if (LIVE[j] != null) out[j] = LIVE[j]; }
    return out;
  }

  // Le bundle fait `window.MDATA = {...}` (mock) : on l'enregistre et on
  // renvoie la fusion live a la lecture (MApp lit window.MDATA au montage).
  Object.defineProperty(window, 'MDATA', {
    configurable: true,
    get: function () { return merged(); },
    set: function (v) { mockMDATA = v; }
  });

  // --- 3. Capture du root React pour remontage (re-seed des useState) ---
  // Enveloppe createRoot pour memoriser (container, element) du dernier
  // render. Subtilite UMD : react-dom fait `window.ReactDOM = {}` (objet
  // VIDE) PUIS `exports.createRoot = fn`. On gere donc les deux cas :
  //  - objet deja peuple (createRoot present)  -> enveloppe direct ;
  //  - objet vide a peupler                    -> setter sur createRoot.
  function wrapCreateRoot(fn) {
    return function (el, o) {
      var root = fn(el, o);
      var oRender = root.render.bind(root);
      root.render = function (element) {
        rootInfo = { el: el, element: element, root: root };
        return oRender(element);
      };
      return root;
    };
  }
  function hookReactDOM(v) {
    if (!v || typeof v !== 'object' || v.__noxaHook) return;
    v.__noxaHook = true;
    if (typeof v.createRoot === 'function') {
      v.createRoot = wrapCreateRoot(v.createRoot.bind(v));
    } else {
      var stored;
      try {
        Object.defineProperty(v, 'createRoot', {
          configurable: true,
          enumerable: true,
          get: function () { return stored; },
          set: function (fn) { stored = (typeof fn === 'function') ? wrapCreateRoot(fn) : fn; }
        });
      } catch (e) {}
    }
  }
  Object.defineProperty(window, 'ReactDOM', {
    configurable: true,
    get: function () { return _ReactDOM; },
    set: function (v) { _ReactDOM = v; hookReactDOM(v); }
  });

  // Remonte l'app : unmount + nouveau root => les useState reseedent
  // depuis window.MDATA (donc depuis le snapshot live fusionne).
  function remount() {
    if (!rootInfo || !_ReactDOM) return;
    var info = rootInfo;
    try {
      info.root.unmount();
      var nroot = _ReactDOM.createRoot(info.el); // re-capture via createRoot enveloppe
      nroot.render(info.element);
      // Le nouvel MApp re-seede visible=false (cache par defaut en FiveM) :
      // on lui redemande de s'afficher une fois ses effets (listener) montes.
      // gestionData n'est emis QUE panneau ouvert -> reshow sans risque.
      setTimeout(function () {
        try { window.postMessage({ action: 'show' }, '*'); } catch (e) {}
      }, 60);
    } catch (e) { console.error('[noxa-gestion] remount', e); }
  }

  // Applique un snapshot live (et remonte si l'app est deja affichee).
  function applyLive(data) {
    if (!data) return;
    LIVE = data;
    if (rootInfo) remount();
  }

  // --- 4. Reception live depuis client.lua ---
  window.addEventListener('message', function (ev) {
    var d = (ev && ev.data) || {};
    if (d.action === 'gestionData' && d.data) applyLive(d.data);
  });

  // Demande initiale du snapshot (course avec le montage : applyLive
  // remonte si besoin une fois les donnees recues).
  function pull() {
    nui('getData', {}).then(function (res) {
      if (res && res.data) applyLive(res.data);
    });
  }
  pull();
  document.addEventListener('DOMContentLoaded', pull);
})();
