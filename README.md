# Noxa — Base FiveM RP sur ESX Legacy

Base RP construite sur **ESX Legacy officiel** (stable, éprouvé), enrichie par des
panels NUI premium (designs Claude Design) et développée quotidiennement par des agents.

## Stack
- **ESX Legacy** (esx_core officiel) — framework de référence, tous scripts ESX compatibles
- **oxmysql** — base de données
- **menuv** (ThymonA) — système de menus unifié (thème default)
- **Panels NUI Noxa** (visuels exacts, ne pas modifier le HTML) :
  - `noxa_anticheat` — panel anti-cheat tablette N&B (F6)
  - `noxa_gestion` — panel gestion serveur (F9, superadmin) — éditeur de config branché live à ESX
  - `noxa_phone` — téléphone (F1)
  - `noxa_inventaire` — inventaire (I)
- **`noxa_admin`** — menu admin ultra complet **menuv** (F10) + **/report** joueur→staff + **prise de service** (/duty)
- **`noxa_vehicles`** — **véhicules** : concession (7 classes F→S), garages, fourrière, carburant (2$/%) — 100% ESX natif (`owned_vehicles`, `ESX.Game`)
- **`noxa_drugs`** — **drogues** : champs de culture, laboratoires (**menuv**), revendeurs marché noir (`black_money`) — 100% ESX natif (inventaire `xPlayer`)
- **`noxa_updater`** — **auto-update lié à GitHub** : commande console `noxa update` (sync base via oxmysql + migrations idempotentes + reload des ressources). Voir *Mettre à jour le serveur*.

## Installation (première fois)
1. **Cloner le repo dans le dossier de ton serveur** (recommandé — c'est ce qui rend
   les mises à jour automatiques possibles ensuite) :
   ```bash
   cd /chemin/vers/ton/serveur        # le dossier qui contient resources/, server.cfg
   git clone https://github.com/gregstrl/noxa-esx .
   ```
   > Le clone DOIT être à la racine du serveur pour que `update.sh` / `update.bat`
   > puissent faire le `git pull` au bon endroit.
2. Importer **`install.sql`** (racine) dans ta base MySQL `noxa` (phpMyAdmin) — **fichier unique** : ESX complet + toutes les tables custom Noxa (`noxa_reports`, `noxa_admin_logs`, `noxa_warns`, `noxa_bans`, `noxa_migrations`, phone, anti-cheat...). Idempotent (réimport sans risque).
3. Ouvrir `server.cfg` — remplir `sv_licenseKey` + `mysql_connection_string`.
   ⚠️ Garder **`multipleStatements=true`** dans la chaîne de connexion (requis par `noxa update`).
4. Vérifier que `resources/` est en place (livré par le clone).
5. Ajouter `exec server.cfg`, ou utiliser ce server.cfg. Démarrer.

## Mettre à jour le serveur
Après la première install, **plus jamais besoin de re-télécharger ni de ré-importer la base à la main**. Une seule commande synchronise tout avec GitHub.

**Le principe (contrainte FiveM)** : le Lua serveur est *sandboxé* — `os.execute` est bloqué, donc `git` ne peut pas tourner depuis une ressource. On sépare donc en 2 temps :

1. **`update.sh`** (Linux/macOS) ou **`update.bat`** (Windows), lancé **à la racine du serveur** :
   ```bash
   ./update.sh        # Windows : update.bat
   ```
   - `git fetch origin main && git reset --hard origin/main` → récupère la dernière version (ressources **ajoutées / modifiées / supprimées**, install.sql, migrations) ;
   - calcule le **diff des ressources** dans `resources/noxa_updater/sync/state.txt` ;
   - **synchronise** `install.sql` + `sql/migrations/` dans `resources/noxa_updater/sql/` (le seul emplacement que le serveur a le droit de lire, sandbox oblige).
2. **Dans la console serveur** (txAdmin / RCON / live console) :
   ```
   noxa update
   ```
   - **Base** : (re)joue `install.sql` si besoin (idempotent, via une *baseline*) puis applique **chaque migration une seule fois** (suivi dans la table `noxa_migrations`), le tout via **oxmysql** ;
   - **Ressources** : `refresh` → **ensure/restart** les ressources changées, **stop** celles retirées du repo ;
   - **Rapport console** clair : *Ajoutées / Mises à jour / Supprimées* + résumé SQL.

> 🔒 `noxa update` est **réservée à la console** (`source == 0`) ou aux détenteurs de l'ACE **`noxa.updater`** (jamais un joueur).
>
> 🧩 **Ajouter une migration** (modifier une table existante sur des bases déjà importées) : créer `sql/migrations/NNN_description.sql` (idempotent — voir `sql/migrations/README.md`), relancer `update.sh`, puis `noxa update`. Les **nouvelles tables** vont toujours dans `install.sql` (jamais de `.sql` dispersé dans les ressources).

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
  **Couverture 100 %** : chaque item de la table `items` (39/39) possède son icône. Icônes réelles
  issues de packs FiveM publics (ox_inventory, aifazi/items-images, esx_inventoryhud) — ex.
  `blowpipe`→blowtorch, `carotool`→toolbox, `carokit`→body kit, `gazbottle`→jerry can, et la filière
  drogues `coca_leaf`→feuille, `cocaine`→poudre, `poppy`→plant, `heroin`→seringue. Image absente →
  `images/placeholder.png` automatiquement.
  → **Ajouter un item** : déposer son PNG `html/images/<name>.png` (le `files{}` du fxmanifest
  charge `html/images/*.png`, aucune autre étape).

## Véhicules (`noxa_vehicles`)
100% **ESX natif** — utilise la table ESX `owned_vehicles` et `ESX.Game` (props véhicule).
Tout passe par le serveur (argent, ownership, plaques) : le client n'affiche que du validé.
- **Concession** (Premium Deluxe, marqueur + ped) : catalogue **menuv** regroupé par **7 classes F→S**
  (`F` Citadine → `S` Hypercar), prix justifiés par segment (≈9k$ → >900k$). Achat débité
  server-side (banque puis cash), plaque unique générée, ligne `owned_vehicles` créée, véhicule livré.
- **Garages** (Légion, Sandy) : menu **menuv** des véhicules possédés. **Sortir** un véhicule stocké
  (spawn + restitution des props/carburant), **Ranger** le véhicule courant (persiste les props ESX,
  carburant inclus). `stored` géré en base, ownership revérifié à chaque action.
- **Fourrière** : véhicules `pound` saisis, **récupération contre amende** (500$) → replacés au garage.
- **Carburant** : `fuelLevel` **persisté nativement** dans les props ESX (`owned_vehicles.vehicle`).
  Consommation moteur selon le régime ; plein aux stations-service à **2$/%** (débité server-side).
- **Touche d'interaction** : `E` aux marqueurs (concession / garage / fourrière / pompe).
- **Ajouter un véhicule au catalogue** : une ligne dans `Config.Catalog` (`model`, `label`, `class`, `price`).

## Drogues (`noxa_drugs`)
100% **ESX natif** — inventaire `xPlayer` (`addInventoryItem` / `removeInventoryItem`) + compte
`black_money`. Récolte, transformation et vente repassent **toutes par le serveur** (anti-farm,
anti-dupe) : le client n'affiche que du validé. Tout est piloté par `config.lua`.
- **Cultures** (champs, marqueur + blip) : `E` pour récolter une **matière première**
  (`cannabis`, `coca_leaf`, `poppy`). Quantité tirée server-side, **cooldown anti-farm** et
  capacité de port ESX (`canCarryItem`) vérifiés à chaque récolte.
- **Transformation** (laboratoire, menu **menuv**) : recettes `input → output`
  (3x `cannabis` → `marijuana`, 3x `coca_leaf` → `cocaine`, 3x `poppy` → `heroin`). Le serveur
  retire l'input **avant** d'ajouter l'output (anti-dupe).
- **Vente** (revendeurs PED, menu **menuv**) : écoule tout le stock d'une drogue contre
  **`black_money`**, prix unitaire **tiré au sort server-side** (marché volatil). Chaque vente est
  journalisée dans `noxa_drugs_sales`.
- **Touche d'interaction** : `E` aux marqueurs (champ / labo / revendeur).
- **Ajouter une filière** : une entrée dans `Config.Fields` + une recette dans `Config.Labs` +
  un prix dans `Config.Dealers` (et l'item dans `install.sql` si nouveau).

## Anti-Cheat (`noxa_anticheat`)
Panel tablette N&B (**F6** / `/anticheat`, réservé ACE `noxa.anticheat`). Visuel React **figé**.
- **Données live** poussées par le serveur (`noxa_ac:data`, toutes les 2 s) au format `window.DATA` :
  joueurs (id, nom, ping, identifier ESX, métier, trust/flags, position), détections, bans, logs, staff, stats.
- **Pont `html/bridge.js`** : le bundle React lit `window.DATA` une fois et n'écoute pas les messages
  de données. Le pont survit au remplacement du DOM (listeners sur `window`), injecte les données live
  dans `window.DATA` (avec helpers `ago`/`fmtTime` temps-réel) et **force un re-render** en capturant le
  root React (patch non intrusif de `ReactDOM.createRoot`). **Aucun HTML/CSS du panel modifié** — seul un
  `<script src="bridge.js">` est ajouté au shell loader, hors template visuel.
- **Détections server-side ESX** (non contournables côté client) : speed hack, warp/teleport, injection
  d'argent (cash+banque) ; sonde client pour l'invincibilité (god mode). Seuils **conservateurs** (anti
  faux-positif), auto-kick **désactivé par défaut** — réglages dans `Config` (`server.lua`).
- **Spawns** : trafic ambiant (`GetEntityPopulationType` 1–5) ignoré ; seuls les spawns **script/réseau**
  près d'un joueur sont comptés.
- **Actions staff** (autorité serveur, ACE re-vérifiée) : surveiller / avertir / expulser / bannir / résoudre.
  Les **bans** utilisent la table **unifiée `noxa_bans`** (partagée avec `noxa_admin`, qui applique le
  bannissement à la connexion). Détections persistées dans `noxa_ac_detections` (rechargées au démarrage).
- **Audit durable `noxa_ac_logs`** : chaque détection (`flag`/`kick`) et chaque sanction staff
  (`watch`/`warn`/`kick`/`ban`/`resolve`) est journalisée en base (identifier, nom, violation, score,
  action) — survit aux redémarrages, contrairement au flux live mémoire affiché dans le panel.

## Économie & Prix (ESX natif)
Tout passe par l'argent **ESX natif** (`cash` / `bank` / `black_money`).

### Salaires (`job_grades.salary`)
- Paie versée **toutes les 10 min** (`Config.PaycheckInterval`) = **6 paies/h** → `$/h = salary × 6`.
- Hors service : **50 %** (`Config.OffDutyPaycheckMultiplier`).
- **Fourchettes** : Civil **500-1500 $/h** · Légal **2000-4000 $/h** · (Illégal **4000-10000 $/h**, réservé aux gangs).
- `unemployed` : 300 $/h — aide minimale, **sous** le plancher civil pour inciter à l'emploi.
- Légal : police, ambulance, banker (2040 → 3960 $/h selon grade). Civil : cardealer, mechanic, taxi + métiers freelance (base + revente).
- Les **boss** (grade max) restent à `0` : rémunérés via le **compte de société**.

### Prix véhicules (concession, HT)
F **5-20k** · E **20-60k** · D **60-150k** · C **150-400k** · B **400-900k** · A **0,9-2M** · S **2-8M $**.
Échelle calée sur les salaires (un légal ≈3000 $/h) pour une vraie progression RP.

### Anti-inflation (puits monétaires)
- **TVA concession 15 %** (`Config.PurchaseTax`) prélevée **en plus** du prix, reversée à personne — affichée au joueur avant achat.
- **Carburant** 2 $/% · **amende fourrière** 500 $.
- Aucun crédit magique : achats / amendes / taxes **débités server-side** ; remboursement intégral seulement si l'opération échoue.

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
| Liaison données panels | 🟡 | anti-cheat + phone + inventaire + **gestion** liés au serveur ESX · autres en cours |
| Anti-cheat (F6) | ✅ | données live (joueurs/détections/bans/logs/staff/stats) · pont React · détections server-side · actions staff · bans unifiés `noxa_bans` |
| Téléphone (F1) | ✅ | données live ESX/SQL, envoi SMS + tweets, ouverture/fermeture |
| Inventaire (I) | ✅ | inventaire ESX live + **images d'items** · utiliser / jeter / donner (anti-dupe serveur) |
| Gestion serveur (F9) | ✅ | éditeur de config **live ESX** (jobs, items, véhicules, lieux) · ouverture + écritures DB superadmin server-side · pont `bridge.js` (visuel figé intact) |
| Menu admin (F10) | ✅ | menuv natif · reports · prise de service · sanctions · logs · grade vérifié server-side |
| Véhicules & Garages | ✅ | ESX natif (`owned_vehicles`) · concession 7 classes F→S · garages · fourrière · carburant 2$/% |
| Drogues | ✅ | ESX natif · cultures (E) · transformation menuv · vente revendeurs (black_money) · anti-farm/anti-dupe server-side |
| Économie & Prix | ✅ | salaires $/h (civil/légal) · prix véhicules F→S calés · TVA 15% + puits monétaires anti-inflation |
| Auto-update (`noxa update`) | ✅ | `update.sh`/`update.bat` (git) + commande console : sync base oxmysql · migrations idempotentes (`noxa_migrations`) · reload ressources (ajoutées/maj/supprimées) · rapport |
> ✅ Fonctionnel · 🟡 En cours · ❌ Non démarré
