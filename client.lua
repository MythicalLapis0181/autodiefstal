local hasStarted = false
local carSpawned = false
local currentVehicle = nil
local carBlip = nil
local deliveryBlip = nil
local policeRadiusBlip = nil
local isTrackingVehicle = false

CreateThread(function()
    local model = lib.requestModel(Config.NPCModel)
    
    local npc = CreatePed(4, model, Config.NPCLocation.x, Config.NPCLocation.y, Config.NPCLocation.z - 1, Config.NPCLocation.w, false, true)
    FreezeEntityPosition(npc, true)
    SetEntityInvincible(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)

    if Config.NPCBlip.Enabled then
        local blip = AddBlipForCoord(Config.NPCLocation.x, Config.NPCLocation.y, Config.NPCLocation.z)
        SetBlipSprite(blip, Config.NPCBlip.Sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, Config.NPCBlip.Scale)
        SetBlipColour(blip, Config.NPCBlip.Color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(Config.NPCBlip.Label)
        EndTextCommandSetBlipName(blip)
    end

    exports.ox_target:addLocalEntity(npc, {
        {
            name = 'start_autodiefstal',
            icon = 'fa-solid fa-car',
            label = 'Autodiefstal Starten',
            onSelect = function()
                TryStartHeist()
            end,
            canInteract = function()
                return not hasStarted
            end
        }
    })
end)

function TryStartHeist()
    local allowed, response = lib.callback.await('autodiefstal:checkStart', false)
    
    if not allowed then
        lib.notify({title = 'Fout', description = response, type = 'error'})
        return
    end

    StartLocatingPhase(response.location, response.model)
end

function StartLocatingPhase(location, modelName)
    hasStarted = true
    carSpawned = false
    
    carBlip = AddBlipForCoord(location.x, location.y, location.z)
    SetBlipSprite(carBlip, 225)
    SetBlipColour(carBlip, 1)
    SetBlipRoute(carBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Doelwit Voertuig")
    EndTextCommandSetBlipName(carBlip)

    lib.notify({title = 'Locatie Ontvangen', description = 'Ga naar de locatie en zoek het voertuig.', type = 'info'})

    CreateThread(function()
        while hasStarted and not carSpawned do
            local pCoords = GetEntityCoords(cache.ped)
            local dist = #(pCoords - vector3(location.x, location.y, location.z))

            if dist < 100.0 then
                SpawnTargetVehicle(location, modelName)
                carSpawned = true
            end
            Wait(1000)
        end
    end)
end

function SpawnTargetVehicle(location, modelName)
    lib.requestModel(modelName)
    
    ESX.Game.SpawnVehicle(modelName, vector3(location.x, location.y, location.z), location.w, function(vehicle)
        currentVehicle = vehicle
        SetVehicleDoorsLocked(vehicle, 2)
        SetVehicleAlarm(vehicle, true)
        
        exports.ox_target:addLocalEntity(vehicle, {
            {
                name = 'break_autodiefstal',
                icon = 'fa-solid fa-lock-open',
                label = 'Openbreken',
                onSelect = function()
                    AttemptBreakIn(vehicle)
                end,
                canInteract = function()
                    return hasStarted and GetVehicleDoorLockStatus(vehicle) == 2
                end
            }
        })
    end)
end

function AttemptBreakIn(vehicle)
    local hasItem = lib.callback.await('autodiefstal:checkItem', false)
    
    if not hasItem then
        lib.notify({title = 'Fout', description = 'Je mist het benodigde gereedschap ('..Config.RequiredItem..').', type = 'error'})
        return
    end

    local success = lib.skillCheck(Config.SkillCheckDifficulty, {'w', 'a', 's', 'd'})
    
    if success then
        TriggerServerEvent('autodiefstal:hackSuccess')
        SetVehicleDoorsLocked(vehicle, 1)
        SetVehicleAlarm(vehicle, false)
        PlaySoundFromEntity(-1, "Remote_Control_Open", vehicle, "PI_Menu_Sounds", 1, 0)
        StartTransportPhase()
    else
        lib.notify({title = 'Gefaald', description = 'Het alarm gaat af! Politie is gewaarschuwd.', type = 'error'})
        SetVehicleAlarm(vehicle, true)
        SetVehicleAlarmTimeLeft(vehicle, 30000)
        TriggerServerEvent('autodiefstal:hackFailed', GetEntityCoords(vehicle))
    end
end

function StartTransportPhase()
    RemoveBlip(carBlip)
    lib.notify({title = 'Gelukt', description = 'Instappen en wegwezen! Breng het voertuig weg.', type = 'success'})

    local deliveryPos = Config.DeliveryPoints[math.random(#Config.DeliveryPoints)]
    SetNewWaypoint(deliveryPos.x, deliveryPos.y)

    deliveryBlip = AddBlipForCoord(deliveryPos.x, deliveryPos.y, deliveryPos.z)
    SetBlipSprite(deliveryBlip, 1)
    SetBlipColour(deliveryBlip, 5)
    SetBlipRoute(deliveryBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Afleverlocatie")
    EndTextCommandSetBlipName(deliveryBlip)

    CreateThread(function()
        local trackingEndTime = GetGameTimer() + (Config.TrackingDuration * 60000)
        local updateInterval = Config.LiveLocationUpdateInterval * 1000
        
        while hasStarted and GetGameTimer() < trackingEndTime do
            if DoesEntityExist(currentVehicle) then
                local coords = GetEntityCoords(currentVehicle)
                TriggerServerEvent('autodiefstal:updateLocation', coords)
            end
            Wait(updateInterval)
        end
        
        if hasStarted then
            TriggerServerEvent('autodiefstal:stopTracking')
        end
    end)

    CreateThread(function()
        while hasStarted do
            local sleep = 1000
            local pCoords = GetEntityCoords(cache.ped)
            local dist = #(pCoords - deliveryPos)

            if dist < 15.0 and IsPedInVehicle(cache.ped, currentVehicle, false) then
                sleep = 0
                lib.showTextUI('[E] - Voertuig Afleveren')
                
                if IsControlJustPressed(0, 38) then
                    FinishMission()
                end
            else
                if lib.isTextUIOpen() then lib.hideTextUI() end
            end
            Wait(sleep)
        end
    end)
end

function FinishMission()
    lib.hideTextUI()
    RemoveBlip(deliveryBlip)
    
    if DoesEntityExist(currentVehicle) then
        ESX.Game.DeleteVehicle(currentVehicle)
    end
    
    TriggerServerEvent('autodiefstal:finish')
    TriggerServerEvent('autodiefstal:stopTracking')
    hasStarted = false
    currentVehicle = nil
end

RegisterNetEvent('autodiefstal:client:policeAlert', function()
    lib.notify({title = '112 Melding', description = 'Melding Autodiefstal! Druk op [G] om te accepteren.', type = 'warning', duration = Config.PoliceAcceptTime * 1000})
    
    local timer = GetGameTimer() + (Config.PoliceAcceptTime * 1000)
    
    CreateThread(function()
        while GetGameTimer() < timer do
            if IsControlJustPressed(0, Config.PoliceAcceptKey) then
                isTrackingVehicle = true
                lib.notify({title = 'Melding Geaccepteerd', description = 'Tracker ingeschakeld.', type = 'success'})
                break
            end
            Wait(0)
        end
    end)
end)

RegisterNetEvent('autodiefstal:client:updatePoliceBlip', function(coords)
    if not isTrackingVehicle then return end

    if DoesBlipExist(policeRadiusBlip) then
        RemoveBlip(policeRadiusBlip)
    end

    policeRadiusBlip = AddBlipForRadius(coords.x, coords.y, coords.z, Config.PoliceRadius)
    SetBlipColour(policeRadiusBlip, 1)
    SetBlipAlpha(policeRadiusBlip, 128)
end)

RegisterNetEvent('autodiefstal:client:removePoliceBlip', function()
    isTrackingVehicle = false
    if DoesBlipExist(policeRadiusBlip) then
        RemoveBlip(policeRadiusBlip)
        lib.notify({title = 'Tracker Verloren', description = 'Signaal van gestolen voertuig verloren.', type = 'info'})
    end
end)

RegisterNetEvent('autodiefstal:client:failedAttemptBlip', function(coords)
    lib.notify({title = '112 Melding', description = 'Poging tot autodiefstal gemeld!', type = 'warning'})
    
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 161)
    SetBlipScale(blip, 1.0)
    SetBlipColour(blip, 1)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Poging Autodiefstal")
    EndTextCommandSetBlipName(blip)

    SetTimeout(60000, function()
        RemoveBlip(blip)
    end)
end)
