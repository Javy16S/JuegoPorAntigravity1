-- VolcanoVFX.client.lua
-- Description: Manages local atmospheric transitions and ash particles for the volcano area.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local root = character:WaitForChild("HumanoidRootPart")

-- CONFIG
local VOLCANO_Z_START = 120
local TRANSITION_DIST = 50 -- Distance to fully transition
local FADE_TIME = 2

-- Lighting Templates
local BASE_ATMOSPHERE = {
	Color = Color3.fromRGB(199, 170, 107),
	Decay = Color3.fromRGB(92, 60, 13),
	Density = 0.3,
	Glare = 0,
	Haze = 0
}

local VOLCANO_ATMOSPHERE = {
	Color = Color3.fromRGB(60, 20, 10),
	Decay = Color3.fromRGB(30, 5, 0),
	Density = 0.5,
	Glare = 0.5,
	Haze = 2
}

-- Setup Lighting Objects
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere", Lighting)
local colorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect", Lighting)

-- Ash Particles
local ashEmitter = nil

local function createAshEmitter()
	local attachment = Instance.new("Attachment", root)
	attachment.Name = "AshAttachment"
	
	local particles = Instance.new("ParticleEmitter")
	particles.Name = "AshParticles"
	particles.Texture = "rbxassetid://243098098" -- Small dot/sparkle
	particles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 200, 200)), -- Gray ash
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 100, 0)), -- Occasional ember
		ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 50, 50))
	})
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 0.5)
	})
	particles.Lifetime = NumberRange.new(2, 4)
	particles.Rate = 0 -- Controlled by script
	particles.Speed = NumberRange.new(5, 15)
	particles.VelocitySpread = 180
	particles.Acceleration = Vector3.new(0, -2, 0) -- Gentle fall
	particles.Drag = 1
	particles.LockedToPart = false
	particles.EmissionDirection = Enum.NormalId.Top
	particles.Transparency = NumberSequence.new(0.2, 1)
	particles.Parent = attachment
	
	return particles
end

-- Update Loop
local lastAlpha = -1

RunService.Heartbeat:Connect(function()
	if not root or not root.Parent then
		character = player.Character
		if character then root = character:FindFirstChild("HumanoidRootPart") end
		return
	end
	
	local z = root.Position.Z
	local alpha = math.clamp((z - VOLCANO_Z_START) / TRANSITION_DIST, 0, 1)
	
	if alpha ~= lastAlpha then
		lastAlpha = alpha
		
	-- Smooth Lighting Transition DISABLED per User Request ("Quita la niebla")
    -- Can re-enable if needed for just particles later
    
    -- Particles
        if alpha > 0.1 then
            if not ashEmitter then
                ashEmitter = createAshEmitter()
            end
            ashEmitter.Rate = 50 * alpha
        elseif ashEmitter then
            ashEmitter.Rate = 0
        end
    end
end)

player.CharacterAdded:Connect(function(newChar)
	character = newChar
	root = character:WaitForChild("HumanoidRootPart")
	if ashEmitter then
		local oldAtt = ashEmitter.Parent
		ashEmitter = createAshEmitter()
		if oldAtt then oldAtt:Destroy() end
	end
end)
