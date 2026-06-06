-- =====================================================================
--  NOXA DRUGS — Client (menus menuv + champs/labos/revendeurs)
--  Affichage seul : récolte, transformation et vente sont validées
--  server-side (anti-dupe / anti-farm). On construit PAR-DESSUS ESX.
-- =====================================================================

-- =====================================================================
--  NOTIFICATIONS
-- =====================================================================
local function notify(msg)
    ESX.ShowNotification(msg)
end

local busy = false  -- empêche le spam de récolte/transfo pendant l'animation

-- Petite barre de progression "maison" (anim de travail + attente)
local function doProgress(durationMs, anim)
    busy = true
    local ped = PlayerPedId()
    if anim then
        RequestAnimDict(anim.dict)
        local t = 0
        while not HasAnimDictLoaded(anim.dict) and t < 50 do RequestAnimDict(anim.dict); Wait(20); t = t + 1 end
        TaskPlayAnim(ped, anim.dict, anim.name, 8.0, -8.0, durationMs, 1, 0, false, false, false)
    end
    Wait(durationMs)
    ClearPedTasks(ped)
    busy = false
end

-- =====================================================================
--  MENUS menuv
-- =====================================================================
local labMenu    = MenuV:CreateMenu('Laboratoire', 'Transformation', 'topright', 245, 65, 65, 'size-110', 'default', 'menuv', 'noxa_drugs_labMenu')
local dealerMenu = MenuV:CreateMenu('Revendeur', 'Marché noir', 'topright', 245, 65, 65, 'size-110', 'default', 'menuv', 'noxa_drugs_dealerMenu')

-- ---- Laboratoire : liste des recettes -------------------------------
local function openLab(lab)
    labMenu:ClearItems()
    labMenu.Title = lab.label
    labMenu.Subtitle = lab.sub
    for _, r in ipairs(lab.recipes) do
        labMenu:AddButton({
            icon = '⚗️', label = r.label,
            description = ('Transforme %dx %s en %dx %s'):format(r.inQty, r.input, r.outQty, r.output),
            value = ('%d:%d'):format(r.inQty, r.outQty),
            select = function()
                if busy then return end
                doProgress(Config.ProcessDuration, { dict = 'amb@prop_human_bbq@male@base', name = 'base' })
                ESX.TriggerServerCallback('noxa_drugs:process', function(res)
                    if not res or not res.ok then
                        return notify('~r~' .. ((res and res.reason) or 'Transformation refusée.'))
                    end
                    notify(('~g~+%dx %s'):format(res.outQty, res.label))
                end, r.output)
            end,
        })
    end
    labMenu:Open()
end

-- ---- Revendeur : liste des drogues vendables ------------------------
local function openDealer(dealer)
    dealerMenu:ClearItems()
    dealerMenu.Title = dealer.label
    dealerMenu.Subtitle = dealer.sub
    ESX.TriggerServerCallback('noxa_drugs:getStock', function(stock)
        local any = false
        for item, qty in pairs(stock or {}) do
            if qty > 0 and dealer.prices[item] then
                any = true
                local label = Config.ItemLabels[item] or item
                dealerMenu:AddButton({
                    icon = '💵', label = ('Vendre %s'):format(label),
                    description = ('Vous avez %dx %s — vente au prix du marché'):format(qty, label),
                    value = ('x%d'):format(qty),
                    select = function()
                        if busy then return end
                        ESX.TriggerServerCallback('noxa_drugs:sell', function(res)
                            if not res or not res.ok then
                                return notify('~r~' .. ((res and res.reason) or 'Vente refusée.'))
                            end
                            notify(('~g~%dx %s vendus pour ~y~$%d~s~ (argent sale).'):format(res.sold, label, res.gain))
                            openDealer(dealer) -- rafraîchit le stock affiché
                        end, item)
                    end,
                })
            end
        end
        if not any then
            dealerMenu:AddButton({ label = 'Rien à vendre', disabled = true, description = 'Aucune drogue transformée sur vous.' })
        end
        dealerMenu:Open()
    end)
end

-- =====================================================================
--  PEDS REVENDEURS + BLIPS
-- =====================================================================
CreateThread(function()
    -- Blips champs
    for _, f in ipairs(Config.Fields) do
        local b = AddBlipForCoord(f.pos.x, f.pos.y, f.pos.z)
        SetBlipSprite(b, f.blip.sprite); SetBlipColour(b, f.blip.color); SetBlipScale(b, f.blip.scale)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName(f.label); EndTextCommandSetBlipName(b)
    end

    -- Blips labos
    for _, l in ipairs(Config.Labs) do
        local b = AddBlipForCoord(l.pos.x, l.pos.y, l.pos.z)
        SetBlipSprite(b, l.blip.sprite); SetBlipColour(b, l.blip.color); SetBlipScale(b, l.blip.scale)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName(l.label); EndTextCommandSetBlipName(b)
    end

    -- Peds + blips revendeurs
    for _, d in ipairs(Config.Dealers) do
        local m = GetHashKey(d.ped)
        RequestModel(m)
        local t = 0
        while not HasModelLoaded(m) and t < 100 do RequestModel(m); Wait(50); t = t + 1 end
        if HasModelLoaded(m) then
            local ped = CreatePed(4, m, d.pos.x, d.pos.y, d.pos.z - 1.0, d.pos.w, false, true)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            SetModelAsNoLongerNeeded(m)
        end
        if d.blip then
            local b = AddBlipForCoord(d.pos.x, d.pos.y, d.pos.z)
            SetBlipSprite(b, d.blip.sprite); SetBlipColour(b, d.blip.color); SetBlipScale(b, d.blip.scale)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName(d.label); EndTextCommandSetBlipName(b)
        end
    end
end)

-- =====================================================================
--  INTERACTION (marqueurs + touche E)
-- =====================================================================
CreateThread(function()
    while true do
        local sleep = 1000
        local pos = GetEntityCoords(PlayerPedId())

        -- Champs : récolte
        for _, f in ipairs(Config.Fields) do
            local d = #(pos - f.pos)
            if d < 15.0 then
                sleep = 0
                DrawMarker(2, f.pos.x, f.pos.y, f.pos.z + 1.0, 0,0,0, 0,0,0, 0.3,0.3,0.3, 0,160,90,150, false, true, 2, nil, nil, false)
                if d < 2.0 and not busy and IsControlJustReleased(0, Config.InteractKey) then
                    doProgress(Config.HarvestDuration, { dict = 'amb@world_human_gardener_plant@male@base', name = 'base' })
                    ESX.TriggerServerCallback('noxa_drugs:harvest', function(res)
                        if not res or not res.ok then
                            return notify('~r~' .. ((res and res.reason) or 'Récolte impossible.'))
                        end
                        notify(('~g~+%dx %s récolté.'):format(res.amount, res.item))
                    end, f.drug)
                end
            end
        end

        -- Labos : transformation
        for _, l in ipairs(Config.Labs) do
            local d = #(pos - l.pos)
            if d < 15.0 then
                sleep = 0
                DrawMarker(2, l.pos.x, l.pos.y, l.pos.z + 1.0, 0,0,0, 0,0,0, 0.3,0.3,0.3, 200,140,0,150, false, true, 2, nil, nil, false)
                if d < 2.0 and IsControlJustReleased(0, Config.InteractKey) then openLab(l) end
            end
        end

        -- Revendeurs : vente
        for _, dl in ipairs(Config.Dealers) do
            local d = #(pos - vector3(dl.pos.x, dl.pos.y, dl.pos.z))
            if d < 15.0 then
                sleep = 0
                DrawMarker(2, dl.pos.x, dl.pos.y, dl.pos.z + 1.0, 0,0,0, 0,0,0, 0.3,0.3,0.3, 200,40,40,150, false, true, 2, nil, nil, false)
                if d < 2.0 and IsControlJustReleased(0, Config.InteractKey) then openDealer(dl) end
            end
        end

        Wait(sleep)
    end
end)
