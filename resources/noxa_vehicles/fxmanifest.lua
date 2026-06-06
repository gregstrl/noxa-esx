-- =====================================================================
--  NOXA VEHICLES — Concession · Garage · Fourrière · Carburant
--  Stack : ESX Legacy (owned_vehicles, ESX.Game) · oxmysql · menuv
-- =====================================================================
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'NOXA'
description 'NOXA — Véhicules : concession (7 classes F→S), garages menuv, fourrière, carburant 2$/%'
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
