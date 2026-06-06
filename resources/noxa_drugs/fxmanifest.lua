-- =====================================================================
--  NOXA DRUGS — Cultures · Transformation · Vente (marché noir)
--  Stack : ESX Legacy (inventaire + black_money) · oxmysql · menuv
-- =====================================================================
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'NOXA'
description 'NOXA — Drogues : champs de culture, laboratoires (menuv), revendeurs (black_money) — 100% ESX natif'
version '1.0.0'

shared_script 'config.lua'

client_scripts {
    '@menuv/menuv.lua',           -- expose le global MenuV
    '@es_extended/imports.lua',   -- expose le global ESX
    'client.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',     -- expose MySQL (oxmysql)
    '@es_extended/imports.lua',   -- expose le global ESX
    'server.lua',
}

dependencies {
    'menuv',
    'es_extended',
    'oxmysql',
}
