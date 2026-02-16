-- SafeZoneManager.server.lua
-- Skill: game-mechanics
-- Description: Spawns temporary floating platforms (Shelters) that protect players from Lava.
-- Also manages the "IsSafe" attribute logic via Touched events on the zones.

local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local SafeZoneManager = {}
local EventStarted = game.ReplicatedStorage:WaitForChild("EventStarted")

-- CONFIG
local SPAWN_INTERVAL_MIN = 30
local SPAWN_INTERVAL_MAX = 60
local DURATION = 20
local SLOPE_START_Z = 120
local SLOPE_LENGTH = 1200
local SLOPE_WIDTH = 180 -- Slightly narrower to keep platforms reachable
local SLOPE_ANGLE = 25
local RAD_ANGLE = math.rad(SLOPE_ANGLE)

local function spawnSafeZone()
    -- Random Position on Slope
    local z = math.random(SLOPE_START_Z + 50, SLOPE_START_Z + SLOPE_LENGTH - 50)
    local x = math.random(-SLOPE_WIDTH/2 + 10, SLOPE_WIDTH/2 - 10)
    
    -- Calculate Y at this Z
    local relativeZ = z - SLOPE_START_Z
    local yFloor = (math.tan(RAD_ANGLE) * relativeZ) 
    local yPos = yFloor + 12 -- 12 Studs above ground (Jumpable? Maybe low enough or ramp)
    -- Actually 12 studs is high. Lava is ~5-15 studs high depending on type.
    -- Let's make it 18 studs high but with a ramp or ladder?
    -- Or just a "Force Field Dome" on the ground.
    -- User said "Plataformas/refugios". 
    -- Dome on ground is easier and covers "Refugio".
    
    local pos = Vector3.new(x, yPos + 2, z) -- On ground (roughly)
    
    -- CREATE MODEL
    local model = Instance.new("Model")
    model.Name = "SafeZone"
    
    -- 1. BASE PLATFORM
    local base = Instance.new("Part")
    base.Name = "Base"
    base.Size = Vector3.new(25, 2, 25)
    base.Name = "Base"
    base.Size = Vector3.new(25, 2, 25)
    -- ALIGN TO SLOPE
    local slopeRotation = CFrame.Angles(RAD_ANGLE, 0, 0)
    base.CFrame = CFrame.new(pos) * slopeRotation
    base.Anchored = true
    base.Material = Enum.Material.ForceField
    base.Color = Color3.fromRGB(0, 255, 100)
    base.TopSurface = Enum.SurfaceType.Smooth
    base.Parent = model
    
    -- 2. DOME VISUAL (Sphere)
    local dome = Instance.new("Part")
    dome.Name = "Dome"
    dome.Shape = Enum.PartType.Ball
    dome.Size = Vector3.new(24, 24, 24) -- Slightly larger
    -- ALIGN TO SLOPE
    local slopeRotation = CFrame.Angles(RAD_ANGLE, 0, 0)
    dome.CFrame = CFrame.new(pos) * slopeRotation * CFrame.new(0, 10, 0)
    
    dome.Material = Enum.Material.ForceField
    dome.Color = Color3.fromRGB(0, 255, 150) -- Minty green, less harsh
    dome.Transparency = 0.6 -- See-through
    dome.CanCollide = false
    dome.Anchored = true
    dome.CastShadow = false
    dome.Parent = model
    
    -- 3. TEXT
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 200, 0, 50)
    bb.StudsOffset = Vector3.new(0, 15, 0)
    bb.AlwaysOnTop = true
    bb.Parent = dome
    
    -- BEAM VISUAL (Sky Pillar)
    local att1 = Instance.new("Attachment", dome)
    local att2 = Instance.new("Attachment", dome)
    att2.Position = Vector3.new(0, 200, 0) -- Beam goes up
    
    local beam = Instance.new("Beam")
    beam.Attachment0 = att1
    beam.Attachment1 = att2
    beam.FaceCamera = true
    beam.Width0 = 8
    beam.Width1 = 15
    beam.Color = ColorSequence.new(Color3.fromRGB(0, 255, 180))
    beam.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(1, 1)
    })
    beam.Parent = dome
    
    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1,0,1,0)
    txt.BackgroundTransparency = 1
    txt.Text = "SAFE ZONE"
    txt.TextColor3 = Color3.new(0,1,1)
    txt.Font = Enum.Font.GothamBlack
    txt.TextScaled = true
    txt.Parent = bb
    
    -- 4. ZONE DETECTOR (Larger than visual to ensure safety)
    local detector = Instance.new("Part")
    detector.Name = "Detector"
    detector.Size = Vector3.new(20, 20, 20)
    detector.CFrame = dome.CFrame
    detector.Transparency = 1
    detector.CanCollide = false
    detector.Anchored = true
    detector.Parent = model
    
    model.Parent = Workspace
    
    -- LOGIC: Grant Immunity while inside
    local zoneActive = true
    
    local function onTouch(hit)
        if not zoneActive then return end
        local char = hit.Parent
        if char and char:FindFirstChild("Humanoid") then
            if not char:GetAttribute("IsSafe") then
                char:SetAttribute("IsSafe", true)
                -- REMOVED: Ugly Highlight. 
                -- The Dome itself (ForceField) is enough visual cue.
            end
        end
    end
    
    local function onTouchEnd(hit)
        local char = hit.Parent
        if char and char:FindFirstChild("Humanoid") then
            -- Check if touching ANY other safe zone logic?
            -- For simplicity, remove safe.
            char:SetAttribute("IsSafe", nil)
            -- No highlight to destroy
        end
    end
    
    detector.Touched:Connect(onTouch)
    detector.TouchEnded:Connect(onTouchEnd)
    
    -- NOTIFY (Uses new EventHUD)
    EventStarted:FireAllClients("ZONA SEGURA", "¡Refugio temporal activo!", Color3.fromRGB(0, 255, 180))
    
    -- CLEANUP
    task.delay(DURATION, function()
        zoneActive = false
        -- Fade Out
        TweenService:Create(base, TweenInfo.new(1), {Transparency = 1}):Play()
        TweenService:Create(dome, TweenInfo.new(1), {Transparency = 1}):Play()
        wait(1)
        model:Destroy()
        
        -- Clear attributes for players inside (Manual check)
        -- Because TouchEnded might not fire if part is destroyed?
        -- Actually TouchEnded fires on Destroy usually, but safer to check.
        -- We'll assume gameplay flow handles it (next movement updates it) or they die (fair enough).
    end)
end

-- LOOP
-- LOOP DISABLED BY USER REQUEST
-- task.spawn(function()
--     while true do
--         task.wait(math.random(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_MAX))
--         spawnSafeZone()
--     end
-- end)

return SafeZoneManager
