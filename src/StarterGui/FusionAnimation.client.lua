-- FusionAnimation.client.lua
-- Skill: 3d-animation
-- Description: 3D World animation for Fusion table (3 models merge into 1)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Modules
local CameraManager = require(ReplicatedStorage:WaitForChild("CameraManager"))

-- Wait for event
local FusionEvent = ReplicatedStorage:WaitForChild("FusionEvent", 10)
if not FusionEvent then
    warn("[FusionAnimation] FusionEvent not found!")
    return
end

-- Configuration
local CONFIG = {
    FloatHeight = 4,           -- How high units float
    SpinSpeed = 360,           -- Degrees per second
    ConvergeDuration = 1.5,    -- Time to merge
    ExplosionDelay = 0.3,      -- Flash before result
    ResultRevealDelay = 0.8,   -- Delay to show result
    CameraDistance = 12,       -- Camera distance from center
}

-- Tier colors
local TIER_COLORS = {
    ["Common"] = Color3.fromRGB(200, 200, 200),
    ["Rare"] = Color3.fromRGB(0, 170, 255),
    ["Epic"] = Color3.fromRGB(170, 0, 255),
    ["Legendary"] = Color3.fromRGB(255, 170, 0),
    ["Mythic"] = Color3.fromRGB(255, 0, 85),
    ["Divine"] = Color3.fromRGB(255, 255, 255)
}

-- Local state
local isAnimating = false

-- Helper: Create glowing orb for sacrificed unit
local function createSacrificeOrb(position, tier, index, total)
    local orb = Instance.new("Part")
    orb.Name = "SacrificeOrb_" .. index
    orb.Shape = Enum.PartType.Ball
    orb.Size = Vector3.new(3, 3, 3)
    orb.Material = Enum.Material.Neon
    orb.Color = TIER_COLORS[tier] or Color3.new(1, 1, 1)
    orb.Anchored = true
    orb.CanCollide = false
    orb.CastShadow = false
    orb.Position = position
    orb.Parent = workspace
    
    -- Inner glow
    local light = Instance.new("PointLight")
    light.Color = orb.Color
    light.Brightness = 3
    light.Range = 8
    light.Parent = orb
    
    -- Trail for movement
    local att0 = Instance.new("Attachment")
    att0.Position = Vector3.new(0, 0, 0)
    att0.Parent = orb
    
    local att1 = Instance.new("Attachment")
    att1.Position = Vector3.new(0, 1, 0)
    att1.Parent = orb
    
    local trail = Instance.new("Trail")
    trail.Attachment0 = att0
    trail.Attachment1 = att1
    trail.Lifetime = 0.5
    trail.Color = ColorSequence.new(orb.Color)
    trail.Transparency = NumberSequence.new(0, 1)
    trail.Parent = orb
    
    return orb
end

-- Helper: Create explosion flash
local function createExplosionFlash(position, color)
    local flash = Instance.new("Part")
    flash.Shape = Enum.PartType.Ball
    flash.Size = Vector3.new(0.5, 0.5, 0.5)
    flash.Material = Enum.Material.Neon
    flash.Color = color
    flash.Anchored = true
    flash.CanCollide = false
    flash.CastShadow = false
    flash.Position = position
    flash.Parent = workspace
    
    -- Expand
    local expandTween = TweenService:Create(flash, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(15, 15, 15),
        Transparency = 0.5
    })
    expandTween:Play()
    
    -- Then fade
    task.delay(0.3, function()
        local fadeTween = TweenService:Create(flash, TweenInfo.new(0.5), {
            Transparency = 1,
            Size = Vector3.new(20, 20, 20)
        })
        fadeTween:Play()
        fadeTween.Completed:Connect(function()
            flash:Destroy()
        end)
    end)
    
    -- Light flash
    local light = Instance.new("PointLight")
    light.Color = color
    light.Brightness = 10
    light.Range = 30
    light.Parent = flash
    
    task.spawn(function()
        task.wait(0.1)
        while light and light.Parent do
            light.Brightness = light.Brightness * 0.8
            if light.Brightness < 0.1 then break end
            task.wait(0.02)
        end
    end)
    
    Debris:AddItem(flash, 2)
end

-- Helper: Create result presentation
local function createResultPresentation(position, name, tier, isShiny)
    local presentation = Instance.new("Model")
    presentation.Name = "FusionResult"
    
    -- Main part
    local part = Instance.new("Part")
    part.Shape = Enum.PartType.Ball
    part.Size = Vector3.new(0.1, 0.1, 0.1) -- Start tiny
    part.Material = Enum.Material.Neon
    part.Color = TIER_COLORS[tier] or Color3.new(1, 1, 1)
    part.Anchored = true
    part.CanCollide = false
    part.Position = position
    part.Parent = presentation
    
    presentation.PrimaryPart = part
    presentation.Parent = workspace
    
    -- Grow animation
    local growTween = TweenService:Create(part, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = Vector3.new(5, 5, 5)
    })
    growTween:Play()
    
    -- Add label
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(8, 0, 4, 0)
    bb.StudsOffset = Vector3.new(0, 5, 0)
    bb.AlwaysOnTop = true
    bb.Parent = part
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Parent = bb
    
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Parent = frame
    
    -- Name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.LayoutOrder = 1
    nameLabel.Size = UDim2.new(1, 0, 0.4, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = name
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.Font = Enum.Font.GothamBlack
    nameLabel.TextScaled = true
    nameLabel.Parent = frame
    
    local s1 = Instance.new("UIStroke")
    s1.Thickness = 2
    s1.Color = Color3.new(0, 0, 0)
    s1.Parent = nameLabel
    
    -- Tier
    local tierLabel = Instance.new("TextLabel")
    tierLabel.LayoutOrder = 2
    tierLabel.Size = UDim2.new(1, 0, 0.3, 0)
    tierLabel.BackgroundTransparency = 1
    tierLabel.Text = string.upper(tier)
    tierLabel.TextColor3 = TIER_COLORS[tier] or Color3.new(1, 1, 1)
    tierLabel.Font = Enum.Font.GothamBold
    tierLabel.TextScaled = true
    tierLabel.Parent = frame
    
    local s2 = Instance.new("UIStroke")
    s2.Thickness = 1.5
    s2.Color = Color3.new(0, 0, 0)
    s2.Parent = tierLabel
    
    -- Shiny?
    if isShiny then
        local shinyLabel = Instance.new("TextLabel")
        shinyLabel.LayoutOrder = 3
        shinyLabel.Size = UDim2.new(1, 0, 0.25, 0)
        shinyLabel.BackgroundTransparency = 1
        shinyLabel.Text = "✨ SHINY ✨"
        shinyLabel.TextColor3 = Color3.new(1, 1, 0)
        shinyLabel.Font = Enum.Font.GothamBlack
        shinyLabel.TextScaled = true
        shinyLabel.Parent = frame
    end
    
    -- Glow
    local light = Instance.new("PointLight")
    light.Color = TIER_COLORS[tier] or Color3.new(1, 1, 1)
    light.Brightness = 5
    light.Range = 20
    light.Parent = part
    
    -- Particles
    local emitter = Instance.new("ParticleEmitter")
    emitter.Color = ColorSequence.new(TIER_COLORS[tier] or Color3.new(1, 1, 1))
    emitter.Size = NumberSequence.new(0.5, 0)
    emitter.Transparency = NumberSequence.new(0, 1)
    emitter.Lifetime = NumberRange.new(0.5, 1)
    emitter.Speed = NumberRange.new(5, 10)
    emitter.SpreadAngle = Vector2.new(360, 360)
    emitter.Rate = isShiny and 100 or 50
    emitter.Parent = part
    
    return presentation
end

-- Main fusion animation
local function playFusionAnimation(data)
    if isAnimating then return end
    isAnimating = true
    
    local character = player.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChild("Humanoid")
    
    if not character or not rootPart or not humanoid then
        isAnimating = false
        return
    end
    
    local originalWalkSpeed = humanoid.WalkSpeed
    local originalJumpPower = humanoid.JumpPower

    local function cleanup()
        CameraManager.unlock("Fusion")
        if humanoid then
            humanoid.WalkSpeed = originalWalkSpeed
            humanoid.JumpPower = originalJumpPower
        end
        isAnimating = false
    end

    -- Run with safety pcall
    local success, err = pcall(function()
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
        
        -- 2. Calculate center position (in front of player)
        local lookDir = rootPart.CFrame.LookVector
        local centerPos = rootPart.Position + lookDir * 8 + Vector3.new(0, CONFIG.FloatHeight, 0)
        
        -- 3. Create sacrifice orbs in triangle formation
        local orbs = {}
        local sacrificedUnits = data.sacrificedUnits or {}
        local unitList = {}
        for id, unit in pairs(sacrificedUnits) do
            table.insert(unitList, unit)
        end
        
        local tier = "Common"
        for i = 1, 3 do
            local angle = (i / 3) * math.pi * 2 - math.pi / 2
            local xOffset = math.cos(angle) * 5
            local zOffset = math.sin(angle) * 5
            local pos = centerPos + Vector3.new(xOffset, 0, zOffset)
            
            local unit = unitList[i]
            if unit then
                tier = unit.Tier
            end
            
            local orb = createSacrificeOrb(pos, tier, i, 3)
            table.insert(orbs, orb)
        end
        
        -- 4. Set camera
        CameraManager.lock("Fusion", CFrame.new(centerPos + Vector3.new(0, 5, CONFIG.CameraDistance), centerPos), 0.5)
        
        -- 5. Spin and float orbs
        local spinStart = tick()
        local spinConnection
        spinConnection = RunService.RenderStepped:Connect(function()
            local elapsed = tick() - spinStart
            
            -- Spinning
            for i, orb in ipairs(orbs) do
                if orb and orb.Parent then
                    local baseAngle = (i / 3) * math.pi * 2 - math.pi / 2
                    local currentAngle = baseAngle + elapsed * math.rad(CONFIG.SpinSpeed)
                    
                    -- Converge towards center over time
                    local progress = math.min(elapsed / CONFIG.ConvergeDuration, 1)
                    local radius = 5 * (1 - progress)
                    
                    local xOffset = math.cos(currentAngle) * radius
                    local zOffset = math.sin(currentAngle) * radius
                    local yOffset = math.sin(elapsed * 4) * 0.5 -- Bobbing
                    
                    orb.Position = centerPos + Vector3.new(xOffset, yOffset, zOffset)
                    
                    -- Shrink as converging
                    orb.Size = Vector3.new(3, 3, 3) * (1 - progress * 0.7)
                end
            end
            
            if elapsed >= CONFIG.ConvergeDuration then
                spinConnection:Disconnect()
            end
        end)
        
        -- 6. Wait for convergence
        task.wait(CONFIG.ConvergeDuration)
        
        -- 7. Explosion!
        for _, orb in ipairs(orbs) do
            if orb and orb.Parent then
                orb:Destroy()
            end
        end
        
        createExplosionFlash(centerPos, TIER_COLORS[data.resultTier] or Color3.new(1, 1, 1))
        
        -- Sound effect
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://138090593"
        sound.Volume = 1
        sound.Parent = workspace
        sound:Play()
        Debris:AddItem(sound, 2)
        
        -- 8. Brief darkness
        task.wait(CONFIG.ExplosionDelay)
        
        -- 9. Result appears!
        local result = createResultPresentation(centerPos, data.resultName, data.resultTier, data.isShiny)
        
        -- Camera push
        TweenService:Create(camera, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
            CFrame = CFrame.new(centerPos + Vector3.new(0, 3, 10), centerPos)
        }):Play()
        
        -- 10. Hold for appreciation
        task.wait(2.5)
        
        -- 11. Cleanup
        if result and result.Parent then
            result:Destroy()
        end
    end)

    if not success then
        warn("[FusionAnimation] CRITICAL ERROR during animation: " .. tostring(err))
    end
    
    cleanup()
end

-- Listen for fusion events
FusionEvent.OnClientEvent:Connect(function(data)
    if data and data.success then
        playFusionAnimation(data)
    end
end)

print("[FusionAnimation] Client animation system loaded")
