-- MutationManager.lua
-- Skill: procedural-vfx
-- Description: Procedurally applies "mutation" visual effects to units based on Tier and Shiny status.

local MutationManager = {}

local TIER_COLORS = {
    ["Common"] = Color3.fromRGB(200, 200, 200),
    ["Rare"] = Color3.fromRGB(0, 170, 255),
    ["Epic"] = Color3.fromRGB(170, 0, 255),
    ["Legendary"] = Color3.fromRGB(255, 170, 0),
    ["Mythic"] = Color3.fromRGB(255, 0, 85),
    ["Divine"] = Color3.fromRGB(255, 255, 100),
    ["Celestial"] = Color3.fromRGB(100, 255, 255),
    ["Cosmic"] = Color3.fromRGB(200, 100, 255),
    ["Eternal"] = Color3.fromRGB(255, 255, 255),
    ["Transcendent"] = Color3.fromRGB(255, 100, 200),
    ["Infinite"] = Color3.fromRGB(50, 255, 150),
}

-- Refined Config (Removed bobbing/floating)
local TIER_VFX_CONFIG = {
    ["Epic"] = { Aura = true, Glow = true, Scale = 1.0 },
    ["Legendary"] = { Aura = true, Glow = true, Particles = "Fire", Scale = 1.0 },
    ["Mythic"] = { Aura = true, Glow = true, Particles = "Dark", Scale = 1.0 },
    ["Divine"] = { Aura = true, Glow = true, Material = Enum.Material.ForceField, Scale = 1.0 },
    ["Celestial"] = { Aura = true, Glow = true, Material = Enum.Material.Neon, Scale = 1.0, Particles = "Stars" },
    ["Cosmic"] = { Aura = true, Glow = true, Material = Enum.Material.Neon, Scale = 1.0, Particles = "Stars" },
    ["Eternal"] = { Aura = true, Glow = true, Scale = 1.0 },
    ["Transcendent"] = { Aura = true, Glow = true, Scale = 1.0, Material = Enum.Material.Glass },
    ["Infinite"] = { Aura = true, Glow = true, Rainbow = true, Scale = 1.0 }
}

function MutationManager.applyMutation(model, tier, isShiny, skipScale)
    if not model then return end
    local config = TIER_VFX_CONFIG[tier] or { Scale = 1.0 }
    
    -- 1. CALCULATE NORMALIZATION SCALE
    local currentSize
    local isModel = model:IsA("Model")
    
    if isModel then
        currentSize = model:GetExtentsSize()
    elseif model:IsA("BasePart") then
        currentSize = model.Size
    else
        return -- Cannot scale non-spatial objects
    end

    if not skipScale then
        -- Use max dimension instead of average to ensure large/weirdly-shaped models fit
        local maxDim = math.max(currentSize.X, currentSize.Y, currentSize.Z)
        local baseRatio = 1.0
        
        -- SMART NORMALIZATION
        if maxDim > 15 then
            baseRatio = 10.0 / maxDim 
        elseif maxDim < 1.5 and maxDim > 0 then
            baseRatio = 4.0 / maxDim
        end
        
        local totalRatio = baseRatio * (config.Scale or 1)
        totalRatio = math.clamp(totalRatio, 0.0001, 100)
        
        pcall(function()
            if isModel then
                model:ScaleTo(totalRatio)
            else
                model.Size = model.Size * totalRatio
            end
        end)
    end
    
    local color = TIER_COLORS[tier] or TIER_COLORS["Common"]
    local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    if not primary then return end

    -- 2. Material & Color Mutation (Preserve textures!)
    if config.Material or config.Rainbow then
        for _, p in pairs(model:GetDescendants()) do
            if p:IsA("BasePart") then
                local hasTexture = (p:IsA("MeshPart") and p.TextureID ~= "") or p:FindFirstChildWhichIsA("Texture") or p:FindFirstChildWhichIsA("SpecialMesh")
                
                -- Apply Material Override safely
                if config.Material and not hasTexture then
                    p.Material = config.Material
                elseif config.Material == Enum.Material.ForceField then
                    -- ForceField usually looks okay over textures, but let's be safe
                    p.Material = Enum.Material.ForceField
                end

                -- Apply Rainbow/Tier Color safely
                if not hasTexture and not config.Rainbow then
                    p.Color = color
                end
            end
        end
    end

    -- [Sections 3 & 4 remain the same...]

    -- 5. Rainbow Mutation (Infinite) - PRESERVE TEXTURES
    if config.Rainbow then
        local partsToColor = {}
        for _, p in pairs(model:GetDescendants()) do
             if p:IsA("BasePart") and p.Name ~= "MutationRing" then
                local hasTexture = (p:IsA("MeshPart") and p.TextureID ~= "") or p:FindFirstChildWhichIsA("Texture")
                if not hasTexture then
                    table.insert(partsToColor, p)
                end
             end
        end
        task.spawn(function()
            local t = 0
            while model and model.Parent do
                local c = Color3.fromHSV(t, 0.7, 1)
                for _, p in ipairs(partsToColor) do p.Color = c end
                light.Color = c
                t = (t + 0.003) % 1
                task.wait(0.05)
            end
        end)
    end
    
    -- 6. Shiny Sparkles
    if isShiny then
        local sparkles = Instance.new("Sparkles")
        sparkles.SparkleColor = Color3.new(1, 1, 0.5)
        sparkles.Parent = primary
    end
end

return MutationManager
