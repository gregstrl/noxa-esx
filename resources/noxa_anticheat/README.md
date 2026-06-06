# NOXA FA — Panel Anti-Cheat (NUI)

Ressource FiveM. Panel staff anti-cheat en style tablette (noir & blanc, dark/light).

## Installation
1. Place le dossier `noxa_anticheat` dans `resources/` (ou `[local]/`).
   ⚠️ Le **nom du dossier doit rester `noxa_anticheat`** (il est utilisé par le pont NUI).
   Pour le renommer : change `RESOURCE_NAME` dans le HTML source **et** rebuild, ou garde ce nom.
2. Dans `server.cfg` :
   ```
   ensure noxa_anticheat
   add_ace group.admin noxa.anticheat allow
   add_principal identifier.fivem:XXXXXX group.admin
   ```
3. En jeu : commande `/anticheat` ou touche **F6** (modifiable dans Paramètres > Touches).

## Permissions
Seuls les joueurs avec l'ACE `noxa.anticheat` peuvent ouvrir le panel (vérifié côté serveur).

## Brancher tes vraies données
- Le panel affiche actuellement des **données de démonstration** (`html/index.html`, intégré).
- Les actions staff (Surveiller / Avertir / Expulser / Bannir / Résoudre) envoient un
  callback NUI `action` → événement serveur `noxa_ac:action` (voir `server.lua`).
  Remplace les `DropPlayer(...)` par ton système réel (ban DB, kick, watchlist…).
- Pour pousser des données live vers le panel, envoie un `SendNUIMessage(...)` côté client
  et écoute le `message` dans le code du panel.

## Fichiers
- `fxmanifest.lua` — manifeste
- `client.lua` — ouverture/fermeture, focus NUI, callbacks
- `server.lua` — permissions ACE + actions
- `html/index.html` — le panel (autonome, hors-ligne)
