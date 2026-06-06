
/* ============================================================
 * NOXA — Fix overlay noir (BUG-13)
 * ------------------------------------------------------------
 * Probleme connu FiveM : un ui_page est TOUJOURS rendu ; SetNuiFocus(false)
 * ne cache pas la page. Le panel (fond opaque sombre) reste donc dessine en
 * permanence par-dessus le jeu, et on ne voit pas le jeu derriere quand il est
 * ouvert. On corrige SANS toucher au design fige :
 *   - masquage reel du <body> a la fermeture (display:none) ;
 *   - transparence html/body + neutralisation de tout backdrop plein ecran
 *     (>=92% du viewport) -> on voit le JEU derriere, la carte (plus petite)
 *     garde son fond.
 * Pose sur window + poller : survit au remplacement du document par le bundler.
 * ============================================================ */
(function () {
  var visible = false;

  function applyVisibility() {
    var b = document.body;
    if (b) b.style.display = visible ? '' : 'none';
  }

  function clearBackdrops() {
    var de = document.documentElement;
    if (de) de.style.background = 'transparent';
    var b = document.body;
    if (!b) return;
    b.style.background = 'transparent';
    var vw = window.innerWidth, vh = window.innerHeight;
    var els = b.getElementsByTagName('*');
    for (var i = 0; i < els.length; i++) {
      var el = els[i];
      var r = el.getBoundingClientRect();
      if (r.width >= vw * 0.92 && r.height >= vh * 0.92) {
        var bg = window.getComputedStyle(el).backgroundColor || '';
        if (bg && bg !== 'transparent' && bg.indexOf('rgba(0, 0, 0, 0)') === -1) {
          el.style.background = 'rgba(6,8,11,.45)';      // scrim leger
          el.style.backdropFilter = 'blur(8px)';
          el.style.webkitBackdropFilter = 'blur(8px)';
        }
      }
    }
  }

  window.addEventListener('message', function (ev) {
    var d = (ev && ev.data) || {};
    if (d.action === 'open') { visible = true; applyVisibility(); }
    else if (d.action === 'close') { visible = false; applyVisibility(); }
  });

  applyVisibility(); // masque l'ecran de chargement "Unpacking..." du bundler par defaut
  setInterval(function () {
    clearBackdrops();
    applyVisibility();
  }, 80);
})();
