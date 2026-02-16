-- EggAnimation.client.lua
-- Skill: 3d-animation
-- Description: HYBRID GACHA ANIMATION SYSTEM
-- Single Open: "Brainrot Pop" (Fast cuts, intense focus).
-- Multi Open: "Horizontal Scroll" (Clean rail reveal).

print("[EggAnimation] Script Initializing...")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Modules
local MutationManager = require(ReplicatedStorage.Modules:WaitForChild("MutationManager"))
local CameraManager = require(ReplicatedStorage.Modules:WaitForChild("CameraManager"))

-- Wait for event
print("[EggAnimation] Waiting for EggOpenEvent...")
local EggOpenEvent = ReplicatedStorage:WaitForChild("EggOpenEvent", 10)
if not EggOpenEvent then 
    warn("[EggAnimation] Failed to find EggOpenEvent!")
    return 
end

-- Cinematic Configuration
local CONFIG = {
    -- Single Open "Pop" Settings
    Pop = {
        Cycles = 12,            -- How many "fake" items pop before reveal
        CycleSpeed = 0.25,      -- Slightly slower for smoother feel
        RevealScale = 1.8,      -- Size of winner
        CameraDistance = 18,    -- Close up
        HeightOffset = 4,
    },
    -- Multi Open "Scroll" Settings
    Scroll = {
        Spacing = 10,           -- Studs between items
        RevealDelay = 0.5,      -- Slightly slower reveal
        CameraDistance = 22,    -- Distance for the rail view
        CameraHeight = 6,
        TravelSpeed = 1,        -- Multiplier for camera pan
    },
    -- Shared
    TierColors = {
        ["Common"] = Color3.fromRGB(200, 200, 200),
        ["Rare"] = Color3.fromRGB(0, 170, 255),
        ["Epic"] = Color3.fromRGB(170, 0, 255),
        ["Legendary"] = Color3.fromRGB(255, 170, 0),
        ["Mythic"] = Color3.fromRGB(255, 0, 85),
        ["Divine"] = Color3.fromRGB(255, 255, 100),
        ["Celestial"] = Color3.fromRGB(100, 255, 255),
        ["Cosmic"] = Color3.fromRGB(200, 100, 255),
        ["Eternal"] = Color3.fromRGB(255, 255, 255),
        ["Infinite"] = Color3.fromRGB(50, 255, 150),
    }
}

local isAnimating = false

-- Helper: Create ambient light for the animation (No physical floor)
local function createStage(position)
    local stage = Instance.new("Model")
    stage.Name = "AnimationStage"
    
    -- Invisible anchor for light so we don't need a physical floor
    local anchor = Instance.new("Part")
    anchor.Name = "StageLightAnchor"
    anchor.Size = Vector3.new(1, 1, 1)
    anchor.Position = position + Vector3.new(0, 8, 0) -- Light from above
    anchor.Anchored = true
    anchor.Transparency = 1      -- INVISIBLE
    anchor.CanCollide = false
    anchor.CastShadow = false
    anchor.Parent = stage
    
    -- Spotlight (Atmosphere)
    local light = Instance.new("PointLight")
    light.Range = 40
    light.Brightness = 3
    light.Color = Color3.fromRGB(220, 200, 255)
    light.Parent = anchor
    
    return stage
end

-- Helper: Get actual model and apply visual mutations
local function getModelPreview(modelName, tier, isShiny)
    local template = ReplicatedStorage:FindFirstChild(modelName, true)
    local preview
    
    if template and template:IsA("Model") then
        preview = template:Clone()
    else
        -- Fallback
        preview = Instance.new("Model")
        local p = Instance.new("Part")
        p.Name = "PrimaryPart"; p.Size = Vector3.new(4,4,4); p.Shape = Enum.PartType.Ball
        p.Material = Enum.Material.Neon; p.Color = CONFIG.TierColors[tier] or Color3.new(1,1,1)
        p.Parent = preview; preview.PrimaryPart = p
    end
    
    preview.Name = modelName
    local primaryPart = preview.PrimaryPart or preview:FindFirstChildWhichIsA("BasePart")
    if primaryPart then 
        primaryPart.Anchored = true
        primaryPart.CanCollide = false 
        preview.PrimaryPart = primaryPart -- Ensure PrimaryPart is set
    end

    -- Apply Visuals
    MutationManager.applyMutation(preview, tier, isShiny)

    -- Floating UI
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(12, 0, 4, 0) -- Slightly larger
    bb.StudsOffset = Vector3.new(0, 7, 0)
    bb.AlwaysOnTop = true
    bb.Parent = primaryPart
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.6, 0)
    nameLabel.Position = UDim2.new(0,0,0,0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = (isShiny and "✨ " or "") .. modelName
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.Font = Enum.Font.FredokaOne
    nameLabel.TextScaled = true
    nameLabel.Parent = bb
    Instance.new("UIStroke", nameLabel).Thickness = 2.5
    
    local tierLabel = Instance.new("TextLabel")
    tierLabel.Size = UDim2.new(1, 0, 0.4, 0)
    tierLabel.Position = UDim2.new(0,0,0.6,0)
    tierLabel.BackgroundTransparency = 1
    tierLabel.Text = string.upper(tier)
    tierLabel.TextColor3 = CONFIG.TierColors[tier] or Color3.new(1,1,1)
    tierLabel.Font = Enum.Font.FredokaOne
    tierLabel.TextScaled = true
    tierLabel.Parent = bb
    Instance.new("UIStroke", tierLabel).Thickness = 2

    return preview
end

-- Helper: Create a silhouette clone (Pure Black Neon/Plastic)
local function createSilhouette(modelName)
    local template = ReplicatedStorage:FindFirstChild(modelName, true)
    if not template then return nil end
    
    local clone = template:Clone()
    
    -- Strip everything, make it a shadow
    for _, part in ipairs(clone:GetDescendants()) do
        if part:IsA("BasePart") then
            -- Make it dark but visible (Neon slightly effective even if black, depends heavily on lighting)
            -- Or just very dark grey Neon
            part.Material = Enum.Material.Neon 
            part.Color = Color3.fromRGB(10, 10, 10) -- Almost Black
            part.Transparency = 0.3 -- Ghostly
            part.CastShadow = false
            part.CanCollide = false
            part.Anchored = true
        elseif part:IsA("Texture") or part:IsA("Decal") or part:IsA("ParticleEmitter") or part:IsA("BillboardGui") or part:IsA("Sparkles") or part:IsA("Fire") or part:IsA("Smoke") then
            part:Destroy()
        end
    end
    
    -- Ensure primary part
    if not clone.PrimaryPart then
        local p = clone:FindFirstChildWhichIsA("BasePart")
        if p then clone.PrimaryPart = p end
    end
    
    return clone
end

-- ANIMATION 1: BRAINROT POP (Single Open)
local function playPopAnimation(data, origin)
    local winnerData = data.results[1]
    local possibilities = data.possibilities
    local centerPos = origin + Vector3.new(0, CONFIG.Pop.HeightOffset, 0)
    
    -- Camera setup
    local camPos = centerPos + Vector3.new(0, 3, CONFIG.Pop.CameraDistance) -- Higher angle
    CameraManager.lock("EggOpening", CFrame.new(camPos, centerPos), 0.8)
    
    -- Sequence: Smoother cuts
    for i = 1, CONFIG.Pop.Cycles do
        -- Pick random fake
        local fakeData = possibilities[math.random(1, #possibilities)]
        local fakeModel = getModelPreview(fakeData.Name, fakeData.Tier, false)
        fakeModel.Parent = workspace
        
        if fakeModel.PrimaryPart then
            fakeModel:PivotTo(CFrame.new(centerPos) * CFrame.Angles(0, math.rad(math.random(0, 360)), 0))
            
            -- Pop Effect: Scale 0 -> 1 -> 0
            local finalSize = fakeModel.PrimaryPart.Size
            fakeModel.PrimaryPart.Size = Vector3.new(0.1, 0.1, 0.1)
            
            -- Scale Up Tween (Slower in)
            local tIn = TweenService:Create(fakeModel.PrimaryPart, TweenInfo.new(CONFIG.Pop.CycleSpeed * 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = finalSize
            })
            tIn:Play()
            
            -- Wait
            task.wait(CONFIG.Pop.CycleSpeed * 0.6)
            
            -- Scale Down Tween (Disappear smoothly)
            local tOut = TweenService:Create(fakeModel.PrimaryPart, TweenInfo.new(CONFIG.Pop.CycleSpeed * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Size = Vector3.new(0.1, 0.1, 0.1)
            })
            tOut:Play()
            tOut.Completed:Wait() -- Wait for shrink before next
        end
        
        fakeModel:Destroy()
    end
    
    -- REVEAL WINNER
    local winnerModel = getModelPreview(winnerData.resultName, winnerData.resultTier, winnerData.isShiny)
    winnerModel.Parent = workspace
    
    if winnerModel.PrimaryPart then
        winnerModel:PivotTo(CFrame.new(centerPos))
        
        -- Start small
        local targetSize = winnerModel.PrimaryPart.Size
        winnerModel.PrimaryPart.Size = Vector3.new(0,0,0)
        
        -- Explosion Effect
        local explosion = Instance.new("Part")
        explosion.Position = centerPos
        explosion.Shape = Enum.PartType.Ball
        explosion.Size = Vector3.new(1,1,1)
        explosion.Color = CONFIG.TierColors[winnerData.resultTier] or Color3.new(1,1,1)
        explosion.Material = Enum.Material.Neon
        explosion.Transparency = 0.2
        explosion.Anchored = true; explosion.CanCollide = false
        explosion.Parent = workspace
        
        TweenService:Create(explosion, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(35,35,35), Transparency = 1}):Play()
        Debris:AddItem(explosion, 0.6)
        
        -- Scale Up Winner (Slower, Majestic)
        local t = TweenService:Create(winnerModel.PrimaryPart, TweenInfo.new(0.8, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
            Size = targetSize
        })
        t:Play()
        t.Completed:Wait()
        
        -- Rotate winner for a moment
        local start = tick()
        while tick() - start < 2.5 do
            winnerModel:PivotTo(CFrame.new(centerPos) * CFrame.Angles(0, (tick()-start)*2, 0))
            RunService.RenderStepped:Wait()
        end
        
        -- Shrink away nicely
        TweenService:Create(winnerModel.PrimaryPart, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Size = Vector3.new(0,0,0)
        }):Play()
        task.wait(0.4)
        
        winnerModel:Destroy()
    end
end

-- ANIMATION 2: HORIZONTAL SCROLL (Multi Open)
local function playScrollAnimation(data, origin)
    local results = data.results
    local possibilities = data.possibilities or {} -- Needed for silhouettes
    local amount = #results
    local activeModels = {}
    
    -- Calculated positions
    local totalWidth = (amount - 1) * CONFIG.Scroll.Spacing
    local startX = -(totalWidth / 2)
    
    -- Setup items (Start with Cycling Silhouettes)
    for i = 1, amount do
        local xOffset = startX + (i-1) * CONFIG.Scroll.Spacing
        local pos = origin + Vector3.new(xOffset, CONFIG.Scroll.CameraHeight, 0)
        
        -- Container for this slot
        local slotData = {
            Position = pos,
            Result = results[i],
            Revealed = false,
            CurrentSilhouette = nil
        }
        
        table.insert(activeModels, slotData)
        
        -- START SILHOUETTE LOOP for this slot (Async)
        task.spawn(function()
            local seed = i * 10 
            while not slotData.Revealed and isAnimating do
                -- 1. Clean previous
                if slotData.CurrentSilhouette then
                    slotData.CurrentSilhouette:Destroy()
                end
                
                -- 2. Pick random possibility to shadow-morph into
                if #possibilities > 0 then
                    local randIndex = math.random(1, #possibilities)
                    local randomData = possibilities[randIndex]
                    local sil = createSilhouette(randomData.Name)
                    
                    if sil and sil.PrimaryPart then
                        sil:PivotTo(CFrame.new(pos) * CFrame.Angles(0, math.rad(math.random(0,360)), 0))
                        sil.Parent = workspace
                        slotData.CurrentSilhouette = sil
                        
                        -- Slight "Breathing" animation for silhouette?
                        TweenService:Create(sil.PrimaryPart, TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
                            Size = sil.PrimaryPart.Size * 1.15
                        }):Play()
                    end
                end
                
                task.wait(0.15) -- Cycle speed (fast)
            end
            
            -- Force Cleanup when loop ends (revealed)
            if slotData.CurrentSilhouette then
                slotData.CurrentSilhouette:Destroy()
                slotData.CurrentSilhouette = nil
            end
        end)
    end
    
    -- Camera Motion: Pan along the line
    local startCamPos = activeModels[1].Position + Vector3.new(0, 2, CONFIG.Scroll.CameraDistance)
    
    CameraManager.lock("EggOpening", CFrame.new(startCamPos, activeModels[1].Position), 0.5)
    task.wait(0.5)
    
    -- Iterate and reveal sequentially
    for i, item in ipairs(activeModels) do
        -- Move camera to this item (Smooth pan)
        local targetCamPos = item.Position + Vector3.new(0, 2, CONFIG.Scroll.CameraDistance)
        local lookAt = item.Position
        
        -- Tween Camera
        local camTween = TweenService:Create(camera, TweenInfo.new(CONFIG.Scroll.RevealDelay * 1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
            CFrame = CFrame.new(targetCamPos, lookAt)
        })
        camTween:Play()
        
        -- Stop silhouette loop and reveal
        item.Revealed = true
        task.wait(0.1) -- Tiny pause for anticipation
        
        local winnerData = item.Result
        
        -- REVEAL: Winner Pops Out Smoothly
        local model = getModelPreview(winnerData.resultName, winnerData.resultTier, winnerData.isShiny)
        model.Parent = workspace
        if model.PrimaryPart then
            model:PivotTo(CFrame.new(item.Position))
            local normalSize = model.PrimaryPart.Size
            model.PrimaryPart.Size = Vector3.new(0,0,0) -- Start tiny
            
            -- Pop In
            TweenService:Create(model.PrimaryPart, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = normalSize
            }):Play()
            
            -- Flash Color Burst
            local flash = Instance.new("Part")
            flash.Position = item.Position
            flash.Anchored = true; flash.CanCollide = false
            flash.Transparency = 0.5
            flash.Size = Vector3.new(1,1,1)
            flash.Shape = Enum.PartType.Ball
            flash.Color = CONFIG.TierColors[winnerData.resultTier] or Color3.new(1,1,1)
            flash.Material = Enum.Material.Neon
            flash.Parent = workspace
            TweenService:Create(flash, TweenInfo.new(0.5), {Size = Vector3.new(12,12,12), Transparency = 1}):Play()
            Debris:AddItem(flash, 0.6)
        end
        
        item.Model = model
        
        task.wait(CONFIG.Scroll.RevealDelay)
    end
    
    -- Hold final view for a second
    task.wait(1.5)
    
    -- Scale down all for cleanup
    for _, item in ipairs(activeModels) do
        if item.Model and item.Model.PrimaryPart then 
            TweenService:Create(item.Model.PrimaryPart, TweenInfo.new(0.4), {Size = Vector3.new(0,0,0)}):Play()
            Debris:AddItem(item.Model, 0.5)
        end
    end
end

-- MAIN RUNNER
local function runEggOpeningAnimation(data)
    print("[EggAnimation] Requesting animation for", data.amount)
    if isAnimating then return end
    isAnimating = true
    
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    
    if not root then isAnimating = false; return end
    
    -- Setup clean environment relative to player
    local origin = root.Position + (root.CFrame.LookVector * 25) + Vector3.new(0, 5, 0)
    
    local stage = createStage(origin)
    stage.Parent = workspace
    
    -- Run appropriate animation
    local success, err = pcall(function()
        if data.amount == 1 then
            playPopAnimation(data, origin)
        else
            playScrollAnimation(data, origin)
        end
    end)
    
    if not success then warn("Animation Error:", err) end
    
    -- Equip last item logic
    pcall(function()
        local lastResult = data.results[#data.results]
        local toolName = "Unit_" .. lastResult.resultName
        local backpack = player:FindFirstChild("Backpack")
        local tool = backpack and backpack:FindFirstChild(toolName)
        if tool and player.Character and player.Character:FindFirstChild("Humanoid") then
            player.Character.Humanoid:EquipTool(tool)
        end
    end)

    -- Cleanup
    Debris:AddItem(stage, 1.1)
    
    CameraManager.unlock("EggOpening")
    isAnimating = false
end

-- Event Listener
EggOpenEvent.OnClientEvent:Connect(function(data)
    print("[EggAnimation] Received Event:", data)
    if data and data.success then
        runEggOpeningAnimation(data)
    else
        warn("[EggAnimation] Failed:", data)
    end
end)

print("[EggAnimation] Hybrid Pop/Scroll System Loaded (Polished v6-SILHOUETTES)")
