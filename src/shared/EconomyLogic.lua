-- EconomyLogic.lua
-- Skill: game-economy
-- Description: Central logic for calculating unit values, income, and unified constants.
-- Last Updated: Fix Sync Issue

local EconomyLogic = {}

-- 1. UNIFIED TIER LIST (The Source of Truth)
EconomyLogic.TIER_ORDER = {
    "Common", "Rare", "Epic", "Legendary", "Mythic",
    "Divine", "Celestial", "Cosmic", "Eternal", "Transcendent", "Infinite"
}

-- 2. UNIFIED COLORS
EconomyLogic.RARITY_COLORS = {
    ["Common"] = Color3.fromRGB(200, 200, 200),      -- Gray
    ["Rare"] = Color3.fromRGB(0, 170, 255),          -- Blue
    ["Epic"] = Color3.fromRGB(170, 0, 255),          -- Purple
    ["Legendary"] = Color3.fromRGB(255, 170, 0),     -- Orange
    ["Mythic"] = Color3.fromRGB(255, 0, 85),         -- Red/Pink
    
    -- SUPREME (Vibrant neons)
    ["Divine"] = Color3.fromRGB(255, 255, 100),      -- Golden Yellow
    ["Celestial"] = Color3.fromRGB(100, 255, 255),   -- Cyan
    ["Cosmic"] = Color3.fromRGB(200, 100, 255),      -- Violet
    ["Eternal"] = Color3.fromRGB(255, 255, 255),     -- Pure White
    ["Transcendent"] = Color3.fromRGB(255, 100, 200),-- Pink/Magenta
    ["Infinite"] = Color3.fromRGB(50, 255, 150),     -- Bright Green
}

-- 3. ECONOMY CONFIG (ABSURD SCALING)
-- Target: Sextillions ($10^21) for highest upgrades.
local TIER_VALUES = {
    -- Tier             Income/s (Base)         Sell Value (Base)
    ["Common"]          = {Inc = 10,            Sell = 100},
    ["Rare"]            = {Inc = 1000,          Sell = 10000},       -- 1k/s
    ["Epic"]            = {Inc = 50000,         Sell = 500000},      -- 50k/s
    ["Legendary"]       = {Inc = 2500000,       Sell = 25000000},    -- 2.5M/s
    ["Mythic"]          = {Inc = 100000000,     Sell = 1000000000},  -- 100M/s
    
    -- SUPREME
    ["Divine"]          = {Inc = 5e10,          Sell = 5e11},        -- 50B/s
    ["Celestial"]       = {Inc = 2.5e13,        Sell = 2.5e14},      -- 25 Trillion/s
    ["Cosmic"]          = {Inc = 1e16,          Sell = 1e17},        -- 10 Quadrillion/s
    ["Eternal"]         = {Inc = 5e18,          Sell = 5e19},        -- 5 Quintillion/s
    ["Transcendent"]    = {Inc = 2e21,          Sell = 2e22},        -- 2 Sextillion/s
    ["Infinite"]        = {Inc = 1e24,          Sell = 1e25},        -- 1 Septillion/s
}

-- 4. CONSTANTS
EconomyLogic.EVENT_MULTIPLIER = 1.0 
local VARIANTS = {
    ["Shiny"] = 5.0,       -- Shiny Buff x5
}

-- 5. VALUE MULTIPLIER GENERATOR
-- Generates a unique multiplier per unit (x1 to x10)
-- Distribution: x1-x3 = 70% chance, x3-x10 = 30% chance
function EconomyLogic.generateValueMultiplier()
    local roll = math.random()
    
    if roll < 0.70 then
        -- 70% chance: Low multiplier (1.0 to 3.0)
        return 1.0 + (math.random() * 2.0)  -- 1.0 to 3.0
    else
        -- 30% chance: High multiplier (3.0 to 10.0)
        return 3.0 + (math.random() * 7.0)  -- 3.0 to 10.0
    end
end

-- 5. HELPERS
function EconomyLogic.Abbreviate(n)
    if n == 0 then return "0" end
    if n < 1000 then return tostring(math.floor(n)) end
    
    local suffixes = {
        "K", "M", "B", "T", "Qd", "Qn", "Sx", "Sp", "Oc", "No", "Dc"
    }
    
    local i = math.floor(math.log(n, 10) / 3)
    local v = math.pow(10, i * 3)
    local suffix = suffixes[i] or "E+"
    
    return string.format("%.1f%s", n / v, suffix)
end

function EconomyLogic.getTierColor(tier)
    return EconomyLogic.RARITY_COLORS[tier] or Color3.new(1,1,1)
end

-- CALCULATE UPGRADE COST
function EconomyLogic.calculateUpgradeCost(tier, currentLevel)
    local config = TIER_VALUES[tier] or TIER_VALUES["Common"]
    local base = config.Sell -- Use Sell value as base for upgrade cost
    
    -- Formula: Base * (1.15 ^ CurrentLevel)
    -- Cost to go form Lvl X to X+1
    local cost = math.floor(base * math.pow(1.15, currentLevel))
    return cost
end

-- CALCULATE SELL PRICE
function EconomyLogic.calculateSellPrice(unit)
    if not unit or not unit.Tier then return 0 end
    
    local config = TIER_VALUES[unit.Tier] or TIER_VALUES["Common"]
    local base = config.Sell
    local multiplier = 1
    
    -- Shiny
    if unit.Shiny or unit.IsShiny then
        multiplier = multiplier * VARIANTS.Shiny
    end
    
    -- Unique Value Multiplier (Generated when unit was created: x1 to x10)
    local valueMult = unit.ValueMultiplier or 1.0
    multiplier = multiplier * valueMult
    
    -- Level Multiplier
    local level = unit.Level or 1
    multiplier = multiplier * level
    
    return math.floor(base * multiplier * EconomyLogic.EVENT_MULTIPLIER)
end

-- CALCULATE INCOME (For Placed Units)
-- valueMultiplier is the unique oscillating value (x1 to x10) assigned to each unit
function EconomyLogic.calculateIncome(unitName, tier, level, isShiny, valueMultiplier)
    local config = TIER_VALUES[tier] or TIER_VALUES["Common"]
    local base = config.Inc
    
    local mult = 1
    
    -- Unique Value Multiplier (x1 to x10) - THE IMPORTANT ONE
    mult = mult * (valueMultiplier or 1.0)
    
    -- Shiny bonus
    if isShiny then mult = mult * VARIANTS.Shiny end
    
    -- Level Scaling
    mult = mult * (level or 1)
    
    return math.floor(base * mult * EconomyLogic.EVENT_MULTIPLIER)
end

return EconomyLogic
