# BUGS CONNUS — NOXA (ESX Legacy)

> Fichier lu par chaque agent au démarrage de session.
> Corriger le bug → supprimer la ligne.
> Fichier vide = aucun bug déclaré joueur (l'agent QA cherche toujours de son côté).

---

## 🔴 CRITIQUE
_(aucun)_

## 🟡 MINEUR

### [BUG-13] Panels NUI — overlay noir / jeu non visible derrière — FIX APPLIQUÉ, à vérifier en jeu
- **État** : fix appliqué aux 4 panels (anticheat, gestion, phone, inventaire) via bridge.js : masquage réel `display:none` à la fermeture + transparence html/body + neutralisation générique de tout backdrop plein écran (≥92% viewport → scrim rgba + blur). Gestion : ajout du `SendNUIMessage close` manquant. Phone : bridge.js créé + référencé.
- **À CONFIRMER en jeu** (après mise à jour des fichiers serveur) : (1) plus d'overlay noir quand un panel est fermé ; (2) on voit bien le jeu (flouté) derrière chaque panel ouvert. Si un panel reste noir : le détecteur générique de backdrop n'a pas attrapé le bon conteneur → inspecter le DOM rendu de CE panel et cibler son conteneur plein écran précis (sans toucher à la carte du design). Ne PAS modifier le layout figé.
- **Fichiers** : `resources/noxa_*/html/bridge.js`.
