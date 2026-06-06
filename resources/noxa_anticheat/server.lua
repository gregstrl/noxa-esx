-- =====================================================================
--  NOXA FA — Panel Anti-Cheat · serveur
-- =====================================================================
-- Permission requise. Dans server.cfg :
--   add_ace group.admin noxa.anticheat allow
--   add_principal identifier.fivem:XXXXXX group.admin   (exemple)
local ACE_PERM = 'noxa.anticheat'

-- Ouverture demandée par un joueur -> on vérifie l'ACE
RegisterNetEvent('noxa_ac:requestOpen', function()
    local src = source
    if IsPlayerAceAllowed(src, ACE_PERM) then
        TriggerClientEvent('noxa_ac:open', src)
    else
        TriggerClientEvent('noxa_ac:denied', src)
    end
end)

-- Action staff effectuée depuis le panel
RegisterNetEvent('noxa_ac:action', function(data)
    local src = source
    if not IsPlayerAceAllowed(src, ACE_PERM) then return end

    local action = data and data.type
    local target = data and data.playerId       -- id du joueur visé (à mapper sur tes IDs réels)

    -- ⚠️ Données de démonstration côté panel : branche ici ta logique réelle
    --     (système de ban en base, kick, watchlist, etc.)
    if action == 'kick' and target then
        DropPlayer(tostring(target), 'NOXA AC — Expulsé par le staff.')
    elseif action == 'ban' and target then
        -- TODO: remplacer par ton système de ban (DB / txAdmin / vMenu...)
        DropPlayer(tostring(target), 'NOXA AC — Banni par le staff.')
    end

    print(('[NOXA AC] %s -> action "%s" sur le joueur %s')
        :format(GetPlayerName(src) or src, tostring(action), tostring(target)))
end)
