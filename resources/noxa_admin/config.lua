-- =====================================================================
--  NOXA ADMIN — Configuration partagée (client + serveur)
-- =====================================================================
Config = {}

-- Touche d'ouverture du menu admin (modifiable in-game : Paramètres > Touches)
Config.MenuKey = 'F10'

-- Anti-spam reports : délai minimum entre deux /report d'un même joueur (secondes)
Config.ReportCooldown = 30

-- Hiérarchie des grades staff (mod < admin < superadmin)
--  Le niveau est résolu server-side à chaque action (jamais confiance au client).
Config.Groups = {
    user       = 0,
    mod        = 1,
    admin      = 2,
    superadmin = 3,
}

-- Niveau minimum requis pour les actions sensibles
--  (set argent, ban permanent, gestion serveur, météo/heure, annonces...)
Config.SensitiveLevel = Config.Groups.admin -- 2 = admin/superadmin

-- Comptes ESX gérables depuis le menu Économie / Set argent
Config.Accounts = {
    { label = 'Cash (money)', value = 'money' },
    { label = 'Banque (bank)', value = 'bank' },
    { label = 'Argent sale (black_money)', value = 'black_money' },
}

-- Lieux de téléportation prédéfinis
Config.Locations = {
    { label = 'Mairie',         coords = vector3(-545.66, -204.91, 38.21) },
    { label = 'Hôpital (Pillbox)', coords = vector3(298.46, -584.66, 43.26) },
    { label = 'LSPD (Mission Row)', coords = vector3(428.23, -984.36, 30.71) },
    { label = 'Garage (Légion)', coords = vector3(215.74, -810.06, 30.73) },
    { label = 'Aéroport LSIA',  coords = vector3(-1037.16, -2737.61, 20.17) },
    { label = 'Sandy Shores',   coords = vector3(1853.18, 3686.62, 34.27) },
    { label = 'Paleto Bay',     coords = vector3(-110.0, 6463.0, 31.63) },
    { label = 'Mont Chiliad',   coords = vector3(450.53, 5566.45, 806.18) },
}

-- Véhicules à accès rapide (le spawn par modèle libre reste possible via saisie)
Config.QuickVehicles = {
    { label = 'Adder (Super)',   value = 'adder' },
    { label = 'Sultan RS',        value = 'sultanrs' },
    { label = 'Police (LSPD)',    value = 'police' },
    { label = 'Ambulance',        value = 'ambulance' },
    { label = 'Flatbed (dépanneuse)', value = 'flatbed' },
    { label = 'Sanchez (moto)',   value = 'sanchez' },
    { label = 'Maverick (héli)',  value = 'maverick' },
}

-- Vitesses de course (multiplicateur de sprint, max moteur = 1.49)
Config.RunSpeeds = {
    { label = 'Normale (x1.0)', value = 1.0 },
    { label = 'Rapide (x1.25)', value = 1.25 },
    { label = 'Max (x1.49)',    value = 1.49 },
}

-- Presets météo (GTA V weather types)
Config.Weathers = {
    'CLEAR', 'EXTRASUNNY', 'CLOUDS', 'OVERCAST', 'RAIN',
    'THUNDER', 'CLEARING', 'NEUTRAL', 'SNOW', 'BLIZZARD', 'SNOWLIGHT', 'XMAS', 'FOGGY',
}
