-- NOXA FA — Panel Gestion Serveur · client
local isOpen = false
local function openPanel()
    if isOpen then return end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })
end
RegisterNUICallback('close', function(_, cb)
    isOpen = false
    SetNuiFocus(false, false)
    cb({ ok = true })
end)
RegisterNUICallback('action', function(data, cb)
    TriggerServerEvent('noxa_gestion:action', data)
    cb({ ok = true })
end)
-- Ouverture via serveur (vérif rang superadmin)
RegisterCommand('gestion', function()
    TriggerServerEvent('noxa_gestion:requestOpen')
end, false)
RegisterKeyMapping('gestion', 'Ouvrir le panel Gestion Serveur', 'keyboard', 'F9')
RegisterNetEvent('noxa_gestion:open', function() openPanel() end)
RegisterNetEvent('noxa_gestion:denied', function()
    print('[NOXA Gestion] Accès refusé : superadmin requis.')
end)
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and isOpen then SetNuiFocus(false, false) end
end)
