fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'NOXA FA'
description 'NOXA FA — Panel Anti-Cheat (NUI) + détections server-side ESX'
version '1.1.0'

-- Page NUI (fichier HTML autonome, aucune dépendance internet requise)
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/bridge.js',     -- pont données live -> React (injecté dans le DOM)
}

client_script 'client.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
}
