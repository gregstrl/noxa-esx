fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'NOXA FA'
description 'NOXA FA — Panel Anti-Cheat (NUI)'
version '1.0.0'

-- Page NUI (fichier HTML autonome, aucune dépendance internet requise)
ui_page 'html/index.html'

files {
    'html/index.html'
}

client_script 'client.lua'
server_script 'server.lua'
