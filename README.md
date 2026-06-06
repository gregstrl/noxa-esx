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
  - `noxa_boutique` — boutique (F7)

## Installation
1. Importer `[SQL]/legacy.sql` puis `[SQL]/noxa_phone.sql` dans ta base MySQL `noxa` (phpMyAdmin)
2. Ouvrir `server.cfg` — remplir `sv_licenseKey` + `mysql_connection_string`
3. Placer le dossier `resources/` dans ton serveur FiveM
4. Ajouter `exec server.cfg` dans ton serveur, ou utiliser ce server.cfg
5. Démarrer

## Architecture
- ESX Legacy = base intacte. On construit PAR-DESSUS, on ne réinvente rien.
- Tout script ESX du marché se drop dans `resources/` et fonctionne direct.
- Les menus in-game custom passent par `exports['menuv']`.
- Les 5 panels NUI = ressources indépendantes, visuels figés, données branchées par-dessus.

## État
| Système | État | Notes |
|---|---|---|
| ESX Legacy core | ✅ | Framework officiel |
| Panels NUI (visuels) | ✅ | anti-cheat, phone, gestion, inventaire, boutique |
| Liaison données panels | 🟡 | phone lié au serveur ESX (contacts, SMS, banque, Canari, garage) · autres en cours |
| Téléphone (F1) | ✅ | données live ESX/SQL, envoi SMS + tweets, ouverture/fermeture |
> ✅ Fonctionnel · 🟡 En cours · ❌ Non démarré
