-- NOXA FA — Inventaire · client
local isOpen = false
local function openInv()
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
RegisterCommand('inventaire', function() openInv() end, false)
RegisterKeyMapping('inventaire', 'Ouvrir l inventaire NOXA', 'keyboard', 'I')
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and isOpen then SetNuiFocus(false, false) end
end)
