--!strict
-- EconomyLogic.lua
-- Skill: game-economy
-- Description: Central logic for calculating unit values, income, and unified constants.

local EconomyLogic = {}

-- 0. TYPE DEFINITIONS
export type Unit = {
    Name: string,
    Tier: string,
    Level: number,
    Shiny: boolean?,
    IsShiny: boolean?, -- Support both naming conventions
    ValueMultiplier: number?,
    UnitId: string?,
    Quality: number?,
    Mutation: string?
}

export type TierConfig = {
    Inc: number,
    Sell: number
}

-- 1. UNIFIED TIER LIST (The Source of Truth)
EconomyLogic.TIER_ORDER = {
    "Common", "Rare", "Epic", "Legendary", "Mythic",
    "Divine", "Celestial", "Eternal", "Cosmic", "Infinite", "Transcendent"
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
    ["Eternal"]         = {Inc = 1e16,          Sell = 1e17},        -- 10 Quadrillion/s
    ["Cosmic"]          = {Inc = 5e18,          Sell = 5e19},        -- 5 Quintillion/s
    ["Infinite"]        = {Inc = 2e21,          Sell = 2e22},        -- 2 Sextillion/s
    ["Transcendent"]    = {Inc = 1e24,          Sell = 1e25},        -- 1 Septillion/s
}

-- 4. CONSTANTS
EconomyLogic.EVENT_MULTIPLIER = 1.0 
local VARIANTS = {
    ["Shiny"] = 5.0,       -- Shiny Buff x5
}

-- 5. VALUE MULTIPLIER GENERATOR
function EconomyLogic.generateValueMultiplier(luckMultiplier: number?): number
    local roll = math.random()
    local luck = luckMultiplier or 1.0
    
    -- Base threshold for Low Tier is 0.70 (70%)
    -- With Luck 2.0, threshold becomes 0.35 (35% Low, 65% High)
    local threshold = 0.70 / luck
    
    if roll < threshold then
        -- Low multiplier (1.0 to 3.0)
        return 1.0 + (math.random() * 2.0)  -- 1.0 to 3.0
    else
        -- High multiplier (3.0 to 10.0)
        return 3.0 + (math.random() * 7.0)  -- 3.0 to 10.0
    end
end



-- 6. QUALITY SYSTEM (0-100%)
function EconomyLogic.generateQuality(): number
    -- Weighted random for Quality
    -- Most units should be Average (50-89)
    local r = math.random()
    if r < 0.1 then return math.random(0, 49)        -- 10% Poor
    elseif r < 0.8 then return math.random(50, 89)   -- 70% Normal
    elseif r < 0.98 then return math.random(90, 99)  -- 18% Excellent
    else return 100 end                              -- 2% Perfect
end

function EconomyLogic.getQualityMultiplier(quality: number?): number
    local q = quality or 50
    if q < 50 then return 0.8        -- Poor
    elseif q < 90 then return 1.0    -- Normal
    elseif q < 100 then return 1.2   -- Excellent
    else return 1.5 end              -- Perfect
end
function EconomyLogic.Abbreviate(n: number?): string
    if not n or n == 0 then return "0" end
    if n < 1000 then return tostring(math.floor(n)) end
    local suffixes = {
        "K", "M", "B", "T", "Qd", "Qn", "Sx", "Sp", "Oc", "No", "Dc", 
        "Ud", "Dd", "Td", "Qad", "Qin", "Sxd", "Spd", "Ocd", "Nod", "Vg"
    }
    
    local i = math.floor(math.log(n, 10) / 3)
    local v = math.pow(10, i * 3)
    local suffix = suffixes[i] or "E+"
    
    return string.format("%.1f%s", n / v, suffix)
end

function EconomyLogic.getTierColor(tier: string): Color3
    return EconomyLogic.RARITY_COLORS[tier] or Color3.new(1,1,1)
end

-- CALCULATE UPGRADE COST
function EconomyLogic.calculateUpgradeCost(tier: string, currentLevel: number): number
    local config = TIER_VALUES[tier] or TIER_VALUES["Common"]
    local base = config.Sell -- Use Sell value as base for upgrade cost
    
    -- Formula: Base * (1.15 ^ CurrentLevel)
    -- Cost to go form Lvl X to X+1
    local cost = math.floor(base * math.pow(1.15, currentLevel))
    return cost
end

-- CALCULATE SELL PRICE
function EconomyLogic.calculateSellPrice(unit: Unit): number
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

    -- Mutation Multiplier
    if unit.Mutation then
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local MutationDefinitions = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MutationDefinitions"))
        if MutationDefinitions and MutationDefinitions[unit.Mutation] then
            multiplier = multiplier * (MutationDefinitions[unit.Mutation].IncomeMultiplier or 1.0)
        end
    end
    
    return math.floor(base * multiplier * EconomyLogic.EVENT_MULTIPLIER)
end

-- CALCULATE INCOME (For Placed Units)
function EconomyLogic.calculateIncome(unitName: string, tier: string, level: number, isShiny: boolean, valueMultiplier: number?, rebirthCount: number?, mutationName: string?): number
    local config = TIER_VALUES[tier] or TIER_VALUES["Common"]
    local base = config.Inc
    
    local mult = 1
    
    -- Unique Value Multiplier (x1 to x10) - THE IMPORTANT ONE
    mult = mult * (valueMultiplier or 1.0)
    
    -- Shiny bonus
    if isShiny then mult = mult * VARIANTS.Shiny end
    
    -- Level Scaling
    mult = mult * (level or 1)
    
    -- Mutation Multiplier
    if mutationName then
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local MutationDefinitions = require(ReplicatedStorage.Modules:WaitForChild("MutationDefinitions"))
        if MutationDefinitions and MutationDefinitions[mutationName] then
            mult = mult * (MutationDefinitions[mutationName].IncomeMultiplier or 1.0)
        end
    end

    -- Rebirth Multiplier
    if rebirthCount and rebirthCount > 0 then
        mult = mult * EconomyLogic.calculateRebirthMultiplier(rebirthCount)
    end
    
    return math.floor(base * mult * EconomyLogic.EVENT_MULTIPLIER)
end

-- REBIRTH CALCULATIONS
function EconomyLogic.calculateRebirthCost(currentRebirths: number?): number
    local base = 1000000 -- 1,000,000 (1M) Start
    local scaling = 5.0    
    local count = currentRebirths or 0
    return math.floor(base * math.pow(scaling, count))
end

function EconomyLogic.calculateRebirthMultiplier(currentRebirths: number?): number
    local bonusPerRebirth = 0.50 -- +50%
    local count = currentRebirths or 0
    return 1.0 + (count * bonusPerRebirth)
end

-- TIER ASCENSION (NEW)
function EconomyLogic.calculateAscensionCost(currentTier: string): number
    local config = TIER_VALUES[currentTier]
    if not config then return math.huge end -- Invalid tier
    
    -- Find next tier
    local tierIndex = nil
    for i, t in ipairs(EconomyLogic.TIER_ORDER) do
        if t == currentTier then
            tierIndex = i
            break
        end
    end
    
    if not tierIndex or tierIndex >= #EconomyLogic.TIER_ORDER then
        return math.huge -- Max tier, can't ascend
    end
    
    local nextTier = EconomyLogic.TIER_ORDER[tierIndex + 1]
    local nextConfig = TIER_VALUES[nextTier]
    
    -- Cost = 10x the next tier's sell value
    return math.floor(nextConfig.Sell * 10)
end

function EconomyLogic.getNextTier(currentTier: string): string?
    for i, t in ipairs(EconomyLogic.TIER_ORDER) do
        if t == currentTier then
            return EconomyLogic.TIER_ORDER[i + 1] -- may be nil if max
        end
    end
    return nil
end

-- QUALITY REROLL (NEW)
function EconomyLogic.calculateQualityRerollCost(currentTier: string, currentQuality: number): number
    local config = TIER_VALUES[currentTier] or TIER_VALUES["Common"]
    -- Base cost = 20% of sell value, increases if quality is already high
    local base = config.Sell * 0.2
    local qualityPenalty = 1 + (currentQuality / 100) -- 1.0x to 2.0x
    return math.floor(base * qualityPenalty)
end

return EconomyLogic
