-- =====================================================================
--  NOXA ADMIN — Menu admin ultra complet + Reports + Prise de service
--  Stack : ESX Legacy · oxmysql · menuv
-- =====================================================================
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'NOXA'
description 'NOXA — Menu admin (F10), système de report joueur->staff, prise de service'
version '1.0.0'

-- Petite NUI utilitaire : saisies texte (raisons, montants...) + bannière d'annonce
ui_page 'html/index.html'
files {
    'html/index.html',
}

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
