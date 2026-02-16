-- EventManager.server.lua
-- Skill: game-events
-- Description: Manages global timed events (5m Random / 8m Major).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local EventManager = {}
local EventStarted = ReplicatedStorage:FindFirstChild("EventStarted")
if not EventStarted then
    EventStarted = Instance.new("RemoteEvent")
    EventStarted.Name = "EventStarted"
    EventStarted.Parent = ReplicatedStorage
    print("[EventManager] Created EventStarted RemoteEvent")
end

local function notifyGlobal(title, text, color)
    EventStarted:FireAllClients(title, text, color)
end

-- CONFIG
local MINOR_EVENT_INTERVAL = 600 -- 10 Minutes
local MAJOR_EVENT_INTERVAL = 1800 -- 30 Minutes

-- PRE-CALC NEXT TIMES (Deterministic)
local function getNextTime(interval)
    local now = os.time()
    local remainder = now % interval
    return now + (interval - remainder)
end

local nextMinorTime = getNextTime(MINOR_EVENT_INTERVAL)
local nextMajorTime = getNextTime(MAJOR_EVENT_INTERVAL)

-- DEPENDENCIES
-- (Lazy load inside functions to avoid cyclic deps if needed)

-- HELPER: Spawn Rare Unit
local function spawnRareUnit(targetTier, shinyChance)
    local storage = game:GetService("ServerStorage")
    local tsunami = storage:FindFirstChild("Tsunami")
    if not tsunami then return end
    
    local brainrots = tsunami:FindFirstChild("BrainrotsModels")
    if not brainrots then return end
    
    local tierFolder = brainrots:FindFirstChild(targetTier)
    if not tierFolder then 
        warn("[EventManager] Tier folder not found: " .. tostring(targetTier))
        return 
    end
    
    local candidates = tierFolder:GetChildren()
    if #candidates == 0 then return end
    
    local chosen = candidates[math.random(1, #candidates)]
    local isShiny = (math.random() < (shinyChance or 0.05))
    
    -- SPAWN VISUAL
    local model = chosen:Clone()
    model.Name = "EventUnit_" .. chosen.Name
    
    -- Find Spawn Location (Random near center or designated spots)
    local spawnPoints = CollectionService:GetTagged("EventSpawn")
    local spawnPos = Vector3.new(0, 10, 0) -- Default
    
    if #spawnPoints > 0 then
        local sp = spawnPoints[math.random(1, #spawnPoints)]
        spawnPos = sp.Position + Vector3.new(0, 5, 0)
    else
        -- Fallback: Random spot around 0,0,0
        spawnPos = Vector3.new(math.random(-50, 50), 10, math.random(-50, 50))
    end
    
    if model:IsA("Model") then
        model:PivotTo(CFrame.new(spawnPos))
    else
        model.Position = spawnPos
    end
    model.Parent = Workspace
    
    -- FX
    local hl = Instance.new("Highlight")
    hl.FillColor = isShiny and Color3.fromHex("#FFD700") or Color3.fromHex("#A020F0") -- Gold or Purple
    hl.OutlineColor = Color3.new(1,1,1)
    hl.Parent = model
    
    -- INTERACTION
    local cd = Instance.new("ClickDetector")
    cd.MaxActivationDistance = 50
    cd.Parent = model
    
    local claimed = false
    cd.MouseClick:Connect(function(player)
        if claimed then return end
        claimed = true
        
        -- GIVE REWARD
        local BrainrotData = require(ServerScriptService.BrainrotData)
        BrainrotData.addUnitAdvanced(player, chosen.Name, targetTier, isShiny, false)
        
        notifyGlobal("¡UNIDAD RECLAMADA!", player.Name .. " encontró: " .. chosen.Name .. (isShiny and " (SHINY)!" or "!"), Color3.new(0, 1, 0))
        
        model:Destroy()
    end)
    
    -- CLEANUP
    task.delay(60, function()
        if model and model.Parent then
            model:Destroy()
            if not claimed then
                 print("[EventManager] Event Unit expired: " .. chosen.Name)
            end
        end
    end)
    
    return chosen.Name
end

-- 1. MAJOR EVENTS (Always Positive or Epic)
local MajorEvents = {
    {
        Name = "CATACLISMO CELESTIAL",
        Desc = "¡UNIDAD CELESTIAL HA APARECIDO! (Busca en el mapa)",
        Action = function()
            spawnRareUnit("Celestial", 0.1) -- 10% Shiny chance
        end
    },
    {
        Name = "DOYBLE WAVE FRENZY",
        Desc = "¡OLEADAS DOBLES! (Doble Spawn de Brainrots en Zona Especial)",
        Action = function()
            -- Enable Global Flags for GameManager
            _G.DoubleWaveActive = true
            
            -- Visual/Notify
            local spawnPoints = CollectionService:GetTagged("EventSpawn")
            if #spawnPoints > 0 then
                -- Optional: Highlight the zone or play a sound
                local hl = Instance.new("Highlight")
                hl.Adornee = spawnPoints[1].Parent 
                hl.Parent = spawnPoints[1].Parent
                game.Debris:AddItem(hl, 60)
            end
            
            -- Disable after 60 seconds (Event Duration)
            task.delay(60, function()
                _G.DoubleWaveActive = false
                notifyGlobal("FIN DE EVENTO", "Las oleadas han vuelto a la normalidad.", Color3.new(1,1,1))
            end)
        end
    },
    {
        Name = "LLUVIA DORADA",
        Desc = "¡Ingresos x2 por 60 segundos!",
        Action = function()
            for _, p in pairs(Players:GetPlayers()) do
                local BrainrotData = require(ServerScriptService.BrainrotData)
                BrainrotData.addCash(p, 5000)
            end
        end
    },
    {
        Name = "LLUVIA DE METEORITOS",
        Desc = "¡CUIDADO! Meteoritos cayendo del cielo (30s)",
        Action = function()
            local MeteorLogic = require(ServerScriptService:FindFirstChild("MeteorLogic") or script) -- Fallback
            if MeteorLogic and MeteorLogic.startShower then
                 MeteorLogic.startShower(30)
            end
        end
    },
    {
        Name = "OLA DE VACÍO (VOID WAVE)",
        Desc = "⚠️ ¡ADVERTENCIA! EL VACÍO SE ACERCA... (Wipeout Inminente)",
        Action = function()
            -- 1. WARNING PHASE (10s)
            local LightingManager = require(ServerScriptService.LightingManager)
            LightingManager.setMode("Apocalyptic") -- Assuming this mode exists or will be added
            
            notifyGlobal("⚠️ ALERTA DE VACÍO ⚠️", "¡CUBRÍOS! EL VACÍO CONSUMIRÁ TODO EN 10 SEGUNDOS...", Color3.fromRGB(128, 0, 128))
            
            task.delay(10, function()
                -- 2. ACTION PHASE: WIPEOUT
                local units = CollectionService:GetTagged("BrainrotUnit")
                for _, u in pairs(units) do
                    if u:IsA("Model") then
                        -- FX before destroy
                        local exp = Instance.new("Explosion")
                        exp.Position = u.PrimaryPart and u.PrimaryPart.Position or u:GetPivot().Position
                        exp.BlastRadius = 0
                        exp.BlastPressure = 0
                        exp.Parent = Workspace
                        u:Destroy()
                    end
                end
                
                notifyGlobal("EL VACÍO HA LLEGADO", "Todas las unidades han sido purgadas.", Color3.fromRGB(80, 0, 80))
                
                -- 3. AFTERMATH: SPAWN MUTATED WAVE
                task.delay(3, function()
                     notifyGlobal("RENACIMIENTO OSCURO", "¡Una nueva generación mutada emerge del vacío!", Color3.fromRGB(255, 0, 255))
                     
                     -- Spawn Logic would normally enable the spawner, but since we rely on natural spawning,
                     -- we can force a "Mutated Wave" state here if GameManager supports it,
                     -- or manually spawn a batch. For now, we'll set a global flag for 100% mutations for 60s.
                     
                     _G.VoidMutationActive = true
                     task.delay(60, function()
                         _G.VoidMutationActive = false
                         LightingManager.setMode("Standard") -- Restore light
                         notifyGlobal("CALMA RESTAURADA", "El vacío se ha disipado.", Color3.new(1,1,1))
                     end)
                end)
            end)
        end
    }
}

-- 2. MINOR EVENTS (Random Good/Bad)
local MinorEvents = {
    -- RARE SPAWN
    {
        Name = "TORMENTA DIVINA",
        Type = "Good",
        Desc = "¡Una unidad Divina ha aparecido!",
        Action = function()
            spawnRareUnit("Divine", 0.05)
        end
    },
    -- MUTATION EVENT (NEW)
    {
        Name = "LOCURA DE MUTACIONES",
        Type = "Good",
        Desc = "¡Radiación Global! Unidades aleatorias están mutando...",
        Action = function()
            local MutationManager = require(ReplicatedStorage.Modules:WaitForChild("MutationManager"))
            local units = CollectionService:GetTagged("BrainrotUnit")
            
            local mutatedCount = 0
            for _, unit in pairs(units) do
                -- Chance to mutate existing units if they aren't already mutated
                if not unit:GetAttribute("Mutation") and math.random() < 0.3 then -- 30% chance per unit
                    local mutation = MutationManager.rollMutation()
                    if mutation then
                        MutationManager.applyMutation(unit, mutation)
                        mutatedCount = mutatedCount + 1
                        
                        -- Visual pop
                        local hl = Instance.new("Highlight")
                        hl.FillColor = Color3.new(0,1,0)
                        hl.OutlineTransparency = 1
                        hl.Parent = unit
                        game.Debris:AddItem(hl, 1)
                    end
                end
            end
            
            if mutatedCount > 0 then
                notifyGlobal("MUTACIÓN MASIVA", "¡" .. mutatedCount .. " unidades han mutado!", Color3.new(0.5, 1, 0))
            end
        end
    },
    -- CHAOS SPEED
    {
        Name = "FRENESÍ DE VELOCIDAD",
        Type = "Good",
        Desc = "¡CORRE! Velocidad x5 por 30 segundos.",
        Action = function()
            local BrainrotData = require(ServerScriptService.BrainrotData)
            
            for _, p in pairs(Players:GetPlayers()) do
                if p.Character and p.Character:FindFirstChild("Humanoid") then
                    p.Character.Humanoid.WalkSpeed = 80 -- Super fast
                end
            end
            task.delay(30, function()
                -- Restore
                for _, p in pairs(Players:GetPlayers()) do
                    if p.Character and p.Character:FindFirstChild("Humanoid") then
                        p.Character.Humanoid.WalkSpeed = BrainrotData.calculateIntendedSpeed(p)
                    end
                end
            end)
        end
    },
    -- "BAD" (Fun Chaos)
    {
        Name = "GRAVEDAD LUNAR",
        Type = "Bad",
        Desc = "¡La gravedad ha bajado!",
        Action = function()
            Workspace.Gravity = 50
            task.delay(30, function()
                Workspace.Gravity = 196.2
            end)
        end
    }
}

--------------------------------------------------------
-- MAIN LOOP
--------------------------------------------------------

local function checkTimers()
    local now = os.time()
    
    -- 1. MAJOR EVENT CHECK
    if now >= nextMajorTime then
        nextMajorTime = getNextTime(MAJOR_EVENT_INTERVAL) -- Schedule next
        
        -- Prevent overlap: If a minor event was also due, skip it (update timer)
        if now >= nextMinorTime then
             nextMinorTime = getNextTime(MINOR_EVENT_INTERVAL)
             print("[EventManager] Skipped Minor Event (Overlap with Major)")
        end
        
        local event = MajorEvents[math.random(1, #MajorEvents)]
        notifyGlobal("EVENTO MAYOR GLOBAL", event.Desc, Color3.new(1, 0.8, 0))
        task.spawn(event.Action)
        
        return 
    end
    
    -- 2. MINOR EVENT CHECK
    if now >= nextMinorTime then
        nextMinorTime = getNextTime(MINOR_EVENT_INTERVAL) -- Schedule next
        
        local event = MinorEvents[math.random(1, #MinorEvents)]
        local color = event.Type == "Good" and Color3.new(0,1,0) or Color3.new(1,0,0)
        notifyGlobal("EVENTO GLOBAL", event.Desc, color)
        task.spawn(event.Action)
    end
    
    -- 3. UPDATE BOARDS (Using Time Remaining)
    -- We can optimize this by only doing it every second, which the loop does.
    local boards = CollectionService:GetTagged("EventTimerBoard")
    for _, b in ipairs(boards) do
        local sg = b:FindFirstChild("EventTimerGUI")
        if sg then
            -- Time Remaining
            local majRem = nextMajorTime - now
            local minRem = nextMinorTime - now
            
            -- Format MM:SS
            local function fmt(s)
                local m = math.floor(s / 60)
                local sec = s % 60
                return string.format("%02d:%02d", m, sec)
            end
            
            if sg:FindFirstChild("MajorTimer") then
                sg.MajorTimer.Text = "JACKPOT: " .. fmt(majRem)
            end
            if sg:FindFirstChild("MinorTimer") then
                sg.MinorTimer.Text = "Evento: " .. fmt(minRem)
            end
        end
    end
end

-- Start Loop
task.spawn(function()
    print("[EventManager] GLOBAL SYNC STARTED.")
    print("   > Next Minor: " .. os.date("%X", nextMinorTime))
    print("   > Next Major: " .. os.date("%X", nextMajorTime))
    
    while true do
        task.wait(1) -- Check every second
        checkTimers()
    end
end)

return EventManager
