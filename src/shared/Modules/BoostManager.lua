-- BoostManager.lua
-- Skill: economy-system
-- Description: Manages temporary boosts (multipliers) for players.

local BoostManager = {}

-- CONFIG
-- Boost Definitions
local BOOSTS = {
    -- SPEED BOOSTS
    ["EnergyDrink"] = {
        Name = "Bebida Energética",
        Type = "Speed",
        Multiplier = 2.0,
        Duration = 300, -- 5 Minutes
        Icon = "rbxassetid://1234567890" -- Placeholder
    },
    ["SuperSpeed"] = {
        Name = "Velocidad Extrema",
        Type = "Speed",
        Multiplier = 3.0,
        Duration = 60, -- 1 Minute (short but powerful)
        Icon = "rbxassetid://1234567893"
    },
    
    -- CASH BOOSTS
    ["GoldenStonks"] = {
        Name = "Stonks Dorados",
        Type = "Cash",
        Multiplier = 2.0,
        Duration = 300,
        Icon = "rbxassetid://1234567891"
    },
    ["DiamondMultiplier"] = {
        Name = "Multiplicador Diamante",
        Type = "Cash",
        Multiplier = 5.0,
        Duration = 120, -- 2 Minutes (rare)
        Icon = "rbxassetid://1234567894"
    },
    
    -- LUCK BOOSTS
    ["LuckPotion"] = {
        Name = "Poción de Suerte",
        Type = "Luck",
        Multiplier = 2.0,
        Duration = 300,
        Icon = "rbxassetid://1234567892"
    },
    
    -- SPECIAL BOOSTS (NEW)
    ["LavaShield"] = {
        Name = "Escudo de Lava",
        Type = "LavaImmunity",
        Multiplier = 1.0, -- Not a multiplier, just immunity flag
        Duration = 15, -- 15 seconds only!
        Icon = "rbxassetid://1234567895"
    },
    ["MutationBoost"] = {
        Name = "Suero Mutágeno",
        Type = "Mutation",
        Multiplier = 10.0, -- 10x mutation chance!
        Duration = 120, -- 2 Minutes
        Icon = "rbxassetid://1234567896"
    }
}

BoostManager.Definitions = BOOSTS

-- API
function BoostManager.getBoostInfo(boostId)
    return BOOSTS[boostId]
end

-- Helper to calculate total multiplier for a specific type
-- dataBoosts should be { [BoostId] = ExpiryTime (os.time) }
function BoostManager.getMultiplier(player, boostType, dataBoosts)
    local mult = 1.0
    
    if not dataBoosts then return mult end
    local now = os.time()
    
    for bId, expiry in pairs(dataBoosts) do
        if expiry > now then
            local def = BOOSTS[bId]
            if def and def.Type == boostType then
                mult = mult * def.Multiplier
            end
        end
    end
    
    return mult
end

-- Helper to check if a specific boost is active
function BoostManager.isBoostActive(boostId, dataBoosts)
    if not dataBoosts then return false end
    local expiry = dataBoosts[boostId]
    return expiry and expiry > os.time()
end

function BoostManager.getAllBoosts()
    local list = {}
    for id, info in pairs(BOOSTS) do
        local copy = {}
        for k, v in pairs(info) do copy[k] = v end
        copy.Id = id
        table.insert(list, copy)
    end
    return list
end

return BoostManager
