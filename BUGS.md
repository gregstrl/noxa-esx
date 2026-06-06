# BUGS CONNUS — NOXA (ESX Legacy)

> Fichier lu par chaque agent au démarrage de session.
> Corriger le bug → supprimer la ligne.
> Fichier vide = aucun bug déclaré joueur (l'agent QA cherche toujours de son côté).

---

## 🔴 CRITIQUE

### [BUG-10] noxa_phone — colonne SQL incohérente (display vs name)
- **Erreur** : `Unknown column 'display' in 'field list'` / `in 'where clause'` sur `noxa_phone_contacts` (server.lua:82 buildData, server.lua:206).
- **Cause** : le code noxa_phone/server.lua interroge la colonne `display`, mais le schéma SQL avait créé la colonne `name`. Désormais install.sql crée bien `display` (corrigé), MAIS les serveurs ayant déjà importé l'ancien schéma ont encore la colonne `name`.
- **Fix** : (1) Vérifier que TOUTES les requêtes noxa_phone utilisent les colonnes réelles de install.sql (`owner`, `display`, `number`). (2) Ajouter dans install.sql une migration idempotente pour les bases existantes — ex : bloc qui renomme/ajoute `display` si absent (via ALTER conditionnel ou procédure), sans casser un import neuf. Objectif : import unique OU réimport = schéma correct sans intervention manuelle.
- **Fichier** : `resources/noxa_phone/server.lua` + `install.sql` (table `noxa_phone_contacts`)

## 🟠 MAJEUR
_(aucun)_

## 🟡 MINEUR
_(aucun)_
