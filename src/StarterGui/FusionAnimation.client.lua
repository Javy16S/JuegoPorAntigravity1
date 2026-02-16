-- FusionAnimation.client.lua
-- Skill: 3d-animation
-- Description: 3D World animation for Fusion table (3 REAL MODELS merge into 1)
-- Refinements: REMOVED CAMERA LOCKING as requested. Player can look around freely.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Modules
local CameraManager = require(ReplicatedStorage.Modules:WaitForChild("CameraManager"))

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
    ConvergeDuration = 2.0,    -- Time to merge
    ExplosionDelay = 0.3,      -- Flash before result
    ResultRevealDelay = 0.8,   -- Delay to show result
}

-- Tier colors
local TIER_COLORS = {
    ["Common"] = Color3.fromRGB(200, 200, 200),
    ["Rare"] = Color3.fromRGB(0, 170, 255),
    ["Epic"] = Color3.fromRGB(170, 0, 255),
    ["Legendary"] = Color3.fromRGB(255, 170, 0),
    ["Mythic"] = Color3.fromRGB(255, 0, 85),
    ["Divine"] = Color3.fromRGB(255, 255, 100),
    ["Celestial"] = Color3.fromRGB(100, 255, 255),
    ["Cosmic"] = Color3.fromRGB(200, 100, 255),
    ["Eternal"] = Color3.fromRGB(220, 220, 255),
    ["Transcendent"] = Color3.fromRGB(255, 100, 200),
    ["Infinite"] = Color3.fromRGB(50, 255, 150),
}

-- Local state
local isAnimating = false

-- ============================================================================
-- HELPER: SAFE COLOR
-- ============================================================================
local function getTierColor(tierName)
    if not tierName then return Color3.new(1, 1, 1) end
    return TIER_COLORS[tierName] or Color3.new(1, 1, 1)
end

-- ============================================================================
-- HELPER: GET REAL MODEL
-- ============================================================================
local function getModelTemplate(name)
    local ST = game:GetService("ReplicatedStorage"):FindFirstChild("BrainrotModels")
    if not ST then return nil end
    local cleanName = string.gsub(name, "Unit_", "")
    local t = ST:FindFirstChild(cleanName, true)
    if not t then
        local spaced = cleanName:gsub("_", " ")
        t = ST:FindFirstChild(spaced, true)
    end
    return t
end

-- ============================================================================
-- HELPER: PREPARE VISUAL MODEL (Nuclear Sterilization)
-- ============================================================================
local function prepareVisualModel(visual)
    -- 1. Sterilize
    for _, v in pairs(visual:GetDescendants()) do
        if v:IsA("Humanoid") or v:IsA("AnimationController") or v:IsA("BodyMover") or v:IsA("Constraint") or v:IsA("Accessory") then
            v:Destroy()
        elseif v:IsA("Script") or v:IsA("LocalScript") or v:IsA("Sound") then
            v:Destroy()
        end
    end
    visual:BreakJoints()

    -- 2. Root & Weld
    local root = visual:IsA("Model") and (visual.PrimaryPart or visual:FindFirstChild("HumanoidRootPart") or visual:FindFirstChildWhichIsA("BasePart", true)) or visual
    if not root and visual:IsA("Model") then
        root = Instance.new("Part")
        root.Name = "MasterRoot"
        root.Size = Vector3.new(1,1,1); root.Transparency=1; root.Anchored=true; root.CanCollide=false
        root.Parent = visual
    end
    
    if visual:IsA("Model") then visual.PrimaryPart = root end

    -- Rigidify to Root
    for _, part in pairs(visual:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = true -- For animation, Anchored is safer and smoother
            part.CanCollide = false
            part.Massless = true
        end
    end
    
    return visual
end

-- ============================================================================
-- ANIMATION HELPERS
-- ============================================================================

local function createSacrificeModel(position, unitName, tier, index)
    local template = getModelTemplate(unitName)
    local model
    
    if template then
        model = template:Clone()
        model = prepareVisualModel(model)
    else
        model = Instance.new("Part")
        model.Shape = Enum.PartType.Ball
        model.Size = Vector3.new(3,3,3)
        model.Material = Enum.Material.Neon
        model.Anchored = true; model.CanCollide = false
    end
    
    model.Name = "Sacrifice_" .. index
    
    local highlight = Instance.new("Highlight")
    highlight.FillColor = getTierColor(tier)
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = Color3.new(1, 1, 1)
    highlight.OutlineTransparency = 0
    highlight.Parent = model
    
    if model:IsA("Model") then
        model:PivotTo(CFrame.new(position))
    else
        model.Position = position
        model.Color = getTierColor(tier)
    end
    
    model.Parent = workspace
    return model
end

local function createExplosionFlash(position, color)
    local flash = Instance.new("Part")
    flash.Shape = Enum.PartType.Ball
    flash.Size = Vector3.new(0.5, 0.5, 0.5)
    flash.Material = Enum.Material.Neon
    flash.Color = color or Color3.new(1,1,1)
    flash.Anchored = true; flash.CanCollide = false; flash.CastShadow = false
    flash.Position = position
    flash.Parent = workspace
    
    TweenService:Create(flash, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(25, 25, 25), Transparency = 0.5
    }):Play()
    
    task.delay(0.3, function()
        local t = TweenService:Create(flash, TweenInfo.new(0.5), {Transparency = 1, Size = Vector3.new(30, 30, 30)})
        t:Play()
        t.Completed:Connect(function() flash:Destroy() end)
    end)
    
    Debris:AddItem(flash, 2)
end

local function createResultPresentation(position, name, tier, isShiny)
    local template = getModelTemplate(name)
    local presentation
    
    if template then
        presentation = template:Clone()
        presentation = prepareVisualModel(presentation)
    else
        presentation = Instance.new("Part")
        presentation.Shape = Enum.PartType.Ball
        presentation.Color = getTierColor(tier)
        presentation.Anchored = true; presentation.CanCollide = false
    end
    
    presentation.Name = "FusionResult"
    
    local finalScale = 1.0
    if presentation:IsA("Model") then
        presentation:PivotTo(CFrame.new(position) * CFrame.new(0,-5,0)) 
    else
        presentation.Size = Vector3.new(0.1,0.1,0.1)
        presentation.Position = position
        TweenService:Create(presentation, TweenInfo.new(0.5, Enum.EasingStyle.Back), {Size = Vector3.new(5,5,5)}):Play()
    end
    
    presentation.Parent = workspace

    if presentation:IsA("Model") then
        local startCF = CFrame.new(position) * CFrame.Angles(0, math.rad(180), 0)
        presentation:PivotTo(startCF)
    end
    
    local h = Instance.new("Highlight")
    h.FillTransparency = 1
    h.OutlineColor = getTierColor(tier)
    h.Parent = presentation
    
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(8, 0, 4, 0)
    bb.StudsOffset = Vector3.new(0, 7, 0)
    bb.AlwaysOnTop = true
    bb.Parent = presentation
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1,0,1,0); frame.BackgroundTransparency = 1; frame.Parent = bb
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.HorizontalAlignment = Enum.HorizontalAlignment.Center; layout.Parent = frame
    
    local txt = Instance.new("TextLabel")
    txt.Text = name:gsub("Unit_",""):gsub("_", " ")
    txt.TextColor3 = Color3.new(1, 1, 1)
    txt.Font = Enum.Font.GothamBlack
    txt.TextScaled = true
    txt.Size = UDim2.new(1,0,0.5,0)
    txt.BackgroundTransparency = 1
    txt.LayoutOrder = 1
    txt.Parent = frame
    Instance.new("UIStroke", txt).Thickness = 2
    
    local tierTxt = Instance.new("TextLabel")
    tierTxt.Text = tier .. (isShiny and " ✨" or "")
    tierTxt.TextColor3 = getTierColor(tier)
    tierTxt.Font = Enum.Font.GothamBold
    tierTxt.TextScaled = true
    tierTxt.Size = UDim2.new(1,0,0.4,0)
    tierTxt.BackgroundTransparency = 1
    tierTxt.LayoutOrder = 2
    tierTxt.Parent = frame
    Instance.new("UIStroke", tierTxt).Thickness = 1.5
    
    return presentation
end

-- ============================================================================
-- MAIN ANIMATION
-- ============================================================================
local function playFusionAnimation(data)
    if isAnimating then return end
    isAnimating = true
    
    local character = player.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    
    if not character or not rootPart then
        isAnimating = false
        return
    end

    local function cleanup()
        -- CameraManager.unlock("Fusion") -- REMOVED: No camera lock
        isAnimating = false
    end

    local success, err = pcall(function()
        -- 1. Setup Center relative to player
        local lookDir = rootPart.CFrame.LookVector
        local centerPos = rootPart.Position + lookDir * 10 + Vector3.new(0, CONFIG.FloatHeight, 0)
        
        -- 2. Create Models (Sacrifice)
        local visuals = {}
        local sacrificedUnits = data.sacrificedUnits or {}
        local unitList = {}
        for _, u in pairs(sacrificedUnits) do table.insert(unitList, u) end
        
        for i = 1, 3 do
            local angle = (i / 3) * math.pi * 2 - math.pi / 2
            local xOffset = math.cos(angle) * 8
            local zOffset = math.sin(angle) * 8
            local pos = centerPos + Vector3.new(xOffset, 0, zOffset)
            
            local unit = unitList[i]
            local name = unit and unit.Name or "Unknown"
            local tier = unit and unit.Tier or "Common"
            
            local visual = createSacrificeModel(pos, name, tier, i)
            
            if visual:IsA("Model") then
                local cf = CFrame.lookAt(pos, centerPos)
                visual:PivotTo(cf)
            end
            
            table.insert(visuals, visual)
        end
        
        -- REMOVED: Camera locking
        -- CameraManager.lock(...)
        
        -- 3. Animate Loop
        local spinStart = tick()
        local spinConnection
        spinConnection = RunService.RenderStepped:Connect(function()
            local elapsed = tick() - spinStart
            
            for i, visual in ipairs(visuals) do
                if visual and visual.Parent then
                    local baseAngle = (i / 3) * math.pi * 2 - math.pi / 2
                    local currentAngle = baseAngle + elapsed * math.rad(CONFIG.SpinSpeed)
                    
                    local progress = math.min(elapsed / CONFIG.ConvergeDuration, 1)
                    local radius = 8 * (1 - progress)
                    
                    local x = math.cos(currentAngle) * radius
                    local z = math.sin(currentAngle) * radius
                    local y = math.sin(elapsed * 5) * 1.5
                    
                    local targetPos = centerPos + Vector3.new(x, y, z)
                    local lookAt = centerPos
                    
                    if visual:IsA("Model") then
                        visual:PivotTo(CFrame.lookAt(targetPos, lookAt) * CFrame.Angles(0, math.rad(elapsed * 360), 0))
                    else
                        visual.Position = targetPos
                    end
                end
            end
            
            if elapsed >= CONFIG.ConvergeDuration then
                spinConnection:Disconnect()
            end
        end)
        
        task.wait(CONFIG.ConvergeDuration)
        
        -- 4. Explosion
        for _, v in ipairs(visuals) do v:Destroy() end
        createExplosionFlash(centerPos, getTierColor(data.resultTier))
        
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://138090593"
        sound.Volume = 1
        sound.Parent = workspace
        sound:Play()
        Debris:AddItem(sound, 2)
        
        task.wait(CONFIG.ExplosionDelay)
        
        -- 5. Result
        local res = createResultPresentation(centerPos, data.resultName, data.resultTier, data.isShiny)
        
        -- REMOVED: Camera Tween push-in
        -- TweenService:Create(camera, ...):Play()
        
        task.wait(3)
        if res then res:Destroy() end
    end)
    
    if not success then warn("Animation Logic Error: " .. tostring(err)) end
    cleanup()
end

DataHandler = nil 

FusionEvent.OnClientEvent:Connect(function(data)
    if data and data.success then
        playFusionAnimation(data)
    end
end)

print("[FusionAnimation] Loaded - Camera Free Look")
