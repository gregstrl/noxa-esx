-- ============================================================
-- NOXA FA — Téléphone · client (ESX Legacy)
-- Liaison données live + actions joueur. Visuel NUI inchangé.
-- ============================================================
local ESX = exports['es_extended']:getSharedObject()

local isOpen = false

-- Récupère les données live du serveur puis ouvre le téléphone
local function openPhone()
    if isOpen then return end
    isOpen = true
    SetNuiFocus(true, true)
    ESX.TriggerServerCallback('noxa_phone:getData', function(data)
        SendNUIMessage({ action = 'open', data = data or {} })
    end)
end

local function closePhone()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

-- F1 bascule (le bundle n'avait aucun moyen de fermeture)
RegisterCommand('phone', function()
    if isOpen then closePhone() else openPhone() end
end, false)
RegisterKeyMapping('phone', 'Ouvrir / fermer le téléphone NOXA', 'keyboard', 'F1')

-- Fermeture déclenchée depuis la NUI (ESC dans le bridge)
RegisterNUICallback('close', function(_, cb)
    closePhone()
    cb({ ok = true })
end)

-- ---- Actions joueur -> serveur ----
RegisterNUICallback('sendMessage', function(payload, cb)
    if payload and payload.to and payload.text and payload.text ~= '' then
        TriggerServerEvent('noxa_phone:sendMessage', payload.to, payload.text)
    end
    cb({ ok = true })
end)

RegisterNUICallback('postTweet', function(payload, cb)
    if payload and payload.text and payload.text ~= '' then
        TriggerServerEvent('noxa_phone:postTweet', payload.text)
    end
    cb({ ok = true })
end)

RegisterNUICallback('call', function(payload, cb)
    -- Placeholder : pas de voix ici, on journalise côté serveur pour l'historique
    if payload and payload.to then
        TriggerServerEvent('noxa_phone:logCall', payload.to)
    end
    cb({ ok = true })
end)

-- Rafraîchit l'écran ouvert quand le serveur pousse une mise à jour (SMS reçu, tweet…)
RegisterNetEvent('noxa_phone:refresh', function()
    if not isOpen then return end
    ESX.TriggerServerCallback('noxa_phone:getData', function(data)
        SendNUIMessage({ action = 'setData', data = data or {} })
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and isOpen then SetNuiFocus(false, false) end
end)
