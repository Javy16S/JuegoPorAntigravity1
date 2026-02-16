-- MeteorLogic.lua
-- Description: Handles spawning and physics for Meteor Shower event.

local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local MeteorLogic = {}

-- CONFIG
local SPAWN_HEIGHT = 150
local MAP_WIDTH = 250
local MAP_LENGTH = 1200 
local MAP_CENTER_Z = 600 -- Adjust based on map
local DAMAGE_RADIUS = 15
local DAMAGE_AMOUNT = 30

local function createExplosion(position)
    local explosion = Instance.new("Explosion")
    explosion.Position = position
    explosion.BlastRadius = 0 -- Custom damage logic
    explosion.DestroyJointRadiusPercent = 0
    explosion.Parent = Workspace
    
    -- Sound
    local sfx = Instance.new("Sound")
    sfx.SoundId = "rbxassetid://163619849" -- Boom
    sfx.Volume = 2
    local soundPart = Instance.new("Part")
    soundPart.Transparency = 1
    soundPart.Anchored = true
    soundPart.CanCollide = false
    soundPart.Position = position
    soundPart.Parent = Workspace
    sfx.Parent = soundPart
    sfx:Play()
    Debris:AddItem(soundPart, 2)
    
    -- Damage
    local region = Region3.new(position - Vector3.new(DAMAGE_RADIUS, DAMAGE_RADIUS, DAMAGE_RADIUS), position + Vector3.new(DAMAGE_RADIUS, DAMAGE_RADIUS, DAMAGE_RADIUS))
    -- Note: Region3 is deprecated but simple. OverlapParams is better.
    
    local parts = Workspace:GetPartBoundsInBox(CFrame.new(position), Vector3.new(DAMAGE_RADIUS*2, DAMAGE_RADIUS*2, DAMAGE_RADIUS*2))
    local hitHumanoids = {}
    
    for _, part in ipairs(parts) do
        local model = part.Parent
        local hum = model and model:FindFirstChild("Humanoid")
        if hum and not hitHumanoids[hum] then
            hitHumanoids[hum] = true
            hum:TakeDamage(DAMAGE_AMOUNT)
            
            -- Knockback
             local root = model:FindFirstChild("HumanoidRootPart")
             if root then
                 local dir = (root.Position - position).Unit
                 root.ApplyImpulse(dir * 1000 + Vector3.new(0, 500, 0))
             end
        end
    end
end

function MeteorLogic.spawnMeteor()
    -- Random Position
    local x = math.random(-MAP_WIDTH/2, MAP_WIDTH/2)
    local z = math.random(100, MAP_LENGTH) -- Along the corridor
    local startPos = Vector3.new(x, SPAWN_HEIGHT, z)
    local endPos = Vector3.new(x, 0, z) -- Assuming flat-ish floor or hitting map geometry
    
    -- Raycast to find ground
    local ray = Ray.new(startPos, Vector3.new(0, -200, 0))
    local hit, hitPos = Workspace:FindPartOnRay(ray)
    if hit then endPos = hitPos end
    
    local meteor = Instance.new("Part")
    meteor.Name = "Meteor"
    meteor.Shape = Enum.PartType.Ball
    meteor.Size = Vector3.new(8, 8, 8)
    meteor.Material = Enum.Material.Slate
    meteor.Color = Color3.fromRGB(50, 20, 0)
    meteor.Position = startPos
    meteor.Anchored = true
    meteor.CanCollide = false
    meteor.Parent = Workspace
    
    -- FIRE FX
    local fire = Instance.new("Fire")
    fire.Size = 15
    fire.Heat = 20
    fire.Parent = meteor
    
    -- MOVEMENT (Tween for control)
    local duration = 1.5 -- Fast fall
    local tween = TweenService:Create(meteor, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Position = endPos})
    
    tween:Play()
    tween.Completed:Connect(function()
        createExplosion(endPos)
        meteor:Destroy()
    end)
end

function MeteorLogic.startShower(duration)
    local endTime = os.time() + duration
    
    task.spawn(function()
        while os.time() < endTime do
            MeteorLogic.spawnMeteor()
            task.wait(math.random(0.2, 0.8)) -- Rapid fire
        end
    end)
end

return MeteorLogic
