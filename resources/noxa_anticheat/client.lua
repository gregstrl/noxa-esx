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
    TriggerServerEvent('noxa_ac:closed')
end

-- ----- Callbacks NUI (envoyés par le panel HTML) ---------------------

-- Fermeture (touche Échap ou bouton ✕ du panel)
RegisterNUICallback('close', function(_, cb)
    isOpen = false
    SetNuiFocus(false, false)
    TriggerServerEvent('noxa_ac:closed')
    cb({ ok = true })
end)

-- Action staff : surveiller / avertir / expulser / bannir / résoudre
RegisterNUICallback('action', function(data, cb)
    TriggerServerEvent('noxa_ac:action', data)
    cb({ ok = true })
end)

-- ----- Données live (serveur -> panel) -------------------------------
-- Le serveur envoie le payload au format window.DATA ; bridge.js l'injecte
-- dans le panel React sans toucher au HTML/CSS figé.
RegisterNetEvent('noxa_ac:data', function(payload)
    SendNUIMessage({ action = 'noxaData', data = payload })
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

-- ----- Sonde anti-triche locale (validée côté serveur) ---------------
-- On remonte des signaux locaux (invincibilité, noclip) ; le serveur décide.
CreateThread(function()
    while true do
        Wait(5000)
        -- Invincibilité = signal fiable et peu bruyant. Le serveur recoupe
        -- avec ses propres détections (vitesse, warp) avant de flagger.
        if GetPlayerInvincible(PlayerId()) then
            TriggerServerEvent('noxa_ac:probe', { invincible = true })
        end
    end
end)

-- Sécurité : si la ressource s'arrête, on relâche le focus
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and isOpen then
        SetNuiFocus(false, false)
    end
end)
