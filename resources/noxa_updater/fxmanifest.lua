-- =====================================================================
--  NOXA UPDATER — Auto-update lié à GitHub (gregstrl/noxa-esx)
--  Commande console : `noxa update`
--   1) Synchronise la base `noxa` (install.sql + sql/migrations) via oxmysql,
--      idempotent, chaque migration jouée une seule fois (table noxa_migrations).
--   2) refresh + ensure/restart des ressources modifiées/ajoutées, stop des
--      ressources retirées du repo, puis rapport console clair.
--
--  Le git pull/reset se fait via update.sh / update.bat (le Lua serveur FiveM
--  est sandboxé : os.execute est bloqué, git ne peut pas s'y lancer).
-- =====================================================================
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'NOXA'
description 'NOXA — Système d''auto-update serveur (SQL + ressources) lié à GitHub'
version '1.0.0'

server_scripts {
    '@oxmysql/lib/MySQL.lua',   -- expose le global MySQL (oxmysql)
    'sv_updater.lua',
}

-- SQL synchronisé depuis la racine par update.sh / update.bat. C'est le SEUL
-- emplacement que le sandbox FiveM autorise le serveur à lire (les opérations
-- hors dossier ressource / dans le dossier racine sont bloquées).
-- (Pas listé dans files{} : LoadResourceFile côté serveur n'en a pas besoin et
--  on évite de streamer le SQL aux clients.)

dependencies {
    'oxmysql',
}
