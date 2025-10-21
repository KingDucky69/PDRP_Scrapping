ScrapUtils = {}

-- Helper function to get all vehicles a player can scrap based on their level
function ScrapUtils.GetAvailableVehicles(playerLevel)
    local availableVehicles = {}
    for tierId, tier in pairs(Config.VehicleTiers) do
        if playerLevel >= tier.requiredLevel then
            for _, vehicle in ipairs(tier.vehicles) do
                table.insert(availableVehicles, vehicle)
            end
        end
    end
    return availableVehicles
end

-- Helper function to get tier info for a specific vehicle
function ScrapUtils.GetVehicleTier(vehicleModel)
    for tierId, tier in pairs(Config.VehicleTiers) do
        for _, vehicle in ipairs(tier.vehicles) do
            if vehicle == vehicleModel then
                return tierId, tier
            end
        end
    end
    return nil, nil
end

-- Helper function to calculate level from XP
function ScrapUtils.GetLevelFromXP(xp)
    local level = 1
    for lvl, requiredXP in pairs(Config.LevelRequirements) do
        if xp >= requiredXP then
            level = lvl
        else
            break
        end
    end
    return level
end

-- Helper function to calculate XP needed for next level
function ScrapUtils.GetXPToNextLevel(currentXP)
    local currentLevel = ScrapUtils.GetLevelFromXP(currentXP)
    local nextLevel = currentLevel + 1
    
    if Config.LevelRequirements[nextLevel] then
        return Config.LevelRequirements[nextLevel] - currentXP
    else
        return 0 -- Max level reached
    end
end

-- Helper function to get player's level progress as percentage
function ScrapUtils.GetLevelProgress(currentXP)
    local currentLevel = ScrapUtils.GetLevelFromXP(currentXP)
    local nextLevel = currentLevel + 1
    
    if not Config.LevelRequirements[nextLevel] then
        return 100 -- Max level reached
    end
    
    local currentLevelXP = Config.LevelRequirements[currentLevel]
    local nextLevelXP = Config.LevelRequirements[nextLevel]
    local progressXP = currentXP - currentLevelXP
    local totalXPNeeded = nextLevelXP - currentLevelXP
    
    return math.floor((progressXP / totalXPNeeded) * 100)
end

-- Helper function to get tier info with UI-friendly data
function ScrapUtils.GetTierInfoForUI(playerLevel)
    local tierInfo = {}
    
    for tierId, tier in pairs(Config.VehicleTiers) do
        local isUnlocked = playerLevel >= tier.requiredLevel
        local tierData = {
            id = tierId,
            name = "Tier " .. tierId,
            requiredLevel = tier.requiredLevel,
            isUnlocked = isUnlocked,
            vehicleCount = #tier.vehicles,
            vehicles = tier.vehicles,
            reward = tier.reward,
            color = Config.UI.theme.tierColors[tierId] or "#95a5a6"
        }
        table.insert(tierInfo, tierData)
    end
    
    -- Sort by tier ID
    table.sort(tierInfo, function(a, b) return a.id < b.id end)
    
    return tierInfo
end

-- Helper function to get vehicle info with UI data
function ScrapUtils.GetVehicleInfoForUI(playerLevel)
    local vehicleInfo = {}
    
    for tierId, tier in pairs(Config.VehicleTiers) do
        for _, vehicleModel in ipairs(tier.vehicles) do
            local isUnlocked = playerLevel >= tier.requiredLevel
            local vehicleData = {
                model = vehicleModel,
                tier = tierId,
                tierName = "Tier " .. tierId,
                requiredLevel = tier.requiredLevel,
                isUnlocked = isUnlocked,
                reward = tier.reward,
                color = Config.UI.theme.tierColors[tierId] or "#95a5a6"
            }
            table.insert(vehicleInfo, vehicleData)
        end
    end
    
    -- Sort by tier and then by vehicle name if groupByTier is enabled
    if Config.UI.groupByTier then
        table.sort(vehicleInfo, function(a, b)
            if a.tier == b.tier then
                return a.model < b.model
            end
            return a.tier < b.tier
        end)
    elseif Config.UI.sortByLevel then
        table.sort(vehicleInfo, function(a, b)
            if a.requiredLevel == b.requiredLevel then
                return a.model < b.model
            end
            return a.requiredLevel < b.requiredLevel
        end)
    end
    
    return vehicleInfo
end

-- Helper function to calculate effective cooldown based on level
function ScrapUtils.GetEffectiveCooldown(playerLevel)
    if not Config.CooldownReduction.enabled then
        return Config.ScrapCooldown
    end
    
    local reduction = math.min(
        playerLevel * Config.CooldownReduction.reductionPerLevel,
        Config.CooldownReduction.maxReduction
    )
    
    local effectiveCooldown = Config.ScrapCooldown * (1 - (reduction / 100))
    return math.floor(effectiveCooldown)
end

-- Helper function to calculate XP bonus for higher tier vehicles
function ScrapUtils.GetXPReward(tier)
    local baseXP = Config.XPSystem.xpPerScrap
    if tier > 1 then
        local bonusMultiplier = Config.XPSystem.xpBonusMultiplier
        return math.floor(baseXP * (1 + ((tier - 1) * (bonusMultiplier - 1))))
    end
    return baseXP
end

-- Helper function to check if player can scrap a specific vehicle
function ScrapUtils.CanScrapVehicle(vehicleModel, playerLevel)
    local tier, tierData = ScrapUtils.GetVehicleTier(vehicleModel)
    if not tier then
        return false, "Vehicle not in scrapping list"
    end
    
    if playerLevel < tierData.requiredLevel then
        return false, "Level " .. tierData.requiredLevel .. " required"
    end
    
    return true, nil
end

-- Helper function to format time (for cooldowns)
function ScrapUtils.FormatTime(seconds)
    if seconds <= 0 then
        return "Ready"
    end
    
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    
    if hours > 0 then
        return string.format("%02d:%02d:%02d", hours, minutes, secs)
    else
        return string.format("%02d:%02d", minutes, secs)
    end
end