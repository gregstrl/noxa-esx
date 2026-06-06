-- =====================================================================
--  NOXA ADMIN — Client (menus menuv + outils staff)
--  Accès gardé par le grade (vérifié server-side). Le client ne fait
--  qu'afficher : toute action impactante repasse par le serveur.
-- =====================================================================

local myLevel = 0          -- niveau staff connu (rafraîchi à chaque ouverture)
local onDuty = false       -- prise de service
local lastPos = nil        -- dernière position (pour "retour")
local lastMenu = nil       -- menu menuv actuellement ouvert (pour fermer avant un prompt NUI)

-- États outils
local noclip = false
local godmode = false
local invisible = false
local spectating = false
local promptCb = nil       -- callback du prompt NUI en cours

-- =====================================================================
--  NOTIFICATIONS
-- =====================================================================
local function notify(msg, type_)
    ESX.ShowNotification(msg)
end

RegisterNetEvent('noxa_admin:notify', function(data)
    if not data then return end
    local prefix = ({
        success = '~g~', error = '~r~', info = '~b~', report = '~y~',
    })[data.type] or '~w~'
    ESX.ShowNotification(('%s%s~s~\n%s'):format(prefix, data.title or 'NOXA', data.msg or ''))
    if data.sound then
        PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', true)
    end
end)

-- =====================================================================
--  PROMPT NUI (saisies texte : raisons, montants, modèles...)
-- =====================================================================
--- @param title string
--- @param fields table  liste { {name=, label=, type='text'|'number', value=} }
--- @param cb function   reçoit une table {name=valeur} ou nil si annulé
local function openPrompt(title, fields, cb)
    if lastMenu then lastMenu:Close() end
    promptCb = cb
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'prompt', title = title, fields = fields })
end

RegisterNUICallback('promptSubmit', function(data, cbNui)
    SetNuiFocus(false, false)
    cbNui({ ok = true })
    local fn = promptCb; promptCb = nil
    if fn then fn(data and data.values or nil) end
end)

RegisterNUICallback('promptCancel', function(_, cbNui)
    SetNuiFocus(false, false)
    cbNui({ ok = true })
    local fn = promptCb; promptCb = nil
    if fn then fn(nil) end
end)

-- =====================================================================
--  OUTILS PERSONNELS (purement locaux : n'affectent que soi)
-- =====================================================================

-- Soin / réanimation de son propre ped
local function healSelf(revive)
    local ped = PlayerPedId()
    if revive and IsEntityDead(ped) then
        local c = GetEntityCoords(ped)
        NetworkResurrectLocalPlayer(c.x, c.y, c.z, GetEntityHeading(ped), true, false)
    end
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    local pid = PlayerId()
    SetPlayerHealthRechargeMultiplier(pid, 1.0)
    ClearPedBloodDamage(ped)
end

RegisterNetEvent('noxa_admin:healMe', function(revive) healSelf(revive == true) end)
RegisterNetEvent('noxa_admin:killMe', function() SetEntityHealth(PlayerPedId(), 0) end)

RegisterNetEvent('noxa_admin:setFrozen', function(frozen)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, frozen)
    notify(frozen and '~b~Tu as été gelé par le staff.' or '~g~Tu as été dégelé.')
end)

-- Téléportation reçue du serveur (TP / bring)
RegisterNetEvent('noxa_admin:teleportTo', function(coords)
    local ped = PlayerPedId()
    lastPos = GetEntityCoords(ped)
    local z = coords.z
    SetEntityCoords(ped, coords.x, coords.y, z, false, false, false, false)
end)

-- Godmode
local function toggleGodmode()
    godmode = not godmode
    SetEntityInvincible(PlayerPedId(), godmode)
    SetPlayerInvincible(PlayerId(), godmode)
    notify(godmode and '~g~Godmode ON' or '~r~Godmode OFF')
end

-- Invisible
local function toggleInvisible()
    invisible = not invisible
    SetEntityVisible(PlayerPedId(), not invisible, false)
    notify(invisible and '~b~Invisible ON' or '~g~Invisible OFF')
end

-- Vitesse de course
local function setRunSpeed(mult)
    SetRunSprintMultiplierForPlayer(PlayerId(), mult + 0.0)
    SetSwimMultiplierForPlayer(PlayerId(), math.min(mult, 1.49))
    notify(('~b~Vitesse de course : x%.2f'):format(mult))
end

-- Réparer son véhicule
local function repairMyVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then return notify('~r~Tu n\'es pas dans un véhicule.') end
    SetVehicleFixed(veh); SetVehicleDeformationFixed(veh)
    SetVehicleEngineHealth(veh, 1000.0); SetVehicleBodyHealth(veh, 1000.0)
    SetVehiclePetrolTankHealth(veh, 1000.0); SetVehicleDirtLevel(veh, 0.0)
    SetVehicleUndriveable(veh, false)
    notify('~g~Véhicule réparé.')
end

-- =====================================================================
--  NOCLIP
-- =====================================================================
CreateThread(function()
    local speed = 1.0
    while true do
        if noclip then
            local ped = PlayerPedId()
            local ent = (GetVehiclePedIsIn(ped, false) ~= 0) and GetVehiclePedIsIn(ped, false) or ped
            SetEntityInvincible(ped, true)
            FreezeEntityPosition(ent, true)
            SetEntityCollision(ent, false, false)

            -- désactive les contrôles gênants
            DisableControlAction(0, 32, true); DisableControlAction(0, 33, true)
            DisableControlAction(0, 34, true); DisableControlAction(0, 35, true)
            DisableControlAction(0, 44, true)

            local x, y, z = table.unpack(GetEntityCoords(ent))
            local heading = GetEntityHeading(ent)
            local dx, dy = 0.0, 0.0

            -- vitesse modulable
            if IsDisabledControlPressed(0, 21) then speed = 3.0 else speed = 1.0 end       -- SHIFT = boost
            if IsDisabledControlPressed(0, 19) then speed = 0.3 end                         -- ALT = lent

            local cam = GetGameplayCamRot(2)
            local fwd = (IsDisabledControlPressed(0, 32) and 1.0 or 0.0) - (IsDisabledControlPressed(0, 33) and 1.0 or 0.0)
            local side = (IsDisabledControlPressed(0, 35) and 1.0 or 0.0) - (IsDisabledControlPressed(0, 34) and 1.0 or 0.0)
            local up = (IsDisabledControlPressed(0, 22) and 1.0 or 0.0) - (IsDisabledControlPressed(0, 36) and 1.0 or 0.0) -- ESPACE up / CTRL down

            local pitch = math.rad(cam.x)
            local yaw = math.rad(cam.z)
            -- direction caméra
            local fx = -math.sin(yaw) * math.cos(pitch)
            local fy = math.cos(yaw) * math.cos(pitch)
            local fz = math.sin(pitch)
            local rx = math.cos(yaw)
            local ry = math.sin(yaw)

            local nx = x + (fx * fwd + rx * side) * speed
            local ny = y + (fy * fwd + ry * side) * speed
            local nz = z + (fz * fwd + up) * speed

            SetEntityHeading(ent, cam.z)
            SetEntityCoordsNoOffset(ent, nx, ny, nz, true, true, true)
            Wait(0)
        else
            Wait(250)
        end
    end
end)

local function toggleNoclip()
    noclip = not noclip
    local ped = PlayerPedId()
    local ent = (GetVehiclePedIsIn(ped, false) ~= 0) and GetVehiclePedIsIn(ped, false) or ped
    if not noclip then
        FreezeEntityPosition(ent, false)
        SetEntityCollision(ent, true, true)
        if not godmode then SetEntityInvincible(ped, false) end
    end
    notify(noclip and '~g~Noclip ON (ZQSD/Souris, ESPACE/CTRL, SHIFT boost)' or '~r~Noclip OFF')
end

-- =====================================================================
--  SPECTATE
-- =====================================================================
RegisterNetEvent('noxa_admin:doSpectate', function(netId, coords, targetName)
    if spectating then
        -- déjà en spectate : on arrête
        NetworkSetInSpectatorMode(false, PlayerPedId())
        spectating = false
        return
    end
    local ped = PlayerPedId()
    lastPos = GetEntityCoords(ped)
    if coords then
        SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    end
    spectating = true
    notify(('~b~Spectate de %s — Retour arrière pour quitter.'):format(targetName or '?'))

    CreateThread(function()
        local tries = 0
        local target = 0
        while spectating and tries < 100 do
            if NetworkDoesEntityExistWithNetworkId(netId) then
                target = NetworkGetEntityFromNetworkId(netId)
                if target ~= 0 and DoesEntityExist(target) then break end
            end
            tries = tries + 1
            Wait(50)
        end
        if target ~= 0 and DoesEntityExist(target) then
            NetworkSetInSpectatorMode(true, target)
        end
        while spectating do
            if IsControlJustPressed(0, 177) then -- Retour arrière
                spectating = false
            end
            Wait(0)
        end
        NetworkSetInSpectatorMode(false, PlayerPedId())
        if lastPos then
            SetEntityCoords(PlayerPedId(), lastPos.x, lastPos.y, lastPos.z, false, false, false, false)
        end
        notify('~g~Fin du spectate.')
    end)
end)

-- =====================================================================
--  VÉHICULES
-- =====================================================================
RegisterNetEvent('noxa_admin:doSpawnVehicle', function(model)
    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        return notify('~r~Modèle de véhicule invalide : ' .. model)
    end
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 100 do RequestModel(hash); Wait(50); timeout = timeout + 1 end
    if not HasModelLoaded(hash) then return notify('~r~Impossible de charger le modèle.') end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local veh = CreateVehicle(hash, coords.x + 2.5, coords.y, coords.z, heading, true, false)
    SetVehicleOnGroundProperly(veh)
    SetPedIntoVehicle(ped, veh, -1)
    SetVehicleNumberPlateText(veh, 'NOXA')
    SetEntityAsMissionEntity(veh, true, true)
    SetModelAsNoLongerNeeded(hash)
    notify('~g~Véhicule spawné : ' .. model)
end)

local function getNearbyVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then return veh end
    local coords = GetEntityCoords(ped)
    veh = GetClosestVehicle(coords.x, coords.y, coords.z, 8.0, 0, 70)
    return veh ~= 0 and veh or nil
end

local function repairNearbyVehicle()
    local veh = getNearbyVehicle()
    if not veh then return notify('~r~Aucun véhicule proche.') end
    SetVehicleFixed(veh); SetVehicleDeformationFixed(veh)
    SetVehicleEngineHealth(veh, 1000.0); SetVehicleBodyHealth(veh, 1000.0)
    SetVehicleDirtLevel(veh, 0.0); SetVehicleUndriveable(veh, false)
    notify('~g~Véhicule réparé.')
end

local function cleanNearbyVehicle()
    local veh = getNearbyVehicle()
    if not veh then return notify('~r~Aucun véhicule proche.') end
    SetVehicleDirtLevel(veh, 0.0)
    notify('~g~Véhicule nettoyé.')
end

local function deleteFrontVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        local coords = GetEntityCoords(ped)
        local fwd = GetEntityForwardVector(ped)
        local target = vector3(coords.x + fwd.x * 4.0, coords.y + fwd.y * 4.0, coords.z)
        veh = GetClosestVehicle(target.x, target.y, target.z, 5.0, 0, 70)
    end
    if veh == 0 then return notify('~r~Aucun véhicule devant toi.') end
    NetworkRequestControlOfEntity(veh)
    local t = 0
    while not NetworkHasControlOfEntity(veh) and t < 20 do NetworkRequestControlOfEntity(veh); Wait(10); t = t + 1 end
    SetEntityAsMissionEntity(veh, true, true)
    DeleteVehicle(veh)
    notify('~g~Véhicule supprimé.')
end

local function boostNearbyVehicle()
    local veh = getNearbyVehicle()
    if not veh then return notify('~r~Aucun véhicule proche.') end
    SetVehicleEnginePowerMultiplier(veh, 30.0)
    ModifyVehicleTopSpeed(veh, 50.0)
    notify('~g~Boost moteur appliqué.')
end

-- =====================================================================
--  MONDE (météo / temps / annonces) appliqués par le serveur à tous
-- =====================================================================
RegisterNetEvent('noxa_admin:applyWeather', function(weather)
    SetOverrideWeather(weather)
    SetWeatherTypeOverTime(weather, 5.0)
    Wait(5000)
    SetWeatherTypeNowPersist(weather)
    SetWeatherTypeNow(weather)
end)

RegisterNetEvent('noxa_admin:applyTime', function(hour)
    NetworkOverrideClockTime(hour, 0, 0)
end)

RegisterNetEvent('noxa_admin:announce', function(text)
    SendNUIMessage({ action = 'announce', text = text })
    TriggerEvent('chat:addMessage', { color = { 255, 60, 60 }, multiline = true,
        args = { '📢 ANNONCE', text } })
end)

-- =====================================================================
--  PANELS NUI (ouverture des autres ressources Noxa)
-- =====================================================================
local function openAnticheat() TriggerServerEvent('noxa_ac:requestOpen') end
local function openGestion() TriggerServerEvent('noxa_gestion:requestOpen') end

-- =====================================================================
--  CONSTRUCTION DES MENUS (menuv)
-- =====================================================================
local mainMenu = MenuV:CreateMenu('NOXA ADMIN', 'Menu staff', 'topleft', 245, 65, 65, 'size-110', 'default', 'menuv', 'native')

local playersMenu     = MenuV:CreateMenu('Joueurs', 'Liste des connectés', 'topleft', 245, 65, 65, 'size-110', 'default', 'menuv', 'native')
local playerActMenu   = MenuV:CreateMenu('Joueur', 'Actions', 'topleft', 245, 65, 65, 'size-110', 'default', 'menuv', 'native')
local staffMenu       = MenuV:CreateMenu('Moi / Staff', 'Outils staff', 'topleft', 245, 65, 65, 'size-110', 'default', 'menuv', 'native')
local tpMenu          = MenuV:CreateMenu('Téléportation', 'Se déplacer', 'topleft', 245, 65, 65, 'size-110', 'default', 'menuv', 'native')
local tpLocMenu       = MenuV:CreateMenu('Lieux', 'Téléportation rapide', 'topleft', 245, 65, 65, 'size-110', 'default', 'menuv', 'native')
local vehMenu         = MenuV:CreateMenu('Véhicules', 'Gestion véhicules', 'topleft', 245, 65, 65, 'size-110', 'default', 'menuv', 'native')
local ecoMenu         = MenuV:CreateMenu('Économie', 'Gestion argent', 'topleft', 245, 65, 65, 'size-110', 'default', 'menuv', 'native')
local ecoPickMenu     = MenuV:CreateMenu('Économie', 'Choisir un joueur', 'topleft', 245, 65, 65, 'size-110', 'default', 'menuv', 'native')
local ecoActMenu      = MenuV:CreateMenu('Économie', 'Actions argent', 'topleft', 245, 65, 65, 'size-110', 'default', 'menuv', 'native')
local jobsMenu        = MenuV:CreateMenu('Jobs', 'Choisir un joueur', 'topleft', 245, 65, 65, 'size-110', 'default', 'menuv', 'native')
local jobListMenu     = MenuV:CreateMenu('Jobs', 'Choisir un job', 'topleft', 245, 65, 65, 'size-110', 'default', 'menuv', 'native')
local sanctionsMenu   = MenuV:CreateMenu('Sanctions', 'Warns & bans', 'topleft', 245, 65, 65, 'size-110', 'default', 'menuv', 'native')
local bansMenu        = MenuV:CreateMenu('Bans', 'Bans actifs', 'topleft', 245, 65, 65, 'size-110', 'default', 'menuv', 'native')
local annonceMenu     = MenuV:CreateMenu('Annonces', 'Communication', 'topleft', 245, 65, 65, 'size-110', 'default', 'menuv', 'native')
local weatherMenu     = MenuV:CreateMenu('Météo & Temps', 'Monde', 'topleft', 245, 65, 65, 'size-110', 'default', 'menuv', 'native')
local reportsMenu     = MenuV:CreateMenu('Reports', 'Signalements', 'topleft', 245, 65, 65, 'size-110', 'default', 'menuv', 'native')
local reportActMenu   = MenuV:CreateMenu('Report', 'Actions', 'topleft', 245, 65, 65, 'size-110', 'default', 'menuv', 'native')
local panelsMenu      = MenuV:CreateMenu('Panels NUI', 'Interfaces Noxa', 'topleft', 245, 65, 65, 'size-110', 'default', 'menuv', 'native')

-- État de sélection courant
local selected = { player = nil, job = nil, report = nil, ecoPlayer = nil }

-- ---------- MENU PRINCIPAL ----------
mainMenu:AddButton({ icon = '👥', label = 'Joueurs', value = playersMenu, description = 'Liste & actions joueurs' })
mainMenu:AddButton({ icon = '🧑‍✈️', label = 'Moi / Staff', value = staffMenu, description = 'Service, noclip, godmode...' })
mainMenu:AddButton({ icon = '📍', label = 'Téléportation', value = tpMenu })
mainMenu:AddButton({ icon = '🚗', label = 'Véhicules', value = vehMenu })
mainMenu:AddButton({ icon = '💰', label = 'Économie', value = ecoMenu })
mainMenu:AddButton({ icon = '💼', label = 'Jobs', value = jobsMenu })
mainMenu:AddButton({ icon = '⚖️', label = 'Sanctions', value = sanctionsMenu })
mainMenu:AddButton({ icon = '📢', label = 'Annonces', value = annonceMenu })
mainMenu:AddButton({ icon = '🌦️', label = 'Météo & Temps', value = weatherMenu })
mainMenu:AddButton({ icon = '🚨', label = 'Reports', value = reportsMenu })
mainMenu:AddButton({ icon = '🖥️', label = 'Panels NUI', value = panelsMenu })

mainMenu:On('open', function(m) lastMenu = m end)

-- ---------- JOUEURS ----------
playersMenu:On('open', function(m)
    lastMenu = m
    m:ClearItems()
    ESX.TriggerServerCallback('noxa_admin:getPlayers', function(players)
        if #players == 0 then m:AddButton({ label = 'Aucun joueur', disabled = true }); return end
        for _, p in ipairs(players) do
            m:AddButton({
                label = ('[%d] %s'):format(p.id, p.name),
                value = playerActMenu,
                description = ('Ping %d · %s · $%s'):format(p.ping, p.jobLabel or p.job, p.cash),
                select = function() selected.player = p end,
            })
        end
    end)
end)

playerActMenu:On('open', function(m)
    lastMenu = m
    m:ClearItems()
    local p = selected.player
    if not p then m:AddButton({ label = 'Aucun joueur', disabled = true }); return end
    m.Subtitle = ('[%d] %s'):format(p.id, p.name)

    m:AddButton({ icon = '🧊', label = 'Geler', select = function() TriggerServerEvent('noxa_admin:freeze', p.id, true) end })
    m:AddButton({ icon = '🔥', label = 'Dégeler', select = function() TriggerServerEvent('noxa_admin:freeze', p.id, false) end })
    m:AddButton({ icon = '➡️', label = 'Se TP à lui', select = function() TriggerServerEvent('noxa_admin:tpToPlayer', p.id) end })
    m:AddButton({ icon = '⬅️', label = 'Le TP à moi', select = function() TriggerServerEvent('noxa_admin:bringPlayer', p.id) end })
    m:AddButton({ icon = '👁️', label = 'Spectate', select = function() TriggerServerEvent('noxa_admin:spectate', p.id) end })
    m:AddButton({ icon = '❤️', label = 'Soigner', select = function() TriggerServerEvent('noxa_admin:heal', p.id) end })
    m:AddButton({ icon = '✨', label = 'Réanimer', select = function() TriggerServerEvent('noxa_admin:revive', p.id) end })
    m:AddButton({ icon = '💀', label = 'Tuer (admin)', select = function() TriggerServerEvent('noxa_admin:kill', p.id) end })
    m:AddButton({ icon = '⚠️', label = 'Avertir (warn)', select = function()
        openPrompt('Avertir ' .. p.name, { { name = 'reason', label = 'Raison', type = 'text' } }, function(v)
            if v and v.reason then TriggerServerEvent('noxa_admin:warn', p.id, v.reason) end
        end)
    end })
    m:AddButton({ icon = '👢', label = 'Kick', select = function()
        openPrompt('Kick ' .. p.name, { { name = 'reason', label = 'Raison', type = 'text' } }, function(v)
            if v then TriggerServerEvent('noxa_admin:kick', p.id, v.reason) end
        end)
    end })
    m:AddButton({ icon = '🔨', label = 'Ban', select = function()
        openPrompt('Ban ' .. p.name, {
            { name = 'reason', label = 'Raison', type = 'text' },
            { name = 'duration', label = 'Durée minutes (0 = permanent)', type = 'number', value = '0' },
        }, function(v)
            if v then TriggerServerEvent('noxa_admin:ban', p.id, v.reason, v.duration) end
        end)
    end })
    m:AddButton({ icon = '💵', label = 'Set argent (admin)', select = function()
        openPrompt('Set argent ' .. p.name, {
            { name = 'account', label = 'Compte (money/bank/black_money)', type = 'text', value = 'bank' },
            { name = 'amount', label = 'Montant', type = 'number', value = '0' },
        }, function(v)
            if v then TriggerServerEvent('noxa_admin:setMoney', p.id, v.account, v.amount) end
        end)
    end })
    m:AddButton({ icon = '📦', label = 'Donner item', select = function()
        openPrompt('Donner item à ' .. p.name, {
            { name = 'item', label = 'Nom item', type = 'text' },
            { name = 'count', label = 'Quantité', type = 'number', value = '1' },
        }, function(v)
            if v then TriggerServerEvent('noxa_admin:giveItem', p.id, v.item, v.count) end
        end)
    end })
    m:AddButton({ icon = '💼', label = 'Set job + grade', select = function()
        selected.player = p
        jobListMenu:Open()
    end })
    m:AddButton({ icon = '🆔', label = 'Voir identifiers', select = function()
        ESX.TriggerServerCallback('noxa_admin:getIdentifiers', function(ids)
            notify('~b~Identifiers de ' .. p.name .. ' :\n' .. table.concat(ids, '\n'))
        end, p.id)
    end })
end)

-- ---------- MOI / STAFF ----------
staffMenu:On('open', function(m)
    lastMenu = m
    m:ClearItems()
    m:AddButton({ icon = onDuty and '🟢' or '⚪', label = onDuty and 'Quitter le service' or 'Prendre le service',
        select = function() TriggerServerEvent('noxa_admin:toggleDuty') end })
    m:AddButton({ icon = '🕊️', label = (noclip and 'Noclip : ON' or 'Noclip : OFF'), select = function() toggleNoclip(); m:Close() end })
    m:AddButton({ icon = '🛡️', label = (godmode and 'Godmode : ON' or 'Godmode : OFF'), select = function() toggleGodmode() end })
    m:AddButton({ icon = '🫥', label = (invisible and 'Invisible : ON' or 'Invisible : OFF'), select = function() toggleInvisible() end })
    m:AddButton({ icon = '❤️', label = 'Se soigner', select = function() healSelf(true) end })
    m:AddButton({ icon = '🔧', label = 'Réparer mon véhicule', select = function() repairMyVehicle() end })
    m:AddSlider({ icon = '🏃', label = 'Vitesse de course', values = (function()
        local vals = {}
        for _, s in ipairs(Config.RunSpeeds) do vals[#vals + 1] = { label = s.label, value = s.value } end
        return vals
    end)(), select = function(_, value) setRunSpeed(value) end })
    m:AddButton({ icon = '👮', label = 'Staff en service', select = function()
        ESX.TriggerServerCallback('noxa_admin:getStaffOnDuty', function(list)
            if #list == 0 then return notify('~b~Aucun staff en service.') end
            local txt = ''
            for _, s in ipairs(list) do txt = txt .. ('[%d] %s\n'):format(s.id, s.name) end
            notify('~b~Staff en service :\n' .. txt)
        end)
    end })
    m:AddButton({ icon = '🗣️', label = 'Message OOC staff', select = function()
        openPrompt('Message OOC staff', { { name = 'msg', label = 'Message', type = 'text' } }, function(v)
            if v and v.msg then TriggerServerEvent('noxa_admin:staffOOC', v.msg) end
        end)
    end })
end)

-- ---------- TÉLÉPORTATION ----------
tpMenu:On('open', function(m) lastMenu = m end)
tpMenu:AddButton({ icon = '📌', label = 'Vers le waypoint', select = function()
    local blip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blip) then return notify('~r~Aucun waypoint défini.') end
    local coords = GetBlipInfoIdCoord(blip)
    local ped = PlayerPedId()
    lastPos = GetEntityCoords(ped)
    -- trouve un Z de sol valide
    local found, z = false, coords.z
    for h = 1000, 0, -25 do
        SetEntityCoordsNoOffset(ped, coords.x, coords.y, h + 0.0, false, false, false)
        Wait(50)
        found, z = GetGroundZFor_3dCoord(coords.x, coords.y, h + 0.0, false)
        if found then break end
    end
    SetEntityCoords(ped, coords.x, coords.y, (found and z or coords.z), false, false, false, false)
    notify('~g~Téléporté au waypoint.')
end })
tpMenu:AddButton({ icon = '🎯', label = 'Vers des coords', select = function()
    openPrompt('Téléportation coords', {
        { name = 'x', label = 'X', type = 'number' },
        { name = 'y', label = 'Y', type = 'number' },
        { name = 'z', label = 'Z', type = 'number' },
    }, function(v)
        if not v then return end
        local x, y, z = tonumber(v.x), tonumber(v.y), tonumber(v.z)
        if not x or not y or not z then return notify('~r~Coords invalides.') end
        local ped = PlayerPedId()
        lastPos = GetEntityCoords(ped)
        SetEntityCoords(ped, x, y, z, false, false, false, false)
    end)
end })
tpMenu:AddButton({ icon = '↩️', label = 'Retour position précédente', select = function()
    if not lastPos then return notify('~r~Aucune position précédente.') end
    SetEntityCoords(PlayerPedId(), lastPos.x, lastPos.y, lastPos.z, false, false, false, false)
    notify('~g~Retour à la position précédente.')
end })
tpMenu:AddButton({ icon = '🏙️', label = 'Lieux prédéfinis', value = tpLocMenu })

for _, loc in ipairs(Config.Locations) do
    tpLocMenu:AddButton({ icon = '📍', label = loc.label, select = function()
        local ped = PlayerPedId()
        lastPos = GetEntityCoords(ped)
        SetEntityCoords(ped, loc.coords.x, loc.coords.y, loc.coords.z, false, false, false, false)
        notify('~g~Téléporté : ' .. loc.label)
    end })
end
tpLocMenu:On('open', function(m) lastMenu = m end)

-- ---------- VÉHICULES ----------
vehMenu:On('open', function(m) lastMenu = m end)
vehMenu:AddButton({ icon = '🚘', label = 'Spawn par modèle', select = function()
    openPrompt('Spawn véhicule', { { name = 'model', label = 'Modèle (ex: adder)', type = 'text' } }, function(v)
        if v and v.model and v.model ~= '' then TriggerServerEvent('noxa_admin:spawnVehicle', v.model) end
    end)
end })
vehMenu:AddSlider({ icon = '⭐', label = 'Spawn rapide', values = (function()
    local vals = {}
    for _, vh in ipairs(Config.QuickVehicles) do vals[#vals + 1] = { label = vh.label, value = vh.value } end
    return vals
end)(), select = function(_, value) TriggerServerEvent('noxa_admin:spawnVehicle', value) end })
vehMenu:AddButton({ icon = '🔧', label = 'Réparer', select = function() repairNearbyVehicle() end })
vehMenu:AddButton({ icon = '🧼', label = 'Nettoyer', select = function() cleanNearbyVehicle() end })
vehMenu:AddButton({ icon = '🗑️', label = 'Supprimer celui devant moi', select = function() deleteFrontVehicle() end })
vehMenu:AddButton({ icon = '🔡', label = 'Plaque personnalisée', select = function()
    local veh = getNearbyVehicle()
    if not veh then return notify('~r~Aucun véhicule proche.') end
    openPrompt('Plaque', { { name = 'plate', label = 'Plaque (8 max)', type = 'text' } }, function(v)
        if v and v.plate then SetVehicleNumberPlateText(veh, v.plate:sub(1, 8)); notify('~g~Plaque modifiée.') end
    end)
end })
vehMenu:AddButton({ icon = '🎛️', label = 'Extra (on/off)', select = function()
    local veh = getNearbyVehicle()
    if not veh then return notify('~r~Aucun véhicule proche.') end
    openPrompt('Extra véhicule', {
        { name = 'id', label = 'Numéro extra (1-14)', type = 'number', value = '1' },
        { name = 'state', label = 'État (1 = on, 0 = off)', type = 'number', value = '1' },
    }, function(v)
        if not v then return end
        local id, st = tonumber(v.id), tonumber(v.state)
        if id and DoesExtraExist(veh, id) then SetVehicleExtra(veh, id, st == 1 and 0 or 1); notify('~g~Extra modifié.') end
    end)
end })
vehMenu:AddButton({ icon = '🚀', label = 'Boost moteur', select = function() boostNearbyVehicle() end })

-- ---------- ÉCONOMIE ----------
ecoMenu:On('open', function(m) lastMenu = m end)
ecoMenu:AddButton({ icon = '💸', label = 'Donner / voir argent (joueur)', value = ecoPickMenu })
ecoMenu:AddButton({ icon = '🌍', label = 'Donner argent à TOUS', select = function()
    openPrompt('Donner à tous', {
        { name = 'account', label = 'Compte (money/bank)', type = 'text', value = 'bank' },
        { name = 'amount', label = 'Montant', type = 'number', value = '0' },
    }, function(v)
        if not v then return end
        ESX.TriggerServerCallback('noxa_admin:getPlayers', function(players)
            for _, p in ipairs(players) do TriggerServerEvent('noxa_admin:giveMoney', p.id, v.account, v.amount) end
            notify('~g~Argent distribué à tous les joueurs.')
        end)
    end)
end })

ecoPickMenu:On('open', function(m)
    lastMenu = m
    m:ClearItems()
    ESX.TriggerServerCallback('noxa_admin:getPlayers', function(players)
        if #players == 0 then m:AddButton({ label = 'Aucun joueur', disabled = true }); return end
        for _, p in ipairs(players) do
            m:AddButton({ label = ('[%d] %s'):format(p.id, p.name), value = ecoActMenu,
                description = ('$%s | banque $%s'):format(p.cash, p.bank),
                select = function() selected.ecoPlayer = p end })
        end
    end)
end)

-- Actions argent pour le joueur sélectionné (voir solde / donner)
ecoActMenu:On('open', function(m)
    lastMenu = m
    m:ClearItems()
    local p = selected.ecoPlayer
    if not p then m:AddButton({ label = 'Aucun joueur', disabled = true }); return end
    m.Subtitle = ('[%d] %s'):format(p.id, p.name)

    m:AddButton({ icon = '🔎', label = 'Voir solde (live)', select = function()
        ESX.TriggerServerCallback('noxa_admin:getBalance', function(b)
            if not b then return notify('~r~Joueur introuvable.') end
            notify(('~b~Solde de %s :\n~g~Cash : $%s\n~g~Banque : $%s\n~r~Sale : $%s')
                :format(b.name, b.cash, b.bank, b.black))
        end, p.id)
    end })
    m:AddButton({ icon = '💸', label = 'Donner de l\'argent', select = function()
        openPrompt('Donner — ' .. p.name, {
            { name = 'account', label = 'Compte (money/bank/black_money)', type = 'text', value = 'bank' },
            { name = 'amount', label = 'Montant à donner', type = 'number', value = '0' },
        }, function(v)
            if v then TriggerServerEvent('noxa_admin:giveMoney', p.id, v.account, v.amount) end
        end)
    end })
    m:AddButton({ icon = '💵', label = 'Set argent (admin)', select = function()
        openPrompt('Set argent — ' .. p.name, {
            { name = 'account', label = 'Compte (money/bank/black_money)', type = 'text', value = 'bank' },
            { name = 'amount', label = 'Nouveau montant', type = 'number', value = '0' },
        }, function(v)
            if v then TriggerServerEvent('noxa_admin:setMoney', p.id, v.account, v.amount) end
        end)
    end })
end)

-- ---------- JOBS ----------
jobsMenu:On('open', function(m)
    lastMenu = m
    m:ClearItems()
    ESX.TriggerServerCallback('noxa_admin:getPlayers', function(players)
        for _, p in ipairs(players) do
            m:AddButton({ label = ('[%d] %s'):format(p.id, p.name), value = jobListMenu,
                description = 'Job actuel : ' .. (p.jobLabel or p.job),
                select = function() selected.player = p end })
        end
    end)
end)

jobListMenu:On('open', function(m)
    lastMenu = m
    m:ClearItems()
    if not selected.player then m:AddButton({ label = 'Choisis un joueur d\'abord', disabled = true }); return end
    m.Subtitle = 'Job pour ' .. selected.player.name
    ESX.TriggerServerCallback('noxa_admin:getJobs', function(jobs)
        for _, job in ipairs(jobs) do
            local gradeValues = {}
            for _, g in ipairs(job.grades) do
                gradeValues[#gradeValues + 1] = { label = ('%s (grade %d)'):format(g.label, g.grade), value = g.grade }
            end
            m:AddSlider({ label = job.label, description = 'Choisis le grade puis valide', values = gradeValues,
                select = function(_, grade)
                    TriggerServerEvent('noxa_admin:setJob', selected.player.id, job.name, grade)
                end })
        end
    end)
end)

-- ---------- SANCTIONS ----------
sanctionsMenu:On('open', function(m) lastMenu = m end)
sanctionsMenu:AddButton({ icon = '📋', label = 'Bans actifs / Débannir', value = bansMenu })
sanctionsMenu:AddButton({ icon = '🔎', label = 'Historique warns d\'un joueur', select = function()
    ESX.TriggerServerCallback('noxa_admin:getPlayers', function(players)
        -- on réutilise un prompt simple : saisir l'id
        openPrompt('Voir warns', { { name = 'id', label = 'ID joueur connecté', type = 'number' } }, function(v)
            if not v then return end
            local target
            for _, p in ipairs(players) do if p.id == tonumber(v.id) then target = p break end end
            if not target then return notify('~r~Joueur introuvable.') end
            ESX.TriggerServerCallback('noxa_admin:getWarns', function(warns)
                if #warns == 0 then return notify('~b~Aucun warn pour ' .. target.name) end
                local txt = ''
                for _, w in ipairs(warns) do txt = txt .. ('• %s (%s)\n'):format(w.reason, w.staff_name or '?') end
                notify('~y~Warns de ' .. target.name .. ' :\n' .. txt)
            end, target.identifier)
        end)
    end)
end })

bansMenu:On('open', function(m)
    lastMenu = m
    m:ClearItems()
    ESX.TriggerServerCallback('noxa_admin:getBans', function(bans)
        if #bans == 0 then m:AddButton({ label = 'Aucun ban', disabled = true }); return end
        for _, b in ipairs(bans) do
            local until_ = b.expire and tostring(b.expire) or 'PERMANENT'
            m:AddButton({ label = ('#%d %s'):format(b.id, b.player_name or '?'),
                description = ('%s | %s | par %s'):format(until_, b.reason or '', b.staff_name or '?'),
                select = function()
                    openPrompt('Débannir #' .. b.id .. ' ?', {
                        { name = 'confirm', label = 'Tape OUI pour confirmer', type = 'text' } }, function(v)
                        if v and (v.confirm or ''):upper() == 'OUI' then TriggerServerEvent('noxa_admin:unban', b.id) end
                    end)
                end })
        end
    end)
end)

-- ---------- ANNONCES ----------
annonceMenu:On('open', function(m) lastMenu = m end)
annonceMenu:AddButton({ icon = '📢', label = 'Annonce serveur (admin)', select = function()
    openPrompt('Annonce serveur', { { name = 'msg', label = 'Message', type = 'text' } }, function(v)
        if v and v.msg then TriggerServerEvent('noxa_admin:announce', v.msg) end
    end)
end })
annonceMenu:AddButton({ icon = '🗣️', label = 'Message OOC staff', select = function()
    openPrompt('OOC staff', { { name = 'msg', label = 'Message', type = 'text' } }, function(v)
        if v and v.msg then TriggerServerEvent('noxa_admin:staffOOC', v.msg) end
    end)
end })

-- ---------- MÉTÉO & TEMPS ----------
weatherMenu:On('open', function(m) lastMenu = m end)
weatherMenu:AddSlider({ icon = '🌦️', label = 'Météo', values = (function()
    local vals = {}
    for _, w in ipairs(Config.Weathers) do vals[#vals + 1] = { label = w, value = w } end
    return vals
end)(), select = function(_, value) TriggerServerEvent('noxa_admin:setWeather', value) end })
weatherMenu:AddSlider({ icon = '🕐', label = 'Heure', values = (function()
    local vals = {}
    for h = 0, 23 do vals[#vals + 1] = { label = ('%02dh00'):format(h), value = h } end
    return vals
end)(), select = function(_, value) TriggerServerEvent('noxa_admin:setTime', value) end })

-- ---------- REPORTS ----------
reportsMenu:On('open', function(m)
    lastMenu = m
    m:ClearItems()
    ESX.TriggerServerCallback('noxa_admin:getReports', function(reports)
        if #reports == 0 then m:AddButton({ label = 'Aucun report ouvert', disabled = true }); return end
        for _, r in ipairs(reports) do
            local mins = math.floor((r.ageSec or 0) / 60)
            local statut = r.status == 'claimed' and ('[pris: ' .. (r.claimedBy or '?') .. ']') or ''
            m:AddButton({
                label = ('#%d %s %s'):format(r.id, r.name, statut),
                value = reportActMenu,
                description = ('%s · il y a %d min'):format(r.message, mins),
                select = function() selected.report = r end,
            })
        end
    end)
end)

reportActMenu:On('open', function(m)
    lastMenu = m
    m:ClearItems()
    local r = selected.report
    if not r then m:AddButton({ label = 'Aucun report', disabled = true }); return end
    m.Subtitle = ('#%d %s'):format(r.id, r.name)
    m:AddButton({ label = '💬 ' .. r.message, disabled = true })

    if r.onlineSrc then
        m:AddButton({ icon = '➡️', label = 'Se TP au joueur', select = function() TriggerServerEvent('noxa_admin:tpToPlayer', r.onlineSrc) end })
        m:AddButton({ icon = '⬅️', label = 'TP le joueur à moi', select = function() TriggerServerEvent('noxa_admin:bringPlayer', r.onlineSrc) end })
        m:AddButton({ icon = '👁️', label = 'Spectate', select = function() TriggerServerEvent('noxa_admin:spectate', r.onlineSrc) end })
    else
        m:AddButton({ label = '(joueur déconnecté)', disabled = true })
    end
    m:AddButton({ icon = '✋', label = 'Prendre en charge (claim)', select = function() TriggerServerEvent('noxa_admin:report:claim', r.id) end })
    m:AddButton({ icon = '💬', label = 'Répondre au joueur', select = function()
        openPrompt('Répondre au report #' .. r.id, { { name = 'msg', label = 'Message privé', type = 'text' } }, function(v)
            if v and v.msg then TriggerServerEvent('noxa_admin:report:reply', r.id, v.msg) end
        end)
    end })
    m:AddButton({ icon = '✅', label = 'Clôturer', select = function() TriggerServerEvent('noxa_admin:report:close', r.id) end })
end)

-- ---------- PANELS NUI ----------
panelsMenu:On('open', function(m) lastMenu = m end)
panelsMenu:AddButton({ icon = '🛡️', label = 'Panel Anti-Cheat', select = function() openAnticheat() end })
panelsMenu:AddButton({ icon = '🗂️', label = 'Panel Gestion serveur', select = function() openGestion() end })

-- =====================================================================
--  ÉTAT PRISE DE SERVICE
-- =====================================================================
RegisterNetEvent('noxa_admin:dutyState', function(state) onDuty = state == true end)

-- =====================================================================
--  OUVERTURE DU MENU (F10) — vérifie le grade côté serveur
-- =====================================================================
RegisterCommand('noxa_admin_menu', function()
    ESX.TriggerServerCallback('noxa_admin:getMyLevel', function(data)
        myLevel = data.level or 0
        onDuty = data.onDuty == true
        if myLevel <= 0 then
            return notify('~r~Accès refusé : tu n\'es pas staff.')
        end
        mainMenu:Open()
    end)
end, false)
RegisterKeyMapping('noxa_admin_menu', 'Ouvrir le menu admin NOXA', 'keyboard', Config.MenuKey)

-- /duty en raccourci texte
RegisterCommand('duty', function() TriggerServerEvent('noxa_admin:toggleDuty') end, false)

-- Libère le focus si la ressource s'arrête
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        SetNuiFocus(false, false)
        if noclip then noclip = false end
    end
end)

print('^2[NOXA ADMIN]^7 Client chargé. Ouvre le menu avec ' .. Config.MenuKey .. '.')
