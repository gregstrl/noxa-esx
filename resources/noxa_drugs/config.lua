-- =====================================================================
--  NOXA DRUGS — Config (cultures · transformation · vente)
--  Stack : ESX Legacy (xPlayer inventory + black_money) · oxmysql · menuv
--  Tout est validé SERVER-SIDE : ce fichier ne décrit que zones/recettes/prix.
-- =====================================================================
Config = {}

-- Touche d'interaction (38 = E), alignée sur noxa_vehicles
Config.InteractKey = 38

-- Anti-farm : délai mini entre deux récoltes sur un même champ (secondes)
Config.HarvestCooldown = 8
-- Anti-farm : durée d'une récolte (ms, barre de progression simple via Wait)
Config.HarvestDuration = 4000
-- Durée d'une transformation (ms)
Config.ProcessDuration = 5000

-- =====================================================================
--  CHAMPS DE CULTURE — récolte d'une matière première (E au marqueur)
--  drug   : identifiant logique de la filière
--  item   : nom EXACT de l'item ESX donné à la récolte (table `items`)
--  amount : {min,max} unités gagnées par récolte
-- =====================================================================
Config.Fields = {
    {
        drug = 'cannabis', item = 'cannabis', label = 'Champ de cannabis',
        amount = { min = 2, max = 4 },
        pos = vector3(2223.18, 5577.31, 53.84),
        blip = { sprite = 469, color = 2, scale = 0.8 },
    },
    {
        drug = 'coca', item = 'coca_leaf', label = 'Plantation de coca',
        amount = { min = 2, max = 4 },
        pos = vector3(-1605.86, 5172.30, 19.78),
        blip = { sprite = 469, color = 25, scale = 0.8 },
    },
    {
        drug = 'opium', item = 'poppy', label = 'Champ de pavot',
        amount = { min = 2, max = 4 },
        pos = vector3(1480.55, 6328.10, 23.95),
        blip = { sprite = 469, color = 47, scale = 0.8 },
    },
}

-- =====================================================================
--  LABORATOIRES — transformation (menuv : choisir une recette)
--  recipes[].input/inQty -> output/outQty
-- =====================================================================
Config.Labs = {
    {
        label = 'Laboratoire clandestin', sub = 'Transformation',
        pos = vector3(1391.21, 3605.41, 38.94),
        blip = { sprite = 499, color = 1, scale = 0.7 },
        recipes = {
            { label = 'Marijuana', input = 'cannabis',  inQty = 3, output = 'marijuana', outQty = 1 },
            { label = 'Cocaïne',   input = 'coca_leaf', inQty = 3, output = 'cocaine',   outQty = 1 },
            { label = 'Héroïne',   input = 'poppy',     inQty = 3, output = 'heroin',    outQty = 1 },
        },
    },
}

-- =====================================================================
--  REVENDEURS — vente au noir (menuv) : paiement en black_money
--  prices : prix unitaire {min,max} par item revendable (RNG server-side)
-- =====================================================================
Config.Dealers = {
    {
        label = 'Revendeur', sub = 'Marché noir', ped = 'g_m_y_mexgoon_01',
        pos = vector4(98.02, -1804.52, 26.74, 230.0),
        blip = { sprite = 51, color = 1, scale = 0.7 },
        prices = {
            marijuana = { min = 45,  max = 70 },
            cocaine   = { min = 120, max = 180 },
            heroin    = { min = 150, max = 220 },
        },
    },
    {
        label = 'Revendeur', sub = 'Marché noir', ped = 'g_m_y_mexgoon_01',
        pos = vector4(-1170.44, -1571.93, 4.39, 120.0),
        blip = { sprite = 51, color = 1, scale = 0.7 },
        prices = {
            marijuana = { min = 45,  max = 70 },
            cocaine   = { min = 120, max = 180 },
            heroin    = { min = 150, max = 220 },
        },
    },
}

-- Libellés FR pour l'affichage (items revendables)
Config.ItemLabels = {
    marijuana = 'Marijuana',
    cocaine   = 'Cocaïne',
    heroin    = 'Héroïne',
}
