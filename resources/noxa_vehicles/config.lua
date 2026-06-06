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
Config.ImpoundFee = 500 -- $ pour récupérer un véhicule fourrière (puits monétaire)

-- ---------------------------------------------------------------------
--  ANTI-INFLATION — TVA concession
--  Taxe prélevée EN PLUS du prix catalogue à l'achat d'un véhicule neuf.
--  N'est reversée à personne : pur puits monétaire pour absorber le cash
--  et freiner l'inflation. Affichée au joueur avant validation.
-- ---------------------------------------------------------------------
Config.PurchaseTax = 0.15 -- 15% de TVA sur tout achat en concession

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
-- Prix calés sur les fourchettes économiques Noxa (HT, hors TVA 15%) :
--   F 5-20k · E 20-60k · D 60-150k · C 150-400k · B 400-900k · A 0,9-2M · S 2-8M
-- Échelle pensée vs salaires (légal ≈3000$/h) pour une vraie progression RP.
Config.Catalog = {
    -- F — Citadine : entrée de gamme accessible (5-20k)
    { model = 'panto',    label = 'Panto',        class = 'F', price = 6500 },  -- 1er véhicule
    { model = 'blista',   label = 'Blista',       class = 'F', price = 9000 },
    { model = 'issi2',    label = 'Issi',         class = 'F', price = 11000 },
    { model = 'dilettante', label = 'Dilettante', class = 'F', price = 13000 }, -- hybride
    { model = 'brioso',   label = 'Brioso R/A',   class = 'F', price = 16000 },

    -- E — Routière : polyvalentes du quotidien (20-60k)
    { model = 'asea',     label = 'Asea',         class = 'E', price = 22000 },
    { model = 'blista2',  label = 'Blista Compact', class = 'E', price = 26000 },
    { model = 'premier',  label = 'Premier',      class = 'E', price = 30000 },
    { model = 'sentinel', label = 'Sentinel',     class = 'E', price = 38000 },
    { model = 'futo',     label = 'Futo',         class = 'E', price = 45000 },  -- icône drift

    -- D — Berline : confort / statut (60-150k)
    { model = 'warrener', label = 'Warrener',     class = 'D', price = 65000 },
    { model = 'fugitive', label = 'Fugitive',     class = 'D', price = 78000 },
    { model = 'tailgater', label = 'Tailgater',   class = 'D', price = 95000 },
    { model = 'oracle',   label = 'Oracle',       class = 'D', price = 115000 },
    { model = 'schafter2', label = 'Schafter',    class = 'D', price = 140000 }, -- luxe

    -- C — Tout-terrain : SUV / 4x4 robustes (150-400k)
    { model = 'kalahari', label = 'Kalahari',     class = 'C', price = 160000 },
    { model = 'mesa',     label = 'Mesa',         class = 'C', price = 200000 },
    { model = 'rebel2',   label = 'Rebel',        class = 'C', price = 245000 },
    { model = 'baller2',  label = 'Baller',       class = 'C', price = 310000 }, -- SUV premium
    { model = 'sandking', label = 'Sandking',     class = 'C', price = 380000 }, -- monster

    -- B — Sportive : performances vives (400-900k)
    { model = 'sultan',   label = 'Sultan',       class = 'B', price = 420000 },
    { model = 'buffalo',  label = 'Buffalo',      class = 'B', price = 520000 },
    { model = 'kuruma',   label = 'Kuruma',       class = 'B', price = 640000 },
    { model = 'elegy2',   label = 'Elegy RH8',    class = 'B', price = 760000 },
    { model = 'comet2',   label = 'Comet',        class = 'B', price = 880000 },

    -- A — Supersport : haut de gamme piste (0,9-2M)
    { model = 'banshee',  label = 'Banshee',      class = 'A', price = 950000 },
    { model = 'feltzer2', label = 'Feltzer',      class = 'A', price = 1150000 },
    { model = 'jester',   label = 'Jester',       class = 'A', price = 1400000 },
    { model = 'massacro', label = 'Massacro',     class = 'A', price = 1650000 },
    { model = 'sultanrs', label = 'Sultan RS',    class = 'A', price = 1950000 },

    -- S — Hypercar : exclusivité absolue (2-8M)
    { model = 'osiris',   label = 'Osiris',       class = 'S', price = 2400000 },
    { model = 'zentorno', label = 'Zentorno',     class = 'S', price = 3200000 },
    { model = 't20',      label = 'T20',          class = 'S', price = 4500000 },
    { model = 'adder',    label = 'Adder',        class = 'S', price = 6000000 },
    { model = 'entityxf', label = 'Entity XF',    class = 'S', price = 7800000 },
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
