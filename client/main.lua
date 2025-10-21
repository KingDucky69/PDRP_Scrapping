local QBCore = exports['qb-core']:GetCoreObject()
local ActiveModels = {}
local ActiveModelNames = {}
local fetching = false
local UIOpen = false
local PendingScrap = nil

-- Vehicle hash to name mapping
local VehicleHashToName = {}
-- Build vehicle pool from all tiers
local allVehicles = {}
for tierId, tier in pairs(Config.VehicleTiers) do
    for _, model in ipairs(tier.vehicles) do
        table.insert(allVehicles, model)
        VehicleHashToName[joaat(model)] = model
    end
end

local function fetchActiveModels()
    if fetching then return end
    fetching = true
    QBCore.Functions.TriggerCallback('qb-scrap:server:GetActiveModels', function(models)
        ActiveModels = models or {}
        ActiveModelNames = {}
        for _, hash in ipairs(ActiveModels) do
            local name = VehicleHashToName[hash]
            if name then
                table.insert(ActiveModelNames, name)
            end
        end
        fetching = false
    end)
end

-- UI Functions
local function openScrapUI()
    if UIOpen then return end
    
    -- Check if player's job is restricted
    local PlayerData = QBCore.Functions.GetPlayerData()
    if PlayerData and PlayerData.job and PlayerData.job.name then
        for _, restrictedJob in ipairs(Config.UI.restrictedJobs) do
            if PlayerData.job.name == restrictedJob then
                QBCore.Functions.Notify('Your job does not allow access to vehicle scrapping.', 'error')
                return
            end
        end
    end
    
    -- fetch models and player stats then open NUI once ready
    fetching = true
    
    -- Get active models
    QBCore.Functions.TriggerCallback('qb-scrap:server:GetActiveModels', function(models)
        ActiveModels = models or {}
        ActiveModelNames = {}
        for _, hash in ipairs(ActiveModels) do
            local name = VehicleHashToName[hash]
            if name then ActiveModelNames[#ActiveModelNames+1] = name end
        end
        
        -- Get player stats
        QBCore.Functions.TriggerCallback('qb-scrap:server:GetPlayerStats', function(playerStats)
            local playerLevel = playerStats and playerStats.level or 1
            
            -- Build vehicle data with tier information
            local vehicleData = {}
            for _, vehicleName in ipairs(ActiveModelNames) do
                local tier, tierData = ScrapUtils.GetVehicleTier(vehicleName)
                if tier and tierData then
                    local canScrap = playerLevel >= tierData.requiredLevel
                    table.insert(vehicleData, {
                        model = vehicleName,
                        tier = tier,
                        requiredLevel = tierData.requiredLevel,
                        isUnlocked = canScrap
                    })
                else
                    -- Fallback for vehicles not in tier system
                    table.insert(vehicleData, {
                        model = vehicleName,
                        tier = 1,
                        requiredLevel = 1,
                        isUnlocked = true
                    })
                end
            end
            
            fetching = false
            UIOpen = true
            SetNuiFocus(true, true)
            SendNUIMessage({ 
                type = 'showUI', 
                vehicles = vehicleData,
                playerStats = playerStats or {
                    level = 1,
                    currentXP = 0,
                    nextLevelXP = 100,
                    xpToNext = 100,
                    levelProgress = 0
                }
            })
        end)
    end)
end

local function closeScrapUI()
    if not UIOpen then return end
    
    UIOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        type = 'hideUI'
    })
    
    -- Ensure cursor is properly disabled
    SetCursorLocation(0.5, 0.5)
end

-- NUI Callback
RegisterNUICallback('ui:close', function(_, cb)
    closeScrapUI()
    if cb then cb('ok') end
end)

-- Also accept legacy close path from NUI (if any)
RegisterNUICallback('closeUI', function(_, cb)
    closeScrapUI()
    if cb then cb('ok') end
end)

-- And a very simple 'close' event name for broad compatibility
RegisterNUICallback('close', function(_, cb)
    closeScrapUI()
    if cb then cb('ok') end
end)

-- Keep controls simple; NUI captures mouse/keyboard while focused

-- Keybind handling
if Config.UI and Config.UI.openKey then
    RegisterKeyMapping('openscrapui', 'Open Scrap Vehicle List', 'keyboard', Config.UI.openKey)
    RegisterCommand('openscrapui', function()
        openScrapUI()
    end, false)
end

-- Resource cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if UIOpen then
            SetNuiFocus(false, false)
            UIOpen = false
        end
    end
end)

CreateThread(function()
    fetchActiveModels()
end)

local function isActiveModel(model)
    for _, h in ipairs(ActiveModels) do
        if h == model then return true end
    end
    return false
end

local function getNearbyVehicle(radius)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local veh = GetClosestVehicle(coords.x, coords.y, coords.z, radius or (Config.ScrapRange or 5.0), 0, 70)
    if veh ~= 0 and DoesEntityExist(veh) then
        return veh
    end
    return 0
end

local function isPlayerDriven(veh)
    local driver = GetPedInVehicleSeat(veh, -1)
    if driver ~= 0 and DoesEntityExist(driver) then
        return IsPedAPlayer(driver)
    end
    return false
end

local function isInScrapZone()
    local zones = Config.ScrapZones or {}
    if not zones or #zones == 0 then return true end -- no restriction
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local px, py, pz = coords.x, coords.y, coords.z
    for _, zone in ipairs(zones) do
        local c = zone.center or zone.centre or {}
        local zx, zy, zz = c.x or 0.0, c.y or 0.0, c.z or 0.0
        local dx, dy = px - zx, py - zy
        local dist2 = dx*dx + dy*dy
        local r = (zone.radius or 0.0)
        if dist2 <= (r*r) then
            return true, (zone.name or 'Scrap Zone')
        end
    end
    return false, nil
end

RegisterCommand('scraplist', function()
    openScrapUI()
end)

-- Alternative command for just getting the list in chat (old behavior)
RegisterCommand('scraplisttext', function()
    fetchActiveModels()
    QBCore.Functions.Notify('Requested todays scrap vehicle list (server).', 'primary')
end)

-- Emergency command to close UI if stuck
RegisterCommand('scrapclose', function()
    if UIOpen then
        closeScrapUI()
        QBCore.Functions.Notify('Scrap UI forcefully closed.', 'success')
    else
        QBCore.Functions.Notify('Scrap UI is not open.', 'error')
    end
end)

RegisterCommand('scrapcar', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        QBCore.Functions.Notify('Step out of the vehicle first.', 'error')
        return
    end

    local inside, zonename = isInScrapZone()
    if not inside then
        QBCore.Functions.Notify('You must be inside a scrap zone to do this.', 'error')
        return
    end

    local veh = getNearbyVehicle(Config.ScrapRange or 5.0)
    if veh == 0 then
        QBCore.Functions.Notify('No vehicle nearby to scrap.', 'error')
        return
    end

    if isPlayerDriven(veh) then
        QBCore.Functions.Notify('You cannot scrap a player-driven vehicle.', 'error')
        return
    end

    local model = GetEntityModel(veh)
    if not isActiveModel(model) then
        QBCore.Functions.Notify('This vehicle model isn’t on today’s scrap list.', 'error')
        return
    end

    local plate = GetVehicleNumberPlateText(veh) or ''
    plate = string.upper(string.gsub(plate, '%s+', ''))

    if PendingScrap then
        QBCore.Functions.Notify('Already scrapping a vehicle…', 'error')
        return
    end

    PendingScrap = { plate = plate, model = model }

    -- Check cooldown before showing progress bar
    local remaining = 0
    QBCore.Functions.TriggerCallback('qb-scrap:server:GetCooldown', function(rem)
        remaining = tonumber(rem or 0) or 0
    end)
    local t = GetGameTimer()
    while remaining == 0 and GetGameTimer() - t < 250 do Wait(0) end
    if remaining > 0 then
        QBCore.Functions.Notify(('You must wait %ds before scrapping again.'):format(remaining), 'error')
        PendingScrap = nil
        return
    end

    -- Freeze player and show ox_lib progress bar for 30 seconds
    local playerPed = PlayerPedId()
    FreezeEntityPosition(playerPed, true)
    TaskStartScenarioInPlace(playerPed, 'WORLD_HUMAN_VEHICLE_MECHANIC', 0, true)

    local ok = lib.progressBar({
        duration = Config.ScrapDuration or 30000,
        label = 'Scrapping vehicle...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true,
            mouse = false
        }
    })

    ClearPedTasks(playerPed)
    FreezeEntityPosition(playerPed, false)

    if not ok then
        QBCore.Functions.Notify('Scrapping cancelled.', 'error')
        PendingScrap = nil
        return
    end

    -- After progress completes, trigger server attempt
    TriggerServerEvent('qb-scrap:server:AttemptScrap', PendingScrap.plate, PendingScrap.model)

    -- remember entity to delete on success
    LocalPlayer.state:set('qb_scrap_lastVeh', VehToNet(veh), true)
end)

RegisterNetEvent('qb-scrap:client:ScrapResult', function(ok, reward, moneyType)
    local netId = LocalPlayer.state.qb_scrap_lastVeh
    if ok and netId then
        local veh = NetToVeh(netId)
        if veh ~= 0 and DoesEntityExist(veh) then
            local start = GetGameTimer()
            NetworkRequestControlOfEntity(veh)
            while not NetworkHasControlOfEntity(veh) and GetGameTimer() - start < 1500 do
                Wait(50)
                NetworkRequestControlOfEntity(veh)
            end
            SetEntityAsMissionEntity(veh, true, true)
            DeleteEntity(veh)
        end
        QBCore.Functions.Notify(string.format('Scrapped vehicle for $%s %s.', reward or 0, moneyType or 'cash'), 'success')
        PendingScrap = nil
    elseif not ok then
        QBCore.Functions.Notify('Scrap failed. Vehicle may be owned or not eligible.', 'error')
        PendingScrap = nil
    end
    LocalPlayer.state:set('qb_scrap_lastVeh', nil, true)
end)

-- NUI progress no longer used; ox_lib handles progress