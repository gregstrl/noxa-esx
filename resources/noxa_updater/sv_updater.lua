-- =====================================================================
--  NOXA UPDATER — sv_updater.lua
--  Commande console : `noxa update`
--
--  Contraintes FiveM respectées :
--   - os.execute / io.popen sont sandboxés -> AUCUN git ici (voir update.sh).
--   - Le serveur ne peut lire que DANS les dossiers ressource -> le SQL est
--     synchronisé dans resources/noxa_updater/sql/ par update.sh / update.bat.
--   - oxmysql par défaut n'autorise pas le multi-statement : on le détecte et
--     on guide l'admin si `multipleStatements=true` manque dans server.cfg.
-- =====================================================================

local RES           = GetCurrentResourceName()
local MIG_DIR       = 'sql/migrations/'
local INSTALL_FILE  = 'sql/install.sql'
local INDEX_FILE    = 'sql/migrations.index'
local STATE_FILE    = 'sync/state.txt'          -- écrit par update.sh (diff git)
local BASELINE_KEY  = '__baseline__'

-- ---------------------------------------------------------------------
--  Sortie console (rapport)
-- ---------------------------------------------------------------------
local function log(msg)  print('^5[noxa_updater]^7 ' .. msg) end
local function ok(msg)   print('^5[noxa_updater]^7 ^2' .. msg .. '^7') end
local function warn(msg) print('^5[noxa_updater]^7 ^3' .. msg .. '^7') end
local function err(msg)  print('^5[noxa_updater]^7 ^1' .. msg .. '^7') end

-- ---------------------------------------------------------------------
--  Helpers SQL (oxmysql, API MySQL.*)
-- ---------------------------------------------------------------------

-- Exécute une requête brute (multi-statements possible) ; renvoie ok, erreur.
local function runSQL(sql)
    if not sql or sql == '' then return true end
    local good, res = pcall(function() return MySQL.query.await(sql) end)
    if not good then return false, tostring(res) end
    return true
end

-- Vérifie que la chaîne de connexion autorise le multi-statement (requis pour
-- jouer install.sql et les migrations PREPARE/EXECUTE en un seul appel).
local function multiStatementsEnabled()
    local good = pcall(function() return MySQL.query.await('SELECT 1 AS a; SELECT 2 AS b') end)
    return good
end

local function tableExists(name)
    local n = MySQL.scalar.await(
        'SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?',
        { name })
    return (tonumber(n) or 0) > 0
end

local function migrationApplied(name)
    local n = MySQL.scalar.await('SELECT COUNT(*) FROM noxa_migrations WHERE name = ?', { name })
    return (tonumber(n) or 0) > 0
end

local function markMigration(name)
    MySQL.query.await('INSERT IGNORE INTO noxa_migrations (name) VALUES (?)', { name })
end

-- ---------------------------------------------------------------------
--  Lecture des fichiers SQL (dans la ressource = autorisé par le sandbox)
-- ---------------------------------------------------------------------

-- Liste ordonnée des migrations. Source primaire : sql/migrations.index
-- (généré par update.sh). Fallback : io.readdir du dossier monté.
local function listMigrations()
    local out = {}
    local index = LoadResourceFile(RES, INDEX_FILE)
    if index and index ~= '' then
        for line in index:gmatch('[^\r\n]+') do
            line = line:gsub('%s+$', ''):gsub('^%s+', '')
            if line ~= '' and line:match('%.sql$') then out[#out + 1] = line end
        end
    else
        -- Fallback : lecture directe du dossier monté @resource/...
        local good, entries = pcall(io.readdir, ('@%s/%s'):format(RES, MIG_DIR))
        if good and type(entries) == 'table' then
            for _, e in ipairs(entries) do
                local fname = type(e) == 'table' and (e.name or e[1]) or e
                if type(fname) == 'string' and fname:match('%.sql$') then out[#out + 1] = fname end
            end
        end
    end
    table.sort(out)
    return out
end

-- ---------------------------------------------------------------------
--  PHASE 1 — Synchronisation SQL
-- ---------------------------------------------------------------------
local function syncDatabase(report)
    -- noxa_migrations doit exister avant tout (CREATE IF NOT EXISTS = sûr).
    local createdMig = runSQL([[
        CREATE TABLE IF NOT EXISTS `noxa_migrations` (
          `name` VARCHAR(190) NOT NULL,
          `applied_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    if not createdMig then
        err('Impossible de créer la table noxa_migrations. Connexion oxmysql ? base `noxa` importée ?')
        return false
    end

    -- BASELINE (install.sql) : joué une seule fois.
    if migrationApplied(BASELINE_KEY) then
        report.sql[#report.sql + 1] = 'base : baseline déjà appliquée (install.sql ignoré)'
    else
        if tableExists('users') then
            -- Base déjà importée (manuellement / phpMyAdmin) : on marque la
            -- baseline sans rejouer install.sql (évite les doublons).
            markMigration(BASELINE_KEY)
            report.sql[#report.sql + 1] = 'base : déjà installée -> baseline enregistrée'
        else
            local install = LoadResourceFile(RES, INSTALL_FILE)
            if not install or install == '' then
                err(('install.sql introuvable (%s/%s). Lance update.sh pour synchroniser le SQL.'):format(RES, INSTALL_FILE))
                return false
            end
            local good, e = runSQL(install)
            if not good then
                err('Echec install.sql : ' .. tostring(e))
                return false
            end
            markMigration(BASELINE_KEY)
            report.sql[#report.sql + 1] = 'base : install.sql appliqué (tables créées) -> baseline enregistrée'
        end
    end

    -- MIGRATIONS incrémentales : chacune une seule fois, dans l'ordre.
    local migrations = listMigrations()
    if #migrations == 0 then
        report.sql[#report.sql + 1] = 'migrations : aucune trouvée'
    end
    for _, name in ipairs(migrations) do
        if migrationApplied(name) then
            -- déjà jouée -> rien
        else
            local content = LoadResourceFile(RES, MIG_DIR .. name)
            if not content or content == '' then
                warn('migration illisible, ignorée : ' .. name)
            else
                local good, e = runSQL(content)
                if good then
                    markMigration(name)
                    report.migrationsApplied[#report.migrationsApplied + 1] = name
                    report.sql[#report.sql + 1] = 'migration appliquée : ' .. name
                else
                    err('migration ECHEC (' .. name .. ') : ' .. tostring(e))
                    report.sql[#report.sql + 1] = 'migration ECHEC : ' .. name
                    report.hadError = true
                end
            end
        end
    end

    return true
end

-- ---------------------------------------------------------------------
--  PHASE 2 — Rechargement des ressources
-- ---------------------------------------------------------------------

-- Lit le diff calculé par update.sh : lignes "A nom", "M nom", "D nom".
local function readState()
    local raw = LoadResourceFile(RES, STATE_FILE)
    if not raw or raw == '' then return nil end
    local st = { added = {}, modified = {}, removed = {} }
    for line in raw:gmatch('[^\r\n]+') do
        local tag, name = line:match('^%s*([AMD])%s+([%w_%[%]%-%.]+)%s*$')
        if tag == 'A' then st.added[#st.added + 1] = name
        elseif tag == 'M' then st.modified[#st.modified + 1] = name
        elseif tag == 'D' then st.removed[#st.removed + 1] = name end
    end
    -- consomme l'état pour ne pas le rejouer au prochain `noxa update`.
    SaveResourceFile(RES, STATE_FILE, '', -1)
    return st
end

local function reloadOne(name)
    local state = GetResourceState(name)
    if state == 'started' then
        ExecuteCommand('restart ' .. name)
    else
        ExecuteCommand('ensure ' .. name)
    end
end

-- Fallback : recharge toutes les ressources noxa_* (+ cœur) présentes.
local function reloadAllNoxa(report)
    -- Fallback (pas de diff git) : on ne recharge QUE les noxa_*. On ne touche
    -- PAS à es_extended ici (un restart du framework en pleine session est
    -- inutilement violent) : le cœur n'est rechargé que si update.sh l'a
    -- explicitement marqué « modifié » dans state.txt (voir reloadResources).
    local total = GetNumResources and GetNumResources() or 0
    for i = 0, total - 1 do
        local name = GetResourceByFindIndex(i)
        if name and (name:sub(1, 5) == 'noxa_') and name ~= RES then
            reloadOne(name)
            report.reloaded[#report.reloaded + 1] = name
        end
    end
end

local function reloadResources(report)
    -- 1) refresh : prend en compte les dossiers ajoutés / supprimés sur disque.
    ExecuteCommand('refresh')
    Wait(500)

    local st = readState()
    if st then
        -- Diff précis fourni par update.sh.
        for _, name in ipairs(st.removed) do
            if GetResourceState(name) == 'started' then
                ExecuteCommand('stop ' .. name)
            end
            report.removed[#report.removed + 1] = name
        end
        for _, name in ipairs(st.added) do
            ExecuteCommand('ensure ' .. name)
            report.added[#report.added + 1] = name
        end
        for _, name in ipairs(st.modified) do
            reloadOne(name)
            report.reloaded[#report.reloaded + 1] = name
        end
        report.usedState = true
    else
        -- Pas de diff git : on (re)charge tout le périmètre noxa_*.
        reloadAllNoxa(report)
    end
end

-- ---------------------------------------------------------------------
--  RAPPORT
-- ---------------------------------------------------------------------
local function printReport(report)
    print('^5=====================================================================^7')
    print('^5  NOXA UPDATER — RAPPORT^7')
    print('^5=====================================================================^7')

    print('^5[SQL]^7')
    if #report.sql == 0 then print('  (rien)') end
    for _, l in ipairs(report.sql) do print('  - ' .. l) end

    local function block(title, list)
        print(('^5[%s]^7 %d'):format(title, #list))
        for _, n in ipairs(list) do print('  - ' .. n) end
    end

    if report.usedState then
        block('AJOUTÉES', report.added)
        block('MISES À JOUR', report.reloaded)
        block('SUPPRIMÉES', report.removed)
    else
        warn('Pas de diff git (sync/state.txt absent) : rechargement global noxa_*.')
        block('RECHARGÉES', report.reloaded)
    end

    print('^5---------------------------------------------------------------------^7')
    if report.hadError then
        err('Terminé AVEC erreurs (voir ci-dessus).')
    else
        ok('Synchronisation terminée avec succès.')
    end
    print('^5=====================================================================^7')
end

-- ---------------------------------------------------------------------
--  COMMANDE : noxa update
-- ---------------------------------------------------------------------
local running = false

local function runInstall(source)
    if running then warn('Mise à jour déjà en cours, patiente.'); return end
    running = true

    local report = {
        sql = {}, migrationsApplied = {},
        added = {}, reloaded = {}, removed = {},
        usedState = false, hadError = false,
    }

    CreateThread(function()
        log('Démarrage de la synchronisation Noxa ...')

        if not multiStatementsEnabled() then
            err('oxmysql refuse le multi-statement.')
            err('Ajoute `multipleStatements=true` à mysql_connection_string dans server.cfg, ex :')
            err('  set mysql_connection_string "mysql://user:pass@host/noxa?multipleStatements=true&charset=utf8mb4"')
            running = false
            return
        end

        local okSql = syncDatabase(report)
        if not okSql then report.hadError = true end

        reloadResources(report)

        printReport(report)
        running = false
    end)
end

-- restricted = true : seuls la console (source 0) et les détenteurs de l'ACE
-- `command.noxa` peuvent l'appeler. On verrouille en plus sur noxa.updater.
RegisterCommand('noxa', function(source, args)
    if (args[1] or ''):lower() ~= 'update' then
        if source == 0 then
            log('Usage : noxa update')
        end
        return
    end

    -- JAMAIS un joueur : console uniquement, ou ACE noxa.updater.
    if source ~= 0 and not IsPlayerAceAllowed(source, 'noxa.updater') then
        return
    end

    runInstall(source)
end, true)

log('Prêt. Tape `noxa update` dans la console pour synchroniser le serveur avec GitHub.')
