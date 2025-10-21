local QBCore = exports['qb-core']:GetCoreObject()
local ActiveModels = {}
local LastScrapTimes = {}
local ScrappedPlates = {}

-- Vehicle hash to name mapping for server-side tier checking
local VehicleHashToName = {}

-- Discord Webhook Functions
local function SendWebhook(data)
    if not Config.Webhook.enabled or not Config.Webhook.url or Config.Webhook.url == "YOUR_DISCORD_WEBHOOK_URL_HERE" then
        return
    end
    
    PerformHttpRequest(Config.Webhook.url, function(err, text, headers) 
        if err ~= 200 then
            print(('[pdrp_scrapping] Webhook error: %s'):format(err))
        end
    end, 'POST', json.encode(data), { ['Content-Type'] = 'application/json' })
end

local function FormatWebhookMessage(playerData, vehicleModel, plate, rewardCash, moneyType, xpGained, playerLevel, newLevel)
    local embed = {
        title = Config.Webhook.title,
        color = Config.Webhook.color,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        fields = {}
    }
    
    -- Add player information
    if Config.Webhook.includePlayerName and playerData.charinfo then
        table.insert(embed.fields, {
            name = "👤 Player",
            value = ("%s %s"):format(playerData.charinfo.firstname or "Unknown", playerData.charinfo.lastname or "Name"),
            inline = true
        })
    end
    
    if Config.Webhook.includePlayerID then
        table.insert(embed.fields, {
            name = "🆔 Server ID",
            value = tostring(playerData.source or "Unknown"),
            inline = true
        })
    end
    
    if Config.Webhook.includeCitizenID then
        table.insert(embed.fields, {
            name = "🎫 Citizen ID",
            value = playerData.citizenid or "Unknown",
            inline = true
        })
    end
    
    -- Add vehicle information
    if Config.Webhook.includeVehicleInfo then
        table.insert(embed.fields, {
            name = "🚗 Vehicle",
            value = ("%s (Plate: %s)"):format(vehicleModel or "Unknown", plate or "Unknown"),
            inline = false
        })
    end
    
    -- Add reward information
    if Config.Webhook.includeRewards and rewardCash and rewardCash > 0 then
        local moneySymbol = moneyType == 'bank' and '🏦' or '💵'
        table.insert(embed.fields, {
            name = ("%s Reward"):format(moneySymbol),
            value = ("$%s %s"):format(rewardCash, moneyType:upper()),
            inline = true
        })
    end
    
    -- Add XP information
    if Config.Webhook.includeXPInfo and Config.XPSystem.enabled then
        local xpText = xpGained and ("+%d XP"):format(xpGained) or "No XP"
        if newLevel and newLevel > playerLevel then
            xpText = xpText .. (" 🎉 **LEVEL UP!** (%d → %d)"):format(playerLevel, newLevel)
        else
            xpText = xpText .. (" (Level %d)"):format(playerLevel or 1)
        end
        
        table.insert(embed.fields, {
            name = "⭐ Experience",
            value = xpText,
            inline = true
        })
    end
    
    local webhookData = {
        username = Config.Webhook.username,
        embeds = {embed}
    }
    
    if Config.Webhook.avatar_url and Config.Webhook.avatar_url ~= "" then
        webhookData.avatar_url = Config.Webhook.avatar_url
    end
    
    return webhookData
end

-- Build vehicle hash mapping from all tiers
local function BuildVehicleHashMapping()
    VehicleHashToName = {}
    for tierId, tier in pairs(Config.VehicleTiers) do
        for _, model in ipairs(tier.vehicles) do
            VehicleHashToName[joaat(model)] = model
        end
    end
    -- Also include legacy VehiclePool if it exists
    if Config.VehiclePool then
        for _, model in ipairs(Config.VehiclePool) do
            VehicleHashToName[joaat(model)] = model
        end
    end
end

-- Auto-inject SQL on resource start
local function InitializeDatabase()
    print('[pdrp_scrapping] Initializing database...')
    
    local sqlFile = LoadResourceFile(GetCurrentResourceName(), 'sql/install.sql')
    if not sqlFile then
        print('[pdrp_scrapping] ERROR: sql/install.sql not found!')
        return
    end
    
    -- Split SQL file by semicolons and execute each statement
    local statements = {}
    for statement in sqlFile:gmatch("([^;]+);") do
        local trimmed = statement:match("^%s*(.-)%s*$")
        if trimmed and trimmed ~= "" and not trimmed:match("^%-%-") and not trimmed:match("^/%*") then
            table.insert(statements, trimmed)
        end
    end
    
    print(('[pdrp_scrapping] Found %d SQL statements to execute'):format(#statements))
    
    if #statements == 0 then
        print('[pdrp_scrapping] Warning: No valid SQL statements found in install.sql')
        return
    end
    
    -- Execute statements sequentially to ensure proper order
    local currentIndex = 1
    
    local function executeNextStatement()
        if currentIndex > #statements then
            print('[pdrp_scrapping] ✅ Database initialization completed!')
            
            -- Verify table was created
            MySQL.Async.fetchAll('SHOW TABLES LIKE "player_scrapping_xp"', {}, function(tableCheck)
                if tableCheck and #tableCheck > 0 then
                    print('[pdrp_scrapping] ✅ Table "player_scrapping_xp" verified successfully')
                else
                    print('[pdrp_scrapping] ❌ Warning: Table "player_scrapping_xp" not found after creation')
                end
            end)
            return
        end
        
        local statement = statements[currentIndex]
        
        MySQL.Async.execute(statement, {}, function(result)
            if result then
                print(('[pdrp_scrapping] SQL Statement %d/%d executed successfully'):format(currentIndex, #statements))
            else
                print(('[pdrp_scrapping] ERROR: SQL Statement %d/%d failed'):format(currentIndex, #statements))
                print('[pdrp_scrapping] Failed statement: ' .. statement:sub(1, 100) .. '...')
            end
            
            currentIndex = currentIndex + 1
            executeNextStatement()
        end)
    end
    
    -- Start executing statements
    executeNextStatement()
end

-- XP Database Functions
local function GetPlayerXPData(citizenid, cb)
    MySQL.Async.fetchAll('SELECT * FROM player_scrapping_xp WHERE citizenid = ?', {citizenid}, function(result)
        if result and #result > 0 then
            cb(result[1])
        else
            -- Create new player record
            MySQL.Async.execute('INSERT INTO player_scrapping_xp (citizenid, current_xp, total_xp_earned, vehicles_scrapped) VALUES (?, ?, ?, ?)', 
                {citizenid, 0, 0, 0}, function(insertId)
                cb({
                    id = insertId,
                    citizenid = citizenid,
                    current_xp = 0,
                    total_xp_earned = 0,
                    vehicles_scrapped = 0,
                    last_scrap_time = nil
                })
            end)
        end
    end)
end

local function UpdatePlayerXP(citizenid, xpGained, cb)
    MySQL.Async.execute('UPDATE player_scrapping_xp SET current_xp = current_xp + ?, total_xp_earned = total_xp_earned + ?, vehicles_scrapped = vehicles_scrapped + 1, last_scrap_time = NOW() WHERE citizenid = ?', 
        {xpGained, xpGained, citizenid}, function(result)
        if cb then cb(result) end
    end)
end

local function GetPlayerStatsForUI(citizenid, cb)
    GetPlayerXPData(citizenid, function(data)
        local currentLevel = ScrapUtils.GetLevelFromXP(data.current_xp)
        local xpToNext = ScrapUtils.GetXPToNextLevel(data.current_xp)
        local levelProgress = ScrapUtils.GetLevelProgress(data.current_xp)
        local nextLevelXP = data.current_xp + xpToNext
        
        cb({
            level = currentLevel,
            currentXP = data.current_xp,
            nextLevelXP = nextLevelXP,
            xpToNext = xpToNext,
            levelProgress = levelProgress,
            totalXPEarned = data.total_xp_earned,
            vehiclesScrapped = data.vehicles_scrapped
        })
    end)
end

local function shuffle(tbl)
    local rand = math.random
    for i = #tbl, 2, -1 do
        local j = rand(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
end

local function RefreshActiveModels(isAutoRefresh)
    ActiveModels = {}
    local pool = {}
    for _, model in ipairs(Config.VehiclePool or {}) do
        pool[#pool+1] = joaat(model)
    end
    if #pool == 0 then return end
    shuffle(pool)
    local count = math.min(Config.ActiveCount or 6, #pool)
    for i = 1, count do
        ActiveModels[#ActiveModels+1] = pool[i]
    end
    
    -- Reset scrapped plates list if configured
    if Config.AutoRefresh.resetScrappedList then
        ScrappedPlates = {}
    end
    
    -- Reset cooldowns if configured (optional)
    if isAutoRefresh and Config.AutoRefresh.resetCooldowns then
        LastScrapTimes = {}
        print('[qb-scrap] Player cooldowns reset due to auto-refresh')
    end
    
    print(('[qb-scrap] Active models: %s'):format(json.encode(ActiveModels)))
    
    -- Notify players if this is an auto-refresh
    if isAutoRefresh and Config.AutoRefresh.notifyPlayers then
        TriggerClientEvent('QBCore:Notify', -1, '🔄 Scrap vehicle list has been refreshed!', 'primary')
    end
end

-- Replace a specific vehicle with a new one from the pool
local function ReplaceActiveModel(scrapedModelHash)
    if not scrapedModelHash then return false end
    
    -- Find and remove the scrapped model from active list
    local removedIndex = nil
    for i, hash in ipairs(ActiveModels) do
        if hash == scrapedModelHash then
            table.remove(ActiveModels, i)
            removedIndex = i
            break
        end
    end
    
    if not removedIndex then
        print('[qb-scrap] Warning: Tried to replace model that wasn\'t in active list')
        return false
    end
    
    -- Get all available vehicles from pool
    local pool = {}
    for _, model in ipairs(Config.VehiclePool or {}) do
        local hash = joaat(model)
        -- Only add vehicles that aren't already in the active list
        local isAlreadyActive = false
        for _, activeHash in ipairs(ActiveModels) do
            if activeHash == hash then
                isAlreadyActive = true
                break
            end
        end
        if not isAlreadyActive then
            pool[#pool+1] = hash
        end
    end
    
    if #pool == 0 then
        print('[qb-scrap] Warning: No available vehicles to replace with')
        return false
    end
    
    -- Pick a random vehicle from available pool
    shuffle(pool)
    local newModelHash = pool[1]
    
    -- Add the new model to the active list
    table.insert(ActiveModels, newModelHash)
    
    -- Get vehicle names for logging
    local scrapedName = VehicleHashToName[scrapedModelHash] or 'Unknown'
    local newName = VehicleHashToName[newModelHash] or 'Unknown'
    
    print(('[qb-scrap] Replaced scrapped vehicle: %s -> %s'):format(scrapedName, newName))
    
    -- Notify all players about the new vehicle if enabled
    if Config.DynamicReplacement.notifyPlayers then
        TriggerClientEvent('QBCore:Notify', -1, ('🚗 New scrap vehicle available: %s'):format(newName), 'primary')
    end
    
    return true
end

-- Auto-refresh timer system
local autoRefreshTimer = nil

local function StartAutoRefreshTimer()
    if not Config.AutoRefresh.enabled then return end
    
    local intervalMs = (Config.AutoRefresh.intervalMinutes or 60) * 60 * 1000
    print(('[qb-scrap] Auto-refresh enabled: %d minutes (%d ms)'):format(Config.AutoRefresh.intervalMinutes or 60, intervalMs))
    
    autoRefreshTimer = SetTimeout(intervalMs, function()
        print('[qb-scrap] Auto-refreshing vehicle list...')
        RefreshActiveModels(true) -- true indicates this is an auto-refresh
        StartAutoRefreshTimer() -- Restart the timer for next refresh
    end)
end

local function StopAutoRefreshTimer()
    if autoRefreshTimer then
        ClearTimeout(autoRefreshTimer)
        autoRefreshTimer = nil
        print('[qb-scrap] Auto-refresh timer stopped')
    end
end

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    math.randomseed(GetGameTimer() + os.time())
    
    -- Build vehicle hash mapping for server-side tier checking
    BuildVehicleHashMapping()
    
    -- Wait a moment for MySQL to be ready, then initialize database
    Citizen.SetTimeout(1000, function()
        InitializeDatabase()
    end)
    
    RefreshActiveModels(false) -- false indicates this is not an auto-refresh
    StartAutoRefreshTimer() -- Start the auto-refresh timer
end)

QBCore.Functions.CreateCallback('qb-scrap:server:GetActiveModels', function(src, cb)
    cb(ActiveModels)
end)

QBCore.Functions.CreateCallback('qb-scrap:server:GetPlayerStats', function(src, cb)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then 
        cb(nil)
        return
    end
    
    GetPlayerStatsForUI(Player.PlayerData.citizenid, function(stats)
        cb(stats)
    end)
end)

QBCore.Functions.CreateCallback('qb-scrap:server:GetActiveModelsWithNames', function(src, cb)
    local result = {}
    for _, hash in ipairs(ActiveModels) do
        for _, modelName in ipairs(Config.VehiclePool) do
            if joaat(modelName) == hash then
                table.insert(result, {hash = hash, name = modelName})
                break
            end
        end
    end
    cb(result)
end)

-- Returns remaining cooldown seconds for the requesting player
QBCore.Functions.CreateCallback('qb-scrap:server:GetCooldown', function(src, cb)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then cb(0) return end
    local cooldown = tonumber(Config.ScrapCooldown or 0) or 0
    if cooldown <= 0 then cb(0) return end
    local cid = Player.PlayerData.citizenid
    local now = os.time()
    local last = LastScrapTimes[cid] or 0
    local rem = (last + cooldown) - now
    if rem < 0 then rem = 0 end
    cb(rem)
end)

RegisterCommand('scraplist', function(source)
    -- Check if player's job is restricted
    local Player = QBCore.Functions.GetPlayer(source)
    if Player and Player.PlayerData.job and Player.PlayerData.job.name then
        for _, restrictedJob in ipairs(Config.UI.restrictedJobs) do
            if Player.PlayerData.job.name == restrictedJob then
                TriggerClientEvent('QBCore:Notify', source, 'Your job does not allow access to vehicle scrapping.', 'error')
                return
            end
        end
    end
    
    local hashes = {}
    for _, hash in ipairs(ActiveModels) do
        hashes[#hashes+1] = tostring(hash)
    end
    TriggerClientEvent('QBCore:Notify', source, 'Active scrap model hashes: ' .. table.concat(hashes, ', '), 'primary', 8000)
end, false)

local function isModelActive(modelHash)
    for _, h in ipairs(ActiveModels) do
        if h == modelHash then return true end
    end
    return false
end

local function isOwnedPlate(plate)
    plate = (plate or ''):gsub('%s+', '')
    if plate == '' then return false end
    local result = MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })
    return result ~= nil
end

RegisterNetEvent('qb-scrap:server:AttemptScrap', function(plate, modelHash)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Get player's current level first
    GetPlayerXPData(Player.PlayerData.citizenid, function(playerData)
        local playerLevel = ScrapUtils.GetLevelFromXP(playerData.current_xp)
        
        -- Get vehicle name from hash for tier checking
        local vehicleName = nil
        
        -- Ensure VehicleHashToName is built
        if not VehicleHashToName or next(VehicleHashToName) == nil then
            BuildVehicleHashMapping()
        end
        
        -- Look up vehicle name by hash
        if VehicleHashToName and next(VehicleHashToName) ~= nil then
            for hash, name in pairs(VehicleHashToName) do
                if hash == modelHash then
                    vehicleName = name
                    break
                end
            end
        end
        
        if not vehicleName then
            -- Fallback: find by iterating through model names
            if Config.VehiclePool then
                for _, modelName in ipairs(Config.VehiclePool) do
                    if joaat(modelName) == modelHash then
                        vehicleName = modelName
                        break
                    end
                end
            end
        end
        
        if not vehicleName then
            TriggerClientEvent('QBCore:Notify', src, 'Vehicle model not recognized.', 'error')
            TriggerClientEvent('qb-scrap:client:ScrapResult', src, false)
            return
        end
        
        -- Check if player can scrap this vehicle (level requirement)
        local tier, tierData = ScrapUtils.GetVehicleTier(vehicleName)
        if tier and tierData then
            if playerLevel < tierData.requiredLevel then
                TriggerClientEvent('QBCore:Notify', src, ('You need Level %d to scrap this vehicle. (Current: Level %d)'):format(tierData.requiredLevel, playerLevel), 'error')
                TriggerClientEvent('qb-scrap:client:ScrapResult', src, false)
                return
            end
        end

    -- Enforce per-player cooldown
    local cooldown = tonumber(Config.ScrapCooldown or 0) or 0
    if cooldown > 0 then
        local now = os.time()
        local cid = Player.PlayerData.citizenid
        local last = LastScrapTimes[cid] or 0
        local rem = (last + cooldown) - now
        if rem > 0 then
            TriggerClientEvent('QBCore:Notify', src, ('You must wait %ds before scrapping again.'):format(rem), 'error')
            TriggerClientEvent('qb-scrap:client:ScrapResult', src, false)
            return
        end
    end

    plate = (plate or ''):upper():gsub('%s+', '')
    if plate == '' then
        TriggerClientEvent('QBCore:Notify', src, 'No plate found.', 'error')
        return
    end

    if ScrappedPlates[plate] then
        TriggerClientEvent('QBCore:Notify', src, 'This vehicle was already scrapped.', 'error')
        return
    end

    if not isModelActive(modelHash) then
        TriggerClientEvent('QBCore:Notify', src, 'This vehicle model isn’t on today’s scrap list.', 'error')
        return
    end

    if isOwnedPlate(plate) then
        TriggerClientEvent('QBCore:Notify', src, 'This vehicle is owned and cannot be scrapped.', 'error')
        return
    end

        -- Use tier-based rewards if available, otherwise fall back to legacy
        local rewardCash = 0
        local moneyType = 'cash'
        local rewardItems = {}
        
        if tier and tierData and tierData.reward then
            -- New tier-based reward system
            local reward = tierData.reward
            if reward.moneyType and reward.moneyType ~= false then
                rewardCash = math.random(reward.min or 0, reward.max or 0)
                moneyType = reward.moneyType
            end
            rewardItems = reward.items or {}
        else
            -- Legacy reward system
            rewardCash = math.random(Config.Reward.min or 100, Config.Reward.max or 300)
            moneyType = Config.Reward.moneyType or 'cash'
            rewardItems = Config.Reward.items or {}
        end

        -- Add money if enabled
        if rewardCash > 0 and moneyType and moneyType ~= false then
            Player.Functions.AddMoney(moneyType, rewardCash, 'npc-car-scrap')
        end

        -- Add items with chance
        if rewardItems then
            for _, item in ipairs(rewardItems) do
                if math.random(1,100) <= (item.chance or 0) then
                    local amount = math.random(item.min or 1, item.max or 1)
                    Player.Functions.AddItem(item.name, amount)
                    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item.name], 'add')
                end
            end
        end

        -- Add XP for scrapping
        local xpGained = 0
        local newLevel = playerLevel
        if Config.XPSystem.enabled then
            xpGained = ScrapUtils.GetXPReward(tier or 1)
            UpdatePlayerXP(Player.PlayerData.citizenid, xpGained, function()
                newLevel = ScrapUtils.GetLevelFromXP(playerData.current_xp + xpGained)
                if newLevel > playerLevel then
                    TriggerClientEvent('QBCore:Notify', src, ('🎉 Level Up! You are now Level %d'):format(newLevel), 'success')
                end
                TriggerClientEvent('QBCore:Notify', src, ('+%d XP gained!'):format(xpGained), 'primary')
            end)
        end

        ScrappedPlates[plate] = true
        if cooldown > 0 then
            LastScrapTimes[Player.PlayerData.citizenid] = os.time()
        end
        
        -- Replace the scrapped vehicle with a new one if enabled
        if Config.DynamicReplacement and Config.DynamicReplacement.enabled then
            ReplaceActiveModel(modelHash)
        end
        
        -- Send Discord webhook notification
        if Config.Webhook.enabled then
            local webhookData = FormatWebhookMessage(
                Player.PlayerData,
                vehicleName,
                plate,
                rewardCash,
                moneyType,
                xpGained,
                playerLevel,
                newLevel
            )
            SendWebhook(webhookData)
        end
        
        TriggerClientEvent('qb-scrap:client:ScrapResult', src, true, rewardCash, moneyType)
    end)
end)

QBCore.Commands.Add('scraprefresh', 'Refresh scrap vehicle list', {}, false, function(src)
    RefreshActiveModels(false) -- false indicates manual refresh
    if src > 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Scrap vehicle list refreshed.', 'success')
    end
end, 'admin')

-- Add commands to control auto-refresh
QBCore.Commands.Add('scrapautorefresh', 'Toggle auto-refresh on/off', {{name = 'action', help = 'start/stop/status'}}, false, function(src, args)
    local action = args[1] and args[1]:lower()
    
    if action == 'start' then
        if autoRefreshTimer then
            TriggerClientEvent('QBCore:Notify', src, 'Auto-refresh is already running.', 'error')
        else
            StartAutoRefreshTimer()
            TriggerClientEvent('QBCore:Notify', src, 'Auto-refresh started.', 'success')
        end
    elseif action == 'stop' then
        if autoRefreshTimer then
            StopAutoRefreshTimer()
            TriggerClientEvent('QBCore:Notify', src, 'Auto-refresh stopped.', 'success')
        else
            TriggerClientEvent('QBCore:Notify', src, 'Auto-refresh is not running.', 'error')
        end
    elseif action == 'status' then
        local status = autoRefreshTimer and 'Running' or 'Stopped'
        local interval = Config.AutoRefresh.intervalMinutes or 60
        TriggerClientEvent('QBCore:Notify', src, ('Auto-refresh: %s (Interval: %d minutes)'):format(status, interval), 'primary')
    else
        TriggerClientEvent('QBCore:Notify', src, 'Usage: /scrapautorefresh [start/stop/status]', 'error')
    end
end, 'admin')

-- Clean up timer on resource stop
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    StopAutoRefreshTimer()
    print('[qb-scrap] Resource stopped, auto-refresh timer cleaned up')
end)