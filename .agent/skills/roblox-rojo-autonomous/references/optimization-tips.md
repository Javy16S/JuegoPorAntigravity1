# Optimization Tips for Roblox

Performance best practices for spawning systems, particles, and high-volume object management.

## Spawning Optimization

### Object Pooling

Instead of constantly creating and destroying brainrots, reuse them:

```lua
-- ObjectPool.lua
local ObjectPool = {}
ObjectPool.__index = ObjectPool

function ObjectPool.new(template, initialSize)
    local self = setmetatable({}, ObjectPool)
    self.template = template
    self.available = {}
    self.active = {}
    
    -- Pre-create pool
    for i = 1, initialSize do
        local obj = template:Clone()
        obj.Parent = nil
        table.insert(self.available, obj)
    end
    
    return self
end

function ObjectPool:Get()
    local obj
    
    if #self.available > 0 then
        obj = table.remove(self.available)
    else
        obj = self.template:Clone()
        warn("[ObjectPool] Pool exhausted, creating new object")
    end
    
    table.insert(self.active, obj)
    return obj
end

function ObjectPool:Return(obj)
    -- Find and remove from active
    for i, activeObj in self.active do
        if activeObj == obj then
            table.remove(self.active, i)
            break
        end
    end
    
    -- Reset object state
    obj.Parent = nil
    obj:SetAttribute("IncomeRate", nil)
    obj:SetAttribute("Rarity", nil)
    obj:SetAttribute("Mutation", nil)
    
    -- Clean up particles and lights
    for _, child in obj.PrimaryPart:GetChildren() do
        if child:IsA("ParticleEmitter") or child:IsA("PointLight") then
            child:Destroy()
        end
    end
    
    table.insert(self.available, obj)
end

function ObjectPool:GetStats()
    return {
        Available = #self.available,
        Active = #self.active,
        Total = #self.available + #self.active
    }
end

return ObjectPool
```

**Usage:**
```lua
local ObjectPool = require(ReplicatedStorage.Modules.ObjectPool)
local brainrotPool = ObjectPool.new(ServerStorage.BrainrotBase, 50)

-- Get from pool
local brainrot = brainrotPool:Get()
brainrot.Parent = workspace.ActiveBrainrots
brainrot:SetPrimaryPartCFrame(CFrame.new(spawnPosition))

-- Return to pool when done
brainrotPool:Return(brainrot)
```

### Batched Spawning

Spawn multiple objects in batches to reduce frame drops:

```lua
local function spawnBatch(count, delayBetween)
    local spawned = 0
    
    local function spawnNext()
        if spawned >= count then return end
        
        -- Spawn one brainrot
        spawnBrainrot()
        spawned += 1
        
        -- Schedule next
        task.delay(delayBetween, spawnNext)
    end
    
    spawnNext()
end

-- Instead of spawning 20 at once:
-- for i = 1, 20 do spawnBrainrot() end

-- Spread over time:
spawnBatch(20, 0.1) -- 20 brainrots, 0.1s apart
```

### Smart Spawn Limits

```lua
local MAX_BRAINROTS_PER_PLAYER = 15
local MAX_BRAINROTS_GLOBAL = 200

local function canSpawnMore()
    local playerCount = #game:GetService("Players"):GetPlayers()
    local currentCount = #workspace.ActiveBrainrots:GetChildren()
    
    local perPlayerLimit = playerCount * MAX_BRAINROTS_PER_PLAYER
    local effectiveLimit = math.min(perPlayerLimit, MAX_BRAINROTS_GLOBAL)
    
    return currentCount < effectiveLimit
end
```

## Particle Optimization

### Culling Distant Particles

```lua
-- Run on client with RunService
local RunService = game:GetService("RunService")
local camera = workspace.CurrentCamera
local PARTICLE_CULL_DISTANCE = 200

RunService.RenderStepped:Connect(function()
    for _, brainrot in workspace.ActiveBrainrots:GetChildren() do
        if brainrot.PrimaryPart then
            local distance = (camera.CFrame.Position - brainrot.PrimaryPart.Position).Magnitude
            
            for _, emitter in brainrot.PrimaryPart:GetDescendants() do
                if emitter:IsA("ParticleEmitter") then
                    emitter.Enabled = distance < PARTICLE_CULL_DISTANCE
                end
            end
        end
    end
end)
```

### Particle Budget Manager

```lua
-- ParticleManager.lua (Client-side)
local ParticleManager = {}

local MAX_ACTIVE_EMITTERS = 80
local activeEmitters = {}

function ParticleManager.register(emitter, priority)
    priority = priority or 1
    
    table.insert(activeEmitters, {
        Emitter = emitter,
        Priority = priority
    })
    
    ParticleManager.update()
end

function ParticleManager.update()
    -- Sort by priority
    table.sort(activeEmitters, function(a, b)
        return a.Priority > b.Priority
    end)
    
    -- Enable top priority emitters
    for i, data in activeEmitters do
        data.Emitter.Enabled = i <= MAX_ACTIVE_EMITTERS
    end
end

function ParticleManager.unregister(emitter)
    for i, data in activeEmitters do
        if data.Emitter == emitter then
            table.remove(activeEmitters, i)
            break
        end
    end
end

return ParticleManager
```

## Network Optimization

### Reduce RemoteEvent Traffic

**BAD:**
```lua
-- Sending individual updates
for _, brainrot in workspace.ActiveBrainrots:GetChildren() do
    ReplicatedStorage.Events.UpdateBrainrot:FireClient(player, brainrot, data)
end
```

**GOOD:**
```lua
-- Batch updates
local updates = {}
for _, brainrot in workspace.ActiveBrainrots:GetChildren() do
    table.insert(updates, {Brainrot = brainrot, Data = data})
end

ReplicatedStorage.Events.BatchUpdateBrainrots:FireClient(player, updates)
```

### Use Attributes for State

Instead of RemoteEvents for every state change, use Attributes:

```lua
-- Server
brainrot:SetAttribute("IncomeRate", 500)
brainrot:SetAttribute("Mutation", "Golden")

-- Client (auto-synced)
local incomeRate = brainrot:GetAttribute("IncomeRate")
brainrot:GetAttributeChangedSignal("Mutation"):Connect(function()
    local mutation = brainrot:GetAttribute("Mutation")
    updateVisuals(brainrot, mutation)
end)
```

## Memory Management

### Cleanup Disconnected Players

```lua
game:GetService("Players").PlayerRemoving:Connect(function(player)
    -- Clean up player-specific brainrots
    local playerFolder = workspace.ActiveBrainrots:FindFirstChild(player.UserId)
    if playerFolder then
        for _, brainrot in playerFolder:GetChildren() do
            -- Return to pool instead of destroying
            if brainrotPool then
                brainrotPool:Return(brainrot)
            else
                brainrot:Destroy()
            end
        end
        playerFolder:Destroy()
    end
    
    -- Clean up data
    local profile = ProfileService:GetProfile(player)
    if profile then
        profile:Release()
    end
end)
```

### Limit Event Connections

```lua
-- BAD: Creates new connection for every brainrot
for _, brainrot in workspace.ActiveBrainrots:GetChildren() do
    brainrot.Touched:Connect(function(hit)
        -- Handle touch
    end)
end

-- GOOD: Single connection with spatial query
local touchParts = {}
workspace.ActiveBrainrots.ChildAdded:Connect(function(brainrot)
    if brainrot.PrimaryPart then
        table.insert(touchParts, brainrot.PrimaryPart)
    end
end)

RunService.Heartbeat:Connect(function()
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = touchParts
    
    local parts = workspace:GetPartBoundsInBox(CFrame.new(0, 0, 0), Vector3.new(1000, 1000, 1000), params)
    -- Process overlaps
end)
```

## Rendering Optimization

### Level of Detail (LOD)

```lua
local LOD_DISTANCES = {
    High = 50,    -- Full detail
    Medium = 100, -- Reduced particles
    Low = 200,    -- No particles, simple materials
    Hidden = 300  -- Don't render
}

local function updateBrainrotLOD(brainrot, distance)
    if distance < LOD_DISTANCES.High then
        -- Full detail
        for _, emitter in brainrot.PrimaryPart:GetDescendants() do
            if emitter:IsA("ParticleEmitter") then
                emitter.Rate = emitter:GetAttribute("BaseRate") or 20
                emitter.Enabled = true
            end
        end
        
    elseif distance < LOD_DISTANCES.Medium then
        -- Reduced particles
        for _, emitter in brainrot.PrimaryPart:GetDescendants() do
            if emitter:IsA("ParticleEmitter") then
                emitter.Rate = (emitter:GetAttribute("BaseRate") or 20) / 2
                emitter.Enabled = true
            end
        end
        
    elseif distance < LOD_DISTANCES.Low then
        -- No particles
        for _, emitter in brainrot.PrimaryPart:GetDescendants() do
            if emitter:IsA("ParticleEmitter") then
                emitter.Enabled = false
            end
        end
        
    else
        -- Hidden (or use lower poly mesh)
        brainrot.Parent = nil
    end
end
```

### Material Simplification

```lua
-- For distant brainrots, use cheaper materials
local function simplifyMaterials(brainrot)
    for _, part in brainrot:GetDescendants() do
        if part:IsA("BasePart") then
            -- Store original
            if not part:GetAttribute("OriginalMaterial") then
                part:SetAttribute("OriginalMaterial", part.Material.Name)
            end
            
            -- Simplify
            if part.Material == Enum.Material.Neon then
                part.Material = Enum.Material.SmoothPlastic
            elseif part.Material == Enum.Material.Glass then
                part.Material = Enum.Material.Plastic
            end
        end
    end
end

local function restoreMaterials(brainrot)
    for _, part in brainrot:GetDescendants() do
        if part:IsA("BasePart") then
            local original = part:GetAttribute("OriginalMaterial")
            if original then
                part.Material = Enum.Material[original]
            end
        end
    end
end
```

## Data Store Optimization

### Batched Saves

```lua
-- Instead of saving on every change
local pendingSaves = {}

local function queueSave(player, key, value)
    if not pendingSaves[player] then
        pendingSaves[player] = {}
    end
    pendingSaves[player][key] = value
end

-- Save all pending changes every 60 seconds
task.spawn(function()
    while task.wait(60) do
        for player, data in pendingSaves do
            local profile = ProfileService:GetProfile(player)
            if profile then
                for key, value in data do
                    profile.Data[key] = value
                end
            end
        end
        pendingSaves = {}
    end
end)
```

### Compression for Large Data

```lua
-- For large arrays/tables
local HttpService = game:GetService("HttpService")

local function compressData(data)
    local json = HttpService:JSONEncode(data)
    -- Store as JSON string instead of nested tables
    return json
end

local function decompressData(json)
    return HttpService:JSONDecode(json)
end

-- Usage
profile.Data.BrainrotInventory = compressData(brainrotList)
local inventory = decompressData(profile.Data.BrainrotInventory)
```

## Profiling and Monitoring

### Performance Monitor

```lua
-- PerformanceMonitor.server.lua
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local performanceData = {
    FPS = 60,
    Ping = 0,
    MemoryUsage = 0,
    ActiveBrainrots = 0,
    ActiveParticles = 0
}

RunService.Heartbeat:Connect(function()
    performanceData.FPS = math.floor(1 / RunService.Heartbeat:Wait())
    performanceData.Ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    performanceData.MemoryUsage = Stats:GetTotalMemoryUsageMb()
    performanceData.ActiveBrainrots = #workspace.ActiveBrainrots:GetChildren()
    
    -- Count particles
    local particleCount = 0
    for _, brainrot in workspace.ActiveBrainrots:GetChildren() do
        for _, emitter in brainrot:GetDescendants() do
            if emitter:IsA("ParticleEmitter") and emitter.Enabled then
                particleCount += 1
            end
        end
    end
    performanceData.ActiveParticles = particleCount
    
    -- Auto-optimize if performance degrades
    if performanceData.FPS < 30 then
        warn("[Performance] Low FPS detected, reducing particle count")
        -- Implement auto-reduction logic
    end
end)
```

## Best Practices Summary

1. **Object Pooling**: Reuse brainrots instead of creating/destroying
2. **Batched Operations**: Spawn/update in batches, not all at once
3. **Spatial Queries**: Use Region3 or OverlapParams instead of loops
4. **Particle Budget**: Limit total active emitters, cull distant ones
5. **LOD System**: Reduce detail based on distance
6. **Network Efficiency**: Batch RemoteEvent calls, use Attributes
7. **Memory Management**: Clean up disconnected players immediately
8. **Data Compression**: Use JSON strings for large nested data
9. **Profiling**: Monitor FPS, memory, and object counts
10. **Client-Side Effects**: Create visual effects on client when possible

## Target Performance Metrics

- **Server FPS**: Maintain 60 FPS with 10+ players
- **Client FPS**: Maintain 60 FPS on medium-spec devices
- **Memory**: Keep under 500MB per client
- **Network**: Under 50 KB/s per player average
- **Active Objects**: Max 200 brainrots globally
- **Active Particles**: Max 100 emitters per client
