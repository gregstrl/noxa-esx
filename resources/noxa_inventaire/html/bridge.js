/* ============================================================
 * NOXA FA — Inventaire · BRIDGE NUI <-> ESX
 * ------------------------------------------------------------
 * Le LAYOUT (index.html / template) est fige : on n'y touche pas.
 * Ce pont :
 *   - ecoute les SendNUIMessage du client.lua (donnees ESX live) ;
 *   - injecte les items reels + leurs IMAGES dans la grille existante
 *     en reutilisant le moteur du layout (inv / renderAll / itemMarkup) ;
 *   - relaie les actions (utiliser / jeter / fermer) au serveur via
 *     RegisterNUICallback (autorite serveur => anti-dupe).
 *
 * Il s'execute au chargement de la page. Le bundler remplace ensuite
 * tout le document, mais nos ecouteurs sont poses sur `window` et notre
 * poller sur `setInterval` : ils survivent au remplacement du DOM.
 * ============================================================ */
(function () {
  var RES = (function () {
    try { return GetParentResourceName(); } catch (e) {}
    return 'noxa_inventaire';
  })();

  var installed = false;   // overrides du moteur layout poses ?
  var pending = null;      // dernier inventaire recu avant que la grille existe

  // --- POST vers un RegisterNUICallback du client.lua ---
  function nui(cb, body) {
    return fetch('https://' + RES + '/' + cb, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(body || {})
    }).catch(function () {});
  }

  function fmtMoney(n) {
    n = Math.floor(Number(n) || 0);
    return n.toLocaleString('fr-FR').replace(/ /g, ' ') + ' $';
  }

  // La grille est-elle rendue et le moteur du layout pret ?
  function ready() {
    return !!document.getElementById('gridL') &&
           typeof window.renderAll === 'function' &&
           typeof window.itemMarkup === 'function';
  }

  // Markup d'un slot avec IMAGE (remplace l'icone SVG du layout).
  // Reutilise exactement les memes classes CSS => visuel identique.
  function imgMarkup(it) {
    var top;
    if (it.value) top = '<span class="val">' + it.value + '</span>';
    else if (it.qty > 1) top = '<span></span><span class="qty">x' + it.qty + '</span>';
    else top = '<span></span>';
    var icon = '<img src="' + it.img + '" alt="" ' +
      'style="width:46%;height:46%;object-fit:contain;pointer-events:none" ' +
      "onerror=\"this.onerror=null;this.src='images/placeholder.png'\">";
    return '<div class="top">' + top + '</div>' +
           '<div class="itm">' + icon + '</div>' +
           '<div class="nm">' + (it.nm || '') + '</div>';
  }

  // Pose les overrides une seule fois, des que le layout est rendu.
  function install() {
    if (installed || !ready()) return;
    installed = true;

    // itemMarkup est une fonction globale (function declaration) : la
    // remplacer suffit, render() la rappelle par son nom. Les items qui
    // portent une image passent par imgMarkup, les autres (argent) gardent
    // le glyphe d'origine.
    var origMarkup = window.itemMarkup;
    window.itemMarkup = function (it) {
      if (it && it.img) return imgMarkup(it);
      return origMarkup(it);
    };

    wireButtons();
  }

  // Lit l'item actuellement selectionne via le DOM (decouple du layout).
  function selItem() {
    try {
      var el = document.querySelector('.slot.sel');
      if (!el) return null;
      return inv[el.dataset.side][+el.dataset.i] || null;
    } catch (e) { return null; }
  }

  function wireButtons() {
    var u = document.getElementById('aUse');
    var m = document.getElementById('aMove');
    var c = document.getElementById('aClose');
    if (u) u.onclick = function () {
      var it = selItem();
      if (!it || it.value || !it.name) return;
      nui('useItem', { name: it.name });
    };
    if (m) m.onclick = function () {
      var it = selItem();
      if (!it || it.value || !it.name) return;
      nui('dropItem', { name: it.name, count: 1 });
    };
    if (c) c.onclick = function () { nui('closeInv', {}); };
  }

  // Recalage precis des jauges de poids (capacite ESX reelle).
  function fixWeights(p) {
    var cap = p.maxWeight || 24;
    var tot = 0;
    (p.items || []).forEach(function (i) { tot += (i.weight || 0); });
    var bar = document.getElementById('w1');
    var kg = document.getElementById('kg1');
    if (bar) bar.style.width = Math.min(100, tot / cap * 100) + '%';
    if (kg) kg.textContent = (Math.round(tot * 10) / 10) + '/' + cap + ' kg';
  }

  // Ecrit l'inventaire ESX dans le moteur du layout puis re-rend.
  function applyNow(p) {
    try {
      // vide les deux cotes (mutation : inv est un const => on garde l'objet)
      for (var k in inv.L) delete inv.L[k];
      for (var r in inv.R) delete inv.R[r];

      var slot = 0;
      if (p.money != null) {
        inv.L[0] = { g: 'money', nm: 'Argent', value: fmtMoney(p.money), wt: 0 };
        slot = 1;
      }
      (p.items || []).forEach(function (it) {
        inv.L[slot] = {
          name: it.name,
          nm: it.label || it.name,
          qty: it.count,
          wt: it.weight || 0,
          img: 'images/' + it.name + '.png',
          g: 'money' // glyphe de secours si l'image manque ET orig() appele
        };
        slot++;
      });

      if (p.name) {
        var pn = document.getElementById('pname');
        if (pn) pn.textContent = p.name;
      }

      window.renderAll();
      fixWeights(p);
    } catch (e) {
      console.error('[noxa-inv] applyNow', e);
    }
  }

  function apply(p) {
    pending = p;
    install();
    if (installed && ready()) { pending = null; applyNow(p); }
  }

  // --- Reception des donnees live depuis client.lua ---
  window.addEventListener('message', function (ev) {
    var d = (ev && ev.data) || {};
    if (d.action === 'open' || d.action === 'setInventory') {
      var payload = d.inv || d.data;
      if (payload) apply(payload);
    }
  });

  // --- Poller : pose les overrides + applique l'inventaire en attente
  //     des que la grille du layout apparait (post-bundler). ---
  var timer = setInterval(function () {
    install();
    if (installed) {
      clearInterval(timer);
      if (pending) { var q = pending; pending = null; applyNow(q); }
    }
  }, 120);
})();
