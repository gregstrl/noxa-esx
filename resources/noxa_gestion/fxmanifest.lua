fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'NOXA FA'
description 'NOXA FA — Panel Gestion Serveur (NUI) lie a ESX Legacy'
version '1.1.0'

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/bridge.js',
}

client_scripts {
    '@es_extended/imports.lua',   -- expose le global ESX
    'client.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',     -- expose MySQL (oxmysql)
    '@es_extended/imports.lua',   -- expose le global ESX
    'server.lua',
}

dependencies {
    'es_extended',
    'oxmysql',
}
