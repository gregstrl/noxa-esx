-- =====================================================================
--  NOXA DRUGS — Serveur (autorité : inventaire ESX + black_money)
--  Récolte (anti-farm), transformation (anti-dupe) et vente repassent
--  TOUTES par le serveur. Le client n'affiche que du validé.
-- =====================================================================

-- ---- Index de validation (construits depuis Config) -----------------
local FieldByDrug = {}            -- drug -> { item, amount }
for _, f in ipairs(Config.Fields) do
    FieldByDrug[f.drug] = f
end

local RecipeByOutput = {}         -- output -> recette
for _, lab in ipairs(Config.Labs) do
    for _, r in ipairs(lab.recipes) do
        RecipeByOutput[r.output] = r
    end
end

local SellPrices = {}             -- item -> { min, max } (prix marché au noir)
for _, d in ipairs(Config.Dealers) do
    for item, p in pairs(d.prices) do
        SellPrices[item] = SellPrices[item] or p
    end
end

-- Cooldown de récolte par joueur (anti-farm) : identifier -> os.time()
local lastHarvest = {}

-- ---- Helpers --------------------------------------------------------

--- Quantité d'un item réellement possédée (autorité serveur).
local function countItem(xPlayer, item)
    local it = xPlayer.getInventoryItem(item)
    return (it and it.count) or 0
end

--- Le joueur peut-il porter `count` de `item` ? (poids ESX)
local function canCarry(xPlayer, item, count)
    if xPlayer.canCarryItem then
        local ok = xPlayer.canCarryItem(item, count)
        return ok ~= false
    end
    return true
end

-- ---------------------------------------------------------------------
--  RÉCOLTE — donne une matière première (anti-farm + capacité de port)
-- ---------------------------------------------------------------------
ESX.RegisterServerCallback('noxa_drugs:harvest', function(source, cb, drug)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ ok = false, reason = 'Joueur introuvable.' }) end

    local field = FieldByDrug[drug]
    if not field then return cb({ ok = false, reason = 'Champ inconnu.' }) end

    -- Anti-farm : cooldown server-side
    local id = xPlayer.getIdentifier()
    local now = os.time()
    if lastHarvest[id] and (now - lastHarvest[id]) < Config.HarvestCooldown then
        return cb({ ok = false, reason = 'Vous récoltez trop vite.' })
    end

    local amount = math.random(field.amount.min, field.amount.max)
    if not canCarry(xPlayer, field.item, amount) then
        return cb({ ok = false, reason = 'Inventaire plein.' })
    end

    lastHarvest[id] = now
    xPlayer.addInventoryItem(field.item, amount)
    cb({ ok = true, item = field.item, amount = amount })
end)

-- ---------------------------------------------------------------------
--  TRANSFORMATION — consomme l'input, produit l'output (anti-dupe)
-- ---------------------------------------------------------------------
ESX.RegisterServerCallback('noxa_drugs:process', function(source, cb, output)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ ok = false, reason = 'Joueur introuvable.' }) end

    local r = RecipeByOutput[output]
    if not r then return cb({ ok = false, reason = 'Recette inconnue.' }) end

    if countItem(xPlayer, r.input) < r.inQty then
        return cb({ ok = false, reason = ('Il faut %dx %s.'):format(r.inQty, r.input) })
    end
    if not canCarry(xPlayer, r.output, r.outQty) then
        return cb({ ok = false, reason = 'Inventaire plein.' })
    end

    -- Retrait d'abord (autorité serveur), puis ajout — anti-dupe.
    xPlayer.removeInventoryItem(r.input, r.inQty)
    xPlayer.addInventoryItem(r.output, r.outQty)
    cb({ ok = true, output = r.output, outQty = r.outQty, label = r.label })
end)

-- ---------------------------------------------------------------------
--  STOCK VENDABLE — ce que le joueur peut écouler (affichage menuv)
-- ---------------------------------------------------------------------
ESX.RegisterServerCallback('noxa_drugs:getStock', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({}) end
    local stock = {}
    for item in pairs(SellPrices) do
        stock[item] = countItem(xPlayer, item)
    end
    cb(stock)
end)

-- ---------------------------------------------------------------------
--  VENTE — écoule tout le stock d'un item contre black_money
-- ---------------------------------------------------------------------
ESX.RegisterServerCallback('noxa_drugs:sell', function(source, cb, item)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ ok = false, reason = 'Joueur introuvable.' }) end

    local price = SellPrices[item]
    if not price then return cb({ ok = false, reason = 'Article non vendable ici.' }) end

    local qty = countItem(xPlayer, item)
    if qty <= 0 then return cb({ ok = false, reason = 'Rien à vendre.' }) end

    -- Prix unitaire tiré au sort server-side (marché volatil), gain total.
    local unit = math.random(price.min, price.max)
    local gain = unit * qty

    -- Retrait d'abord, puis paiement — anti-dupe.
    xPlayer.removeInventoryItem(item, qty)
    xPlayer.addAccountMoney('black_money', gain)

    MySQL.insert(
        'INSERT INTO noxa_drugs_sales (identifier, item, quantity, amount) VALUES (?, ?, ?, ?)',
        { xPlayer.getIdentifier(), item, qty, gain })

    print(('^2[NOXA DRUGS]^7 %s a vendu %dx %s pour $%d (argent sale)'):format(
        xPlayer.getName(), qty, item, gain))
    cb({ ok = true, sold = qty, gain = gain })
end)

-- Nettoyage du cooldown à la déconnexion (event natif FiveM, source = joueur)
AddEventHandler('playerDropped', function()
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then lastHarvest[xPlayer.getIdentifier()] = nil end
end)
