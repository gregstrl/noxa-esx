-- =====================================================================
--  NOXA FA — Panel Anti-Cheat · client
-- =====================================================================
local isOpen = false

local function openPanel()
    if isOpen then return end
    isOpen = true
    SetNuiFocus(true, true)         -- souris + clavier au panel
    SendNUIMessage({ action = 'open' })
end

local function closePanel()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

-- ----- Callbacks NUI (envoyés par le panel HTML) ---------------------

-- Fermeture (touche Échap ou bouton ✕ du panel)
RegisterNUICallback('close', function(_, cb)
    isOpen = false
    SetNuiFocus(false, false)
    cb({ ok = true })
end)

-- Action staff : surveiller / avertir / expulser / bannir / résoudre
RegisterNUICallback('action', function(data, cb)
    TriggerServerEvent('noxa_ac:action', data)
    cb({ ok = true })
end)

-- ----- Ouverture (commande + raccourci) ------------------------------
-- On passe par le serveur pour vérifier les permissions (ACE).
RegisterCommand('anticheat', function()
    TriggerServerEvent('noxa_ac:requestOpen')
end, false)

-- Raccourci par défaut : F6 (modifiable par le joueur dans Paramètres > Touches)
RegisterKeyMapping('anticheat', 'Ouvrir le panel Anti-Cheat NOXA', 'keyboard', 'F6')

RegisterNetEvent('noxa_ac:open', function()
    openPanel()
end)

RegisterNetEvent('noxa_ac:denied', function()
    print('[NOXA AC] Accès refusé : permission manquante.')
end)

-- Sécurité : si la ressource s'arrête, on relâche le focus
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and isOpen then
        SetNuiFocus(false, false)
    end
end)
