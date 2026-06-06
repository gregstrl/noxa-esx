-- NOXA FA — Panel Gestion Serveur · server (permissions)
RegisterNetEvent('noxa_gestion:requestOpen', function()
    local src = source
    -- Vérif via la couche Noxa FA : rang superadmin obligatoire
    local ply = exports['noxa-fa']:GetPlayer(src)
    local isSuper = ply and ply.staffRank == 'superadmin'
    -- Fallback ACE si dispo
    if not isSuper and IsPlayerAceAllowed(src, 'noxa.gestion') then isSuper = true end
    if isSuper then
        TriggerClientEvent('noxa_gestion:open', src)
    else
        TriggerClientEvent('noxa_gestion:denied', src)
    end
end)

RegisterNetEvent('noxa_gestion:action', function(data)
    local src = source
    local ply = exports['noxa-fa']:GetPlayer(src)
    local isSuper = ply and ply.staffRank == 'superadmin'
    if not isSuper and IsPlayerAceAllowed(src, 'noxa.gestion') then isSuper = true end
    if not isSuper then return end
    -- Brancher ici les vraies actions de gestion (config-manager, etc.)
    print(('[NOXA Gestion] %s action: %s'):format(src, json.encode(data or {})))
end)
