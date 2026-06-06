-- ============================================================
-- NOXA FA — Téléphone · serveur (ESX Legacy + oxmysql)
-- Données live (contacts, SMS, banque, Canari, garage) + actions.
-- ============================================================
local ESX = exports['es_extended']:getSharedObject()

-- ---- Tables (idempotent, au cas où le .sql n'a pas été importé) ----
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `noxa_phone_contacts` (
            `id` INT(11) NOT NULL AUTO_INCREMENT, `owner` VARCHAR(64) NOT NULL,
            `display` VARCHAR(64) NOT NULL, `number` VARCHAR(20) NOT NULL,
            PRIMARY KEY (`id`), KEY `idx_owner` (`owner`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `noxa_phone_messages` (
            `id` INT(11) NOT NULL AUTO_INCREMENT, `sender` VARCHAR(20) NOT NULL,
            `receiver` VARCHAR(20) NOT NULL, `message` TEXT NOT NULL,
            `is_read` TINYINT(1) NOT NULL DEFAULT 0,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`), KEY `idx_sender` (`sender`), KEY `idx_receiver` (`receiver`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `noxa_phone_tweets` (
            `id` INT(11) NOT NULL AUTO_INCREMENT, `author_id` VARCHAR(60) NOT NULL,
            `author_name` VARCHAR(64) NOT NULL, `handle` VARCHAR(32) NOT NULL,
            `message` TEXT NOT NULL, `likes` INT(11) NOT NULL DEFAULT 0,
            `retweets` INT(11) NOT NULL DEFAULT 0,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`), KEY `idx_created` (`created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
end)

-- ---- Helpers ----
local function initials(name)
    if not name or name == '' then return '?' end
    local parts = {}
    for w in string.gmatch(name, '%S+') do parts[#parts + 1] = w end
    if #parts >= 2 then
        return (parts[1]:sub(1, 1) .. parts[2]:sub(1, 1)):upper()
    end
    return name:sub(1, 2):upper()
end

-- Formate un 'YYYY-MM-DD HH:MM:SS' en heure courte / date relative (FR)
local function fmtTime(ts)
    if not ts then return '' end
    local y, mo, d, h, mi = ts:match('(%d+)-(%d+)-(%d+)%s+(%d+):(%d+)')
    if not y then return tostring(ts) end
    local today = os.date('%Y-%m-%d')
    local that = string.format('%s-%s-%s', y, mo, d)
    if that == today then
        return string.format('%s:%s', h, mi)
    end
    -- hier ?
    local yest = os.date('%Y-%m-%d', os.time() - 86400)
    if that == yest then return 'Hier' end
    return string.format('%s/%s', d, mo)
end

-- Numéro de téléphone du joueur (users.phone_number), génère si absent
local function getNumber(identifier)
    local num = MySQL.scalar.await('SELECT phone_number FROM users WHERE identifier = ?', { identifier })
    if num and num ~= '' then return tostring(num) end
    num = string.format('555-%04d', math.random(0, 9999))
    MySQL.update.await('UPDATE users SET phone_number = ? WHERE identifier = ?', { num, identifier })
    return num
end

-- ---- Construction du payload complet ----
local function buildData(xPlayer)
    local identifier = xPlayer.identifier
    local myNumber = getNumber(identifier)
    local fullName = (xPlayer.getName and xPlayer.getName()) or
        ((xPlayer.get and xPlayer.get('firstName')) or 'Citoyen')

    -- Contacts
    local contactRows = MySQL.query.await(
        'SELECT display, number FROM noxa_phone_contacts WHERE owner = ? ORDER BY display ASC',
        { identifier }) or {}
    local contacts, byNumber = {}, {}
    for _, c in ipairs(contactRows) do
        contacts[#contacts + 1] = { name = c.display, number = c.number, initials = initials(c.display) }
        byNumber[c.number] = c.display
    end

    -- Messages -> conversations groupées par interlocuteur
    local msgRows = MySQL.query.await([[
        SELECT sender, receiver, message, created_at FROM noxa_phone_messages
        WHERE sender = ? OR receiver = ? ORDER BY created_at ASC
    ]], { myNumber, myNumber }) or {}
    local threadIndex, threads = {}, {}
    for _, m in ipairs(msgRows) do
        local mine = (m.sender == myNumber)
        local other = mine and m.receiver or m.sender
        local th = threadIndex[other]
        if not th then
            th = {
                id = other,
                name = byNumber[other] or other,
                initials = initials(byNumber[other] or other),
                number = other,
                msgs = {},
            }
            threadIndex[other] = th
            threads[#threads + 1] = th
        end
        th.msgs[#th.msgs + 1] = { me = mine, text = m.message, time = fmtTime(m.created_at) }
    end

    -- Récents (dérivés des dernières conversations)
    local recents = {}
    for _, th in ipairs(threads) do
        local last = th.msgs[#th.msgs]
        recents[#recents + 1] = {
            name = th.name,
            type = last.me and 'out' or 'in',
            time = last.time,
        }
    end

    -- Canari
    local tweetRows = MySQL.query.await([[
        SELECT author_name, handle, message, likes, retweets, created_at
        FROM noxa_phone_tweets ORDER BY created_at DESC LIMIT 50
    ]]) or {}
    local canari = {}
    for _, tw in ipairs(tweetRows) do
        canari[#canari + 1] = {
            user = tw.author_name,
            handle = tw.handle,
            initials = initials(tw.author_name),
            text = tw.message,
            time = fmtTime(tw.created_at),
            likes = tw.likes or 0,
            rt = tw.retweets or 0,
        }
    end

    -- Banque (comptes ESX)
    local bankAcc = xPlayer.getAccount and xPlayer.getAccount('bank')
    local cashAcc = xPlayer.getAccount and xPlayer.getAccount('money')

    -- Garage (véhicules possédés)
    local vehRows = MySQL.query.await(
        'SELECT plate, vehicle, type, stored FROM owned_vehicles WHERE owner = ?',
        { identifier }) or {}
    local vehicles = {}
    for _, v in ipairs(vehRows) do
        local label, cat = 'Véhicule', (v.type == 'car' and 'Auto' or v.type)
        local ok, props = pcall(json.decode, v.vehicle or '{}')
        if ok and props and props.model then label = 'Modèle ' .. tostring(props.model) end
        vehicles[#vehicles + 1] = {
            name = label,
            plate = (v.plate or ''):gsub('%s+$', ''),
            cat = cat,
            status = (v.stored == 1) and 'Garage' or 'Sorti',
            loc = (v.stored == 1) and 'Au garage' or 'En circulation',
        }
    end

    return {
        me = { name = fullName, number = myNumber },
        contacts = contacts,
        recents = recents,
        threads = threads,
        canari = canari,
        bank = {
            cash = cashAcc and cashAcc.money or 0,
            bank = bankAcc and bankAcc.money or 0,
            tx = {}, -- pas de table de transactions dédiée
        },
        vehicles = vehicles,
    }
end

-- ---- Callback principal ----
ESX.RegisterServerCallback('noxa_phone:getData', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({}) end
    CreateThread(function()
        local ok, data = pcall(buildData, xPlayer)
        if not ok then
            print(('[noxa_phone] erreur buildData: %s'):format(data))
            return cb({})
        end
        cb(data)
    end)
end)

-- ---- Envoi d'un SMS ----
RegisterNetEvent('noxa_phone:sendMessage', function(to, text)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or not to or not text or text == '' then return end
    text = tostring(text):sub(1, 500)

    -- 'to' peut être un nom de contact : on résout en numéro
    local fromNumber = getNumber(xPlayer.identifier)
    local target = tostring(to)
    if not target:match('%d') or target:match('%a') then
        local resolved = MySQL.scalar.await(
            'SELECT number FROM noxa_phone_contacts WHERE owner = ? AND display = ? LIMIT 1',
            { xPlayer.identifier, target })
        if resolved then target = resolved end
    end

    MySQL.insert.await(
        'INSERT INTO noxa_phone_messages (sender, receiver, message) VALUES (?, ?, ?)',
        { fromNumber, target, text })

    -- Notifie le destinataire s'il est en ligne
    for _, pid in ipairs(GetPlayers()) do
        local xTarget = ESX.GetPlayerFromId(tonumber(pid))
        if xTarget then
            local tnum = MySQL.scalar.await('SELECT phone_number FROM users WHERE identifier = ?', { xTarget.identifier })
            if tnum == target then
                TriggerClientEvent('noxa_phone:refresh', xTarget.source)
                if xTarget.showNotification then xTarget.showNotification('~b~SMS~s~ de ' .. fromNumber) end
                break
            end
        end
    end
    TriggerClientEvent('noxa_phone:refresh', src)
end)

-- ---- Publier un tweet Canari ----
RegisterNetEvent('noxa_phone:postTweet', function(text)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or not text or text == '' then return end
    text = tostring(text):sub(1, 280)

    local name = (xPlayer.getName and xPlayer.getName()) or 'Citoyen'
    local handle = '@' .. (name:gsub('%s+', ''):lower())
    MySQL.insert.await(
        'INSERT INTO noxa_phone_tweets (author_id, author_name, handle, message) VALUES (?, ?, ?, ?)',
        { xPlayer.identifier, name, handle, text })

    -- Rafraîchit tous les téléphones ouverts (feed public)
    TriggerClientEvent('noxa_phone:refresh', -1)
end)

-- ---- Journal d'appel (placeholder, pas de voix) ----
RegisterNetEvent('noxa_phone:logCall', function(to)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or not to then return end
    -- Hook futur : intégration voix/call. Pour l'instant on ne stocke rien.
end)
