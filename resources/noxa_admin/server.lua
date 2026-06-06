-- =====================================================================
--  NOXA ADMIN — Serveur
--  Toute action sensible est validée côté serveur (source + grade).
--  Jamais de confiance au client : montants/grades/cibles revérifiés ici.
-- =====================================================================

local ACE_PERM = 'noxa.admin'

-- État de prise de service : onDuty[src] = true/false (perdu au déco, voulu)
local onDuty = {}
-- Anti-spam reports : lastReport[identifier] = os.time()
local lastReport = {}

-- =====================================================================
--  PERMISSIONS / GRADES
-- =====================================================================

--- Retourne le niveau staff d'un joueur (0 = aucun, 1 = mod, 2 = admin, 3 = superadmin)
local function getStaffLevel(src)
    local level = 0
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then
        level = Config.Groups[xPlayer.getGroup()] or 0
    end
    -- L'ACE noxa.admin accorde l'accès complet (superadmin)
    if IsPlayerAceAllowed(src, ACE_PERM) then
        level = math.max(level, Config.Groups.superadmin)
    end
    return level
end

--- Vérifie qu'un joueur possède au moins le niveau requis
local function hasLevel(src, required)
    return getStaffLevel(src) >= (required or Config.Groups.mod)
end

-- =====================================================================
--  UTILITAIRES
-- =====================================================================

--- Récupère un identifiant d'un type donné (license, discord, steam...)
local function getIdentifierByType(src, idType)
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id and id:sub(1, #idType + 1) == (idType .. ':') then
            return id
        end
    end
    return nil
end

--- Coordonnées d'un joueur (fiable sous OneSync côté serveur)
local function getPlayerCoords(playerId)
    local ped = GetPlayerPed(playerId)
    if ped and ped ~= 0 then
        local c = GetEntityCoords(ped)
        return { x = c.x, y = c.y, z = c.z }
    end
    return nil
end

--- Journalise une action staff (DB + console)
local function logAdmin(src, action, targetIdentifier, targetName, details)
    local xStaff = ESX.GetPlayerFromId(src)
    local staffIdentifier = xStaff and xStaff.getIdentifier() or ('src:' .. tostring(src))
    local staffName = xStaff and xStaff.getName() or GetPlayerName(src) or ('src:' .. tostring(src))

    MySQL.insert(
        'INSERT INTO noxa_admin_logs (staff_identifier, staff_name, action, target_identifier, target_name, details) VALUES (?, ?, ?, ?, ?, ?)',
        { staffIdentifier, staffName, action, targetIdentifier, targetName, details }
    )

    print(('^5[NOXA ADMIN]^7 %s (%s) -> ^3%s^7 | cible: %s | %s')
        :format(staffName, staffIdentifier, action, targetName or 'n/a', details or ''))
end

--- Notification live à tout le staff EN SERVICE (menuv-style notif + son)
local function notifyStaffOnDuty(payload)
    for staffSrc in pairs(onDuty) do
        if onDuty[staffSrc] then
            TriggerClientEvent('noxa_admin:notify', staffSrc, payload)
        end
    end
end

-- =====================================================================
--  SERVER CALLBACKS (lecture de données pour construire les menus)
-- =====================================================================

-- Niveau staff du joueur (sert au client à autoriser l'ouverture du menu)
ESX.RegisterServerCallback('noxa_admin:getMyLevel', function(source, cb)
    cb({ level = getStaffLevel(source), onDuty = onDuty[source] == true })
end)

-- Liste des joueurs connectés (nom, id, ping, job, argent)
ESX.RegisterServerCallback('noxa_admin:getPlayers', function(source, cb)
    if not hasLevel(source, Config.Groups.mod) then return cb({}) end

    local players = {}
    for _, xPlayer in pairs(ESX.GetExtendedPlayers()) do
        local job = xPlayer.getJob()
        players[#players + 1] = {
            id      = xPlayer.source,
            name    = xPlayer.getName(),
            ping    = GetPlayerPing(xPlayer.source),
            job     = job.name,
            jobLabel = job.label,
            grade   = job.grade,
            gradeLabel = job.grade_label,
            cash    = xPlayer.getAccount('money').money,
            bank    = xPlayer.getAccount('bank').money,
            black   = xPlayer.getAccount('black_money').money,
            identifier = xPlayer.getIdentifier(),
        }
    end
    table.sort(players, function(a, b) return a.id < b.id end)
    cb(players)
end)

-- Identifiants détaillés d'un joueur
ESX.RegisterServerCallback('noxa_admin:getIdentifiers', function(source, cb, targetId)
    if not hasLevel(source, Config.Groups.mod) then return cb({}) end
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return cb({}) end

    local ids = {}
    for i = 0, GetNumPlayerIdentifiers(targetId) - 1 do
        ids[#ids + 1] = GetPlayerIdentifier(targetId, i)
    end
    cb(ids)
end)

-- Liste du staff actuellement en service
ESX.RegisterServerCallback('noxa_admin:getStaffOnDuty', function(source, cb)
    if not hasLevel(source, Config.Groups.mod) then return cb({}) end
    local list = {}
    for staffSrc in pairs(onDuty) do
        if onDuty[staffSrc] and GetPlayerName(staffSrc) then
            local xStaff = ESX.GetPlayerFromId(staffSrc)
            list[#list + 1] = {
                id    = staffSrc,
                name  = xStaff and xStaff.getName() or GetPlayerName(staffSrc),
                level = getStaffLevel(staffSrc),
            }
        end
    end
    cb(list)
end)

-- Reports non clôturés
ESX.RegisterServerCallback('noxa_admin:getReports', function(source, cb)
    if not hasLevel(source, Config.Groups.mod) then return cb({}) end

    local rows = MySQL.query.await(
        "SELECT *, TIMESTAMPDIFF(SECOND, created_at, NOW()) AS age_sec FROM noxa_reports WHERE status != 'closed' ORDER BY created_at ASC") or {}

    -- index identifier -> src en ligne
    local online = {}
    for _, xPlayer in pairs(ESX.GetExtendedPlayers()) do
        online[xPlayer.getIdentifier()] = xPlayer.source
    end

    local reports = {}
    for _, r in ipairs(rows) do
        reports[#reports + 1] = {
            id         = r.id,
            name       = r.player_name,
            message    = r.message,
            status     = r.status,
            claimedBy  = r.claimed_by,
            identifier = r.identifier,
            onlineSrc  = online[r.identifier], -- nil si déconnecté
            ageSec     = tonumber(r.age_sec) or 0,
            createdAt  = r.created_at,
        }
    end
    cb(reports)
end)

-- Warns d'un joueur (par identifier)
ESX.RegisterServerCallback('noxa_admin:getWarns', function(source, cb, identifier)
    if not hasLevel(source, Config.Groups.mod) then return cb({}) end
    local rows = MySQL.query.await(
        'SELECT * FROM noxa_warns WHERE identifier = ? ORDER BY created_at DESC', { identifier }) or {}
    cb(rows)
end)

-- Liste des bans actifs
ESX.RegisterServerCallback('noxa_admin:getBans', function(source, cb)
    if not hasLevel(source, Config.Groups.mod) then return cb({}) end
    local rows = MySQL.query.await(
        'SELECT * FROM noxa_bans ORDER BY created_at DESC LIMIT 100') or {}
    cb(rows)
end)

-- Liste des jobs + grades (pour Set job)
ESX.RegisterServerCallback('noxa_admin:getJobs', function(source, cb)
    if not hasLevel(source, Config.Groups.mod) then return cb({}) end
    local jobs = {}
    for name, job in pairs(ESX.GetJobs()) do
        local grades = {}
        for g, grade in pairs(job.grades) do
            grades[#grades + 1] = { grade = tonumber(g), label = grade.label, name = grade.name }
        end
        table.sort(grades, function(a, b) return a.grade < b.grade end)
        jobs[#jobs + 1] = { name = name, label = job.label, grades = grades }
    end
    table.sort(jobs, function(a, b) return a.label < b.label end)
    cb(jobs)
end)

-- Solde d'un joueur (Économie)
ESX.RegisterServerCallback('noxa_admin:getBalance', function(source, cb, targetId)
    if not hasLevel(source, Config.Groups.mod) then return cb(nil) end
    local xTarget = ESX.GetPlayerFromId(tonumber(targetId))
    if not xTarget then return cb(nil) end
    cb({
        cash  = xTarget.getAccount('money').money,
        bank  = xTarget.getAccount('bank').money,
        black = xTarget.getAccount('black_money').money,
        name  = xTarget.getName(),
    })
end)

-- =====================================================================
--  PRISE DE SERVICE STAFF
-- =====================================================================
RegisterNetEvent('noxa_admin:toggleDuty', function()
    local src = source
    if not hasLevel(src, Config.Groups.mod) then return end
    onDuty[src] = not onDuty[src]
    local state = onDuty[src]
    TriggerClientEvent('noxa_admin:dutyState', src, state)
    TriggerClientEvent('noxa_admin:notify', src, {
        title = 'Prise de service',
        msg = state and 'Vous êtes désormais EN SERVICE.' or 'Vous êtes désormais HORS service.',
        type = state and 'success' or 'info',
    })
    logAdmin(src, 'duty', nil, nil, state and 'ON' or 'OFF')
end)

AddEventHandler('playerDropped', function()
    onDuty[source] = nil
    lastReport[source] = nil
end)

-- =====================================================================
--  SYSTÈME DE REPORT (joueur -> staff)
-- =====================================================================
RegisterCommand('report', function(src, args)
    if src == 0 then return end -- pas depuis la console
    local message = table.concat(args, ' ')
    if message == '' then
        TriggerClientEvent('noxa_admin:notify', src, {
            title = 'Report', msg = 'Usage : /report <ton message>', type = 'error' })
        return
    end

    -- Anti-spam : 1 report / Config.ReportCooldown s
    local now = os.time()
    if lastReport[src] and (now - lastReport[src]) < Config.ReportCooldown then
        local wait = Config.ReportCooldown - (now - lastReport[src])
        TriggerClientEvent('noxa_admin:notify', src, {
            title = 'Report', msg = ('Patiente %d s avant un nouveau report.'):format(wait), type = 'error' })
        return
    end
    lastReport[src] = now

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local coords = getPlayerCoords(src)
    local posStr = coords and ('%.1f, %.1f, %.1f'):format(coords.x, coords.y, coords.z) or 'inconnue'

    MySQL.insert(
        'INSERT INTO noxa_reports (identifier, player_name, message, position, status) VALUES (?, ?, ?, ?, ?)',
        { xPlayer.getIdentifier(), xPlayer.getName(), message, posStr, 'open' },
        function(insertId)
            -- Notif live à tout le staff en service + son
            notifyStaffOnDuty({
                title = ('📢 Report #%s'):format(insertId or '?'),
                msg = ('%s : %s'):format(xPlayer.getName(), message),
                type = 'report',
                sound = true,
            })
            TriggerClientEvent('noxa_admin:notify', src, {
                title = 'Report envoyé',
                msg = 'Ton signalement a été transmis au staff. Patiente.',
                type = 'success',
            })
            print(('^5[NOXA REPORT]^7 #%s %s : %s'):format(insertId or '?', xPlayer.getName(), message))
        end
    )
end, false)

-- Prendre en charge un report (claim)
RegisterNetEvent('noxa_admin:report:claim', function(reportId)
    local src = source
    if not hasLevel(src, Config.Groups.mod) then return end
    local xStaff = ESX.GetPlayerFromId(src)
    local staffName = xStaff and xStaff.getName() or GetPlayerName(src)

    MySQL.update('UPDATE noxa_reports SET status = ?, claimed_by = ? WHERE id = ? AND status = ?',
        { 'claimed', staffName, reportId, 'open' })
    logAdmin(src, 'report_claim', nil, nil, 'report #' .. tostring(reportId))

    -- Prévenir le joueur si en ligne
    local row = MySQL.single.await('SELECT identifier FROM noxa_reports WHERE id = ?', { reportId })
    if row then
        local tSrc = ESX.GetPlayerFromIdentifier(row.identifier)
        if tSrc then
            TriggerClientEvent('noxa_admin:notify', tSrc.source, {
                title = 'Report pris en charge',
                msg = ('Le staff %s s\'occupe de ton signalement.'):format(staffName),
                type = 'info',
            })
        end
    end
    notifyStaffOnDuty({ title = 'Report', msg = ('%s a pris le report #%s'):format(staffName, reportId), type = 'info' })
end)

-- Clôturer un report
RegisterNetEvent('noxa_admin:report:close', function(reportId)
    local src = source
    if not hasLevel(src, Config.Groups.mod) then return end
    local staffName = (ESX.GetPlayerFromId(src) or {}).getName and ESX.GetPlayerFromId(src).getName() or GetPlayerName(src)

    local row = MySQL.single.await('SELECT identifier FROM noxa_reports WHERE id = ?', { reportId })
    MySQL.update('UPDATE noxa_reports SET status = ?, closed_at = NOW(), claimed_by = ? WHERE id = ?',
        { 'closed', staffName, reportId })
    logAdmin(src, 'report_close', nil, nil, 'report #' .. tostring(reportId))

    if row then
        local tSrc = ESX.GetPlayerFromIdentifier(row.identifier)
        if tSrc then
            TriggerClientEvent('noxa_admin:notify', tSrc.source, {
                title = 'Report clôturé',
                msg = 'Ton signalement a été traité et clôturé. Merci.',
                type = 'success',
            })
        end
    end
end)

-- Répondre au joueur (message privé)
RegisterNetEvent('noxa_admin:report:reply', function(reportId, message)
    local src = source
    if not hasLevel(src, Config.Groups.mod) then return end
    if type(message) ~= 'string' or message == '' then return end
    local staffName = ESX.GetPlayerFromId(src) and ESX.GetPlayerFromId(src).getName() or GetPlayerName(src)

    local row = MySQL.single.await('SELECT identifier, player_name FROM noxa_reports WHERE id = ?', { reportId })
    if not row then return end
    local tSrc = ESX.GetPlayerFromIdentifier(row.identifier)
    if tSrc then
        TriggerClientEvent('noxa_admin:notify', tSrc.source, {
            title = ('💬 Staff (%s)'):format(staffName),
            msg = message,
            type = 'report',
            sound = true,
        })
    end
    logAdmin(src, 'report_reply', row.identifier, row.player_name, message)
end)

-- =====================================================================
--  ACTIONS SUR LES JOUEURS (toutes revérifiées server-side)
-- =====================================================================

-- Récupère cible + valide. Renvoie xTarget ou nil (et notifie l'admin si KO)
local function resolveTarget(src, targetId, requiredLevel)
    if not hasLevel(src, requiredLevel or Config.Groups.mod) then
        TriggerClientEvent('noxa_admin:notify', src, { title = 'Refusé', msg = 'Grade insuffisant.', type = 'error' })
        return nil
    end
    local xTarget = ESX.GetPlayerFromId(tonumber(targetId))
    if not xTarget then
        TriggerClientEvent('noxa_admin:notify', src, { title = 'Erreur', msg = 'Joueur introuvable.', type = 'error' })
        return nil
    end
    return xTarget
end

-- Geler / dégeler
RegisterNetEvent('noxa_admin:freeze', function(targetId, frozen)
    local src = source
    local xTarget = resolveTarget(src, targetId, Config.Groups.mod)
    if not xTarget then return end
    TriggerClientEvent('noxa_admin:setFrozen', xTarget.source, frozen == true)
    logAdmin(src, 'freeze', xTarget.getIdentifier(), xTarget.getName(), frozen and 'ON' or 'OFF')
end)

-- TP vers le joueur (on renvoie les coords à l'admin)
RegisterNetEvent('noxa_admin:tpToPlayer', function(targetId)
    local src = source
    local xTarget = resolveTarget(src, targetId, Config.Groups.mod)
    if not xTarget then return end
    local coords = getPlayerCoords(xTarget.source)
    if coords then
        TriggerClientEvent('noxa_admin:teleportTo', src, coords)
        logAdmin(src, 'tp_to_player', xTarget.getIdentifier(), xTarget.getName(), nil)
    end
end)

-- Amener le joueur à moi
RegisterNetEvent('noxa_admin:bringPlayer', function(targetId)
    local src = source
    local xTarget = resolveTarget(src, targetId, Config.Groups.mod)
    if not xTarget then return end
    local coords = getPlayerCoords(src)
    if coords then
        TriggerClientEvent('noxa_admin:teleportTo', xTarget.source, coords)
        TriggerClientEvent('noxa_admin:notify', xTarget.source, { title = 'Téléportation', msg = 'Un staff t\'a téléporté.', type = 'info' })
        logAdmin(src, 'bring_player', xTarget.getIdentifier(), xTarget.getName(), nil)
    end
end)

-- Spectate (on fournit le netId du ped cible + coords)
RegisterNetEvent('noxa_admin:spectate', function(targetId)
    local src = source
    local xTarget = resolveTarget(src, targetId, Config.Groups.mod)
    if not xTarget then return end
    local ped = GetPlayerPed(xTarget.source)
    local netId = NetworkGetNetworkIdFromEntity(ped)
    local coords = getPlayerCoords(xTarget.source)
    TriggerClientEvent('noxa_admin:doSpectate', src, netId, coords, xTarget.getName())
    logAdmin(src, 'spectate', xTarget.getIdentifier(), xTarget.getName(), nil)
end)

-- Soigner
RegisterNetEvent('noxa_admin:heal', function(targetId)
    local src = source
    local xTarget = resolveTarget(src, targetId, Config.Groups.mod)
    if not xTarget then return end
    TriggerClientEvent('noxa_admin:healMe', xTarget.source, false)
    TriggerClientEvent('noxa_admin:notify', xTarget.source, { title = 'Soigné', msg = 'Un staff t\'a soigné.', type = 'success' })
    logAdmin(src, 'heal', xTarget.getIdentifier(), xTarget.getName(), nil)
end)

-- Réanimer
RegisterNetEvent('noxa_admin:revive', function(targetId)
    local src = source
    local xTarget = resolveTarget(src, targetId, Config.Groups.mod)
    if not xTarget then return end
    TriggerClientEvent('noxa_admin:healMe', xTarget.source, true)
    TriggerClientEvent('noxa_admin:notify', xTarget.source, { title = 'Réanimé', msg = 'Un staff t\'a réanimé.', type = 'success' })
    logAdmin(src, 'revive', xTarget.getIdentifier(), xTarget.getName(), nil)
end)

-- Tuer
RegisterNetEvent('noxa_admin:kill', function(targetId)
    local src = source
    local xTarget = resolveTarget(src, targetId, Config.Groups.admin)
    if not xTarget then return end
    TriggerClientEvent('noxa_admin:killMe', xTarget.source)
    logAdmin(src, 'kill', xTarget.getIdentifier(), xTarget.getName(), nil)
end)

-- Kick
RegisterNetEvent('noxa_admin:kick', function(targetId, reason)
    local src = source
    local xTarget = resolveTarget(src, targetId, Config.Groups.mod)
    if not xTarget then return end
    reason = (type(reason) == 'string' and reason ~= '') and reason or 'Aucune raison fournie'
    logAdmin(src, 'kick', xTarget.getIdentifier(), xTarget.getName(), reason)
    DropPlayer(tostring(xTarget.source), ('[NOXA] Expulsé par le staff.\nRaison : %s'):format(reason))
end)

-- Ban (durée en minutes ; 0 = permanent). Ban perma = admin+
RegisterNetEvent('noxa_admin:ban', function(targetId, reason, durationMin)
    local src = source
    durationMin = tonumber(durationMin) or 0
    local needed = (durationMin <= 0) and Config.Groups.admin or Config.Groups.mod
    local xTarget = resolveTarget(src, targetId, needed)
    if not xTarget then return end
    reason = (type(reason) == 'string' and reason ~= '') and reason or 'Aucune raison fournie'

    local staffName = ESX.GetPlayerFromId(src) and ESX.GetPlayerFromId(src).getName() or GetPlayerName(src)
    local identifier = xTarget.getIdentifier()
    local license = getIdentifierByType(xTarget.source, 'license')
    local expireSql = (durationMin > 0)
        and ('DATE_ADD(NOW(), INTERVAL %d MINUTE)'):format(durationMin) or 'NULL'

    MySQL.insert(
        ('INSERT INTO noxa_bans (identifier, license, player_name, staff_name, reason, expire) VALUES (?, ?, ?, ?, ?, %s)')
            :format(expireSql),
        { identifier, license, xTarget.getName(), staffName, reason })

    logAdmin(src, 'ban', identifier, xTarget.getName(),
        ('%s | %s'):format(durationMin > 0 and (durationMin .. ' min') or 'PERMANENT', reason))
    local durTxt = durationMin > 0 and ('%d minutes'):format(durationMin) or 'définitif'
    DropPlayer(tostring(xTarget.source), ('[NOXA] Banni (%s).\nRaison : %s'):format(durTxt, reason))
end)

-- Set argent (admin+)
RegisterNetEvent('noxa_admin:setMoney', function(targetId, account, amount)
    local src = source
    local xTarget = resolveTarget(src, targetId, Config.Groups.admin)
    if not xTarget then return end
    amount = math.floor(tonumber(amount) or 0)
    if amount < 0 or amount > 1000000000 then
        return TriggerClientEvent('noxa_admin:notify', src, { title = 'Erreur', msg = 'Montant invalide.', type = 'error' })
    end
    local validAccounts = { money = true, bank = true, black_money = true }
    if not validAccounts[account] then return end
    xTarget.setAccountMoney(account, amount)
    logAdmin(src, 'set_money', xTarget.getIdentifier(), xTarget.getName(), ('%s = %d'):format(account, amount))
    TriggerClientEvent('noxa_admin:notify', src, { title = 'Argent', msg = ('%s : %s mis à %d'):format(xTarget.getName(), account, amount), type = 'success' })
end)

-- Donner de l'argent (Économie ; ajoute, ne remplace pas)
RegisterNetEvent('noxa_admin:giveMoney', function(targetId, account, amount)
    local src = source
    local xTarget = resolveTarget(src, targetId, Config.Groups.admin)
    if not xTarget then return end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or amount > 1000000000 then
        return TriggerClientEvent('noxa_admin:notify', src, { title = 'Erreur', msg = 'Montant invalide.', type = 'error' })
    end
    local validAccounts = { money = true, bank = true, black_money = true }
    if not validAccounts[account] then return end
    xTarget.addAccountMoney(account, amount, 'Admin NOXA')
    logAdmin(src, 'give_money', xTarget.getIdentifier(), xTarget.getName(), ('+%d %s'):format(amount, account))
    TriggerClientEvent('noxa_admin:notify', src, { title = 'Argent', msg = ('+%d %s donné à %s'):format(amount, account, xTarget.getName()), type = 'success' })
end)

-- Donner un item
RegisterNetEvent('noxa_admin:giveItem', function(targetId, item, count)
    local src = source
    local xTarget = resolveTarget(src, targetId, Config.Groups.mod)
    if not xTarget then return end
    item = tostring(item or ''):lower()
    count = math.floor(tonumber(count) or 0)
    if item == '' or count <= 0 or count > 10000 then
        return TriggerClientEvent('noxa_admin:notify', src, { title = 'Erreur', msg = 'Item/quantité invalide.', type = 'error' })
    end
    if not xTarget.canCarryItem(item, count) then
        return TriggerClientEvent('noxa_admin:notify', src, { title = 'Erreur', msg = 'Inventaire plein ou item inconnu.', type = 'error' })
    end
    xTarget.addInventoryItem(item, count)
    logAdmin(src, 'give_item', xTarget.getIdentifier(), xTarget.getName(), ('%dx %s'):format(count, item))
    TriggerClientEvent('noxa_admin:notify', src, { title = 'Item', msg = ('%dx %s donné à %s'):format(count, item, xTarget.getName()), type = 'success' })
end)

-- Set job + grade
RegisterNetEvent('noxa_admin:setJob', function(targetId, job, grade)
    local src = source
    local xTarget = resolveTarget(src, targetId, Config.Groups.mod)
    if not xTarget then return end
    job = tostring(job or '')
    grade = tostring(tonumber(grade) or 0)
    xTarget.setJob(job, grade)
    logAdmin(src, 'set_job', xTarget.getIdentifier(), xTarget.getName(), ('%s grade %s'):format(job, grade))
    TriggerClientEvent('noxa_admin:notify', src, { title = 'Job', msg = ('%s -> %s (%s)'):format(xTarget.getName(), job, grade), type = 'success' })
    TriggerClientEvent('noxa_admin:notify', xTarget.source, { title = 'Job', msg = ('Ton job est maintenant : %s'):format(job), type = 'info' })
end)

-- Avertir (warn)
RegisterNetEvent('noxa_admin:warn', function(targetId, reason)
    local src = source
    local xTarget = resolveTarget(src, targetId, Config.Groups.mod)
    if not xTarget then return end
    reason = (type(reason) == 'string' and reason ~= '') and reason or 'Aucune raison fournie'
    local staffName = ESX.GetPlayerFromId(src) and ESX.GetPlayerFromId(src).getName() or GetPlayerName(src)
    MySQL.insert('INSERT INTO noxa_warns (identifier, player_name, staff_name, reason) VALUES (?, ?, ?, ?)',
        { xTarget.getIdentifier(), xTarget.getName(), staffName, reason })
    logAdmin(src, 'warn', xTarget.getIdentifier(), xTarget.getName(), reason)
    TriggerClientEvent('noxa_admin:notify', xTarget.source, {
        title = '⚠️ Avertissement', msg = reason, type = 'error', sound = true })
    TriggerClientEvent('noxa_admin:notify', src, { title = 'Warn', msg = ('%s averti.'):format(xTarget.getName()), type = 'success' })
end)

-- Débannir
RegisterNetEvent('noxa_admin:unban', function(banId)
    local src = source
    if not hasLevel(src, Config.Groups.admin) then return end
    local row = MySQL.single.await('SELECT identifier, player_name FROM noxa_bans WHERE id = ?', { banId })
    MySQL.query('DELETE FROM noxa_bans WHERE id = ?', { banId })
    logAdmin(src, 'unban', row and row.identifier, row and row.player_name, 'ban #' .. tostring(banId))
    TriggerClientEvent('noxa_admin:notify', src, { title = 'Débannissement', msg = 'Ban supprimé.', type = 'success' })
end)

-- =====================================================================
--  MONDE : annonces, OOC staff, météo, heure (admin+)
-- =====================================================================

RegisterNetEvent('noxa_admin:announce', function(message)
    local src = source
    if not hasLevel(src, Config.Groups.admin) then return end
    if type(message) ~= 'string' or message == '' then return end
    TriggerClientEvent('noxa_admin:announce', -1, message)
    logAdmin(src, 'announce', nil, nil, message)
end)

RegisterNetEvent('noxa_admin:staffOOC', function(message)
    local src = source
    if not hasLevel(src, Config.Groups.mod) then return end
    if type(message) ~= 'string' or message == '' then return end
    local staffName = ESX.GetPlayerFromId(src) and ESX.GetPlayerFromId(src).getName() or GetPlayerName(src)
    notifyStaffOnDuty({ title = ('Staff OOC — %s'):format(staffName), msg = message, type = 'info' })
end)

RegisterNetEvent('noxa_admin:setWeather', function(weather)
    local src = source
    if not hasLevel(src, Config.Groups.admin) then return end
    TriggerClientEvent('noxa_admin:applyWeather', -1, tostring(weather))
    logAdmin(src, 'weather', nil, nil, tostring(weather))
end)

RegisterNetEvent('noxa_admin:setTime', function(hour)
    local src = source
    if not hasLevel(src, Config.Groups.admin) then return end
    hour = math.floor(tonumber(hour) or 12) % 24
    TriggerClientEvent('noxa_admin:applyTime', -1, hour)
    logAdmin(src, 'time', nil, nil, tostring(hour) .. 'h')
end)

-- =====================================================================
--  VÉHICULES (spawn validé server-side, création client-side OneSync)
-- =====================================================================
RegisterNetEvent('noxa_admin:spawnVehicle', function(model)
    local src = source
    if not hasLevel(src, Config.Groups.mod) then return end
    model = tostring(model or ''):lower()
    if model == '' then return end
    TriggerClientEvent('noxa_admin:doSpawnVehicle', src, model)
    logAdmin(src, 'spawn_vehicle', nil, nil, model)
end)

-- =====================================================================
--  CONTRÔLE DE BAN À LA CONNEXION
-- =====================================================================
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)

    local identifiers = {}
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        identifiers[#identifiers + 1] = GetPlayerIdentifier(src, i)
    end
    local license
    for _, id in ipairs(identifiers) do
        if id:sub(1, 8) == 'license:' then license = id break end
    end

    deferrals.update('NOXA — vérification du bannissement...')

    local mainId = license or identifiers[1]
    local row = MySQL.single.await(
        'SELECT * FROM noxa_bans WHERE (identifier = ? OR license = ?) AND (expire IS NULL OR expire > NOW()) ORDER BY created_at DESC LIMIT 1',
        { mainId, license })

    if row then
        local until_ = row.expire and ('jusqu\'au ' .. tostring(row.expire)) or 'DÉFINITIF'
        deferrals.done(('[NOXA] Tu es banni (%s).\nRaison : %s'):format(until_, row.reason or 'n/a'))
        return
    end

    deferrals.done()
end)

print('^2[NOXA ADMIN]^7 Serveur chargé. /report disponible, menu staff via F10.')
