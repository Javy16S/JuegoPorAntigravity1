-- EggData.lua
-- Skill: gacha-mechanics
-- Description: Configuration for Egg types, prices, and drop rates.

local EggData = {}

-- Tier order for reference (11 tiers total)
EggData.TIER_ORDER = {
    "Common", "Rare", "Epic", "Legendary", "Mythic",
    "Divine", "Celestial", "Cosmic", "Eternal", "Transcendent", "Infinite"
}

-- Shiny chance (applies to all eggs)
EggData.SHINY_CHANCE = 0.15 -- 15%

-- Egg Configurations
EggData.EGGS = {
    ["BasicEgg"] = {
        Price = 1000,
        DisplayName = "Basic Egg 🥚",
        Description = "Un huevo básico con criaturas comunes.",
        Chances = {
            Common = 0.85,    -- 85%
            Rare = 0.12,      -- 12%
            Epic = 0.03       -- 3%
        },
        -- Visual Config
        EggColor = Color3.fromRGB(255, 255, 255),
        GlowColor = Color3.fromRGB(200, 200, 200)
    },
    
    ["PremiumEgg"] = {
        Price = 50000,
        DisplayName = "Premium Egg ✨",
        Description = "Garantiza rarezas más altas.",
        Chances = {
            Rare = 0.65,      -- 65%
            Epic = 0.28,      -- 28%
            Legendary = 0.07  -- 7%
        },
        EggColor = Color3.fromRGB(0, 170, 255),
        GlowColor = Color3.fromRGB(0, 100, 255)
    },
    
    ["DivineEgg"] = {
        Price = 10000000,
        DisplayName = "Divine Egg 🌟",
        Description = "Solo para los más ricos...",
        Chances = {
            Epic = 0.50,       -- 50%
            Legendary = 0.35,  -- 35%
            Mythic = 0.15      -- 15%
        },
        EggColor = Color3.fromRGB(255, 215, 0),
        GlowColor = Color3.fromRGB(255, 170, 0)
    },
    
    -- SUPREME EGGS
    ["CosmicEgg"] = {
        Price = 1000000000, -- 1B
        DisplayName = "Cosmic Egg 🌌",
        Description = "Un huevo del espacio exterior...",
        Chances = {
            Mythic = 0.50,     -- 50%
            Divine = 0.35,     -- 35%
            Celestial = 0.12,  -- 12%
            Cosmic = 0.03      -- 3%
        },
        EggColor = Color3.fromRGB(200, 100, 255),
        GlowColor = Color3.fromRGB(150, 50, 200)
    },
    
    ["InfiniteEgg"] = {
        Price = 100000000000000, -- 100T
        DisplayName = "∞ Infinite Egg ∞",
        Description = "El huevo definitivo. Poder sin límites.",
        Chances = {
            Cosmic = 0.50,        -- 50%
            Eternal = 0.30,       -- 30%
            Transcendent = 0.15,  -- 15%
            Infinite = 0.05       -- 5%
        },
        EggColor = Color3.fromRGB(50, 255, 150),
        GlowColor = Color3.fromRGB(0, 200, 100)
    }
}

-- Animation Config
EggData.ANIMATION = {
    CarouselRadius = 8,        -- Distance from player
    CarouselHeight = 4,        -- Height above ground
    ModelCount = 10,           -- Models visible in carousel
    SpinDuration = 4.5,        -- Total seconds of animation
    SlowdownStart = 0.6,       -- When to start slowing (% of duration)
}

-- VFX Config by Tier
EggData.TIER_VFX = {
    ["Common"] = {
        ParticleColor = Color3.fromRGB(200, 200, 200),
        ParticleCount = 10,
        SoundId = "rbxassetid://138090593", -- Pop sound
        ExtraDelay = 0
    },
    ["Rare"] = {
        ParticleColor = Color3.fromRGB(0, 170, 255),
        ParticleCount = 25,
        SoundId = "rbxassetid://138090593",
        ExtraDelay = 0.3
    },
    ["Epic"] = {
        ParticleColor = Color3.fromRGB(170, 0, 255),
        ParticleCount = 50,
        SoundId = "rbxassetid://138090593",
        ExtraDelay = 0.7
    },
    ["Legendary"] = {
        ParticleColor = Color3.fromRGB(255, 170, 0),
        ParticleCount = 100,
        SoundId = "rbxassetid://138090593",
        ExtraDelay = 1.2
    },
    ["Mythic"] = {
        ParticleColor = Color3.fromRGB(255, 0, 85),
        ParticleCount = 200,
        SoundId = "rbxassetid://138090593",
        ExtraDelay = 2.0
    },
    
    -- SUPREME VFX (Epic visual effects!)
    ["Divine"] = {
        ParticleColor = Color3.fromRGB(255, 255, 100),
        ParticleCount = 400,
        SoundId = "rbxassetid://138090593",
        ExtraDelay = 2.5
    },
    ["Celestial"] = {
        ParticleColor = Color3.fromRGB(100, 255, 255),
        ParticleCount = 600,
        SoundId = "rbxassetid://138090593",
        ExtraDelay = 3.0
    },
    ["Cosmic"] = {
        ParticleColor = Color3.fromRGB(200, 100, 255),
        ParticleCount = 800,
        SoundId = "rbxassetid://138090593",
        ExtraDelay = 3.5
    },
    ["Eternal"] = {
        ParticleColor = Color3.fromRGB(255, 255, 255),
        ParticleCount = 1000,
        SoundId = "rbxassetid://138090593",
        ExtraDelay = 4.0
    },
    ["Transcendent"] = {
        ParticleColor = Color3.fromRGB(255, 100, 200),
        ParticleCount = 1500,
        SoundId = "rbxassetid://138090593",
        ExtraDelay = 5.0
    },
    ["Infinite"] = {
        ParticleColor = Color3.fromRGB(50, 255, 150),
        ParticleCount = 2000,
        SoundId = "rbxassetid://138090593",
        ExtraDelay = 6.0  -- Maximum suspense!
    }
}

-- Helper: Get random tier based on egg chances
function EggData.rollTier(eggId)
    local egg = EggData.EGGS[eggId]
    if not egg then return "Common" end
    
    local roll = math.random()
    local cumulative = 0
    
    -- Sort tiers by rarity (rarest first for proper cumulative)
    local sortedTiers = {}
    for tier, chance in pairs(egg.Chances) do
        table.insert(sortedTiers, {tier = tier, chance = chance})
    end
    table.sort(sortedTiers, function(a, b) return a.chance < b.chance end)
    
    for _, data in ipairs(sortedTiers) do
        cumulative = cumulative + data.chance
        if roll <= cumulative then
            return data.tier
        end
    end
    
    -- Fallback to most common
    return sortedTiers[#sortedTiers].tier
end

return EggData
