-- NOXA FA — Téléphone · client
local isOpen = false
local function openPhone()
    if isOpen then return end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })
end
local function closePhone()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end
RegisterNUICallback('close', function(_, cb)
    isOpen = false
    SetNuiFocus(false, false)
    cb({ ok = true })
end)
RegisterCommand('phone', function() openPhone() end, false)
RegisterKeyMapping('phone', 'Ouvrir le téléphone NOXA', 'keyboard', 'F1')
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and isOpen then SetNuiFocus(false, false) end
end)
