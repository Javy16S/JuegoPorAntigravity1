-- MutationDefinitions.lua
-- Description: Configuration for Unit Mutations (Name, Chance, Visuals, Stats)
-- UPDATED: Added Frozen, Infernal, Phantom, Cosmic, and Arcane mutations

local MutationDefinitions = {
    -- TABLE: name -> data
    
    -- COMMON MUTATIONS (1 in 50 - 100)
    ["Radioactive"] = {
        Chance = 100, -- 1 in 100
        IncomeMultiplier = 2.5,
        Color = Color3.fromRGB(50, 255, 50),
        Material = Enum.Material.Neon,
        ParticleColor = ColorSequence.new(Color3.fromRGB(50, 255, 50)),
        ParticleTexture = "rbxassetid://243098098", -- Generic ring/bubble
        Description = "Emits dangerous radiation. Boosts income!"
    },
    
    ["Frozen"] = {
        Chance = 75, -- 1 in 75
        IncomeMultiplier = 2.0,
        Color = Color3.fromRGB(150, 220, 255),
        Material = Enum.Material.Ice,
        Transparency = 0.2,
        Reflectance = 0.4,
        ParticleColor = ColorSequence.new(Color3.fromRGB(200, 240, 255)),
        ParticleTexture = "rbxassetid://241685484", -- Snowflake
        Description = "Frozen solid. Chills the competition."
    },
    
    ["Infernal"] = {
        Chance = 80, -- 1 in 80
        IncomeMultiplier = 2.8,
        Color = Color3.fromRGB(255, 80, 0),
        Material = Enum.Material.Neon,
        ParticleColor = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 0)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0))
        }),
        ParticleTexture = "rbxassetid://243660364", -- Fire
        Description = "Burns with hellfire. Hot income!"
    },
    
    -- RARE MUTATIONS (1 in 500 - 1000)
    ["Golden"] = {
        Chance = 500, -- 1 in 500
        IncomeMultiplier = 5.0,
        Color = Color3.fromRGB(255, 215, 0),
        Material = Enum.Material.Metal, -- Reflective
        Reflectance = 0.8,
        ParticleColor = ColorSequence.new(Color3.fromRGB(255, 255, 100)),
        ParticleTexture = "rbxassetid://241372866", -- Sparkles
        Description = "Made of pure gold. Massive income boost."
    },
    
    ["Phantom"] = {
        Chance = 600, -- 1 in 600
        IncomeMultiplier = 4.0,
        Color = Color3.fromRGB(180, 180, 220),
        Material = Enum.Material.Glass,
        Transparency = 0.5,
        ParticleColor = ColorSequence.new(Color3.fromRGB(200, 200, 255)),
        ParticleTexture = "rbxassetid://243663673", -- Smoke/wisp
        Description = "Partially phased out of reality."
    },
    
    ["Void"] = {
        Chance = 1000,
        IncomeMultiplier = 3.0,
        Color = Color3.fromRGB(10, 0, 20),
        Material = Enum.Material.ForceField, -- Ghostly
        ParticleColor = ColorSequence.new(Color3.fromRGB(0, 0, 0)),
        ParticleTexture = "rbxassetid://243663673", -- Smoke
        Description = "Consumed by the void."
    },
    
    -- EPIC MUTATIONS (1 in 2000 - 3000)
    ["Glitched"] = {
        Chance = 2000,
        IncomeMultiplier = 10.0,
        Color = Color3.fromRGB(255, 0, 255),
        Material = Enum.Material.Glass,
        ParticleColor = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(1,0,1)),
            ColorSequenceKeypoint.new(0.5, Color3.new(0,1,1)),
            ColorSequenceKeypoint.new(1, Color3.new(0,0,1))
        }),
        ParticleTexture = "rbxassetid://242293498", -- Squares/Pixels
        Description = "ERROR: SYSTEM CORRUPTION. UNLIMITED POWER."
    },
    
    ["Cosmic"] = {
        Chance = 2500, -- 1 in 2500
        IncomeMultiplier = 12.0,
        Color = Color3.fromRGB(100, 50, 200),
        Material = Enum.Material.Neon,
        ParticleColor = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 50, 255)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 150, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 100, 200))
        }),
        ParticleTexture = "rbxassetid://241804908", -- Star
        Description = "Contains the power of galaxies."
    },
    
    ["Arcane"] = {
        Chance = 3000, -- 1 in 3000
        IncomeMultiplier = 8.0,
        Color = Color3.fromRGB(180, 100, 255),
        Material = Enum.Material.ForceField,
        Transparency = 0.15,
        ParticleColor = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 100, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 200, 255))
        }),
        ParticleTexture = "rbxassetid://243098098", -- Magic rings
        Description = "Infused with ancient magic."
    },
    
    -- LEGENDARY MUTATION (1 in 5000)
    ["Celestial"] = {
        Chance = 5000,
        IncomeMultiplier = 15.0,
        Color = Color3.fromRGB(100, 255, 255),
        Material = Enum.Material.Ice,
        Transparency = 0.3,
        ParticleColor = ColorSequence.new(Color3.fromRGB(200, 255, 255)),
        ParticleTexture = "rbxassetid://241804908", -- Star
        Description = "Blessed by the stars."
    },

    -- SPECIAL VFX MUTATIONS
    ["Prism"] = {
        Chance = 1500, -- Epic rarity
        IncomeMultiplier = 6.0,
        Color = Color3.fromRGB(200, 255, 255), -- Cyanish White
        Material = Enum.Material.Glass,
        Reflectance = 0.5,
        VFXModels = {
            { 
                SourceName = "ColoredMasterPark", 
                PositionMode = "Bottom", 
                Offset = CFrame.Angles(0, math.rad(-90), 0) -- Rotated -90 Y
            }
        },
        Description = "Refracts light into pure wealth."
    },

    ["Blood"] = {
        Chance = 1200, -- Rare/Epic
        IncomeMultiplier = 5.5,
        Color = Color3.fromRGB(80, 0, 0), -- Dark Red
        Material = Enum.Material.Granite, -- Rough texture
        VFXColor = Color3.fromRGB(150, 0, 0), -- Creating contrast
        VFXModels = {
            { SourceName = "Blood", Offset = CFrame.new(0, 0, 0) },
            { SourceName = "BlackFlash", Offset = CFrame.new(0, 0, 0) }
        },
        Description = "A sinister aura surrounds it."
    }
}

return MutationDefinitions

