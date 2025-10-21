Config = {}

-- How many models are active at once
Config.ActiveCount = 8

-- Auto-refresh settings for vehicle list
Config.AutoRefresh = {
    enabled = true,                -- Enable automatic vehicle list refresh
    intervalMinutes = 60,          -- Refresh interval in minutes (60 = 1 hour)
    notifyPlayers = false,          -- Notify all players when list refreshes
    resetCooldowns = false,        -- Reset player cooldowns on refresh (optional)
    resetScrappedList = true,      -- Reset already scrapped vehicles list
}

-- Dynamic vehicle replacement (when a vehicle is scrapped)
Config.DynamicReplacement = {
    enabled = true,                -- Replace scrapped vehicles immediately with new ones
    notifyPlayers = false,          -- Notify players when a new vehicle is added
}

-- XP-based leveling system
Config.XPSystem = {
    enabled = true,
    xpPerScrap = 25, -- Base XP gained per successful scrap
    xpBonusMultiplier = 1.5, -- Bonus XP multiplier for higher tier vehicles
}

-- Level requirements (cumulative XP needed to reach each level)
Config.LevelRequirements = {
    [1] = 0,     -- Level 1 (starting level)
    [2] = 100,   -- Level 2
    [3] = 250,   -- Level 3
    [4] = 500,   -- Level 4
    [5] = 1000,  -- Level 5
    [6] = 1750,  -- Level 6
    [7] = 2750,  -- Level 7
    [8] = 4000,  -- Level 8
    [9] = 5500,  -- Level 9
    [10] = 7500, -- Level 10 (max level)
}

-- Vehicle tiers based on player level
Config.VehicleTiers = {
    -- Tier 1: Beginner vehicles (Level 1+)
    [1] = {
        requiredLevel = 1,
        vehicles = {'blista', 'panto', 'dilettante', 'asea', 'emperor'},
        reward = {
            moneyType = false, -- 'cash', 'bank', or false to disable money rewards
            min = 800,
            max = 1200,
            items = {
                {name = 'black_money', min = 700, max = 1000, chance = 100},
            }
        }
    },
    -- Tier 2: Common vehicles (Level 3+)
    [2] = {
        requiredLevel = 3,
        vehicles = {'washington', 'premier', 'stanier', 'intruder', 'primo'},
        reward = {
            moneyType = false, -- 'cash', 'bank', or false to disable money rewards
            min = 1200,
            max = 1800,
            items = {
                {name = 'black_money', min = 1000, max = 1500, chance = 100},
            }
        }
    },
    -- Tier 3: Uncommon vehicles (Level 5+)
    [3] = {
        requiredLevel = 5,
        vehicles = {'fugitive', 'tailgater', 'asterope', 'ingot', 'oracle'},
        reward = {
            moneyType = false, -- 'cash', 'bank', or false to disable money rewards
            min = 1800,
            max = 2500,
            items = {
                {name = 'black_money', min = 1500, max = 2200, chance = 100},
            }
        }
    },
    -- Tier 4: Rare vehicles (Level 7+)
    [4] = {
        requiredLevel = 7,
        vehicles = {'schafter2', 'cognoscenti', 'exemplar', 'felon', 'jackal'},
        reward = {
            moneyType = false, -- 'cash', 'bank', or false to disable money rewards
            min = 2500,
            max = 3500,
            items = {
                {name = 'black_money', min = 2200, max = 3000, chance = 100},
            }
        }
    },
    -- Tier 5: Elite vehicles (Level 10+)
    [5] = {
        requiredLevel = 10,
        vehicles = {'buffalo2', 'dominator', 'gauntlet', 'phoenix', 'ruiner'},
        reward = {
            moneyType = false, -- 'cash', 'bank', or false to disable money rewards
            min = 3500,
            max = 5000,
            items = {
                {name = 'black_money', min = 3000, max = 4500, chance = 100},
            }
        }
    },
}

-- Legacy compatibility: Generate VehiclePool from tiers for older code
Config.VehiclePool = {}
for tierId, tier in pairs(Config.VehicleTiers) do
    for _, vehicle in ipairs(tier.vehicles) do
        table.insert(Config.VehiclePool, vehicle)
    end
end

-- Legacy reward config (kept for compatibility, use VehicleTiers instead)
Config.Reward = {
    moneyType = 'cash', -- 'cash', 'bank', or false to disable money rewards
    min = 0,
    max = 0,
    items = { -- optional item drops
        {name = 'black_money', min = 1500, max = 2500, chance = 100}
    }
}

-- Max distance to target a vehicle for scrapping
Config.ScrapRange = 5.0

-- Duration (ms) for scrapping action
Config.ScrapDuration = 30000

-- Per-player cooldown between successful scraps (seconds). Set to 0 to disable.
Config.ScrapCooldown = 1800

-- Level-based cooldown reduction (percentage reduction per level)
Config.CooldownReduction = {
    enabled = true,
    reductionPerLevel = 5, -- 5% reduction per level (max 50% at level 10)
    maxReduction = 50, -- Maximum cooldown reduction percentage
}

-- UI Configuration
Config.UI = {
    -- Job restrictions for accessing the scrap list
    restrictedJobs = {'police'}, -- Jobs that cannot access the scrap list (empty table {} to allow all jobs)
    
    -- Keybind to open scrap list (you can also use /scraplist command)
    openKey = false, -- Set to false to disable keybind
    
    -- Level and XP display settings
    showLevelInfo = true,              -- Show player's current level and XP
    showXPProgress = true,             -- Show XP progress bar to next level
    showXPGainNotification = true,     -- Show notification when gaining XP
    
    -- Tier information display
    showTierInfo = true,               -- Show available vehicle tiers
    showTierColors = true,             -- Color-code tiers (requires UI support)
    showTierRewards = true,            -- Display reward info for each tier
    showLockedTiers = true,            -- Show tiers player hasn't unlocked yet
    
    -- Vehicle list display
    showVehicleLevel = true,           -- Show required level next to each vehicle
    showVehicleTier = true,            -- Show tier classification for vehicles
    groupByTier = true,                -- Group vehicles by tier in the UI
    sortByLevel = true,                -- Sort vehicles by required level
    
    -- Reward display settings
    showRewardPreview = true,          -- Show estimated rewards before scrapping
    showItemChances = false,           -- Show item drop chances (can clutter UI)
    showMoneyRange = true,             -- Show min-max money amounts
    
    -- Progress and statistics
    showCooldownTimer = true,          -- Show remaining cooldown time
    showDailyProgress = false,         -- Show daily scrapping progress
    showTotalScrapped = false,         -- Show lifetime vehicles scrapped
    showLevelProgress = true,          -- Show progress to next level
    
    -- Notification settings
    notifications = {
        levelUp = true,                -- Notify on level up
        newTierUnlocked = true,        -- Notify when new tier becomes available
        xpGained = true,               -- Notify on XP gain
        cooldownReady = true,          -- Notify when cooldown expires
        rewardReceived = true,         -- Notify when receiving rewards
    },
    
    -- UI Theme and styling (for UI developers)
    theme = {
        primaryColor = "#3498db",      -- Primary UI color
        secondaryColor = "#2c3e50",    -- Secondary UI color
        successColor = "#27ae60",      -- Success/positive color
        warningColor = "#f39c12",      -- Warning color
        errorColor = "#e74c3c",        -- Error/negative color
        tierColors = {                 -- Colors for each tier
            [1] = "#95a5a6",          -- Tier 1: Gray (Beginner)
            [2] = "#27ae60",          -- Tier 2: Green (Common)
            [3] = "#3498db",          -- Tier 3: Blue (Uncommon)
            [4] = "#9b59b6",          -- Tier 4: Purple (Rare)
            [5] = "#f39c12",          -- Tier 5: Gold (Elite)
        }
    },
    
    -- Text and localization keys (for translation support)
    text = {
        levelLabel = "Level",
        xpLabel = "XP",
        tierLabel = "Tier",
        requiredLevel = "Required Level",
        rewardsLabel = "Rewards",
        cooldownLabel = "Cooldown",
        lockedTier = "LOCKED",
        maxLevel = "MAX LEVEL",
        nextLevel = "Next Level",
        currentXP = "Current XP",
        xpToNext = "XP to Next Level",
    }
}

-- Discord Webhook Configuration
Config.Webhook = {
    enabled = true,                                    -- Enable/disable webhook logging
    url = "YOUR_DISCORD_WEBHOOK_URL_HERE",            -- Replace with your Discord webhook URL
    
    -- Webhook settings
    username = "Vehicle Scrapping",                    -- Bot username that appears in Discord
    avatar_url = "",                                   -- Bot avatar URL (optional)
    
    -- Message settings
    color = 3066993,                                  -- Embed color (green = 3066993, blue = 3447003, red = 15158332)
    title = "🔧 Vehicle Scrapped",                    -- Embed title
    
    -- What information to include in webhook
    includePlayerName = true,                         -- Include player's character name
    includePlayerID = true,                           -- Include player's server ID
    includeCitizenID = true,                          -- Include player's citizen ID
    includeVehicleInfo = true,                        -- Include vehicle model and plate
    includeRewards = true,                            -- Include reward information
    includeLocation = false,                          -- Include player coordinates (might be too much info)
    includeXPInfo = true,                             -- Include XP gained and level info
}

-- Restrict scrapping to specific areas (leave empty to allow anywhere)
-- Each zone: { name = 'Scrapyard', center = { x = 2350.0, y = 3130.0, z = 48.0 }, radius = 75.0 }
Config.ScrapZones = {
    -- Example (Sandy Shores Scrapyard area):
    { name = 'Sandy Scrapyard', center = { x = 2377.48, y = 3121.03, z = 47.00 }, radius = 100.0 }, 
    { name = 'City Scrapyard', center = { x = -494.81, y = -1645.99, z = 17.8 }, radius = 15.0 }, 
}