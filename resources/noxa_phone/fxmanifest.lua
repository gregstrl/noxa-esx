fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'NOXA FA'
description 'NOXA FA — Téléphone (NUI) lié à ESX Legacy'
version '1.1.0'

ui_page 'html/index.html'
files { 'html/index.html' }

client_script 'client.lua'

server_script '@oxmysql/lib/MySQL.lua'
server_script 'server.lua'

dependencies { 'es_extended', 'oxmysql' }
