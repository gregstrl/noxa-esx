-- ============================================================
-- NOXA FA — Inventaire · client (ESX Legacy)
-- Liaison donnees live (inventaire ESX + images) au panel NUI fige.
-- Le visuel n'est pas modifie : tout passe par le bridge (html/bridge.js).
-- ============================================================
local ESX = exports['es_extended']:getSharedObject()

local isOpen = false

-- Ouvre l'inventaire avec le contenu reel du joueur (snapshot serveur)
local function openInv()
    if isOpen then return end
    isOpen = true
    SetNuiFocus(true, true)
    ESX.TriggerServerCallback('noxa_inventaire:getInventory', function(data)
        SendNUIMessage({ action = 'open', inv = data or {} })
    end)
end

local function closeInv()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

-- ---- NUI callbacks (declenches par le bridge) ----
RegisterNUICallback('close', function(_, cb) closeInv(); cb({ ok = true }) end)
RegisterNUICallback('closeInv', function(_, cb) closeInv(); cb({ ok = true }) end)

RegisterNUICallback('useItem', function(data, cb)
    if data and data.name then TriggerServerEvent('noxa_inventaire:useItem', data.name) end
    cb({ ok = true })
end)

RegisterNUICallback('dropItem', function(data, cb)
    if data and data.name then
        TriggerServerEvent('noxa_inventaire:dropItem', data.name, tonumber(data.count) or 1)
    end
    cb({ ok = true })
end)

RegisterNUICallback('giveItem', function(data, cb)
    if data and data.name then
        TriggerServerEvent('noxa_inventaire:giveItem', data.name, tonumber(data.count) or 1)
    end
    cb({ ok = true })
end)

-- ---- Refresh pousse par le serveur apres une action (autorite serveur) ----
RegisterNetEvent('noxa_inventaire:setInventory', function(data)
    if isOpen then SendNUIMessage({ action = 'setInventory', inv = data or {} }) end
end)

-- ---- Effets visuels des objets consommes ----
RegisterNetEvent('noxa_inventaire:effect', function(kind, amount)
    local ped = PlayerPedId()
    local max = GetEntityMaxHealth(ped)
    if kind == 'heal' then
        SetEntityHealth(ped, math.min(max, GetEntityHealth(ped) + (tonumber(amount) or 20)))
    elseif kind == 'eat' or kind == 'drink' then
        SetEntityHealth(ped, math.min(max, GetEntityHealth(ped) + 5))
    end
end)

-- ---- Ouverture / fermeture ----
local function toggleInv()
    if isOpen then closeInv() else openInv() end
end

-- Touche I (spec Noxa) + F2 (annonce par le footer du layout) : les deux togglent.
RegisterCommand('inventaire', toggleInv, false)
RegisterKeyMapping('inventaire', 'Ouvrir / fermer l inventaire NOXA', 'keyboard', 'I')

RegisterCommand('inventaire_f2', toggleInv, false)
RegisterKeyMapping('inventaire_f2', 'Ouvrir / fermer l inventaire NOXA (F2)', 'keyboard', 'F2')

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and isOpen then SetNuiFocus(false, false) end
end)
