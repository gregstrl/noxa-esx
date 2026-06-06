-- =====================================================================
--  NOXA FA — Panel Gestion Serveur · SERVEUR
--  Autorite serveur : rang superadmin revérifié a CHAQUE action.
--  Donnees & ecritures 100% ESX Legacy natif (jobs, job_grades, items,
--  vehicles, vehicle_categories) via oxmysql. Le panel n'est qu'une vue.
-- =====================================================================

local ACE_PERM = 'noxa.gestion'

--- Rang superadmin ? (groupe ESX « superadmin » OU ACE noxa.gestion)
local function isSuper(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer and xPlayer.getGroup() == 'superadmin' then return true end
    if IsPlayerAceAllowed(src, ACE_PERM) then return true end
    return false
end

-- =====================================================================
--  TABLE NON-ESX : lieux & coordonnees (ESX n'en a pas nativement)
-- =====================================================================
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `noxa_gestion_locations` (
            `id` VARCHAR(64) NOT NULL,
            `name` VARCHAR(100) DEFAULT NULL,
            `type` VARCHAR(32) DEFAULT 'Blip',
            `x` DOUBLE NOT NULL DEFAULT 0, `y` DOUBLE NOT NULL DEFAULT 0,
            `z` DOUBLE NOT NULL DEFAULT 0, `h` DOUBLE NOT NULL DEFAULT 0,
            `job` VARCHAR(50) DEFAULT '—',
            `sprite` INT NOT NULL DEFAULT 1, `color` INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB
    ]])
end)

-- =====================================================================
--  CONSTRUCTION DU SNAPSHOT LIVE (mappe les tables ESX -> schema MDATA)
-- =====================================================================
local function buildSnapshot()
    -- Items ESX (la table items n'a ni categorie ni prix : valeurs neutres).
    local itemRows = MySQL.query.await('SELECT `name`, `label`, `weight`, `rare`, `can_remove` FROM `items` ORDER BY `label`') or {}
    local items = {}
    for _, r in ipairs(itemRows) do
        items[#items + 1] = {
            id = r.name, name = r.name, label = r.label or r.name,
            cat = 'Divers', weight = (r.weight or 1) + 0.0, price = 0,
            stack = true, rare = (r.rare == 1), removable = (r.can_remove == 1), desc = '',
        }
    end

    -- Categories de vehicules ESX.
    local catRows = MySQL.query.await('SELECT `name`, `label` FROM `vehicle_categories`') or {}
    local catLabel, vehCats = {}, {}
    for _, c in ipairs(catRows) do
        catLabel[c.name] = c.label
        vehCats[#vehCats + 1] = c.label
    end

    -- Vehicules concession ESX (table vehicles : name, model, price, category).
    local vehRows = MySQL.query.await('SELECT `name`, `model`, `price`, `category` FROM `vehicles` ORDER BY `category`, `name`') or {}
    local vehicles = {}
    for _, v in ipairs(vehRows) do
        vehicles[#vehicles + 1] = {
            id = v.name, label = v.name, model = v.model, brand = '',
            cat = catLabel[v.category] or v.category or '—',
            vclass = v.category or '', price = v.price or 0, seats = 4,
        }
    end

    -- Effectifs par job (table users ESX).
    local memberRows = MySQL.query.await('SELECT `job`, COUNT(*) AS `c` FROM `users` GROUP BY `job`') or {}
    local members = {}
    for _, m in ipairs(memberRows) do members[m.job] = m.c end

    -- Jobs + grades ESX.
    local jobRows = MySQL.query.await('SELECT `name`, `label` FROM `jobs`') or {}
    local gradeRows = MySQL.query.await('SELECT `job_name`, `grade`, `label`, `salary` FROM `job_grades` ORDER BY `job_name`, `grade`') or {}
    local gradesByJob = {}
    for _, g in ipairs(gradeRows) do
        local b = gradesByJob[g.job_name]
        if not b then b = { labels = {}, maxSalary = 0 }; gradesByJob[g.job_name] = b end
        b.labels[#b.labels + 1] = g.label
        if (g.salary or 0) > b.maxSalary then b.maxSalary = g.salary end
    end
    local jobs = {}
    for _, j in ipairs(jobRows) do
        local b = gradesByJob[j.name] or { labels = { 'Grade 0' }, maxSalary = 0 }
        jobs[#jobs + 1] = {
            id = j.name, label = j.label or j.name, members = members[j.name] or 0,
            grades = b.labels, salary = b.maxSalary,
        }
    end

    -- Lieux (table noxa, hors ESX) — seulement si renseignes (sinon le panel
    -- garde ses lieux par defaut via le bridge).
    local locRows = MySQL.query.await('SELECT * FROM `noxa_gestion_locations`') or {}
    local locations = nil
    if #locRows > 0 then
        locations = {}
        for _, l in ipairs(locRows) do
            locations[#locations + 1] = {
                id = l.id, name = l.name, type = l.type,
                x = l.x, y = l.y, z = l.z, h = l.h,
                job = l.job, sprite = l.sprite, color = l.color,
            }
        end
    end

    return {
        serverName = GetConvar('sv_projectName', GetConvar('sv_hostname', 'NOXA FA')),
        version = 'ESX Legacy',
        online = #GetPlayers(),
        maxSlots = GetConvarInt('sv_maxclients', 48),
        items = items, vehicles = vehicles, jobs = jobs,
        vehCats = (#vehCats > 0) and vehCats or nil,
        locations = locations,
    }
end

local function pushSnapshot(src)
    local snap = buildSnapshot()
    TriggerClientEvent('noxa_gestion:snapshot', src, snap)
end

-- =====================================================================
--  OUVERTURE
-- =====================================================================
RegisterNetEvent('noxa_gestion:requestOpen', function()
    local src = source
    if isSuper(src) then
        TriggerClientEvent('noxa_gestion:open', src)
        pushSnapshot(src)
    else
        TriggerClientEvent('noxa_gestion:denied', src)
    end
end)

RegisterNetEvent('noxa_gestion:getSnapshot', function()
    local src = source
    if not isSuper(src) then return end
    pushSnapshot(src)
end)

-- =====================================================================
--  ENREGISTREMENT DES MODIFICATIONS (ecriture ESX native)
-- =====================================================================
local function num(v) return tonumber(v) or 0 end

local function saveItem(d, isNew)
    local name = d.id ~= '' and d.id or d.name
    if not name or name == '' then return end
    local weight = math.max(0, math.floor(num(d.weight) + 0.5))
    local rare = d.rare and 1 or 0
    local canRemove = (d.removable == nil or d.removable) and 1 or 0
    if isNew then
        MySQL.update.await(
            'INSERT INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`) VALUES (?, ?, ?, ?, ?)',
            { name, d.label or name, weight, rare, canRemove })
    else
        MySQL.update.await(
            'UPDATE `items` SET `label` = ?, `weight` = ?, `rare` = ?, `can_remove` = ? WHERE `name` = ?',
            { d.label or name, weight, rare, canRemove, name })
    end
end

local function saveVehicle(d, isNew)
    local name = d.id ~= '' and d.id or d.model
    if not name or name == '' then return end
    -- `category` attendu = `name` de vehicle_categories. vclass porte deja ce
    -- name (vehicule existant) ; sinon `cat` est un LABEL -> on le resout.
    local category = (d.vclass and d.vclass ~= '') and d.vclass or nil
    if not category and d.cat and d.cat ~= '' then
        category = MySQL.scalar.await('SELECT `name` FROM `vehicle_categories` WHERE `label` = ? OR `name` = ? LIMIT 1', { d.cat, d.cat }) or d.cat
    end
    if isNew then
        MySQL.update.await(
            'INSERT INTO `vehicles` (`name`, `model`, `price`, `category`) VALUES (?, ?, ?, ?)',
            { name, d.model or name, num(d.price), category })
    else
        MySQL.update.await(
            'UPDATE `vehicles` SET `model` = ?, `price` = ?, `category` = ? WHERE `name` = ?',
            { d.model or name, num(d.price), category, name })
    end
end

local function saveJob(d)
    local name = d.id ~= '' and d.id or nil
    if not name or name == '' then return end
    -- upsert du job (insert si absent, sinon maj du label)
    local exists = MySQL.scalar.await('SELECT 1 FROM `jobs` WHERE `name` = ?', { name })
    if exists then
        MySQL.update.await('UPDATE `jobs` SET `label` = ? WHERE `name` = ?', { d.label or name, name })
    else
        MySQL.update.await('INSERT INTO `jobs` (`name`, `label`, `whitelisted`) VALUES (?, ?, 0)', { name, d.label or name })
    end
    -- reconstruction des grades depuis la liste du panel (salaire applique a chaque grade)
    local grades = d.grades or {}
    if #grades > 0 then
        MySQL.update.await('DELETE FROM `job_grades` WHERE `job_name` = ?', { name })
        local baseId = num(MySQL.scalar.await('SELECT MAX(`id`) FROM `job_grades`'))
        local salary = num(d.salary)
        for i, label in ipairs(grades) do
            baseId = baseId + 1
            MySQL.update.await(
                'INSERT INTO `job_grades` (`id`, `job_name`, `grade`, `name`, `label`, `salary`, `skin_male`, `skin_female`) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
                { baseId, name, i - 1, (label or ('grade' .. (i - 1))):lower():gsub('%s+', '_'), label or ('Grade ' .. (i - 1)), salary, '{}', '{}' })
        end
    end
end

local function saveLocation(d)
    local id = d.id ~= '' and d.id or nil
    if not id or id == '' then return end
    MySQL.update.await([[
        INSERT INTO `noxa_gestion_locations` (`id`, `name`, `type`, `x`, `y`, `z`, `h`, `job`, `sprite`, `color`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE `name`=VALUES(`name`), `type`=VALUES(`type`),
            `x`=VALUES(`x`), `y`=VALUES(`y`), `z`=VALUES(`z`), `h`=VALUES(`h`),
            `job`=VALUES(`job`), `sprite`=VALUES(`sprite`), `color`=VALUES(`color`)
    ]], {
        id, d.name or id, d.type or 'Blip',
        num(d.x), num(d.y), num(d.z), num(d.h),
        d.job or '—', math.floor(num(d.sprite)), math.floor(num(d.color)),
    })
end

RegisterNetEvent('noxa_gestion:save', function(payload)
    local src = source
    if not isSuper(src) then
        print(('[NOXA Gestion] Save refuse (non-superadmin) src=%s'):format(src))
        return
    end
    payload = payload or {}
    local t, d, isNew = payload.type, payload.data or {}, payload.isNew == true
    if t == 'item' then saveItem(d, isNew)
    elseif t == 'vehicle' then saveVehicle(d, isNew)
    elseif t == 'job' then saveJob(d)
    elseif t == 'location' then saveLocation(d)
    else return end
    print(('[NOXA Gestion] %s a enregistre %s « %s »'):format(src, tostring(t), tostring(d.id or d.name or d.label)))
    -- Pas de re-push ici : le bundle met deja a jour sa vue de maniere
    -- optimiste (et un remontage reinitialiserait la navigation). La
    -- persistance DB ci-dessus est l'autorite ; le prochain open relira frais.
end)
