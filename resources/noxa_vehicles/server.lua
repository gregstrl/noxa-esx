-- =====================================================================
--  NOXA VEHICLES — Serveur (autorité : argent, ownership, owned_vehicles)
--  Le client n'affiche jamais que des données validées ici. Achat,
--  stockage, sortie, fourrière et plein repassent TOUS par le serveur.
-- =====================================================================

-- Index modèle->entrée catalogue (validation des achats côté serveur)
local CatalogByModel = {}
for _, v in ipairs(Config.Catalog) do
    CatalogByModel[v.model] = v
end

local ClassLabel = {}
for _, c in ipairs(Config.Classes) do
    ClassLabel[c.id] = c.label
end

-- ---------------------------------------------------------------------
--  HELPERS
-- ---------------------------------------------------------------------

--- Débite le joueur (cash + banque selon Config.PreferCash). Atomique.
--- @return boolean true si payé
local function chargePlayer(xPlayer, amount)
    amount = math.floor(amount + 0.5)
    if amount <= 0 then return true end
    local cash = xPlayer.getAccount('money').money
    local bank = xPlayer.getAccount('bank').money
    if (cash + bank) < amount then return false end

    local first, second = 'bank', 'money'
    if Config.PreferCash then first, second = 'money', 'bank' end
    local firstBal = xPlayer.getAccount(first).money
    local fromFirst = math.min(firstBal, amount)
    if fromFirst > 0 then xPlayer.removeAccountMoney(first, fromFirst) end
    local rest = amount - fromFirst
    if rest > 0 then xPlayer.removeAccountMoney(second, rest) end
    return true
end

--- Génère une plaque unique (format ESX "AAA 000").
local function generatePlate(cb)
    local function attempt()
        local plate = ('%s%s%s %s%s%s'):format(
            string.char(math.random(65, 90)), string.char(math.random(65, 90)), string.char(math.random(65, 90)),
            math.random(0, 9), math.random(0, 9), math.random(0, 9))
        MySQL.scalar('SELECT plate FROM owned_vehicles WHERE plate = ?', { plate }, function(found)
            if found then attempt() else cb(plate) end
        end)
    end
    attempt()
end

--- Récupère une ligne owned_vehicles pour ce joueur + plaque (anti-triche ownership).
local function getOwnedRow(identifier, plate, cb)
    MySQL.single('SELECT * FROM owned_vehicles WHERE owner = ? AND plate = ?',
        { identifier, plate }, cb)
end

-- ---------------------------------------------------------------------
--  CONCESSION — achat
-- ---------------------------------------------------------------------
ESX.RegisterServerCallback('noxa_vehicles:buy', function(source, cb, model)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ ok = false, reason = 'Joueur introuvable.' }) end

    local entry = CatalogByModel[model]
    if not entry then return cb({ ok = false, reason = 'Modèle indisponible.' }) end

    if not chargePlayer(xPlayer, entry.price) then
        return cb({ ok = false, reason = 'Fonds insuffisants.' })
    end

    generatePlate(function(plate)
        -- Props minimales ESX : modèle, plaque, réservoir plein. Le reste
        -- (couleurs, mods) reste d'origine ; fuelLevel est persisté nativement.
        local props = {
            model     = GetHashKey(model),
            plate     = plate,
            fuelLevel = 100.0,
        }
        MySQL.insert(
            'INSERT INTO owned_vehicles (owner, plate, vehicle, type, stored, parking) VALUES (?, ?, ?, ?, ?, ?)',
            { xPlayer.getIdentifier(), plate, json.encode(props), 'car', 0, 'concession' },
            function(id)
                if not id then
                    -- remboursement si l'insert échoue
                    xPlayer.addAccountMoney('bank', entry.price)
                    return cb({ ok = false, reason = "Erreur d'enregistrement." })
                end
                print(('^2[NOXA VEH]^7 %s a acheté %s (%s) pour $%d'):format(
                    xPlayer.getName(), entry.label, plate, entry.price))
                cb({ ok = true, model = model, plate = plate, props = props })
            end)
    end)
end)

-- ---------------------------------------------------------------------
--  GARAGE — liste des véhicules du joueur
-- ---------------------------------------------------------------------
ESX.RegisterServerCallback('noxa_vehicles:getGarage', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({}) end
    MySQL.query('SELECT plate, vehicle, stored FROM owned_vehicles WHERE owner = ? AND (pound IS NULL OR pound = \'\')',
        { xPlayer.getIdentifier() }, function(rows)
            local list = {}
            for _, r in ipairs(rows or {}) do
                local props = r.vehicle and json.decode(r.vehicle) or {}
                list[#list + 1] = {
                    plate  = r.plate,
                    stored = r.stored == 1,
                    fuel   = math.floor((props.fuelLevel or 100.0) + 0.5),
                }
            end
            cb(list)
        end)
end)

-- ---------------------------------------------------------------------
--  GARAGE — sortir un véhicule stocké
-- ---------------------------------------------------------------------
ESX.RegisterServerCallback('noxa_vehicles:retrieve', function(source, cb, plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ ok = false, reason = 'Joueur introuvable.' }) end

    getOwnedRow(xPlayer.getIdentifier(), plate, function(row)
        if not row then return cb({ ok = false, reason = 'Véhicule non possédé.' }) end
        if row.pound and row.pound ~= '' then return cb({ ok = false, reason = 'Véhicule en fourrière.' }) end
        if row.stored ~= 1 then return cb({ ok = false, reason = 'Véhicule déjà sorti.' }) end

        MySQL.update('UPDATE owned_vehicles SET stored = 0 WHERE plate = ?', { plate }, function()
            local props = row.vehicle and json.decode(row.vehicle) or { plate = plate }
            cb({ ok = true, props = props })
        end)
    end)
end)

-- ---------------------------------------------------------------------
--  GARAGE — stocker un véhicule (persiste props + fuelLevel)
-- ---------------------------------------------------------------------
ESX.RegisterServerCallback('noxa_vehicles:store', function(source, cb, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or type(data) ~= 'table' or not data.plate then
        return cb({ ok = false, reason = 'Données invalides.' })
    end

    getOwnedRow(xPlayer.getIdentifier(), data.plate, function(row)
        if not row then return cb({ ok = false, reason = 'Ce véhicule ne vous appartient pas.' }) end
        if row.pound and row.pound ~= '' then return cb({ ok = false, reason = 'Véhicule en fourrière.' }) end

        local props = type(data.props) == 'table' and data.props or (row.vehicle and json.decode(row.vehicle)) or {}
        props.plate = data.plate
        MySQL.update('UPDATE owned_vehicles SET stored = 1, vehicle = ? WHERE plate = ?',
            { json.encode(props), data.plate }, function()
                cb({ ok = true })
            end)
    end)
end)

-- ---------------------------------------------------------------------
--  FOURRIÈRE — liste + récupération contre amende
-- ---------------------------------------------------------------------
ESX.RegisterServerCallback('noxa_vehicles:getImpound', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({}) end
    MySQL.query('SELECT plate, vehicle FROM owned_vehicles WHERE owner = ? AND pound IS NOT NULL AND pound != \'\'',
        { xPlayer.getIdentifier() }, function(rows)
            local list = {}
            for _, r in ipairs(rows or {}) do
                list[#list + 1] = { plate = r.plate, fee = Config.ImpoundFee }
            end
            cb(list)
        end)
end)

ESX.RegisterServerCallback('noxa_vehicles:impoundRetrieve', function(source, cb, plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ ok = false, reason = 'Joueur introuvable.' }) end

    getOwnedRow(xPlayer.getIdentifier(), plate, function(row)
        if not row then return cb({ ok = false, reason = 'Véhicule non possédé.' }) end
        if not row.pound or row.pound == '' then return cb({ ok = false, reason = 'Véhicule pas en fourrière.' }) end
        if not chargePlayer(xPlayer, Config.ImpoundFee) then
            return cb({ ok = false, reason = ('Amende de $%d impayable.'):format(Config.ImpoundFee) })
        end
        -- Sort de fourrière => rangé au garage (stored=1), prêt à ressortir.
        MySQL.update('UPDATE owned_vehicles SET pound = NULL, stored = 1 WHERE plate = ?', { plate }, function()
            cb({ ok = true, fee = Config.ImpoundFee })
        end)
    end)
end)

-- ---------------------------------------------------------------------
--  CARBURANT — refaire le plein (2$/%)
-- ---------------------------------------------------------------------
ESX.RegisterServerCallback('noxa_vehicles:refuel', function(source, cb, missingPercent)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ ok = false, reason = 'Joueur introuvable.' }) end

    missingPercent = tonumber(missingPercent) or 0
    if missingPercent <= 0 then return cb({ ok = false, reason = 'Réservoir déjà plein.' }) end
    missingPercent = math.min(missingPercent, 100)

    local cost = math.ceil(missingPercent * Config.FuelPricePerPercent)
    if not chargePlayer(xPlayer, cost) then
        return cb({ ok = false, reason = ('Plein à $%d : fonds insuffisants.'):format(cost) })
    end
    cb({ ok = true, cost = cost })
end)
