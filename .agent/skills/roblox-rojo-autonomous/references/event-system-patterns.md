# Event System Patterns

This reference provides detailed patterns for implementing event systems in the Roblox project.

## Event Rotation System

### Core Architecture

```lua
-- EventManager.server.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- CONFIG
local EVENT_CYCLE_TIME = 300 -- 5 minutes between events
local TRANSITION_TIME = 10 -- 10 seconds warning before event

-- EVENT REGISTRY
local EVENTS = {
    {
        Name = "MeteorShower",
        Duration = 120,
        Weight = 10,
        Module = "MeteorEvent",
        MinPlayers = 1,
        MaxConcurrent = 1
    },
    {
        Name = "LavaRise",
        Duration = 60,
        Weight = 15,
        Module = "LavaRiseEvent",
        MinPlayers = 1,
        MaxConcurrent = 1
    },
    {
        Name = "CelestialBrainrots",
        Duration = 180,
        Weight = 5,
        Module = "CelestialEvent",
        MinPlayers = 3,
        MaxConcurrent = 1
    },
    {
        Name = "BrainrotFusion",
        Duration = 90,
        Weight = 8,
        Module = "FusionEvent",
        MinPlayers = 1,
        MaxConcurrent = 3 -- Can happen multiple times on map
    },
}

-- STATE
local activeEvents = {}
local eventHistory = {}
local lastEventTime = 0

-- WEIGHTED RANDOM SELECTION
local function selectRandomEvent()
    local eligibleEvents = {}
    local playerCount = #game:GetService("Players"):GetPlayers()
    
    -- Filter events by player requirements and concurrent limits
    for _, eventData in EVENTS do
        if playerCount >= eventData.MinPlayers then
            local activeCount = 0
            for _, activeEvent in activeEvents do
                if activeEvent.Name == eventData.Name then
                    activeCount += 1
                end
            end
            
            if activeCount < eventData.MaxConcurrent then
                table.insert(eligibleEvents, eventData)
            end
        end
    end
    
    if #eligibleEvents == 0 then
        return nil -- No eligible events
    end
    
    -- Calculate total weight
    local totalWeight = 0
    for _, event in eligibleEvents do
        totalWeight += event.Weight
    end
    
    -- Weighted random selection
    local roll = math.random(1, totalWeight)
    local currentWeight = 0
    
    for _, event in eligibleEvents do
        currentWeight += event.Weight
        if roll <= currentWeight then
            return event
        end
    end
    
    return eligibleEvents[1] -- Fallback
end

-- EVENT LIFECYCLE
local function startEvent(eventData)
    local eventInstance = {
        Name = eventData.Name,
        StartTime = os.time(),
        EndTime = os.time() + eventData.Duration,
        Active = true,
        Module = nil
    }
    
    -- Load and initialize event module
    local eventModule = require(ReplicatedStorage.Modules.Events[eventData.Module])
    eventInstance.Module = eventModule
    
    -- Start the event
    local success = eventModule.Start()
    if success then
        table.insert(activeEvents, eventInstance)
        table.insert(eventHistory, {Name = eventData.Name, Time = os.time()})
        
        -- Notify all clients
        ReplicatedStorage.Events.EventStarted:FireAllClients(eventData.Name, eventData.Duration)
        
        print("[EventManager] Started event:", eventData.Name)
    else
        warn("[EventManager] Failed to start event:", eventData.Name)
    end
end

local function endEvent(eventInstance)
    if eventInstance.Module and eventInstance.Module.End then
        eventInstance.Module.End()
    end
    
    eventInstance.Active = false
    
    -- Remove from active list
    for i, event in activeEvents do
        if event == eventInstance then
            table.remove(activeEvents, i)
            break
        end
    end
    
    -- Notify clients
    ReplicatedStorage.Events.EventEnded:FireAllClients(eventInstance.Name)
    
    print("[EventManager] Ended event:", eventInstance.Name)
end

-- MAIN LOOP
local function updateEvents()
    local currentTime = os.time()
    
    -- Check for ended events
    for i = #activeEvents, 1, -1 do
        local event = activeEvents[i]
        if currentTime >= event.EndTime then
            endEvent(event)
        end
    end
    
    -- Check if it's time to start a new event
    if currentTime - lastEventTime >= EVENT_CYCLE_TIME then
        local selectedEvent = selectRandomEvent()
        if selectedEvent then
            -- Warn players before starting
            ReplicatedStorage.Events.EventWarning:FireAllClients(selectedEvent.Name, TRANSITION_TIME)
            task.wait(TRANSITION_TIME)
            
            startEvent(selectedEvent)
            lastEventTime = currentTime
        end
    end
end

-- INITIALIZATION
RunService.Heartbeat:Connect(updateEvents)
```

## Event Module Template

Each event should be a ModuleScript in `shared/Modules/Events/`:

```lua
-- MeteorEvent.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")

local MeteorEvent = {}

-- CONFIG
local METEOR_SPAWN_RATE = 2 -- Seconds between meteors
local METEOR_DAMAGE = 50
local METEOR_RADIUS = 20

-- STATE
local meteorLoop = nil
local activeMeteors = {}

-- FUNCTIONS
local function spawnMeteor()
    local playArea = workspace.PlayArea
    local randomX = math.random(playArea.Position.X - playArea.Size.X/2, playArea.Position.X + playArea.Size.X/2)
    local randomZ = math.random(playArea.Position.Z - playArea.Size.Z/2, playArea.Position.Z + playArea.Size.Z/2)
    local spawnHeight = 500
    
    local meteor = Instance.new("Part")
    meteor.Name = "Meteor"
    meteor.Size = Vector3.new(8, 8, 8)
    meteor.Shape = Enum.PartType.Ball
    meteor.Material = Enum.Material.Neon
    meteor.BrickColor = BrickColor.new("Deep orange")
    meteor.CFrame = CFrame.new(randomX, spawnHeight, randomZ)
    meteor.CanCollide = false
    
    -- Add particle trail
    local trail = Instance.new("ParticleEmitter")
    trail.Texture = "rbxasset://textures/particles/fire_main.dds"
    trail.Color = ColorSequence.new(Color3.fromRGB(255, 100, 0))
    trail.Rate = 50
    trail.Lifetime = NumberRange.new(1, 2)
    trail.Parent = meteor
    
    meteor.Parent = workspace.Events
    
    -- Falling animation
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Velocity = Vector3.new(0, -100, 0)
    bodyVelocity.MaxForce = Vector3.new(0, math.huge, 0)
    bodyVelocity.Parent = meteor
    
    -- Impact detection
    meteor.Touched:Connect(function(hit)
        if hit.Parent ~= workspace.Events then
            -- Create explosion
            local explosion = Instance.new("Explosion")
            explosion.Position = meteor.Position
            explosion.BlastRadius = METEOR_RADIUS
            explosion.BlastPressure = 500000
            explosion.Parent = workspace
            
            -- Damage players in radius
            for _, player in game:GetService("Players"):GetPlayers() do
                if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    local distance = (player.Character.HumanoidRootPart.Position - meteor.Position).Magnitude
                    if distance <= METEOR_RADIUS then
                        local humanoid = player.Character:FindFirstChild("Humanoid")
                        if humanoid then
                            humanoid:TakeDamage(METEOR_DAMAGE)
                        end
                    end
                end
            end
            
            meteor:Destroy()
        end
    end)
    
    -- Cleanup after 10 seconds
    Debris:AddItem(meteor, 10)
    table.insert(activeMeteors, meteor)
end

function MeteorEvent.Start()
    print("[MeteorEvent] Starting meteor shower")
    
    -- Create events folder if it doesn't exist
    if not workspace:FindFirstChild("Events") then
        local eventsFolder = Instance.new("Folder")
        eventsFolder.Name = "Events"
        eventsFolder.Parent = workspace
    end
    
    -- Start spawning loop
    meteorLoop = task.spawn(function()
        while task.wait(METEOR_SPAWN_RATE) do
            spawnMeteor()
        end
    end)
    
    return true
end

function MeteorEvent.End()
    print("[MeteorEvent] Ending meteor shower")
    
    -- Stop spawning
    if meteorLoop then
        task.cancel(meteorLoop)
        meteorLoop = nil
    end
    
    -- Clean up active meteors
    for _, meteor in activeMeteors do
        if meteor and meteor.Parent then
            meteor:Destroy()
        end
    end
    activeMeteors = {}
end

return MeteorEvent
```

## Super Events

Super events are rare, high-impact events with special rewards:

```lua
-- SuperEventManager.server.lua
local SUPER_EVENTS = {
    {
        Name = "GoldenHour",
        Duration = 300,
        Chance = 0.05, -- 5% chance
        Multipliers = {
            Income = 10,
            SpawnRate = 2,
            RarityBoost = 2 -- Shifts rarity tiers up
        }
    },
    {
        Name = "BrainrotApocalypse",
        Duration = 180,
        Chance = 0.02, -- 2% chance
        Effects = {
            SpawnAllRarities = true,
            DoubleCapacity = true,
            BonusRewards = true
        }
    }
}

local function checkSuperEvent()
    local roll = math.random()
    
    for _, superEvent in SUPER_EVENTS do
        if roll <= superEvent.Chance then
            return superEvent
        end
    end
    
    return nil
end

local function activateSuperEvent(eventData)
    -- Apply global multipliers
    if eventData.Multipliers then
        _G.IncomeMultiplier = (_G.IncomeMultiplier or 1) * eventData.Multipliers.Income
        _G.SpawnRateMultiplier = (_G.SpawnRateMultiplier or 1) * eventData.Multipliers.SpawnRate
    end
    
    -- Notify all players with big announcement
    ReplicatedStorage.Events.SuperEventStarted:FireAllClients(eventData.Name, eventData.Duration)
    
    -- Schedule end
    task.delay(eventData.Duration, function()
        deactivateSuperEvent(eventData)
    end)
end
```

## Event Notifications (Client-Side)

```lua
-- EventNotifier.client.lua (StarterPlayerScripts)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Listen for event warnings
ReplicatedStorage.Events.EventWarning.OnClientEvent:Connect(function(eventName, timeUntilStart)
    local gui = playerGui:FindFirstChild("EventWarning")
    if gui then
        gui.Title.Text = eventName .. " in " .. timeUntilStart .. "s!"
        gui.Enabled = true
        
        task.wait(timeUntilStart)
        gui.Enabled = false
    end
end)

-- Listen for event start
ReplicatedStorage.Events.EventStarted.OnClientEvent:Connect(function(eventName, duration)
    local gui = playerGui:FindFirstChild("EventActive")
    if gui then
        gui.EventName.Text = eventName
        gui.Timer.Text = duration .. "s remaining"
        gui.Enabled = true
        
        -- Update timer
        for i = duration, 0, -1 do
            gui.Timer.Text = i .. "s remaining"
            task.wait(1)
        end
        
        gui.Enabled = false
    end
end)
```

## Best Practices

1. **Event balancing**: Keep event durations between 60-300 seconds
2. **Player count scaling**: Adjust difficulty based on server population
3. **Cooldowns**: Prevent the same event from triggering twice in a row
4. **Transition warnings**: Always give players 10-15 seconds warning
5. **Cleanup**: Always properly clean up event objects when events end
6. **Error handling**: Wrap event logic in pcall() to prevent crashes
7. **Performance**: Limit particle effects and part counts during events
