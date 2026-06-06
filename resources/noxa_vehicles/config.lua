-- =====================================================================
--  NOXA VEHICLES — Configuration partagée (client + serveur)
--  Concession · Garage · Fourrière · Carburant
--  Stack : ESX Legacy (owned_vehicles, ESX.Game) · oxmysql · menuv
-- =====================================================================
Config = {}

-- Touche d'interaction (marqueurs concession / garage / fourrière / pompe)
Config.InteractKey = 38 -- E

-- Compte ESX prioritaire débité (on prend dans cash puis bank si insuffisant)
Config.PreferCash = false -- false = banque d'abord (achat), true = cash d'abord

-- ---------------------------------------------------------------------
--  CARBURANT
-- ---------------------------------------------------------------------
-- Prix au pourcent (2$/%). Réservoir plein = 100% => 200$ de 0 à plein.
Config.FuelPricePerPercent = 2
-- Consommation : % retiré par "tick" moteur allumé (réglage léger et lisible).
Config.FuelTickSeconds   = 12       -- intervalle d'un tick de conso
Config.FuelIdleUsage     = 0.10     -- conso au ralenti / tick
Config.FuelDriveUsage    = 0.55     -- conso à plein régime / tick
-- La persistance du carburant est NATIVE ESX : fuelLevel fait partie des
-- props (ESX.Game.GetVehicleProperties), stockées dans owned_vehicles.vehicle.

-- ---------------------------------------------------------------------
--  FOURRIÈRE — amende de récupération
-- ---------------------------------------------------------------------
Config.ImpoundFee = 500 -- $ pour récupérer un véhicule fourrière

-- ---------------------------------------------------------------------
--  7 CLASSES F → S (qualité croissante, prix justifiés par segment)
--  La concession regroupe le catalogue par ces classes.
-- ---------------------------------------------------------------------
Config.Classes = {
    { id = 'F', label = 'Classe F — Citadine',   color = 39, desc = 'Petits prix, premier véhicule' },
    { id = 'E', label = 'Classe E — Routière',   color = 46, desc = 'Polyvalentes du quotidien' },
    { id = 'D', label = 'Classe D — Berline',    color = 3,  desc = 'Confort et statut' },
    { id = 'C', label = 'Classe C — Tout-terrain', color = 5, desc = 'SUV & 4x4 robustes' },
    { id = 'B', label = 'Classe B — Sportive',   color = 1,  desc = 'Performances vives' },
    { id = 'A', label = 'Classe A — Supersport', color = 6,  desc = "Haut de gamme de la piste" },
    { id = 'S', label = 'Classe S — Hypercar',   color = 7,  desc = 'Exclusivité absolue' },
}

-- Catalogue concession : modèle GTA, libellé, classe, prix.
-- Prix justifiés : progression cohérente F (~9k) → S (>1M).
Config.Catalog = {
    -- F — Citadine : entrée de gamme, accessible
    { model = 'blista',   label = 'Blista',       class = 'F', price = 9000 },
    { model = 'panto',    label = 'Panto',        class = 'F', price = 7500 },
    { model = 'brioso',   label = 'Brioso R/A',   class = 'F', price = 12000 },
    { model = 'dilettante', label = 'Dilettante', class = 'F', price = 11000 },
    { model = 'issi2',    label = 'Issi',         class = 'F', price = 10500 },

    -- E — Routière : polyvalentes
    { model = 'asea',     label = 'Asea',         class = 'E', price = 16000 },
    { model = 'premier',  label = 'Premier',      class = 'E', price = 18000 },
    { model = 'sentinel', label = 'Sentinel',     class = 'E', price = 22000 },
    { model = 'futo',     label = 'Futo',         class = 'E', price = 24000 },
    { model = 'blista2',  label = 'Blista Compact', class = 'E', price = 19000 },

    -- D — Berline : confort / statut
    { model = 'fugitive', label = 'Fugitive',     class = 'D', price = 32000 },
    { model = 'tailgater', label = 'Tailgater',   class = 'D', price = 38000 },
    { model = 'oracle',   label = 'Oracle',       class = 'D', price = 42000 },
    { model = 'schafter2', label = 'Schafter',    class = 'D', price = 48000 },
    { model = 'warrener', label = 'Warrener',     class = 'D', price = 35000 },

    -- C — Tout-terrain : SUV / 4x4
    { model = 'baller2',  label = 'Baller',       class = 'C', price = 65000 },
    { model = 'mesa',     label = 'Mesa',         class = 'C', price = 52000 },
    { model = 'sandking', label = 'Sandking',     class = 'C', price = 70000 },
    { model = 'rebel2',   label = 'Rebel',        class = 'C', price = 58000 },
    { model = 'kalahari', label = 'Kalahari',     class = 'C', price = 49000 },

    -- B — Sportive : performances vives
    { model = 'sultan',   label = 'Sultan',       class = 'B', price = 95000 },
    { model = 'kuruma',   label = 'Kuruma',       class = 'B', price = 110000 },
    { model = 'buffalo',  label = 'Buffalo',      class = 'B', price = 105000 },
    { model = 'comet2',   label = 'Comet',        class = 'B', price = 135000 },
    { model = 'elegy2',   label = 'Elegy RH8',    class = 'B', price = 125000 },

    -- A — Supersport : haut de gamme piste
    { model = 'banshee',  label = 'Banshee',      class = 'A', price = 220000 },
    { model = 'jester',   label = 'Jester',       class = 'A', price = 280000 },
    { model = 'feltzer2', label = 'Feltzer',      class = 'A', price = 260000 },
    { model = 'massacro', label = 'Massacro',     class = 'A', price = 310000 },
    { model = 'sultanrs', label = 'Sultan RS',    class = 'A', price = 350000 },

    -- S — Hypercar : exclusif
    { model = 'zentorno', label = 'Zentorno',     class = 'S', price = 725000 },
    { model = 't20',      label = 'T20',          class = 'S', price = 850000 },
    { model = 'osiris',   label = 'Osiris',       class = 'S', price = 780000 },
    { model = 'adder',    label = 'Adder',        class = 'S', price = 900000 },
    { model = 'entityxf', label = 'Entity XF',    class = 'S', price = 950000 },
}

-- ---------------------------------------------------------------------
--  CONCESSION(S)
-- ---------------------------------------------------------------------
Config.Concession = {
    ped     = 's_m_m_autoshop_01',
    pos     = vector4(-33.8, -1102.0, 26.42, 64.0),   -- Premium Deluxe Motorsport
    spawn   = vector4(-19.8, -1088.7, 26.5, 50.0),    -- livraison du véhicule acheté
    blip    = { sprite = 326, color = 46, scale = 0.9, label = 'Concession' },
}

-- ---------------------------------------------------------------------
--  GARAGES (parkings) — sortir / stocker
-- ---------------------------------------------------------------------
Config.Garages = {
    {
        id = 'legion',
        label = 'Garage Légion',
        pos   = vector3(215.7, -810.0, 30.7),
        spawn = vector4(226.9, -801.0, 30.4, 250.0),
        blip  = { sprite = 357, color = 3, scale = 0.8 },
    },
    {
        id = 'sandy',
        label = 'Garage Sandy Shores',
        pos   = vector3(1208.9, 2660.9, 37.9),
        spawn = vector4(1215.4, 2660.5, 37.9, 0.0),
        blip  = { sprite = 357, color = 3, scale = 0.8 },
    },
}

-- ---------------------------------------------------------------------
--  FOURRIÈRE — récupération contre amende
-- ---------------------------------------------------------------------
Config.Impound = {
    label = 'Fourrière municipale',
    pos   = vector3(-188.9, -1166.6, 23.0),
    spawn = vector4(-204.6, -1174.0, 23.0, 160.0),
    blip  = { sprite = 68, color = 1, scale = 0.8 },
}

-- ---------------------------------------------------------------------
--  POMPES À CARBURANT — refaire le plein (2$/%)
--  Liste des stations-service principales de Los Santos.
-- ---------------------------------------------------------------------
Config.FuelStations = {
    vector3(49.4, 2778.7, 58.0),
    vector3(263.9, 2606.4, 44.9),
    vector3(1039.9, 2671.1, 39.6),
    vector3(1207.2, 2660.2, 37.9),
    vector3(2539.7, 2594.2, 37.9),
    vector3(2679.9, 3263.9, 55.2),
    vector3(2005.0, 3773.8, 32.4),
    vector3(1687.1, 4929.4, 42.1),
    vector3(1701.3, 6416.0, 32.8),
    vector3(179.8, 6602.8, 31.9),
    vector3(-94.4, 6419.5, 31.5),
    vector3(-2554.9, 2334.4, 33.1),
    vector3(-1800.3, 803.6, 138.7),
    vector3(-1437.6, -276.7, 46.2),
    vector3(-2096.2, -320.2, 13.2),
    vector3(-724.6, -935.1, 19.2),
    vector3(-526.0, -1211.0, 18.2),
    vector3(-70.2, -1761.8, 29.5),
    vector3(265.6, -1261.3, 29.3),
    vector3(819.6, -1028.8, 26.4),
    vector3(1208.9, -1402.6, 35.2),
    vector3(1181.4, -330.8, 69.3),
    vector3(620.8, 268.1, 103.1),
    vector3(2581.3, 362.0, 108.5),
    vector3(176.6, -1562.0, 29.3),
}
Config.FuelStationRadius = 6.0 -- distance d'interaction à une pompe
