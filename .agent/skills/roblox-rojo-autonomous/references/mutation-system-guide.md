# Mutation System Guide

This reference provides detailed patterns for implementing brainrot mutation systems with visual effects and spawn mechanics.

## Mutation Architecture

### Core Mutation Manager

```lua
-- MutationManager.server.lua
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- MUTATION DEFINITIONS
local MUTATIONS = {
    {
        Name = "Radioactive",
        SpawnChance = 0.10, -- 10% of brainrots
        IncomeMultiplier = 2.0,
        Color = Color3.fromRGB(100, 255, 100),
        Material = Enum.Material.Neon,
        ParticleConfig = {
            Texture = "rbxasset://textures/particles/smoke_main.dds",
            Color = ColorSequence.new(Color3.fromRGB(0, 255, 0)),
            Rate = 20,
            Lifetime = NumberRange.new(1, 2),
            Speed = NumberRange.new(2, 5)
        }
    },
    {
        Name = "Golden",
        SpawnChance = 0.05, -- 5% rare
        IncomeMultiplier = 5.0,
        Color = Color3.fromRGB(255, 215, 0),
        Material = Enum.Material.Neon,
        ParticleConfig = {
            Texture = "rbxasset://textures/particles/sparkles_main.dds",
            Color = ColorSequence.new(Color3.fromRGB(255, 215, 0)),
            Rate = 15,
            Lifetime = NumberRange.new(0.5, 1),
            Speed = NumberRange.new(1, 3)
        },
        PointLightConfig = {
            Brightness = 2,
            Color = Color3.fromRGB(255, 215, 0),
            Range = 15
        }
    },
    {
        Name = "Shadow",
        SpawnChance = 0.08,
        IncomeMultiplier = 3.0,
        Color = Color3.fromRGB(50, 50, 80),
        Material = Enum.Material.ForceField,
        Transparency = 0.3,
        ParticleConfig = {
            Texture = "rbxasset://textures/particles/smoke_main.dds",
            Color = ColorSequence.new(Color3.fromRGB(0, 0, 0)),
            Rate = 10,
            Lifetime = NumberRange.new(2, 3),
            Speed = NumberRange.new(0.5, 1)
        }
    },
    {
        Name = "Crystalline",
        SpawnChance = 0.06,
        IncomeMultiplier = 4.0,
        Color = Color3.fromRGB(100, 200, 255),
        Material = Enum.Material.Glass,
        Reflectance = 0.5,
        ParticleConfig = {
            Texture = "rbxasset://textures/particles/sparkles_main.dds",
            Color = ColorSequence.new(Color3.fromRGB(150, 220, 255)),
            Rate = 25,
            Lifetime = NumberRange.new(0.3, 0.8),
            Speed = NumberRange.new(3, 6)
        }
    },
    {
        Name = "Infernal",
        SpawnChance = 0.03, -- Very rare
        IncomeMultiplier = 10.0,
        Color = Color3.fromRGB(255, 50, 0),
        Material = Enum.Material.Neon,
        ParticleConfig = {
            Texture = "rbxasset://textures/particles/fire_main.dds",
            Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 0)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 100, 0)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0))
            },
            Rate = 30,
            Lifetime = NumberRange.new(1, 1.5),
            Speed = NumberRange.new(5, 10)
        },
        PointLightConfig = {
            Brightness = 3,
            Color = Color3.fromRGB(255, 100, 0),
            Range = 20
        }
    }
}

-- FUNCTIONS
function selectMutation()
    local roll = math.random()
    local cumulativeChance = 0
    
    for _, mutation in MUTATIONS do
        cumulativeChance += mutation.SpawnChance
        if roll <= cumulativeChance then
            return mutation
        end
    end
    
    return nil -- No mutation
end

function applyMutation(brainrot, mutationData)
    if not brainrot or not mutationData then return false end
    
    -- Store mutation data
    brainrot:SetAttribute("Mutation", mutationData.Name)
    brainrot:SetAttribute("MutationMultiplier", mutationData.IncomeMultiplier)
    
    -- Apply visual changes to all parts
    for _, descendant in brainrot:GetDescendants() do
        if descendant:IsA("BasePart") or descendant:IsA("MeshPart") then
            descendant.Color = mutationData.Color
            descendant.Material = mutationData.Material
            
            if mutationData.Transparency then
                descendant.Transparency = mutationData.Transparency
            end
            
            if mutationData.Reflectance then
                descendant.Reflectance = mutationData.Reflectance
            end
        end
    end
    
    -- Add particle effects
    if mutationData.ParticleConfig and brainrot.PrimaryPart then
        local particles = Instance.new("ParticleEmitter")
        particles.Texture = mutationData.ParticleConfig.Texture
        particles.Color = mutationData.ParticleConfig.Color
        particles.Rate = mutationData.ParticleConfig.Rate
        particles.Lifetime = mutationData.ParticleConfig.Lifetime
        particles.Speed = mutationData.ParticleConfig.Speed
        particles.SpreadAngle = Vector2.new(45, 45)
        particles.Parent = brainrot.PrimaryPart
    end
    
    -- Add point light if configured
    if mutationData.PointLightConfig and brainrot.PrimaryPart then
        local light = Instance.new("PointLight")
        light.Brightness = mutationData.PointLightConfig.Brightness
        light.Color = mutationData.PointLightConfig.Color
        light.Range = mutationData.PointLightConfig.Range
        light.Parent = brainrot.PrimaryPart
    end
    
    return true
end

return {
    SelectMutation = selectMutation,
    ApplyMutation = applyMutation,
    GetMutations = function() return MUTATIONS end
}
```

## Advanced Mesh Modifications

### Dynamic Mesh Scaling

```lua
local function applyMeshDistortion(brainrot, distortionType)
    for _, descendant in brainrot:GetDescendants() do
        if descendant:IsA("MeshPart") then
            local originalSize = descendant.Size
            
            if distortionType == "Bulge" then
                -- Make it bigger and rounder
                descendant.Size = originalSize * 1.3
                
            elseif distortionType == "Spiky" then
                -- Create spiky protrusions
                for i = 1, 5 do
                    local spike = Instance.new("Part")
                    spike.Size = Vector3.new(0.5, 2, 0.5)
                    spike.Shape = Enum.PartType.Cylinder
                    spike.Material = descendant.Material
                    spike.Color = descendant.Color
                    spike.CanCollide = false
                    
                    local weld = Instance.new("WeldConstraint")
                    weld.Part0 = descendant
                    weld.Part1 = spike
                    weld.Parent = spike
                    
                    local randomAngle = math.random() * math.pi * 2
                    spike.CFrame = descendant.CFrame * CFrame.Angles(randomAngle, 0, 0) * CFrame.new(0, descendant.Size.Y/2 + 1, 0)
                    spike.Parent = brainrot
                end
                
            elseif distortionType == "Crystalline" then
                -- Add crystal shards
                for i = 1, 8 do
                    local crystal = Instance.new("Part")
                    crystal.Size = Vector3.new(0.3, 1.5, 0.3)
                    crystal.Shape = Enum.PartType.Cylinder
                    crystal.Material = Enum.Material.Glass
                    crystal.Color = Color3.fromRGB(100, 200, 255)
                    crystal.Reflectance = 0.8
                    crystal.CanCollide = false
                    
                    local weld = Instance.new("WeldConstraint")
                    weld.Part0 = descendant
                    weld.Part1 = crystal
                    weld.Parent = crystal
                    
                    local randomPos = Vector3.new(
                        math.random(-1, 1) * descendant.Size.X/2,
                        math.random(-1, 1) * descendant.Size.Y/2,
                        math.random(-1, 1) * descendant.Size.Z/2
                    )
                    crystal.CFrame = descendant.CFrame * CFrame.new(randomPos) * CFrame.Angles(math.random() * math.pi, math.random() * math.pi, 0)
                    crystal.Parent = brainrot
                end
            end
        end
    end
end
```

## Spectacular Particle Systems

### Multi-Layer Particle Effects

```lua
local function createSpectacularParticles(parent, effectType)
    if effectType == "Rainbow" then
        -- Create rainbow trail with multiple emitters
        local colors = {
            Color3.fromRGB(255, 0, 0),
            Color3.fromRGB(255, 127, 0),
            Color3.fromRGB(255, 255, 0),
            Color3.fromRGB(0, 255, 0),
            Color3.fromRGB(0, 0, 255),
            Color3.fromRGB(75, 0, 130),
            Color3.fromRGB(148, 0, 211)
        }
        
        for i, color in colors do
            local emitter = Instance.new("ParticleEmitter")
            emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
            emitter.Color = ColorSequence.new(color)
            emitter.Rate = 15
            emitter.Lifetime = NumberRange.new(1, 2)
            emitter.Speed = NumberRange.new(2, 5)
            emitter.SpreadAngle = Vector2.new(360, 360)
            emitter.Rotation = NumberRange.new(0, 360)
            emitter.RotSpeed = NumberRange.new(-100, 100)
            emitter.Parent = parent
            
            -- Slight delay for wave effect
            task.delay(i * 0.05, function()
                emitter.Enabled = true
            end)
        end
        
    elseif effectType == "Cosmic" then
        -- Stars and nebula
        local starEmitter = Instance.new("ParticleEmitter")
        starEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        starEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
        starEmitter.Rate = 30
        starEmitter.Lifetime = NumberRange.new(2, 3)
        starEmitter.Speed = NumberRange.new(0.5, 2)
        starEmitter.SpreadAngle = Vector2.new(180, 180)
        starEmitter.Size = NumberSequence.new{
            NumberSequenceKeypoint.new(0, 0.1),
            NumberSequenceKeypoint.new(0.5, 0.3),
            NumberSequenceKeypoint.new(1, 0)
        }
        starEmitter.LightEmission = 1
        starEmitter.Parent = parent
        
        local nebulaEmitter = Instance.new("ParticleEmitter")
        nebulaEmitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
        nebulaEmitter.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 0, 255)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 100, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 0, 255))
        }
        nebulaEmitter.Rate = 10
        nebulaEmitter.Lifetime = NumberRange.new(3, 5)
        nebulaEmitter.Speed = NumberRange.new(0.2, 0.5)
        nebulaEmitter.SpreadAngle = Vector2.new(90, 90)
        nebulaEmitter.Size = NumberSequence.new{
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.3, 3),
            NumberSequenceKeypoint.new(1, 0)
        }
        nebulaEmitter.Transparency = NumberSequence.new{
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.2, 0.5),
            NumberSequenceKeypoint.new(0.8, 0.5),
            NumberSequenceKeypoint.new(1, 1)
        }
        nebulaEmitter.Parent = parent
        
    elseif effectType == "Lightning" then
        -- Electric arcs
        local electricEmitter = Instance.new("ParticleEmitter")
        electricEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        electricEmitter.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 200, 255)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 200, 255))
        }
        electricEmitter.Rate = 50
        electricEmitter.Lifetime = NumberRange.new(0.1, 0.3)
        electricEmitter.Speed = NumberRange.new(10, 20)
        electricEmitter.SpreadAngle = Vector2.new(360, 360)
        electricEmitter.Size = NumberSequence.new{
            NumberSequenceKeypoint.new(0, 0.2),
            NumberSequenceKeypoint.new(1, 0)
        }
        electricEmitter.LightEmission = 1
        electricEmitter.Parent = parent
        
        -- Add flickering light
        local light = Instance.new("PointLight")
        light.Brightness = 5
        light.Color = Color3.fromRGB(150, 200, 255)
        light.Range = 25
        light.Parent = parent
        
        -- Flicker effect
        task.spawn(function()
            while light.Parent do
                light.Brightness = math.random(3, 7)
                task.wait(0.05)
            end
        end)
    end
end
```

## Spawn Rate System

### Per-Mutation Spawn Weights

```lua
-- In GameManager or spawning logic
local function spawnBrainrotWithMutation()
    local MutationManager = require(ReplicatedStorage.Modules.MutationManager)
    
    -- Roll for mutation
    local mutation = MutationManager.SelectMutation()
    
    -- Spawn base brainrot
    local brainrot = ServerStorage.BrainrotBase:Clone()
    
    -- Apply mutation if rolled
    if mutation then
        MutationManager.ApplyMutation(brainrot, mutation)
        
        -- Apply income multiplier
        local baseIncome = brainrot:GetAttribute("IncomeRate") or 100
        brainrot:SetAttribute("IncomeRate", baseIncome * mutation.IncomeMultiplier)
        
        print("[Spawn] Created", mutation.Name, "brainrot with", mutation.IncomeMultiplier .. "x income")
    end
    
    brainrot.Parent = workspace.ActiveBrainrots
    return brainrot
end
```

## Dynamic Mutation Events

```lua
-- MutationStorm event that temporarily increases mutation rates
local function startMutationStorm(duration)
    local originalChances = {}
    
    -- Store original chances and boost them
    for i, mutation in MUTATIONS do
        originalChances[i] = mutation.SpawnChance
        mutation.SpawnChance = mutation.SpawnChance * 5 -- 5x mutation rate
    end
    
    -- Notify players
    ReplicatedStorage.Events.MutationStormStarted:FireAllClients(duration)
    
    -- Restore after duration
    task.delay(duration, function()
        for i, mutation in MUTATIONS do
            mutation.SpawnChance = originalChances[i]
        end
        ReplicatedStorage.Events.MutationStormEnded:FireAllClients()
    end)
end
```

## Performance Optimization

### Particle Budget System

```lua
local MAX_PARTICLE_EMITTERS = 100
local activeParticleCount = 0

local function createOptimizedParticles(parent, config)
    if activeParticleCount >= MAX_PARTICLE_EMITTERS then
        warn("[Mutation] Particle budget exceeded, skipping particles")
        return nil
    end
    
    local emitter = Instance.new("ParticleEmitter")
    -- ... apply config
    emitter.Parent = parent
    
    activeParticleCount += 1
    
    -- Track cleanup
    emitter.AncestryChanged:Connect(function()
        if not emitter.Parent then
            activeParticleCount -= 1
        end
    end)
    
    return emitter
end
```

### LOD (Level of Detail) for Mutations

```lua
local function updateMutationLOD(player)
    local camera = workspace.CurrentCamera
    
    for _, brainrot in workspace.ActiveBrainrots:GetChildren() do
        local mutation = brainrot:GetAttribute("Mutation")
        if mutation then
            local distance = (camera.CFrame.Position - brainrot.PrimaryPart.Position).Magnitude
            
            -- Disable particles when far away
            for _, emitter in brainrot.PrimaryPart:GetChildren() do
                if emitter:IsA("ParticleEmitter") then
                    emitter.Enabled = distance < 200
                end
            end
            
            -- Disable lights when very far
            for _, light in brainrot.PrimaryPart:GetChildren() do
                if light:IsA("PointLight") then
                    light.Enabled = distance < 150
                end
            end
        end
    end
end
```

## Best Practices

1. **Particle limits**: Never exceed 100 active ParticleEmitters per client
2. **Mutation stacking**: Decide if brainrots can have multiple mutations (not recommended)
3. **Visual clarity**: Ensure mutations are visually distinct at a glance
4. **Income balance**: Higher rarity mutations should have proportionally higher multipliers
5. **Performance**: Use LOD system for particles and lights on distant units
6. **Cleanup**: Always clean up particles when brainrots are destroyed
7. **Networked effects**: Create particles on client-side when possible to reduce server load
