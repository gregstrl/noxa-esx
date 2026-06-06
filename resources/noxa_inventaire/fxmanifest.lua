fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'NOXA FA'
description 'NOXA FA — Inventaire (NUI) lie a ESX Legacy'
version '1.1.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/bridge.js',
    'html/images/*.png',
}

client_script 'client.lua'
server_script 'server.lua'

dependencies { 'es_extended' }
