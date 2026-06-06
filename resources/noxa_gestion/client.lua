-- =====================================================================
--  NOXA FA — Panel Gestion Serveur · CLIENT
--  Le bundle React (visuel fige) lit window.MDATA et fetch « noxa_manage ».
--  bridge.js redirige ces fetch vers CETTE ressource et injecte les
--  donnees live. Ici : ouverture (superadmin server-side), relais des
--  actions et diffusion du snapshot ESX au panel.
-- =====================================================================
local isOpen = false
local snapshot = nil   -- dernier snapshot ESX recu du serveur (cache pour getData)

local function openPanel()
    if isOpen then return end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })
    -- demande le snapshot ESX frais (un seul remontage -> pas de double flash)
    TriggerServerEvent('noxa_gestion:getSnapshot')
end

local function closePanel()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })   -- masque reellement la NUI (sinon overlay noir permanent)
end

-- --- Callbacks NUI (le bundle fetch « noxa_manage » -> bridge.js redirige ici) ---
RegisterNUICallback('close', function(_, cb)
    closePanel()
    cb({ ok = true })
end)

RegisterNUICallback('save', function(data, cb)
    -- Autorite serveur : la validation superadmin + l'ecriture DB sont server-side.
    TriggerServerEvent('noxa_gestion:save', data)
    cb({ ok = true })
end)

RegisterNUICallback('getData', function(_, cb)
    cb({ data = snapshot })
end)

-- --- Ouverture (verif rang superadmin cote serveur) ---
RegisterCommand('gestion', function()
    TriggerServerEvent('noxa_gestion:requestOpen')
end, false)
RegisterKeyMapping('gestion', 'Ouvrir le panel Gestion Serveur', 'keyboard', 'F9')

RegisterNetEvent('noxa_gestion:open', function() openPanel() end)
RegisterNetEvent('noxa_gestion:denied', function()
    print('[NOXA Gestion] Acces refuse : superadmin requis.')
end)

-- Snapshot ESX live pousse par le serveur (a l'ouverture et apres chaque save).
RegisterNetEvent('noxa_gestion:snapshot', function(data)
    snapshot = data
    if isOpen then SendNUIMessage({ action = 'gestionData', data = data }) end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and isOpen then SetNuiFocus(false, false) end
end)
