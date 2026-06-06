# BUGS CONNUS — NOXA (ESX Legacy)

> Fichier lu par chaque agent au démarrage de session.
> Corriger le bug → supprimer la ligne.
> Fichier vide = aucun bug déclaré joueur (l'agent QA cherche toujours de son côté).

---

## 🔴 CRITIQUE

### [BUG-11] noxa_vehicles — Config.Catalog nil au démarrage
- **Erreur** : `@noxa_vehicles/client.lua:8: bad argument #1 to 'for iterator' (table expected, got nil)`
- **Cause** : ligne 8 `for _, v in ipairs(Config.Catalog) do` — `Config` ou `Config.Catalog` est nil au chargement du client. Le fichier config (config.lua) n'est probablement pas chargé AVANT client.lua dans le fxmanifest (shared_scripts manquant/ordre), ou Config.Catalog n'est pas défini.
- **Fix** : Dans resources/noxa_vehicles/fxmanifest.lua, charger config.lua en `shared_script` AVANT client.lua. Vérifier que config.lua définit bien `Config = Config or {}` puis `Config.Catalog = { ... }`. Ajouter un garde : `for _, v in ipairs(Config.Catalog or {}) do`. S'assurer que le catalogue (7 classes F→S) existe réellement.
- **Fichier** : `resources/noxa_vehicles/client.lua:8` + `fxmanifest.lua` + `config.lua`

### [BUG-12] MenuV — Namespace 'native' is already taken
- **Erreur** : `@menuv/menuv.lua:1060: [MenuV] Namespace 'native' is already taken, make sure it is unique.` (répété)
- **Cause** : menuv s'initialise/enregistre le namespace 'native' plusieurs fois. Typiquement : une ressource inclut `@menuv/menuv.lua` en double (client_script ET shared_script), ou menuv démarre 2x, ou un resource restart re-déclenche l'init avant nettoyage. Plusieurs ressources noxa_* incluent @menuv/menuv.lua (noxa_admin, noxa_vehicles, noxa_drugs) — c'est normal, MAIS le doublon vient si menuv.lua est listé deux fois dans un même fxmanifest, ou si menuv lui-même est chargé deux fois.
- **Fix** : (1) Vérifier que CHAQUE fxmanifest noxa_* inclut `@menuv/menuv.lua` UNE seule fois (pas en client_script ET shared_script). (2) Vérifier qu'il n'y a qu'un seul `ensure menuv` dans server.cfg (OK actuellement) et pas de double dossier menuv. (3) S'assurer que menuv est bien démarré AVANT les ressources qui en dépendent (dependency 'menuv' dans les fxmanifest). (4) Vérifier la version de menuv (build dist présent, pas de double init au boot).
- **Fichier** : fxmanifest.lua des ressources noxa_* utilisant menuv + `resources/menuv/`

## 🟡 MINEUR
_(aucun)_
