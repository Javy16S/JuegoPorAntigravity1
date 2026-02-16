-- LavaManager.server.lua
-- Skill: game-mechanics
-- Description: Manages the generation, configuration and movement of Lava Waves.

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local LavaManager = {}

-- CONFIG
local MIN_SPAWN = 4 -- Minimum seconds between waves
local MAX_SPAWN = 12 -- Maximum seconds between waves
local WAVE_LIFESPAN = 45 -- Increased life for 1500 studs slope
local SLOPE_ANGLE = 25 -- Degrees (Synced with MapManager)
local SLOPE_LENGTH = 1500 -- Updated to match MapManager
local SLOPE_START_Z = 120
local SLOPE_WIDTH = 120
local SAFE_Z_LIMIT = SLOPE_START_Z + 15 -- Disappear 15 studs before reaching players

-- PRECALCULATED
local RAD_ANGLE = math.rad(SLOPE_ANGLE)
local H_DIST = SLOPE_LENGTH * math.cos(RAD_ANGLE)
local V_DIST = SLOPE_LENGTH * math.sin(RAD_ANGLE)

local P1 = Vector3.new(0, 0, SLOPE_START_Z)
local P2 = Vector3.new(0, V_DIST, SLOPE_START_Z + H_DIST)
local MOVE_DIR = (P1 - P2).Unit

-- SPEED TYPES CONFIG
-- Scale: Multiplier for the model size to make faster waves intimidating
local SPEED_TYPES = {
	{Name = "Slow",    Speed = 40,   Scale = 1.0, DepthScale = 1.0, Color = BrickColor.new("Neon orange"),   Emoji = "rbxassetid://12560706226"}, -- 🐢
	{Name = "Medium",  Speed = 75,   Scale = 1.2, DepthScale = 1.2, Color = BrickColor.new("Bright orange"), Emoji = "rbxassetid://12560706797"}, -- 🏃
	{Name = "Fast",    Speed = 120,  Scale = 1.5, DepthScale = 1.8, Color = BrickColor.new("Bright red"),    Emoji = "rbxassetid://12560707328"}, -- ⚡
	{Name = "Hyper",   Speed = 200,  Scale = 2.0, DepthScale = 2.5, Color = BrickColor.new("Magenta"),       Emoji = "rbxassetid://12560708027"}, -- 🚀
	{Name = "Ultra",   Speed = 350,  Scale = 3.0, DepthScale = 4.0, Color = BrickColor.new("White"),         Emoji = "rbxassetid://12560708688"}, -- 🌌
	{Name = "ABYSSAL", Speed = 500,  Scale = 5.0, DepthScale = 7.0, Color = BrickColor.new("Navy blue"),    Emoji = "rbxassetid://12560706226"}, -- 💀
	{Name = "VOID",    Speed = 750,  Scale = 8.0, DepthScale = 12.0, Color = BrickColor.new("Really black"), Emoji = "rbxassetid://12560708688"}, -- 🌑
}

function LavaManager.init()
	-- 1. Setup Storage
	local template = Workspace:FindFirstChild("Lava")
	if not template then
		warn("[LavaManager] No 'Lava' model found in Workspace! Waiting for it...")
		template = Workspace:WaitForChild("Lava", 5)
	end
	
	if not template then
		warn("[LavaManager] ABORT: 'Lava' model not found.")
		return
	end
	
	local storageFolder = ServerStorage:FindFirstChild("LavaTypes") or Instance.new("Folder", ServerStorage)
	storageFolder.Name = "LavaTypes"
	
	template.Parent = ServerStorage -- Move original to storage
	
	-- 2. Create Variants
	for _, config in ipairs(SPEED_TYPES) do
		local model = template:Clone()
		model.Name = "Lava_" .. config.Name
		
        -- Resize PrimaryPart (X=Width, Y=Depth, Z=Height before rotation)
        if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
            local p = model.PrimaryPart
            p.Size = Vector3.new(SLOPE_WIDTH, p.Size.Y * config.DepthScale, p.Size.Z * config.Scale)
        end

		-- Configure Visuals (Scale Z for HEIGHT, Force X for WIDTH)
		for _, part in pairs(model:GetDescendants()) do
			if part:IsA("BasePart") or part:IsA("MeshPart") then
				if part.Name:lower():find("lava") then
					part.BrickColor = config.Color
					part.Material = Enum.Material.Neon
					part.CanCollide = false
					part.Anchored = true
					
					-- AXIS FIX: After 90deg X rotation: X=Width, Z=Height, Y=Depth
					local originalSize = part.Size
					part.Size = Vector3.new(SLOPE_WIDTH, originalSize.Y * config.DepthScale, originalSize.Z * config.Scale)
					
					-- MAXIMUM RENDERING: Add Glowing Light
					local light = part:FindFirstChild("LavaLight") or Instance.new("PointLight")
					light.Name = "LavaLight"
					light.Color = config.Color.Color
					light.Brightness = 5
					light.Range = 25 * config.Scale
					light.Shadows = true
					light.Parent = part
				end
			end
		end
		
		-- Configure Billboard (SpeedText)
		local speedPart = nil
		for _, part in pairs(model:GetDescendants()) do
			if part.Name == "SpeedText" then
				speedPart = part
				break
			end
		end
		
		if speedPart then
			local bgui = speedPart:FindFirstChildWhichIsA("BillboardGui")
			if bgui then
				-- Adjust billboard height based on Z-scale (the new vertical axis)
				bgui.StudsOffset = Vector3.new(0, 5 * config.Scale, 0)
				
				local emojiLabel = bgui:FindFirstChild("Emoji")
				local speedLabel = bgui:FindFirstChild("Speed")
				
				if emojiLabel and emojiLabel:IsA("ImageLabel") then
					emojiLabel.Image = config.Emoji
				end
				
				if speedLabel and speedLabel:IsA("TextLabel") then
					speedLabel.Text = config.Name:upper()
					speedLabel.TextColor3 = config.Color.Color
					-- Make text stroke more visible for fast waves
					local stroke = speedLabel:FindFirstChildWhichIsA("UIStroke") or Instance.new("UIStroke", speedLabel)
					stroke.Thickness = 2 * config.Scale
					stroke.Color = Color3.new(0,0,0)
				end
			end
		end
		
		model.Parent = storageFolder
	end
	
	print("[LavaManager] Initialized with " .. #SPEED_TYPES .. " Lava Types.")
	
	-- 3. Start Spawner
	task.spawn(LavaManager.spawnerLoop)
end

function LavaManager.spawnerLoop()
	local storageFolder = ServerStorage:FindFirstChild("LavaTypes")
	if not storageFolder then return end
	
	while true do
		local waitTime = math.random(MIN_SPAWN * 10, MAX_SPAWN * 10) / 10
		task.wait(waitTime)
		
		local variants = storageFolder:GetChildren()
		if #variants > 0 then
			local chosen = variants[math.random(1, #variants)]
			local config = nil
			for _, c in ipairs(SPEED_TYPES) do
				if chosen.Name == "Lava_" .. c.Name then
					config = c
					break
				end
			end
			
			if config then
				LavaManager.spawnWave(chosen, config)
			end
		end
	end
end

function LavaManager.spawnWave(template, config)
	local wave = template:Clone()
	wave.Name = "ActiveLavaWave"
	
	-- Starting Position (Cima del Volcán)
	local lookAtCFrame = CFrame.lookAt(P2, P1)
	
	-- CALCULATE HEIGHT OFFSET: Ensure the base of the wave is on the floor
    -- Since we rotate 90 deg on X:
    -- Original Z becomes Height (UP)
    -- Original X stays Width (SIDE)
    -- Original Y becomes Depth (FORWARD/BACK)
    local heightPart = wave:FindFirstChild("Lava", true) or wave.PrimaryPart
    local heightOffset = 0
    if heightPart and heightPart:IsA("BasePart") then
        heightOffset = (heightPart.Size.Z / 2)
    end
	
	-- Position at P2, looking at P1, rotated 90 on X, and shifted UP relative to its own orientation
	wave:SetPrimaryPartCFrame(lookAtCFrame * CFrame.Angles(math.rad(90), 0, 0) * CFrame.new(0, heightOffset, 0))
	
	-- DOUBLE SIDED MESH LOGIC:
	-- Duplicate meshes and rotate them 180 degrees so they are visible from both sides.
	for _, part in pairs(wave:GetDescendants()) do
		if (part:IsA("MeshPart") or part:IsA("BasePart")) and part.Name:lower():find("lava") then
			local backSide = part:Clone()
			backSide.Name = "Lava_Backside"
			backSide.Parent = part.Parent
			-- Rotate the backside 180 degrees so it faces the opposite direction
			backSide.CFrame = part.CFrame * CFrame.Angles(0, math.rad(180), 0)
			
			-- Weld it to the original part so it moves together
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = part
			weld.Part1 = backSide
			weld.Parent = backSide
			
			-- Make it visual only
			backSide.CanCollide = false
			backSide.CanTouch = false
		end
	end
	
	wave.Parent = Workspace
	
	-- Damage Logic (Enhanced Lethality)
	for _, part in pairs(wave:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Touched:Connect(function(hit)
				local char = hit.Parent
				local hum = char:FindFirstChild("Humanoid")
				if hum and hum.Health > 0 then
					hum.Health = 0 -- Instant Death
					-- Secondary kill check for high speed bypasses
					task.wait(0.1)
					if hum.Parent and hum.Health > 0 then hum.Health = 0 end
				end
			end)
		end
	end
	
	-- Movement Logic (Heartbeat for smoothness)
	local speed = config.Speed
	local startTime = tick()
	local connection
	
	connection = RunService.Heartbeat:Connect(function(dt)
		if not wave or not wave.Parent then
			connection:Disconnect()
			return
		end
		
		if tick() - startTime > WAVE_LIFESPAN then
			wave:Destroy()
			connection:Disconnect()
			return
		end
		
		-- SAFETY ZONE: Destroy if it enters the player platform area
		local currentPos = wave:GetPrimaryPartCFrame().Position
		if currentPos.Z < SAFE_Z_LIMIT then
			wave:Destroy()
			connection:Disconnect()
			return
		end
		
		-- Move along the precalculated world direction vector
		local moveStep = MOVE_DIR * (speed * dt)
		wave:SetPrimaryPartCFrame(wave:GetPrimaryPartCFrame() + moveStep)
	end)
	
	Debris:AddItem(wave, WAVE_LIFESPAN)
end

LavaManager.init()

return LavaManager
