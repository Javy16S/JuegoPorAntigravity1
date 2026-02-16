--!strict
-- MutationManager.lua
-- Skill: procedural-vfx
-- Description: Procedurally applies "mutation" visual effects to units based on Tier and Shiny status.
-- UPDATED: Now supports specific Mutation Types (Radioactive, Golden, Frozen, Infernal, etc.)

local MutationManager = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Try to require MutationDefinitions, handle if not found immediately
local MutationDefinitions

function table_count(t)
    local c = 0
    for _ in pairs(t) do c += 1 end
    return c
end
local success, result = pcall(function()
    return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MutationDefinitions"))
end)

if success then
    MutationDefinitions = result
    print("[MutationManager] Loaded definitions. Count: " .. (MutationDefinitions and table_count(MutationDefinitions) or 0)) 
else
    warn("CRITICAL: [MutationManager] Failed to load MutationDefinitions: " .. tostring(result))
end



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
    ["Legendary"] = { Aura = true, Glow = true, Particles = "Fire", Scale = 1.05 },
    ["Mythic"] = { Aura = true, Glow = true, Particles = "Dark", Scale = 1.1 },
    ["Divine"] = { Aura = true, Glow = true, Material = Enum.Material.ForceField, Scale = 1.3 },
    ["Celestial"] = { Aura = true, Glow = true, Material = Enum.Material.Neon, Scale = 1.5, Particles = "Stars" },
    ["Cosmic"] = { Aura = true, Glow = true, Material = Enum.Material.ForceField, Scale = 1.8, Particles = "Stars" },
    ["Eternal"] = { Aura = true, Glow = true, Scale = 2.1, Material = Enum.Material.Neon, Particles = "Fire" },
    ["Transcendent"] = { Aura = true, Glow = true, Scale = 2.5, Material = Enum.Material.Glass, Rainbow = true },
    ["Infinite"] = { Aura = true, Glow = true, Rainbow = true, Scale = 3.0 }
}

-- Helper to roll a mutation
function MutationManager.rollMutation(luckMultiplier: number?)
    if not MutationDefinitions then 
        warn("[MutationManager] Cannot roll: Definitions missing!")
        return nil 
    end
    
    local luck = luckMultiplier or 1.0
    
    -- Sort keys by chance (descending rarity, i.e. highest Chance Value)
    local sortedMutations = {}
    for k, v in pairs(MutationDefinitions) do
        table.insert(sortedMutations, {Name = k, Data = v})
    end
    -- Sort by Chance descending (e.g. 5000 before 100)
    table.sort(sortedMutations, function(a, b) return a.Data.Chance > b.Data.Chance end)
    
    for _, item in ipairs(sortedMutations) do
        -- Probability is scaled by luck
        local prob = (1 / item.Data.Chance) * luck
        if math.random() <= prob then
            return item.Name
        end
    end
    
    return nil
end

-- Force pick a mutation (Guaranteed result if we decide it's a success)
function MutationManager.pickMutation(luckMultiplier: number?)
    if not MutationDefinitions then return nil end
    local luck = luckMultiplier or 1.0
    
    local candidates = {}
    local totalWeight = 0
    
    for name, data in pairs(MutationDefinitions) do
        local weight = (1 / data.Chance)
        table.insert(candidates, {Name = name, Weight = weight})
        totalWeight += weight
    end
    
    local r = math.random() * totalWeight
    local current = 0
    for _, item in ipairs(candidates) do
        current += item.Weight
        if r <= current then
            return item.Name
        end
    end
    
    local firstKey = next(MutationDefinitions)
    return firstKey
end

function MutationManager.applyMutation(model, mutationName)
    if not model or not mutationName then return end
    if not MutationDefinitions then return end
    
    local data = MutationDefinitions[mutationName]
    if not data then return end
    
    -- Apply Visuals
    for _, part in pairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            -- FORCE MATERIAL VISIBILITY (Strip Texture)
            if data.Material then
                 if part:IsA("MeshPart") then
                      part.TextureID = "" 
                 elseif part:IsA("Part") then
                      -- If it's a Part with a Texture child, remove/hide it?
                      for _, t in pairs(part:GetChildren()) do
                          if t:IsA("Texture") or t:IsA("Decal") then t:Destroy() end
                      end
                 end
                 part.Material = data.Material 
            end
            
            if data.Color then part.Color = data.Color end
            if data.Transparency then part.Transparency = data.Transparency end
            if data.Reflectance then part.Reflectance = data.Reflectance end
        end
    end
    local primary = nil
    if model:IsA("Model") then
        primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    elseif model:IsA("BasePart") then
        primary = model
    end

    -- EXTERNAL VFX MODELS (New System)
    if data.VFXModels and primary then
        local particlesFolder = workspace:FindFirstChild("Particles") or ReplicatedStorage:FindFirstChild("Particles")
        if particlesFolder then
            for _, vfxDef in ipairs(data.VFXModels) do
                local sourcePart = particlesFolder:FindFirstChild(vfxDef.SourceName)
                if sourcePart and sourcePart:IsA("BasePart") then
                    local clone = sourcePart:Clone()
                    clone.Name = "MutationVFX_" .. vfxDef.SourceName
                    clone.CanCollide = false
                    clone.Anchored = false
                    clone.Massless = true
                    
                    -- Visual Overrides
                    if data.VFXColor then clone.Color = data.VFXColor end
                    if data.VFXMaterial then clone.Material = data.VFXMaterial end
                    
                    -- Parenting
                    clone.Parent = model
                    
                    -- Welding & Positioning
                    -- Default to Center, but support "Bottom"
                    local offset = vfxDef.Offset or CFrame.new()
                    
                    if vfxDef.PositionMode == "Bottom" then
                         -- Find bottom of model
                         local cf, size
                         if model:IsA("Model") then
                             cf, size = model:GetBoundingBox()
                         else
                             cf, size = model.CFrame, model.Size
                         end
                         -- Relative to PrimaryPart
                         local bottomOffset = Vector3.new(0, -size.Y/2, 0)
                         offset = CFrame.new(bottomOffset) * offset
                    end

                    -- Correct Welding logic
                    clone.CFrame = primary.CFrame * offset
                    
                    local weld = Instance.new("WeldConstraint")
                    weld.Part0 = primary
                    weld.Part1 = clone
                    weld.Parent = clone
                else
                    warn("[MutationManager] VFX Source not found: " .. vfxDef.SourceName)
                end
            end
        else
            warn("[MutationManager] 'Particles' folder not found in Workspace.")
        end
    end
    
    if primary and data.ParticleTexture then
        local p = Instance.new("ParticleEmitter")
        p.Texture = data.ParticleTexture
        p.Color = data.ParticleColor or ColorSequence.new(Color3.new(1,1,1))
        p.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0)})
        p.Rate = 10
        p.Lifetime = NumberRange.new(1, 2)
        p.Speed = NumberRange.new(2, 4)
        p.SpreadAngle = Vector2.new(360, 360)
        p.Parent = primary
        p.Name = "MutationParticles"
    end
    
    model:SetAttribute("Mutation", mutationName)
    
    -- Combine multipliers? Or Set?
    -- If model has multiplier, multiply it.
    local current = model:GetAttribute("IncomeMultiplier") or 1
    model:SetAttribute("IncomeMultiplier", current * (data.IncomeMultiplier or 1))
end

function MutationManager.applyTierEffects(model, tier, isShiny, skipScale)
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
        local maxDim = math.max(currentSize.X, currentSize.Y, currentSize.Z)
        local baseRatio = 1.0
        
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

    -- 2. Material & Color (TIER)
    if config.Material or config.Rainbow then
        for _, p in pairs(model:GetDescendants()) do
            if p:IsA("BasePart") then
                local hasTexture = (p:IsA("MeshPart") and p.TextureID ~= "") or p:FindFirstChildWhichIsA("Texture") or p:FindFirstChildWhichIsA("SpecialMesh")
                
                if config.Material and not hasTexture then
                    p.Material = config.Material
                elseif config.Material == Enum.Material.ForceField then
                    p.Material = Enum.Material.ForceField
                end

                if not hasTexture and not config.Rainbow then
                    p.Color = color
                end
            end
        end
    end
    
    -- 3. Rainbow Mutation (Infinite) -> Actually Tier Effect
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
             -- Use weak ref or check parent? Loop handles Check
            local hl = model:FindFirstChildWhichIsA("Highlight")
            local t = 0
            while model and model.Parent do
                local c = Color3.fromHSV(t, 0.7, 1)
                for _, p in ipairs(partsToColor) do p.Color = c end
                if hl then hl.FillColor = c end
                t = (t + 0.003) % 1
                task.wait(0.05)
            end
        end)
    end
    
    -- 4. HIGHLIGHT (Supreme Tiers)
    if tier == "Transcendent" or tier == "Infinite" or tier == "Divine" then
        local hl = model:FindFirstChildWhichIsA("Highlight")
        if not hl then
            hl = Instance.new("Highlight")
            hl.Parent = model
        end
        hl.FillColor = color
        hl.OutlineColor = Color3.new(1,1,1)
        hl.FillTransparency = 0.5
        hl.OutlineTransparency = 0
    end
    
    -- 4. Shiny Sparkles
    if isShiny then
        local sparkles = Instance.new("Sparkles")
        sparkles.SparkleColor = Color3.new(1, 1, 0.5)
        sparkles.Parent = primary
        sparkles.Name = "ShinySparkles"
    end
end

return MutationManager
