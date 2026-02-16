-- FusionData.lua
-- Skill: gacha-mechanics
-- Description: Configuration for the Fusion system.

local FusionData = {}

-- Tier progression (11 tiers total)
FusionData.TIER_ORDER = {
    "Common", "Rare", "Epic", "Legendary", "Mythic",
    "Divine", "Celestial", "Eternal", "Cosmic", "Infinite", "Transcendent"
}

-- How many units needed to fuse
FusionData.FUSION_COST = 3

-- Chance to get a Shiny variant
FusionData.SHINY_CHANCE = 0.15 -- 15%

-- Mapping: Current Tier -> Next Tier
FusionData.TIER_NEXT = {
    ["Common"] = "Rare",
    ["Rare"] = "Epic",
    ["Epic"] = "Legendary",
    ["Legendary"] = "Mythic",
    ["Mythic"] = "Divine",
    
    -- SUPREME PROGRESSION
    ["Divine"] = "Celestial",
    ["Celestial"] = "Eternal",
    ["Eternal"] = "Cosmic",
    ["Cosmic"] = "Infinite",
    ["Infinite"] = "Transcendent",
    ["Transcendent"] = nil -- MAX TIER
}

-- Income multipliers by tier (for placed units)
FusionData.TIER_MULTIPLIERS = {
    ["Common"] = 1,
    ["Rare"] = 10,
    ["Epic"] = 100,
    ["Legendary"] = 1000,
    ["Mythic"] = 10000,
    
    -- SUPREME MULTIPLIERS
    ["Divine"] = 100000,
    ["Celestial"] = 1000000,
    ["Eternal"] = 10000000,
    ["Cosmic"] = 100000000,
    ["Infinite"] = 1000000000,
    ["Transcendent"] = 10000000000
}

-- Shiny bonus multiplier
FusionData.SHINY_MULTIPLIER = 2.0 -- Shiny units earn 2x

-- Animation Config for Fusion Table
FusionData.ANIMATION = {
    FloatHeight = 3,          -- How high units float during fusion
    SpinSpeed = 360,          -- Degrees per second
    ConvergeDuration = 1.5,   -- Seconds to converge to center
    ExplosionDuration = 0.5,  -- Explosion flash duration
    ResultRevealDelay = 0.8   -- Delay before showing result
}

-- VFX Colors by Tier (for fusion result)
FusionData.TIER_COLORS = {
    ["Common"] = Color3.fromRGB(200, 200, 200),
    ["Rare"] = Color3.fromRGB(0, 170, 255),
    ["Epic"] = Color3.fromRGB(170, 0, 255),
    ["Legendary"] = Color3.fromRGB(255, 170, 0),
    ["Mythic"] = Color3.fromRGB(255, 0, 85),
    
    -- SUPREME COLORS (Vibrant and unique!)
    ["Divine"] = Color3.fromRGB(255, 255, 100),      -- Golden Yellow
    ["Celestial"] = Color3.fromRGB(100, 255, 255),   -- Cyan
    ["Cosmic"] = Color3.fromRGB(200, 100, 255),      -- Violet
    ["Eternal"] = Color3.fromRGB(255, 255, 255),     -- Pure White
    ["Transcendent"] = Color3.fromRGB(255, 100, 200),-- Pink/Magenta
    ["Infinite"] = Color3.fromRGB(50, 255, 150),     -- Bright Green
}

-- Helper: Get tier index
function FusionData.getTierIndex(tier)
    for i, t in ipairs(FusionData.TIER_ORDER) do
        if t == tier then return i end
    end
    return 1
end

-- Helper: Check if fusion is possible
function FusionData.canFuse(tier)
    return FusionData.TIER_NEXT[tier] ~= nil
end

return FusionData
