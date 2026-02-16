-- LavaManager.server.lua
-- Skill: game-mechanics
-- Description: Manages the generation, configuration and movement of Lava Waves.
-- Refinements: Synced Width (200). TWEAKED WEIGHTS (Less Abyssal). SLOWER SPAWN RATE.

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local LavaManager = {}
local activeWaves = 0
local globalRumble = nil

local function updateRumble()
    if not globalRumble then
        local wall = Workspace:FindFirstChild("CelestialSpawnWall") or Workspace
        globalRumble = Instance.new("Sound")
        globalRumble.Name = "GlobalLavaRumble"
        globalRumble.SoundId = "rbxassetid://130972023"
        globalRumble.Volume = 0.8
        globalRumble.Looped = true
        globalRumble.RollOffMaxDistance = 2000 -- Global Ambience
        globalRumble.Parent = wall
    end
    
    if activeWaves > 0 then
        if not globalRumble.IsPlaying then globalRumble:Play() end
    else
        if globalRumble.IsPlaying then globalRumble:Stop() end
    end
end

-- CONFIG
local MIN_SPAWN = 2.0 -- Increased from 1.0 (Slower spawn)
local MAX_SPAWN = 5.5 -- Increased from 4.0
local WAVE_LIFESPAN = 60 
local SLOPE_ANGLE = 25 
local SLOPE_LENGTH = 1500 
local CELESTIAL_EXTENSION = 400 
local TOTAL_LENGTH = SLOPE_LENGTH + CELESTIAL_EXTENSION

local SLOPE_START_Z = 75 -- SYNCED: Matches MapManager
local SLOPE_WIDTH = 200 
local SAFE_Z_LIMIT = SLOPE_START_Z -- Kill exactly at bottom

-- PRECALCULATED GEOMETRY
local RAD_ANGLE = math.rad(SLOPE_ANGLE)
local HEIGHT_DIFF = TOTAL_LENGTH * math.sin(RAD_ANGLE)
local HORIZ_DIFF = TOTAL_LENGTH * math.cos(RAD_ANGLE)

local P1 = Vector3.new(0, -0.5, SLOPE_START_Z)
local P2 = Vector3.new(0, P1.Y + HEIGHT_DIFF, SLOPE_START_Z + HORIZ_DIFF)
local MOVE_DIR = (P1 - P2).Unit

-- SPEED TYPES CONFIG (Tweaked Weights)
local SPEED_TYPES = {
	{Name = "Slow",    Speed = 45,   Scale = 1.0, DepthScale = 1.0, Color = BrickColor.new("Neon orange"),   Emoji = "rbxassetid://12560706226", Weight = 60}, 
	{Name = "Medium",  Speed = 80,   Scale = 1.2, DepthScale = 1.2, Color = BrickColor.new("Bright orange"), Emoji = "rbxassetid://12560706797", Weight = 80}, 
	
	-- Fast & Hyper still common, but Abyssals reduced
	{Name = "Fast",    Speed = 130,  Scale = 1.5, DepthScale = 1.8, Color = BrickColor.new("Bright red"),    Emoji = "rbxassetid://12560707328", Weight = 70}, 
	{Name = "Hyper",   Speed = 210,  Scale = 2.0, DepthScale = 2.5, Color = BrickColor.new("Magenta"),       Emoji = "rbxassetid://12560708027", Weight = 50}, 
	{Name = "Ultra",   Speed = 360,  Scale = 3.0, DepthScale = 4.0, Color = BrickColor.new("White"),         Emoji = "rbxassetid://12560708688", Weight = 30}, 
	
	-- REDUCED WEIGHTS
	{Name = "ABYSSAL", Speed = 520,  Scale = 5.0, DepthScale = 7.0, Color = BrickColor.new("Navy blue"),    Emoji = "rbxassetid://12560706226", Weight = 8}, -- Was 20
	{Name = "VOID",    Speed = 780,  Scale = 8.0, DepthScale = 12.0, Color = BrickColor.new("Really black"), Emoji = "rbxassetid://12560708688", Weight = 3}, -- Was 10
}

local TOTAL_WEIGHT = 0
for _, t in ipairs(SPEED_TYPES) do TOTAL_WEIGHT += t.Weight end

function LavaManager.init()
	local template = Workspace:FindFirstChild("Lava")
	if not template then
		warn("[LavaManager] No 'Lava' model found! Waiting...")
		template = Workspace:WaitForChild("Lava", 5)
	end
	
	if not template then return end
	
	local storageFolder = ServerStorage:FindFirstChild("LavaTypes") or Instance.new("Folder", ServerStorage)
	storageFolder.Name = "LavaTypes"
	
	template.Parent = ServerStorage 
	
	-- Create Variants
	for _, config in ipairs(SPEED_TYPES) do
		local model = template:Clone()
		model.Name = "Lava_" .. config.Name
		
        if model.PrimaryPart then
            local p = model.PrimaryPart
            p.Size = Vector3.new(SLOPE_WIDTH, p.Size.Y * config.DepthScale, p.Size.Z * config.Scale)
        end

		for _, part in pairs(model:GetDescendants()) do
			if part:IsA("BasePart") and part.Name:lower():find("lava") then
                part.BrickColor = config.Color
                part.Material = Enum.Material.Neon
                part.CanCollide = false
                part.Anchored = true
                part.CastShadow = false
                
                -- STANDARDIZE SIZE: High and thick enough (Rotating 90 next)
                -- Size.Y becomes Grosor (Front-to-Back), Size.Z becomes Alto (Vertical) after rotation
                part.Size = Vector3.new(SLOPE_WIDTH, 12 * config.DepthScale, 40 * config.Scale)
                
                local light = part:FindFirstChild("LavaLight") or Instance.new("PointLight")
                light.Name = "LavaLight"
                light.Color = config.Color.Color
                light.Brightness = 5
                light.Range = 25 * config.Scale
                light.Parent = part
			end
		end
		
		-- Setup Billboard
		local speedPart = nil
		for _, part in pairs(model:GetDescendants()) do if part.Name == "SpeedText" then speedPart = part break end end
		if speedPart then
			local bgui = speedPart:FindFirstChildWhichIsA("BillboardGui")
			if bgui then
				bgui.StudsOffset = Vector3.new(0, 5 * config.Scale, 0)
				local emojiLabel = bgui:FindFirstChild("Emoji")
				if emojiLabel then emojiLabel.Image = config.Emoji end
				local speedLabel = bgui:FindFirstChild("Speed")
				if speedLabel then speedLabel.Text = config.Name:upper() end
			end
		end
		model.Parent = storageFolder
	end
	
	LavaManager.createSpawnWall()
	task.spawn(LavaManager.spawnerLoop)
end

function LavaManager.chooseWeightedVariant()
    local r = math.random(0, TOTAL_WEIGHT)
    local current = 0
    for _, t in ipairs(SPEED_TYPES) do
        current += t.Weight
        if r <= current then return t end
    end
    return SPEED_TYPES[1]
end

function LavaManager.createSpawnWall()
    -- ... (Existing code) ...
    if Workspace:FindFirstChild("CelestialSpawnWall") then Workspace.CelestialSpawnWall:Destroy() end
    
    local wall = Instance.new("Part")
    wall.Name = "CelestialSpawnWall"
    wall.Size = Vector3.new(SLOPE_WIDTH + 20, 80, 5)
    wall.Color = Color3.fromRGB(10, 10, 15)
    wall.Material = Enum.Material.Neon
    wall.Anchored = true
    
    local spawnCF = CFrame.lookAt(P2, P1)
    wall.CFrame = spawnCF * CFrame.new(0, 20, -5) 
    
    -- SIREN SOUND SOURCE
    local siren = Instance.new("Sound")
    siren.Name = "TsunamiSiren"
    siren.SoundId = "rbxassetid://4612375233" -- Valid Warning Siren (Alert Sweep)
    siren.Volume = 5
    siren.RollOffMaxDistance = 5000 -- Global-ish
    siren.Parent = wall
    
    wall.Parent = Workspace
end

-- ...

-- ============================================================================
-- DYNAMIC SEGMENT SPAWNING
-- ============================================================================
function LavaManager.spawnWavePattern(template, config, pattern)
    
    local function spawnSegment(width, centerOffset)
        if width < 2 then return end 
        
        local wave = template:Clone()
        wave.Name = "ActiveLavaWave"
        
        local lookAtCFrame = CFrame.lookAt(P2, P1)
        
        local heightPart = wave:FindFirstChild("Lava", true) or wave.PrimaryPart
        
        -- Resize: Ensure ALL meshes have the SAME width
        for _, part in pairs(wave:GetDescendants()) do
            if part:IsA("BasePart") and part.Name:lower():find("lava") then
                part.Size = Vector3.new(width, part.Size.Y, part.Size.Z)
            end
        end
        if wave.PrimaryPart then
            wave.PrimaryPart.Size = Vector3.new(width, wave.PrimaryPart.Size.Y, wave.PrimaryPart.Size.Z)
        end
        
        -- Position: Center at (centerOffset), Depth sits on surface
        -- 2 is the half-thickness of the slope part (size 4)
        local verticalOffset = (heightPart.Size.Z / 2) + 2
        wave:SetPrimaryPartCFrame(lookAtCFrame * CFrame.Angles(math.rad(90), 0, 0) * CFrame.new(centerOffset, verticalOffset, 0))
        
        -- Double Sided
    	for _, part in pairs(wave:GetDescendants()) do
    		if (part:IsA("MeshPart") or part:IsA("BasePart")) and part.Name:lower():find("lava") then
    			local backSide = part:Clone()
    			backSide.Name = "Lava_Backside"
    			backSide.Parent = part.Parent
    			backSide.CFrame = part.CFrame * CFrame.Angles(0, math.rad(180), 0)
    			local weld = Instance.new("WeldConstraint")
    			weld.Part0 = part; weld.Part1 = backSide; weld.Parent = backSide
    			backSide.CanCollide = false; backSide.CanTouch = false
    		end
    	end
        
        wave.Parent = Workspace
        LavaManager.activateWave(wave, config)
    end
    
    -- PATTERN LOGIC
    if pattern == "Full" then
        spawnSegment(SLOPE_WIDTH, 0)
        
    elseif pattern == "SideGap" then
        local gapSize = math.random(25, 45)
        local side = math.random(1, 2) == 1 and 1 or -1 
        local waveWidth = SLOPE_WIDTH - gapSize
        local waveCenter = -(gapSize * side) / 2
        
        spawnSegment(waveWidth, waveCenter)
        
    elseif pattern == "DynamicSplit" then
        local gapSize = math.random(25, 45)
        local margin = 10 
        local minCenter = -SLOPE_WIDTH/2 + margin + gapSize/2
        local maxCenter = SLOPE_WIDTH/2 - margin - gapSize/2
        
        if minCenter >= maxCenter then 
            spawnSegment(SLOPE_WIDTH, 0) 
            return 
        end
        
        local gapCenter = math.random(minCenter, maxCenter)
        
        local leftBound = -SLOPE_WIDTH/2
        local gapLeftEdge = gapCenter - gapSize/2
        local leftWidth = gapLeftEdge - leftBound
        local leftCenter = leftBound + leftWidth/2
        
        local rightBound = SLOPE_WIDTH/2
        local gapRightEdge = gapCenter + gapSize/2
        local rightWidth = rightBound - gapRightEdge
        local rightCenter = gapRightEdge + rightWidth/2
        
        spawnSegment(leftWidth, leftCenter)
        spawnSegment(rightWidth, rightCenter)
    end
end

function LavaManager.spawnerLoop()
	local storageFolder = ServerStorage:FindFirstChild("LavaTypes")
	if not storageFolder then return end
	
	while true do
		local waitTime = math.random(MIN_SPAWN * 10, MAX_SPAWN * 10) / 10
		task.wait(waitTime)
		
		local config = LavaManager.chooseWeightedVariant()
		local template = storageFolder:FindFirstChild("Lava_" .. config.Name)
		
		if template then
             -- Play Siren if High Threat
             if config.Name == "ABYSSAL" or config.Name == "VOID" then
                 local wall = Workspace:FindFirstChild("CelestialSpawnWall")
                 if wall and wall:FindFirstChild("TsunamiSiren") then
                     wall.TsunamiSiren:Play()
                 end
             end

            local pRoll = math.random(1, 100)
            local pattern = "Full"
            
            if pRoll > 80 then pattern = "SideGap"
            elseif pRoll > 50 then pattern = "DynamicSplit"
            else pattern = "Full" end
            
			LavaManager.spawnWavePattern(template, config, pattern)
		end
	end
end

-- ...

function LavaManager.activateWave(wave, config)
	for _, part in pairs(wave:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Touched:Connect(function(hit)
				local char = hit.Parent
				local hum = char:FindFirstChild("Humanoid")
				if hum and hum.Health > 0 then 
                    -- SAFE ZONE / SHIELD CHECK
                    if char:GetAttribute("IsSafe") then return end
                    hum.Health = 0 
                end
			end)
		end
	end
	
    -- TRACKING
    activeWaves += 1
    updateRumble()
    
    -- Cleanup when destroyed
    wave.Destroying:Connect(function()
        activeWaves -= 1
        updateRumble()
    end)
    
	local speed = config.Speed
	local startTime = tick()
	local connection
	
	connection = RunService.Heartbeat:Connect(function(dt)
		if not wave or not wave.Parent then connection:Disconnect(); return end
		if tick() - startTime > WAVE_LIFESPAN then wave:Destroy(); connection:Disconnect(); return end
		
		local currentPos = wave:GetPrimaryPartCFrame().Position
		if currentPos.Z < SAFE_Z_LIMIT then wave:Destroy(); connection:Disconnect(); return end
		
		local moveStep = MOVE_DIR * (speed * dt)
		wave:SetPrimaryPartCFrame(wave:GetPrimaryPartCFrame() + moveStep)
	end)
	
	Debris:AddItem(wave, WAVE_LIFESPAN)
end

LavaManager.init()

return LavaManager
