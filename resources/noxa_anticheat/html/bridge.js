/* =====================================================================
 *  NOXA FA — Panel Anti-Cheat · bridge NUI -> React
 * ---------------------------------------------------------------------
 *  Le panel React (bundle figé) lit `window.DATA` et n'écoute pas les
 *  messages de données. Ce pont :
 *    1. survit au remplacement du document par le loader (listeners sur
 *       window, qui n'est jamais remplacé) ;
 *    2. recoit les données live (SendNUIMessage action 'noxaData') et les
 *       fusionne dans window.DATA SANS toucher au HTML/CSS ;
 *    3. force un re-render propre en capturant le root React (patch non
 *       intrusif de ReactDOM.createRoot) — repli : re-render naturel.
 * ===================================================================== */
(function () {
  'use strict';

  var latest = null;          // dernier payload recu (format window.DATA)
  var capturedRoot = null;    // root React capturé pour forcer le re-render

  /* ---- helpers temps-réel (remplacent ceux figés du mock) ----------- */
  function toMs(d) { return (d instanceof Date) ? d.getTime() : (typeof d === 'number' ? d : Date.parse(d)); }

  function ago(d) {
    var s = Math.round((Date.now() - toMs(d)) / 1000);
    if (s < 0) s = 0;
    if (s < 60) return 'il y a ' + s + 's';
    var m = Math.round(s / 60);
    if (m < 60) return 'il y a ' + m + ' min';
    var h = Math.round(m / 60);
    if (h < 24) return 'il y a ' + h + ' h';
    return 'il y a ' + Math.round(h / 24) + ' j';
  }

  function fmtTime(d) {
    var x = (d instanceof Date) ? d : new Date(toMs(d));
    var p = function (n) { return n.toString().padStart(2, '0'); };
    return p(x.getHours()) + ':' + p(x.getMinutes()) + ':' + p(x.getSeconds());
  }

  /* ---- fusion des données live dans window.DATA --------------------- */
  function applyData() {
    if (!latest || !window.DATA) return false;
    var D = window.DATA;
    var keys = ['serverName', 'maxSlots', 'players', 'detections', 'bans',
                'logs', 'staff', 'watchlist', 'stats'];
    for (var i = 0; i < keys.length; i++) {
      if (latest[keys[i]] !== undefined && latest[keys[i]] !== null) {
        D[keys[i]] = latest[keys[i]];
      }
    }
    // helpers temps-réel + horloge de référence
    D.ago = ago;
    D.fmtTime = fmtTime;
    D.now = new Date();
    return true;
  }

  /* ---- re-render React (capture du root, repli naturel) ------------- */
  function forceRender() {
    try {
      if (capturedRoot && window.App && window.React) {
        capturedRoot.render(window.React.createElement(window.App));
        return true;
      }
    } catch (e) { /* repli : re-render naturel (horloge 30s / navigation) */ }
    return false;
  }

  // Patch non intrusif. Le bundle est en UMD à mutation :
  //   factory(global.ReactDOM = {}, global.React)
  // -> window.ReactDOM recoit d'abord un objet VIDE, puis createRoot lui est
  // ajouté par affectation (exports.createRoot = ...). On piège donc la
  // propriété createRoot sur l'objet pour capturer le root créé par le bundle.
  function wrapCreateRoot(fn) {
    return function (container, opts) {
      var root = fn(container, opts);
      capturedRoot = root;
      return root;
    };
  }
  function trapCreateRoot(obj) {
    if (!obj || typeof obj !== 'object') return;
    try { Object.defineProperty(obj, '__noxaPatched', { value: true, enumerable: false }); }
    catch (e) { return; }
    var slot = (typeof obj.createRoot === 'function') ? wrapCreateRoot(obj.createRoot) : obj.createRoot;
    try {
      Object.defineProperty(obj, 'createRoot', {
        configurable: true, enumerable: true,
        get: function () { return slot; },
        set: function (v) { slot = (typeof v === 'function') ? wrapCreateRoot(v) : v; }
      });
    } catch (e) { /* repli : re-render naturel */ }
  }
  try {
    var _RD;
    Object.defineProperty(window, 'ReactDOM', {
      configurable: true,
      get: function () { return _RD; },
      set: function (v) { _RD = v; if (v && !v.__noxaPatched) trapCreateRoot(v); }
    });
  } catch (e) { /* environnement non patchable : on garde le repli naturel */ }

  /* ---- réception des messages NUI ----------------------------------- */
  window.addEventListener('message', function (e) {
    var d = e && e.data;
    if (!d || d.action !== 'noxaData' || !d.data) return;
    latest = d.data;
    if (applyData()) forceRender();
  });

  // window.DATA peut arriver après le 1er payload : on réessaie un court
  // instant jusqu'à ce que le mock soit en place, puis on applique le live.
  var tries = 0;
  var iv = setInterval(function () {
    tries++;
    if (window.DATA && latest) {
      if (applyData()) forceRender();
    }
    if (window.DATA && capturedRoot || tries > 100) clearInterval(iv);
  }, 100);
})();
