-- =====================================================================
--  NOXA VEHICLES — Client (menus menuv + concession/garage/fourrière/pompe)
--  Affichage seul : achat, stockage, sortie, fourrière et plein sont
--  validés server-side. On construit PAR-DESSUS ESX (ESX.Game, owned_vehicles).
-- =====================================================================

local catalogByClass = {}   -- { classId = { entries... } }
for _, v in ipairs(Config.Catalog) do
    catalogByClass[v.class] = catalogByClass[v.class] or {}
    table.insert(catalogByClass[v.class], v)
end

-- =====================================================================
--  NOTIFICATIONS
-- =====================================================================
local function notify(msg)
    ESX.ShowNotification(msg)
end

local function money(n)
    return ('$%s'):format(tostring(n):reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^%s', ''))
end

-- =====================================================================
--  HELPERS VÉHICULE (ESX natif)
-- =====================================================================

--- Fait apparaître un véhicule possédé et y installe le joueur.
local function spawnOwned(model, props, spawnPos)
    ESX.Game.SpawnVehicle(model, vector3(spawnPos.x, spawnPos.y, spawnPos.z), spawnPos.w, function(veh)
        if props then ESX.Game.SetVehicleProperties(veh, props) end
        if props and props.plate then SetVehicleNumberPlateText(veh, props.plate) end
        SetPedIntoVehicle(PlayerPedId(), veh, -1)
        SetVehicleEngineOn(veh, true, true, false)
    end)
end

--- Véhicule courant du joueur (conducteur) ou nil.
local function currentVehicle()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return nil end
    local veh = GetVehiclePedIsIn(ped, false)
    if GetPedInVehicleSeat(veh, -1) ~= ped then return nil end
    return veh
end

-- =====================================================================
--  MENUS menuv
-- =====================================================================
local concessionMenu = MenuV:CreateMenu('Concession', 'NOXA Motors', 'topright', 245, 65, 65, 'size-110', 'default', 'menuv', 'native')
local classMenu      = MenuV:CreateMenu('Classe', 'Modèles disponibles', 'topright', 245, 65, 65, 'size-110', 'default', 'menuv', 'native')
local garageMenu     = MenuV:CreateMenu('Garage', 'Vos véhicules', 'topright', 245, 65, 65, 'size-110', 'default', 'menuv', 'native')
local impoundMenu    = MenuV:CreateMenu('Fourrière', 'Véhicules saisis', 'topright', 245, 65, 65, 'size-110', 'default', 'menuv', 'native')

-- ---- Concession : liste des 7 classes -------------------------------
for _, c in ipairs(Config.Classes) do
    concessionMenu:AddButton({
        icon = '🚗', label = c.label, value = classMenu, description = c.desc,
        select = function()
            classMenu:ClearItems()
            classMenu.Title = c.id
            classMenu.Subtitle = c.label
            for _, entry in ipairs(catalogByClass[c.id] or {}) do
                classMenu:AddButton({
                    label = entry.label,
                    description = ('Acheter pour %s'):format(money(entry.price)),
                    value = money(entry.price),
                    select = function()
                        ESX.TriggerServerCallback('noxa_vehicles:buy', function(res)
                            if not res or not res.ok then
                                return notify('~r~' .. ((res and res.reason) or 'Achat refusé.'))
                            end
                            notify(('~g~%s achetée ! Plaque ~y~%s~s~. Livraison en cours...'):format(entry.label, res.plate))
                            -- Le serveur l'a enregistrée sortie (stored=0) : on la livre.
                            spawnOwned(entry.model, res.props, Config.Concession.spawn)
                            concessionMenu:Close()
                        end, entry.model)
                    end,
                })
            end
        end,
    })
end

-- ---- Garage ---------------------------------------------------------
local function openGarage()
    garageMenu:ClearItems()
    -- Stocker le véhicule courant s'il y en a un
    local veh = currentVehicle()
    if veh then
        garageMenu:AddButton({
            icon = '📥', label = 'Ranger ce véhicule', description = 'Stocke et persiste le carburant',
            select = function()
                local props = ESX.Game.GetVehicleProperties(veh)
                ESX.TriggerServerCallback('noxa_vehicles:store', function(res)
                    if not res or not res.ok then
                        return notify('~r~' .. ((res and res.reason) or 'Rangement refusé.'))
                    end
                    ESX.Game.DeleteVehicle(veh)
                    notify('~g~Véhicule rangé au garage.')
                    garageMenu:Close()
                end, { plate = props.plate, props = props })
            end,
        })
    end

    ESX.TriggerServerCallback('noxa_vehicles:getGarage', function(list)
        if #list == 0 then
            garageMenu:AddButton({ label = 'Aucun véhicule', disabled = true })
            return
        end
        for _, v in ipairs(list) do
            if v.stored then
                garageMenu:AddButton({
                    icon = '🚙', label = v.plate,
                    description = ('Carburant %d%% — Sortir'):format(v.fuel),
                    value = ('%d%%'):format(v.fuel),
                    select = function()
                        ESX.TriggerServerCallback('noxa_vehicles:retrieve', function(res)
                            if not res or not res.ok then
                                return notify('~r~' .. ((res and res.reason) or 'Sortie refusée.'))
                            end
                            local model = res.props and res.props.model or v.plate
                            spawnOwned(model, res.props, currentGarage and currentGarage.spawn or Config.Garages[1].spawn)
                            notify('~g~Véhicule sorti du garage.')
                            garageMenu:Close()
                        end, v.plate)
                    end,
                })
            else
                garageMenu:AddButton({
                    icon = '🅿️', label = v.plate, disabled = true,
                    description = 'Déjà sorti', value = 'dehors',
                })
            end
        end
    end)
    garageMenu:Open()
end

-- ---- Fourrière ------------------------------------------------------
local function openImpound()
    impoundMenu:ClearItems()
    ESX.TriggerServerCallback('noxa_vehicles:getImpound', function(list)
        if #list == 0 then
            impoundMenu:AddButton({ label = 'Aucun véhicule en fourrière', disabled = true })
        else
            for _, v in ipairs(list) do
                impoundMenu:AddButton({
                    icon = '🚓', label = v.plate,
                    description = ('Récupérer contre %s'):format(money(v.fee)),
                    value = money(v.fee),
                    select = function()
                        ESX.TriggerServerCallback('noxa_vehicles:impoundRetrieve', function(res)
                            if not res or not res.ok then
                                return notify('~r~' .. ((res and res.reason) or 'Récupération refusée.'))
                            end
                            notify(('~g~Amende payée (%s). Véhicule rangé au garage.'):format(money(res.fee)))
                            impoundMenu:Close()
                        end, v.plate)
                    end,
                })
            end
        end
    end)
    impoundMenu:Open()
end

-- =====================================================================
--  PED CONCESSION + BLIPS
-- =====================================================================
CreateThread(function()
    -- Ped concession
    local m = Config.Concession.ped
    RequestModel(m)
    local t = 0
    while not HasModelLoaded(m) and t < 100 do RequestModel(m); Wait(50); t = t + 1 end
    if HasModelLoaded(m) then
        local p = Config.Concession.pos
        local ped = CreatePed(4, m, p.x, p.y, p.z - 1.0, p.w, false, true)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetModelAsNoLongerNeeded(m)
    end

    -- Blip concession
    local b = Config.Concession.blip
    local blip = AddBlipForCoord(Config.Concession.pos.x, Config.Concession.pos.y, Config.Concession.pos.z)
    SetBlipSprite(blip, b.sprite); SetBlipColour(blip, b.color); SetBlipScale(blip, b.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName(b.label); EndTextCommandSetBlipName(blip)

    -- Blips garages
    for _, g in ipairs(Config.Garages) do
        local gb = AddBlipForCoord(g.pos.x, g.pos.y, g.pos.z)
        SetBlipSprite(gb, g.blip.sprite); SetBlipColour(gb, g.blip.color); SetBlipScale(gb, g.blip.scale)
        SetBlipAsShortRange(gb, true)
        BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName(g.label); EndTextCommandSetBlipName(gb)
    end

    -- Blip fourrière
    local ib = AddBlipForCoord(Config.Impound.pos.x, Config.Impound.pos.y, Config.Impound.pos.z)
    SetBlipSprite(ib, Config.Impound.blip.sprite); SetBlipColour(ib, Config.Impound.blip.color); SetBlipScale(ib, Config.Impound.blip.scale)
    SetBlipAsShortRange(ib, true)
    BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName(Config.Impound.label); EndTextCommandSetBlipName(ib)
end)

-- Garage le plus proche (pour le point de sortie du véhicule)
currentGarage = nil

-- =====================================================================
--  INTERACTION (marqueurs + touche E)
-- =====================================================================
CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)

        -- Concession
        local dC = #(pos - vector3(Config.Concession.pos.x, Config.Concession.pos.y, Config.Concession.pos.z))
        if dC < 15.0 then
            sleep = 0
            DrawMarker(2, Config.Concession.pos.x, Config.Concession.pos.y, Config.Concession.pos.z + 1.0,
                0,0,0, 0,0,0, 0.3,0.3,0.3, 46,156,200,150, false, true, 2, nil, nil, false)
            if dC < 2.0 and IsControlJustReleased(0, Config.InteractKey) then
                concessionMenu:Open()
            end
        end

        -- Garages
        for _, g in ipairs(Config.Garages) do
            local dG = #(pos - g.pos)
            if dG < 15.0 then
                sleep = 0
                DrawMarker(2, g.pos.x, g.pos.y, g.pos.z + 1.0, 0,0,0, 0,0,0, 0.3,0.3,0.3, 0,160,90,150, false, true, 2, nil, nil, false)
                if dG < 3.0 then
                    currentGarage = g
                    if IsControlJustReleased(0, Config.InteractKey) then openGarage() end
                end
            end
        end

        -- Fourrière
        local dI = #(pos - Config.Impound.pos)
        if dI < 15.0 then
            sleep = 0
            DrawMarker(2, Config.Impound.pos.x, Config.Impound.pos.y, Config.Impound.pos.z + 1.0, 0,0,0, 0,0,0, 0.3,0.3,0.3, 200,40,40,150, false, true, 2, nil, nil, false)
            if dI < 3.0 and IsControlJustReleased(0, Config.InteractKey) then openImpound() end
        end

        Wait(sleep)
    end
end)

-- =====================================================================
--  CARBURANT — pompes (2$/%) + consommation
-- =====================================================================

-- Plein aux stations-service
CreateThread(function()
    while true do
        local sleep = 1500
        local veh = currentVehicle()
        if veh then
            local pos = GetEntityCoords(veh)
            for _, station in ipairs(Config.FuelStations) do
                if #(pos - station) < Config.FuelStationRadius then
                    sleep = 0
                    local fuel = GetVehicleFuelLevel(veh)
                    if IsControlJustReleased(0, Config.InteractKey) and fuel < 99.0 then
                        local missing = 100.0 - fuel
                        ESX.TriggerServerCallback('noxa_vehicles:refuel', function(res)
                            if not res or not res.ok then
                                return notify('~r~' .. ((res and res.reason) or 'Plein refusé.'))
                            end
                            SetVehicleFuelLevel(veh, 100.0)
                            notify(('~g~Plein effectué pour %s.'):format(money(res.cost)))
                        end, missing)
                    end
                    break
                end
            end
        end
        Wait(sleep)
    end
end)

-- Consommation moteur (réservoir descend selon le régime)
CreateThread(function()
    while true do
        Wait(Config.FuelTickSeconds * 1000)
        local veh = currentVehicle()
        if veh and GetIsVehicleEngineRunning(veh) then
            local fuel = GetVehicleFuelLevel(veh)
            local rpm = GetVehicleCurrentRpm(veh) -- 0.0 .. 1.0
            local usage = Config.FuelIdleUsage + (Config.FuelDriveUsage - Config.FuelIdleUsage) * rpm
            local newFuel = math.max(0.0, fuel - usage)
            SetVehicleFuelLevel(veh, newFuel + 0.0)
        end
    end
end)
