# BUGS CONNUS — NOXA (ESX Legacy)

> Fichier lu par chaque agent au démarrage de session.
> Corriger le bug → supprimer la ligne.
> Fichier vide = aucun bug déclaré joueur (l'agent QA cherche toujours de son côté).

---

## 🔴 CRITIQUE

### [BUG-13] Panels NUI — overlay noir permanent (NUI pas masquée à la fermeture)
- **Symptôme** : un fond noir/sombre des panels reste affiché par-dessus le jeu en permanence (visible même panel "fermé"). Problème UI FiveM connu — PAS un souci de CSS background.
- **Cause** : les panels noxa_* (anticheat, gestion, phone, inventaire) utilisent le format auto-rendu « Claude Design `__bundler` » : le fichier index.html contient un loader (`__bundler_thumbnail` + "Unpacking...") qui REMPLACE tout le document par la vraie app React (`<html data-theme="dark">`, fond opaque #0b0b0d/#0f0f12). Or un `ui_page` FiveM est TOUJOURS rendu. `SetNuiFocus(false,false)` à la fermeture retire seulement la souris/clavier, **ne cache PAS la page**. L'app React swappée n'écoute pas le message `close` pour se masquer → l'UI opaque sombre reste dessinée = overlay noir permanent. Classique « NUI not hidden on close ».
- **Fix (NE PAS toucher au layout/design figé)** :
  1. Masquer réellement la NUI quand fermée. Script compagnon (bridge.js / nui.js dans files{}) qui SURVIT au swap du __bundler (attacher sur window, ou MutationObserver, ou ré-appliquer après le replace) et : racine `display:none` par défaut ; sur message window action 'open'/'noxaData' → afficher ; action 'close' → `display:none`. Toggle sur document.documentElement ou un wrapper plein écran, JAMAIS sur la carte du design.
  2. Défensif : `html,body{ background:transparent !important; }` (pour qu'un rendu bref laisse voir le jeu) — mais le fix PRINCIPAL est le display:none-à-la-fermeture.
  3. noxa_phone n'a pas de bridge.js → en ajouter un.
  - Le client.lua envoie déjà action 'open'/'close' : il manque juste le masquage côté page.
- **Fichiers** : `resources/noxa_anticheat|noxa_gestion|noxa_phone|noxa_inventaire/html/` (bridge) — client.lua OK.

## 🟡 MINEUR
_(aucun)_
