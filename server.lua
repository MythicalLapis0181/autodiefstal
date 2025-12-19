local cooldowns = {}
local currentHeist = {
    active = false,
    source = nil
}

lib.callback.register('autodiefstal:checkStart', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then return false, 'Speler niet gevonden.' end

    for _, restrictedJob in pairs(Config.RestrictedJobs) do
        if xPlayer.job.name == restrictedJob then
            return false, 'Je kunt dit niet doen met jouw beroep.'
        end
    end
    
    local policeCount = 0
    local xPlayers = ESX.GetExtendedPlayers()
    
    for _, p in pairs(xPlayers) do
        for _, job in pairs(Config.PoliceJobs) do
            if p.job.name == job then
                policeCount = policeCount + 1
                break
            end
        end
    end

    if policeCount < Config.MinPolice then
        return false, 'Niet genoeg politie online ('..policeCount..'/'..Config.MinPolice..').'
    end
    
    if currentHeist.active then
        return false, 'Er is al een autodiefstal bezig.'
    end

    if cooldowns[source] and os.time() < cooldowns[source] then
        local timeLeft = math.ceil((cooldowns[source] - os.time()) / 60)
        return false, 'Je moet nog ' .. timeLeft .. ' minuten wachten.'
    end

    local location = Config.TheftLocations[math.random(#Config.TheftLocations)]
    local model = Config.Vehicles[math.random(#Config.Vehicles)]

    currentHeist.active = true
    currentHeist.source = source

    return true, {location = location, model = model}
end)

lib.callback.register('autodiefstal:checkItem', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if Config.RequiredItem then
        local item = xPlayer.getInventoryItem(Config.RequiredItem)
        if item.count < 1 then
            return false
        end
        if Config.RemoveItem then
            xPlayer.removeInventoryItem(Config.RequiredItem, 1)
        end
    end
    return true
end)

RegisterNetEvent('autodiefstal:hackFailed', function(coords)
    local xPlayers = ESX.GetExtendedPlayers()
    for _, xPlayer in pairs(xPlayers) do
        for _, job in pairs(Config.PoliceJobs) do
            if xPlayer.job.name == job then
                TriggerClientEvent('autodiefstal:client:failedAttemptBlip', xPlayer.source, coords)
            end
        end
    end
end)

RegisterNetEvent('autodiefstal:hackSuccess', function()
    local src = source
    cooldowns[src] = os.time() + (Config.Cooldown * 60)
    
    local xPlayers = ESX.GetExtendedPlayers()
    for _, xPlayer in pairs(xPlayers) do
        for _, job in pairs(Config.PoliceJobs) do
            if xPlayer.job.name == job then
                TriggerClientEvent('autodiefstal:client:policeAlert', xPlayer.source)
            end
        end
    end
end)

RegisterNetEvent('autodiefstal:updateLocation', function(coords)
    local xPlayers = ESX.GetExtendedPlayers()
    for _, xPlayer in pairs(xPlayers) do
        for _, job in pairs(Config.PoliceJobs) do
            if xPlayer.job.name == job then
                TriggerClientEvent('autodiefstal:client:updatePoliceBlip', xPlayer.source, coords)
            end
        end
    end
end)

RegisterNetEvent('autodiefstal:stopTracking', function()
    local xPlayers = ESX.GetExtendedPlayers()
    currentHeist.active = false
    currentHeist.source = nil

    for _, xPlayer in pairs(xPlayers) do
        for _, job in pairs(Config.PoliceJobs) do
            if xPlayer.job.name == job then
                TriggerClientEvent('autodiefstal:client:removePoliceBlip', xPlayer.source)
            end
        end
    end
end)

RegisterNetEvent('autodiefstal:finish', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    if currentHeist.source == src then
        currentHeist.active = false
        currentHeist.source = nil
    
        if xPlayer then
            local reward = math.random(Config.RewardAmount.min, Config.RewardAmount.max)
            xPlayer.addAccountMoney(Config.RewardAccount, reward)
            
            lib.notify(src, {
                title = 'Voltooid',
                description = 'Je hebt €' .. reward .. ' ontvangen.',
                type = 'success'
            })
        end
    end
end)

AddEventHandler('playerDropped', function()
    if currentHeist.source == source then
        currentHeist.active = false
        currentHeist.source = nil
        TriggerEvent('autodiefstal:stopTracking')
    end
end)
