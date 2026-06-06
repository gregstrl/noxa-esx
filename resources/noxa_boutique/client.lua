-- NOXA FA — Boutique · client
local isOpen = false
local function openShop()
    if isOpen then return end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })
end
RegisterNUICallback('close', function(_, cb)
    isOpen = false
    SetNuiFocus(false, false)
    cb({ ok = true })
end)
RegisterCommand('boutique', function() openShop() end, false)
RegisterKeyMapping('boutique', 'Ouvrir la boutique NOXA', 'keyboard', 'F7')
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and isOpen then SetNuiFocus(false, false) end
end)
