# Noxa — Base FiveM RP sur ESX Legacy

Base RP construite sur **ESX Legacy officiel** (stable, éprouvé), enrichie par des
panels NUI premium (designs Claude Design) et développée quotidiennement par des agents.

## Stack
- **ESX Legacy** (esx_core officiel) — framework de référence, tous scripts ESX compatibles
- **oxmysql** — base de données
- **menuv** (ThymonA) — système de menus unifié (thème default)
- **Panels NUI Noxa** (visuels exacts, ne pas modifier le HTML) :
  - `noxa_anticheat` — panel anti-cheat tablette N&B (F6)
  - `noxa_gestion` — panel gestion serveur (F9, superadmin)
  - `noxa_phone` — téléphone (F1)
  - `noxa_inventaire` — inventaire (I)
- **`noxa_admin`** — menu admin ultra complet **menuv** (F10) + **/report** joueur→staff + **prise de service** (/duty)

## Installation
1. Importer **`install.sql`** (racine) dans ta base MySQL `noxa` (phpMyAdmin) — **fichier unique** : ESX complet + toutes les tables custom Noxa (`noxa_reports`, `noxa_admin_logs`, `noxa_warns`, `noxa_bans`, phone, anti-cheat...). Idempotent (réimport sans risque).
2. Ouvrir `server.cfg` — remplir `sv_licenseKey` + `mysql_connection_string`
3. Placer le dossier `resources/` dans ton serveur FiveM
4. Ajouter `exec server.cfg` dans ton serveur, ou utiliser ce server.cfg
5. Démarrer

## Menu Admin (`noxa_admin`)
- **Accès staff** : groupes ESX `mod < admin < superadmin`, ou ACE `noxa.admin`. Grade revérifié server-side à **chaque** action.
- **F10** : menu menuv (Joueurs · Moi/Staff · Téléportation · Véhicules · Économie · Jobs · Sanctions · Annonces · Météo & Temps · Reports · Panels NUI).
- **/duty** : prise de service on/off. En service → réception des `/report` en live, staff chat, spectate/noclip.
- **/report `<message>`** : signalement joueur → notif live à tout le staff en service (anti-spam 30 s). Sous-menu Reports : TP, spectate, claim, répondre, clôturer.
- Actions sensibles (set argent, ban permanent, météo/heure, annonces) = **admin/superadmin** uniquement.
- Toute action sensible journalisée dans `noxa_admin_logs` (+ console).

## Inventaire (`noxa_inventaire`)
- **Visuel figé** : `html/index.html` (layout) **non modifié**. La liaison ESX passe par un
  pont (`html/bridge.js`) qui réutilise le moteur du layout (`inv` / `renderAll` / `itemMarkup`)
  et injecte les données réelles + les **images** sans toucher au markup/CSS.
- **Données live** : `client.lua` ouvre l'inventaire avec le snapshot serveur (items, quantités,
  poids, argent, capacité ESX réelle). Chaque slot affiche `images/<name>.png`.
- **Actions** (autorité serveur, **anti-dupe**) : Utiliser (`aUse`), Jeter (`aMove`),
  Fermer (`aClose`) + event `giveItem` (donner au joueur proche). Le serveur vérifie toujours
  la possession réelle avant de retirer.
- **Images** : `html/images/<name>.png` (nom = `name` exact de l'item dans la table ESX `items`).
  Icônes réelles via ox_inventory + icônes générées pour les items ESX manquants. Image
  absente → `images/placeholder.png` automatiquement.
  → **Ajouter un item** : déposer son PNG `html/images/<name>.png` (le `files{}` du fxmanifest
  charge `html/images/*.png`, aucune autre étape).

## Architecture
- ESX Legacy = base intacte. On construit PAR-DESSUS, on ne réinvente rien.
- Tout script ESX du marché se drop dans `resources/` et fonctionne direct.
- Les menus in-game custom passent par **menuv** (`@menuv/menuv.lua` → global `MenuV`).
- Les panels NUI = ressources indépendantes, visuels figés, données branchées par-dessus.

## État
| Système | État | Notes |
|---|---|---|
| ESX Legacy core | ✅ | Framework officiel |
| Panels NUI (visuels) | ✅ | anti-cheat, phone, gestion, inventaire, boutique |
| Liaison données panels | 🟡 | phone + inventaire liés au serveur ESX · autres en cours |
| Téléphone (F1) | ✅ | données live ESX/SQL, envoi SMS + tweets, ouverture/fermeture |
| Inventaire (I) | ✅ | inventaire ESX live + **images d'items** · utiliser / jeter / donner (anti-dupe serveur) |
| Menu admin (F10) | ✅ | menuv natif · reports · prise de service · sanctions · logs · grade vérifié server-side |
> ✅ Fonctionnel · 🟡 En cours · ❌ Non démarré
