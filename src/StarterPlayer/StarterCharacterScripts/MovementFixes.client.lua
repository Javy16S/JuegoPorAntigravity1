-- MovementFixes.client.lua
-- Description: Disables tripping, provides Gyro stabilization, and prevents "Playmobil" flipping.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local function applyFixes(char)
	local hum = char:WaitForChild("Humanoid", 10)
	local root = char:WaitForChild("HumanoidRootPart", 10)
	
	if not hum or not root then return end

	-- 1. DISABLE TUMBLING STATES
	hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false) 
	
	-- 2. STABILIZER (The "Anti-Flip" Mechanism)
	-- Switching to BodyGyro to allow FREE Y-Axis Turning while locking X/Z.
	local gyro = root:FindFirstChild("StabilizerGyro") or Instance.new("BodyGyro")
	gyro.Name = "StabilizerGyro"
	gyro.MaxTorque = Vector3.new(math.huge, 0, math.huge) -- Lock Pitch/Roll, Free Yaw
	gyro.P = 3000 -- Power
	gyro.D = 100 -- Damping
	gyro.CFrame = CFrame.new() -- Target Upright
	gyro.Parent = root
	
	-- 3. COLLISION MONITOR
	local connection
	local lastStuckTime = 0
	
	connection = RunService.Heartbeat:Connect(function(dt)
		if not char.Parent or not root.Parent or hum.Health <= 0 then
			connection:Disconnect()
			return
		end
		
		-- A. Force Upright (BodyGyro handles this passively via MaxTorque)
		-- No need to update CFrame loop for BodyGyro if Y is free.
		
		-- B. DETECT "FLING" / STUCK STATE
		local velocity = root.AssemblyLinearVelocity
		local angular = root.AssemblyAngularVelocity
		
		if velocity.Magnitude > 100 or angular.Magnitude > 20 then
			-- Panic Mode: Soften stabilization to prevent explosion
			gyro.P = 1000 
			gyro.D = 500
			
			-- Cap Physics (Anti-Fling) (Strict)
			if velocity.Magnitude > 200 then
				root.AssemblyLinearVelocity = velocity.Unit * 200
			end
			-- Don't clamp Y angular here, allow turning, but clamp tumbling
			if angular.Magnitude > 30 then
				root.AssemblyAngularVelocity = Vector3.new(0, angular.Y, 0) -- Keep turning, kill tumble
			end
		else
			-- Normal Mode
			gyro.P = 3000
			gyro.D = 100
		end
		
		-- C. RECOVERY FROM "TIESSA" (Stiff/Ragdoll)
		-- If we are PlatformStanding or Seated/Physics but shouldn't be
		if hum.PlatformStand then
			hum.PlatformStand = false
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
		
		local state = hum:GetState()
		if state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown then
			hum:ChangeState(Enum.HumanoidStateType.Running)
		end
	end)
	
	print("[MovementFixes] Active: Smart Stabilizer + Wall Slide + Panic Recovery enabled.")
end

-- Apply to existing
local player = Players.LocalPlayer
if player.Character then
    applyFixes(player.Character)
end

-- Apply on Respawn
player.CharacterAdded:Connect(function(newChar)
	task.wait(0.2) -- Wait for physics to settle slightly
	applyFixes(newChar)
end)
