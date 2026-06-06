-- =====================================================================
--  NOXA FA — Panel Anti-Cheat · serveur (ESX Legacy natif)
-- =====================================================================
--  - Données LIVE vers le panel (joueurs, détections, bans, logs, staff)
--  - Actions staff : surveiller / avertir / expulser / bannir / résoudre
--  - Détections server-side : speed hack, warp/teleport, god mode,
--    injection d'argent, spawns script (ignore le trafic ambiant 1-5)
--  - Persistance : détections -> noxa_ac_detections ; bans -> noxa_bans
--    (table unifiée partagée avec noxa_admin, qui applique le ban à la
--    connexion -> on ne re-défère PAS ici).
--  Permission : ACE noxa.anticheat
-- =====================================================================

local ESX = exports['es_extended']:getSharedObject()

local ACE_PERM    = 'noxa.anticheat'
local SERVER_NAME = GetConvar('sv_projectName', 'NOXA FA')
local MAX_SLOTS   = GetConvarInt('sv_maxclients', 48)

-- ----------------------------------------------------------------- CONFIG
local Config = {
    pushMs      = 2000,    -- fréquence d'envoi des données live au panel
    scanMs      = 1000,    -- fréquence du moteur de détection

    -- Seuils volontairement conservateurs (anti faux-positif). On FLAGGE,
    -- les auto-actions restent désactivées par défaut : le staff tranche.
    speedMax    = 90.0,    -- m/s au sol soutenu (~324 km/h) -> speed hack
    speedHits   = 3,       -- nb de scans consécutifs au-dessus du seuil
    warpDist    = 300.0,   -- m parcourus en 1 scan -> teleport/warp
    moneyJump   = 250000,  -- gain instantané (cash+banque) sans transaction
    spawnMax    = 8,       -- entités script créées par un joueur / fenêtre
    spawnWindow = 5,       -- secondes de la fenêtre de spawn

    autoKick    = false,   -- expulser auto si confiance >= autoKickConf
    autoKickConf= 90,
    keepDet     = 60,      -- détections gardées en mémoire pour le panel
    keepLogs    = 60,      -- entrées du flux de logs (ring buffer mémoire)
}

-- ------------------------------------------------------------------ STATE
local openPanels  = {}     -- [src] = true : staff ayant le panel ouvert
local detections  = {}     -- liste live (la plus récente en tête)
local watchlist   = {}     -- [identifier] = { ... }
local pstate      = {}     -- [src] = { lastCoords, lastMoney, connectedAt, ... }
local staffActs   = {}     -- [identifier] = nombre d'actions staff
local playerSeries= {}     -- historique du nombre de joueurs (24 points)
local acLogs      = {}     -- flux de logs live (ring buffer, plus récent en tête)
local detRefSeq   = 0

-- --------------------------------------------------------------- HELPERS
local function isStaff(src)
    return IsPlayerAceAllowed(src, ACE_PERM)
end

local function initials(name)
    if not name or name == '' then return '?' end
    local parts = {}
    for w in name:gmatch('%S+') do parts[#parts + 1] = w end
    local out = (parts[1] and parts[1]:sub(1, 1) or '') .. (parts[2] and parts[2]:sub(1, 1) or '')
    if out == '' then out = name:sub(1, 1) end
    return out:upper()
end

local function statusFromTrust(trust, flags)
    if trust < 40 or flags >= 4 then return 'critical' end
    if trust < 75 or flags >= 1 then return 'warn' end
    return 'clean'
end

local function nowMs()  return os.time() * 1000 end

local function nextDetRef()
    detRefSeq = detRefSeq + 1
    return ('D-%04X'):format(0x9E00 + detRefSeq)
end

local function getIdentifier(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then return xPlayer.identifier end
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        if id:sub(1, 8) == 'license:' then return id end
    end
    return nil
end

local function idOfType(src, prefix)
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        if id:sub(1, #prefix) == prefix then return id end
    end
    return nil
end

-- ------------------------------------------------------------------- LOGS
-- Flux temps réel du panel : ring buffer mémoire (pas de table dédiée ;
-- noxa_ac_logs existe déjà avec un autre schéma -> on n'y touche pas).
local function pushLog(tag, level, msg)
    table.insert(acLogs, 1, { time = os.date('%H:%M:%S'), tag = tag, level = level, msg = msg })
    while #acLogs > Config.keepLogs do table.remove(acLogs) end
end

-- Audit durable : table noxa_ac_logs (survit aux redémarrages, contrairement
-- au ring buffer mémoire). On y persiste les détections et les sanctions
-- staff (violation = type, score = confiance, action = flag/kick/ban/warn...).
local function logDb(identifier, name, violation, score, action)
    MySQL.insert(
        'INSERT INTO noxa_ac_logs (identifier, name, violation, score, action) VALUES (?,?,?,?,?)',
        { identifier, name, violation, math.floor(tonumber(score) or 0), action }
    )
end

-- ------------------------------------------------------ TRUST / FLAGS
-- flags = nb de détections non résolues pour ce joueur ; trust en dérive.
local function flagsFor(identifier)
    local n = 0
    for _, d in ipairs(detections) do
        if d.identifier == identifier and d.status ~= 'resolved' then n = n + 1 end
    end
    return n
end

local function trustFor(identifier)
    local f = flagsFor(identifier)
    local t = 95 - (f * 18)
    if watchlist[identifier] then t = t - 10 end
    if t < 5 then t = 5 end
    if t > 99 then t = 99 end
    return t
end

-- --------------------------------------------------- BUILD : JOUEURS LIVE
local function buildPlayers()
    local list = {}
    for _, src in ipairs(ESX.GetPlayers()) do
        local xPlayer = ESX.GetPlayerFromId(src)
        local st = pstate[src]
        local identifier = xPlayer and xPlayer.identifier or getIdentifier(src)
        local name = (xPlayer and xPlayer.getName()) or GetPlayerName(src) or ('Joueur #' .. src)
        local flags = flagsFor(identifier)
        local trust = trustFor(identifier)
        local ped = GetPlayerPed(src)
        local c = ped ~= 0 and GetEntityCoords(ped) or vector3(0, 0, 0)
        local mins = st and math.floor((os.time() - st.connectedAt) / 60) or 0
        local discord = idOfType(src, 'discord:')

        list[#list + 1] = {
            id        = src,
            name      = name,
            initials  = initials(name),
            license   = identifier or 'license:?',
            steam     = idOfType(src, 'steam:') or '—',
            discord   = discord and discord:gsub('discord:', '') or '—',
            ip        = 'masquée',  -- sv_endpointPrivacy
            ping      = GetPlayerPing(src) or 0,
            playtime  = ('%dh %02dm'):format(math.floor(mins / 60), mins % 60),
            trust     = trust,
            flags     = flags,
            status    = statusFromTrust(trust, flags),
            job       = (xPlayer and xPlayer.job and (xPlayer.job.label or xPlayer.job.name)) or 'Civil',
            joined    = st and st.joined or '—',
            -- position transmise pour usages staff futurs (TP/contexte)
            pos       = { x = math.floor(c.x), y = math.floor(c.y), z = math.floor(c.z) },
        }
    end
    return list
end

-- ----------------------------------------------------------- BUILD : STAFF
local function buildStaff()
    local out = {}
    for _, src in ipairs(ESX.GetPlayers()) do
        if isStaff(src) then
            local xPlayer = ESX.GetPlayerFromId(src)
            local name = (xPlayer and xPlayer.getName()) or GetPlayerName(src)
            local identifier = xPlayer and xPlayer.identifier or getIdentifier(src)
            local st = pstate[src]
            local mins = st and math.floor((os.time() - st.connectedAt) / 60) or 0
            local role = 'Modérateur'
            if IsPlayerAceAllowed(src, 'group.admin') then role = 'Admin' end
            if IsPlayerAceAllowed(src, 'noxa.gestion') then role = 'Founder' end
            out[#out + 1] = {
                name = name, initials = initials(name), role = role, online = true,
                actions = staffActs[identifier] or 0,
                since = ('%dh %02dm'):format(math.floor(mins / 60), mins % 60),
            }
        end
    end
    return out
end

-- ----------------------------------------------------------- BUILD : STATS
local function buildStats()
    local labelMap = {
        ['Aimbot'] = 'Aimbot', ['Speed Hack'] = 'Speed Hack', ['Lua Injection'] = 'Lua Inj.',
        ['God Mode'] = 'God Mode', ['Money Exploit'] = 'Money', ['Teleport'] = 'Teleport',
        ['Noclip'] = 'Noclip', ['Weapon Spawn'] = 'Weapon',
    }
    local order = { 'Aimbot', 'Speed Hack', 'Lua Inj.', 'God Mode', 'Money', 'Teleport', 'Noclip', 'Weapon' }
    local counts = {}
    for _, d in ipairs(detections) do
        local lbl = labelMap[d.type] or d.type
        counts[lbl] = (counts[lbl] or 0) + 1
    end
    local detByType = {}
    for _, lbl in ipairs(order) do detByType[#detByType + 1] = { label = lbl, value = counts[lbl] or 0 } end

    -- tendance : 12 derniers buckets de 5 min
    local trend, base = {}, os.time()
    for i = 11, 0, -1 do
        local hi, lo = base - i * 300, base - (i + 1) * 300
        local n = 0
        for _, d in ipairs(detections) do
            local ts = (d.time or 0) / 1000
            if ts <= hi and ts > lo then n = n + 1 end
        end
        trend[#trend + 1] = n
    end

    return { playerSeries = playerSeries, detByType = detByType, detTrend = trend }
end

-- --------------------------------------------------------- BUILD : BANS
-- Lecture depuis la table unifiée noxa_bans (partagée avec noxa_admin).
local function fetchBans(cb)
    MySQL.query([[SELECT id, player_name, license, identifier, reason, staff_name, created_at, expire,
                  (expire IS NULL OR expire > NOW()) AS is_active
                  FROM noxa_bans ORDER BY created_at DESC LIMIT 50]],
        {}, function(rows)
            local bans = {}
            for _, r in ipairs(rows or {}) do
                bans[#bans + 1] = {
                    id = 'B-' .. tostring(r.id),
                    player = r.player_name or '—',
                    license = r.license or r.identifier or '—',
                    reason = r.reason or 'Anti-Cheat',
                    by = r.staff_name or 'Anti-Cheat',
                    date = r.created_at and tostring(r.created_at):sub(1, 10) or '—',
                    duration = (r.expire == nil) and 'Permanent' or tostring(r.expire):sub(1, 10),
                    active = (r.is_active == 1 or r.is_active == true),
                }
            end
            cb(bans)
        end)
end

local function buildWatchlist()
    local out = {}
    for identifier, w in pairs(watchlist) do
        out[#out + 1] = {
            pid = w.pid, name = w.name, initials = initials(w.name),
            trust = trustFor(identifier), since = w.since, note = w.note, by = w.by,
        }
    end
    return out
end

-- --------------------------------------------------------- PUSH AU PANEL
local function buildAndPush()
    if next(openPanels) == nil then return end
    local players = buildPlayers()
    fetchBans(function(bans)
        local payload = {
            serverName = SERVER_NAME,
            maxSlots   = MAX_SLOTS,
            players    = players,
            detections = detections,
            bans       = bans,
            logs       = acLogs,
            staff      = buildStaff(),
            watchlist  = buildWatchlist(),
            stats      = buildStats(),
        }
        for src in pairs(openPanels) do
            TriggerClientEvent('noxa_ac:data', src, payload)
        end
    end)
end

-- ------------------------------------------------------------ DÉTECTIONS
local function addDetection(src, dtype, severity, confidence, detail)
    local xPlayer = ESX.GetPlayerFromId(src)
    local identifier = xPlayer and xPlayer.identifier or getIdentifier(src)
    local name = (xPlayer and xPlayer.getName()) or GetPlayerName(src) or ('Joueur #' .. src)

    -- anti-spam : pas deux fois le même type pour le même joueur en 30s
    for _, d in ipairs(detections) do
        if d.identifier == identifier and d.type == dtype and (nowMs() - d.time) < 30000 then
            return
        end
    end

    local ref = nextDetRef()
    local det = {
        id = ref, type = dtype, player = name, pid = src,
        identifier = identifier, severity = severity, status = 'open',
        time = nowMs(), detail = detail, confidence = confidence,
    }
    table.insert(detections, 1, det)
    while #detections > Config.keepDet do table.remove(detections) end

    pushLog('DETECT', severity, ('%s — %s (#%s) %d%%'):format(dtype, name, src, confidence))
    MySQL.insert(
        'INSERT INTO noxa_ac_detections (ref, type, identifier, name, pid, severity, status, confidence, detail) VALUES (?,?,?,?,?,?,?,?,?)',
        { ref, dtype, identifier, name, src, severity, 'open', confidence, detail }
    )

    local autoKicked = Config.autoKick and confidence >= Config.autoKickConf
    logDb(identifier, name, dtype, confidence, autoKicked and 'kick' or 'flag')

    if autoKicked then
        pushLog('KICK', 'warn', ('Auto-kick : %s (#%s) — %s'):format(name, src, dtype))
        DropPlayer(tostring(src), ('NOXA AC — Expulsion automatique : %s'):format(dtype))
    end

    buildAndPush()
end
exports('addDetection', addDetection) -- réutilisable par d'autres ressources Noxa

-- Moteur de scan server-side (vitesse, warp, argent)
CreateThread(function()
    while true do
        Wait(Config.scanMs)
        local t = os.time()
        for _, src in ipairs(ESX.GetPlayers()) do
            local st = pstate[src]
            if st then
                local ped = GetPlayerPed(src)
                if ped and ped ~= 0 then
                    local c = GetEntityCoords(ped)

                    -- vitesse / warp
                    if st.lastCoords then
                        local d = #(c - st.lastCoords)
                        local dt = (t - (st.lastT or t))
                        if dt <= 0 then dt = Config.scanMs / 1000 end
                        local speed = d / dt

                        if d > Config.warpDist then
                            addDetection(src, 'Teleport', 'high', 86,
                                ('Déplacement de %d m en %.1fs (warp probable).'):format(math.floor(d), dt))
                            st.speedHits = 0
                        elseif speed > Config.speedMax then
                            st.speedHits = (st.speedHits or 0) + 1
                            if st.speedHits >= Config.speedHits then
                                addDetection(src, 'Speed Hack', 'high', 91,
                                    ('Vélocité %d m/s soutenue (max attendu %d m/s).'):format(math.floor(speed), math.floor(Config.speedMax)))
                                st.speedHits = 0
                            end
                        else
                            st.speedHits = 0
                        end
                    end
                    st.lastCoords = c
                    st.lastT = t

                    -- injection d'argent (cash + banque)
                    local xPlayer = ESX.GetPlayerFromId(src)
                    if xPlayer then
                        local acM = xPlayer.getAccount('money')
                        local acB = xPlayer.getAccount('bank')
                        local money = (acM and acM.money or 0) + (acB and acB.money or 0)
                        if st.lastMoney and (money - st.lastMoney) > Config.moneyJump then
                            addDetection(src, 'Money Exploit', 'medium', 72,
                                ('Gain de %d$ sans transaction serveur correspondante.'):format(money - st.lastMoney))
                        end
                        st.lastMoney = money
                    end
                end
            end
        end
    end
end)

-- God mode : sonde client validée serveur (cf. client.lua)
RegisterNetEvent('noxa_ac:probe', function(data)
    local src = source
    if type(data) ~= 'table' then return end
    if data.invincible then
        addDetection(src, 'God Mode', 'critical', 94,
            'Invincibilité détectée (santé verrouillée pendant des événements de dégâts).')
    end
end)

-- Spawns script : on ignore le trafic ambiant (populationType 1-5),
-- on ne compte que les entités créées par script/réseau près d'un joueur.
AddEventHandler('entityCreating', function(entity)
    local pop = GetEntityPopulationType(entity)
    if pop >= 1 and pop <= 5 then return end -- ambiant : ignoré

    local etype = GetEntityType(entity) -- 1=ped 2=vehicle 3=object
    if etype ~= 1 and etype ~= 2 then return end
    local ec = GetEntityCoords(entity)

    -- attribue au joueur le plus proche (< 30m)
    local nearest, bestd = nil, 30.0
    for _, src in ipairs(ESX.GetPlayers()) do
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 then
            local d = #(GetEntityCoords(ped) - ec)
            if d < bestd then bestd, nearest = d, src end
        end
    end
    if not nearest then return end

    local st = pstate[nearest]
    if not st then return end
    local t = os.time()
    if not st.spawnWinStart or (t - st.spawnWinStart) > Config.spawnWindow then
        st.spawnWinStart, st.spawns = t, 0
    end
    st.spawns = (st.spawns or 0) + 1
    if st.spawns == Config.spawnMax + 1 then
        addDetection(nearest, 'Weapon Spawn', 'medium', 76,
            ('%d entités créées en %ds (spawn script anormal).'):format(st.spawns, Config.spawnWindow))
    end
end)

-- ------------------------------------------------------- ACTIONS STAFF
local function recordStaffAction(src)
    local id = getIdentifier(src)
    if id then staffActs[id] = (staffActs[id] or 0) + 1 end
end

RegisterNetEvent('noxa_ac:action', function(data)
    local src = source
    if not isStaff(src) then return end
    local action = data and data.type
    local target = data and tonumber(data.playerId)
    local detId  = data and data.detectionId
    local byName = GetPlayerName(src) or ('staff#' .. src)
    recordStaffAction(src)

    if action == 'resolve' and detId then
        local rId, rName
        for _, d in ipairs(detections) do
            if d.id == detId then d.status = 'resolved'; rId, rName = d.identifier, d.player; break end
        end
        MySQL.update('UPDATE noxa_ac_detections SET status = ? WHERE ref = ?', { 'resolved', detId })
        logDb(rId, rName, 'Détection ' .. detId .. ' (par ' .. byName .. ')', 0, 'resolve')
        pushLog('ACTION', 'info', ('Détection %s résolue par %s'):format(detId, byName))
        buildAndPush()
        return
    end

    if not target then return end
    local tPlayer = ESX.GetPlayerFromId(target)
    local tName = (tPlayer and tPlayer.getName()) or GetPlayerName(target) or ('Joueur #' .. target)
    local tId   = tPlayer and tPlayer.identifier or getIdentifier(target)
    local tLic  = idOfType(target, 'license:') or tId

    if action == 'watch' then
        if tId then
            watchlist[tId] = { pid = target, name = tName, since = nowMs(),
                note = ('Ajouté à la surveillance par %s.'):format(byName), by = byName }
        end
        logDb(tId, tName, 'Surveillance (par ' .. byName .. ')', 0, 'watch')
        pushLog('ACTION', 'warn', ('Watchlist + : %s (#%s) par %s'):format(tName, target, byName))

    elseif action == 'warn' then
        TriggerClientEvent('esx:showNotification', target, '~r~Avertissement staff~s~ : comportement signalé.')
        logDb(tId, tName, 'Avertissement (par ' .. byName .. ')', 0, 'warn')
        pushLog('ACTION', 'warn', ('Avertissement -> %s (#%s) par %s'):format(tName, target, byName))

    elseif action == 'kick' then
        logDb(tId, tName, 'Expulsion staff (par ' .. byName .. ')', 0, 'kick')
        pushLog('KICK', 'warn', ('Expulsion : %s (#%s) par %s'):format(tName, target, byName))
        DropPlayer(tostring(target), 'NOXA AC — Expulsé par le staff.')

    elseif action == 'ban' then
        -- Ban permanent dans la table unifiée noxa_bans -> noxa_admin applique
        -- le bannissement à la prochaine connexion (pas de defer ici).
        MySQL.insert(
            'INSERT INTO noxa_bans (identifier, license, player_name, staff_name, reason, expire) VALUES (?,?,?,?,?,NULL)',
            { tId, tLic, tName, byName, 'Sanction Anti-Cheat (staff)' }
        )
        logDb(tId, tName, 'Ban permanent (par ' .. byName .. ')', 0, 'ban')
        pushLog('BAN', 'critical', ('Ban permanent : %s (#%s) par %s'):format(tName, target, byName))
        DropPlayer(tostring(target), 'NOXA AC — Banni par le staff.')
    end

    buildAndPush()
end)

-- --------------------------------------------------- OUVERTURE / FOCUS
RegisterNetEvent('noxa_ac:requestOpen', function()
    local src = source
    if isStaff(src) then
        openPanels[src] = true
        TriggerClientEvent('noxa_ac:open', src)
        buildAndPush()
    else
        TriggerClientEvent('noxa_ac:denied', src)
    end
end)

RegisterNetEvent('noxa_ac:closed', function()
    openPanels[source] = nil
end)

-- ---------------------------------------------------- CYCLE DE VIE JOUEUR
AddEventHandler('esx:playerLoaded', function(src, xPlayer)
    pstate[src] = {
        connectedAt = os.time(),
        joined = os.date('%d/%m/%Y'),
        speedHits = 0, spawns = 0,
    }
    pushLog('CONNECT', 'info', ('%s a rejoint — %s'):format(xPlayer.getName(), xPlayer.identifier))
end)

AddEventHandler('playerDropped', function()
    local src = source
    if pstate[src] then
        pushLog('DISCONNECT', 'info', ('%s a quitté'):format(GetPlayerName(src) or src))
        pstate[src] = nil
    end
    openPanels[src] = nil
end)

-- ------------------------------------------- CHARGEMENT HISTORIQUE
-- Recharge les détections récentes au démarrage pour que le panel ne soit
-- pas vide après un redémarrage de ressource.
CreateThread(function()
    Wait(1500)
    MySQL.query('SELECT ref, type, identifier, name, pid, severity, status, confidence, detail, UNIX_TIMESTAMP(created_at)*1000 AS ts FROM noxa_ac_detections ORDER BY id DESC LIMIT ?',
        { Config.keepDet }, function(rows)
            for _, r in ipairs(rows or {}) do
                detections[#detections + 1] = {
                    id = r.ref, type = r.type, player = r.name or '—', pid = r.pid,
                    identifier = r.identifier, severity = r.severity or 'medium',
                    status = r.status or 'open', confidence = r.confidence or 0,
                    detail = r.detail or '', time = math.floor(r.ts or nowMs()),
                }
            end
            pushLog('SCAN', 'info', ('Historique chargé — %d détections'):format(#detections))
        end)
end)

-- ----------------------------------------------------- BOUCLE DE PUSH
CreateThread(function()
    while true do
        Wait(Config.pushMs)
        buildAndPush()
    end
end)

-- Échantillonnage affluence (courbe 24 points, 1 point/min)
CreateThread(function()
    while true do
        playerSeries[#playerSeries + 1] = #ESX.GetPlayers()
        while #playerSeries > 24 do table.remove(playerSeries, 1) end
        Wait(60000)
    end
end)

print('[NOXA AC] Serveur anti-cheat prêt — ACE: ' .. ACE_PERM)
