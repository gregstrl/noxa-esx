-- ============================================================
-- NOXA FA — Inventaire · serveur (ESX Legacy)
-- Source d'autorite : toute action passe ici, on verifie TOUJOURS la
-- possession reelle avant de retirer (anti-dupe). Le client n'a aucun
-- pouvoir sur l'inventaire, il ne fait que demander.
-- ============================================================
local ESX = exports['es_extended']:getSharedObject()

-- ---- Snapshot envoye au panel NUI ----
local function buildSnapshot(xPlayer)
    local items = {}
    for _, it in pairs(xPlayer.getInventory()) do
        if it.count and it.count > 0 then
            items[#items + 1] = {
                name   = it.name,
                label  = it.label,
                count  = it.count,
                -- ESX stocke le poids en grammes : on envoie le total du slot en kg
                weight = (it.weight or 0) * it.count / 1000.0,
            }
        end
    end

    local money = xPlayer.getAccount('money')
    local maxW = (xPlayer.getMaxWeight and xPlayer.getMaxWeight())
        or xPlayer.maxWeight or 24000

    return {
        name      = xPlayer.getName(),
        money     = money and money.money or 0,
        maxWeight = maxW / 1000.0, -- kg (defaut ESX = 24)
        items     = items,
    }
end

local function push(xPlayer)
    TriggerClientEvent('noxa_inventaire:setInventory', xPlayer.source, buildSnapshot(xPlayer))
end

ESX.RegisterServerCallback('noxa_inventaire:getInventory', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({}) end
    cb(buildSnapshot(xPlayer))
end)

-- ---- Effets des objets consommables (serveur decide, client applique) ----
local EFFECTS = {
    water    = { kind = 'drink' },
    bread    = { kind = 'eat' },
    sandwich = { kind = 'eat' },
    bandage  = { kind = 'heal', amount = 20 },
    medikit  = { kind = 'heal', amount = 60 },
}

-- ---- Utiliser un objet ----
RegisterNetEvent('noxa_inventaire:useItem', function(itemName)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or type(itemName) ~= 'string' then return end

    local item = xPlayer.getInventoryItem(itemName)
    if not item or (item.count or 0) <= 0 then return end -- anti-dupe : rien si non possede

    local fx = EFFECTS[itemName]
    if not fx then
        TriggerClientEvent('esx:showNotification', src, 'Cet objet n\'est pas utilisable.')
        return
    end

    xPlayer.removeInventoryItem(itemName, 1)
    TriggerClientEvent('noxa_inventaire:effect', src, fx.kind, fx.amount)
    push(xPlayer)
end)

-- ---- Jeter un objet ----
RegisterNetEvent('noxa_inventaire:dropItem', function(itemName, count)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or type(itemName) ~= 'string' then return end

    count = math.floor(tonumber(count) or 1)
    if count < 1 then return end

    local item = xPlayer.getInventoryItem(itemName)
    if not item or (item.count or 0) < count then return end -- anti-dupe : jamais plus que possede
    if item.canRemove == false then
        TriggerClientEvent('esx:showNotification', src, 'Cet objet ne peut pas etre jete.')
        return
    end

    xPlayer.removeInventoryItem(itemName, count)
    TriggerClientEvent('esx:showNotification', src,
        ('Vous avez jete %dx %s.'):format(count, item.label or itemName))
    push(xPlayer)
end)

-- ---- Donner a un joueur proche ----
local function nearestPlayer(src)
    local srcPed = GetPlayerPed(src)
    if srcPed == 0 then return nil end
    local coords = GetEntityCoords(srcPed)
    local best, bestDist = nil, 3.0
    for _, pid in ipairs(GetPlayers()) do
        pid = tonumber(pid)
        if pid and pid ~= src then
            local ped = GetPlayerPed(pid)
            if ped ~= 0 then
                local d = #(coords - GetEntityCoords(ped))
                if d < bestDist then bestDist = d; best = pid end
            end
        end
    end
    return best
end

RegisterNetEvent('noxa_inventaire:giveItem', function(itemName, count)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or type(itemName) ~= 'string' then return end

    count = math.floor(tonumber(count) or 1)
    if count < 1 then return end

    local item = xPlayer.getInventoryItem(itemName)
    if not item or (item.count or 0) < count then return end -- anti-dupe

    local targetId = nearestPlayer(src)
    if not targetId then
        TriggerClientEvent('esx:showNotification', src, 'Aucun joueur a proximite.')
        return
    end
    local xTarget = ESX.GetPlayerFromId(targetId)
    if not xTarget then return end

    if xTarget.canCarryItem and not xTarget.canCarryItem(itemName, count) then
        TriggerClientEvent('esx:showNotification', src, 'Le joueur ne peut pas porter cela.')
        return
    end

    -- ordre sur : on retire d'abord, on ajoute ensuite
    xPlayer.removeInventoryItem(itemName, count)
    xTarget.addInventoryItem(itemName, count)

    TriggerClientEvent('esx:showNotification', src,
        ('Vous avez donne %dx %s.'):format(count, item.label or itemName))
    TriggerClientEvent('esx:showNotification', targetId,
        ('Vous avez recu %dx %s.'):format(count, item.label or itemName))

    push(xPlayer)
    push(xTarget)
end)
