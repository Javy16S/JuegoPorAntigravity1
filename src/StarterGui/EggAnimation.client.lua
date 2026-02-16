-- EggAnimation.client.lua
-- Skill: 3d-animation
-- Description: EPIC MULTI-OPENING GACHA.
-- Phase 1: A "Tornado" of spinning models around the tower area.
-- Phase 2: Staggered reveal where each slot stops its roulette and shows the winner.
-- Phase 3: The final vertical column spins together in a panoramic wide view.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Modules
local MutationManager = require(ReplicatedStorage:WaitForChild("MutationManager"))
local CameraManager = require(ReplicatedStorage:WaitForChild("CameraManager"))

-- Wait for event
local EggOpenEvent = ReplicatedStorage:WaitForChild("EggOpenEvent", 10)
if not EggOpenEvent then return end

-- Cinematic Configuration
local CONFIG = {
    CameraDistance = 50,       -- Slightly closer for better detail
    FocusDistance = 20,        -- Closer to player
    BaseHeight = 6,           -- Lower starting height
    VerticalSpacing = 5.5,     -- Tighter vertical stack for better visibility
    RouletteDuration = 3.5,    -- More tension
    SpinSpeed = 12,            -- Faster rotation
    RevealStagger = 0.35,      -- Slightly faster reveal
}

local TIER_COLORS = {
    ["Common"] = Color3.fromRGB(200, 200, 200),
    ["Rare"] = Color3.fromRGB(0, 170, 255),
    ["Epic"] = Color3.fromRGB(170, 0, 255),
    ["Legendary"] = Color3.fromRGB(255, 170, 0),
    ["Mythic"] = Color3.fromRGB(255, 0, 85),
    ["Divine"] = Color3.fromRGB(255, 255, 100),
    ["Celestial"] = Color3.fromRGB(100, 255, 255),
    ["Cosmic"] = Color3.fromRGB(200, 100, 255),
    ["Eternal"] = Color3.fromRGB(255, 255, 255),
    ["Transcendent"] = Color3.fromRGB(255, 100, 200),
    ["Infinite"] = Color3.fromRGB(50, 255, 150),
}

local isAnimating = false

-- Helper: Get actual model and apply visual mutations
local function getModelPreview(modelName, tier, isShiny)
    -- 1. Try to find real model in ReplicatedStorage
    local template = ReplicatedStorage:FindFirstChild(modelName, true)
    local preview
    
    if template and template:IsA("Model") then
        preview = template:Clone()
    else
        -- Fallback to ball if model not localized
        preview = Instance.new("Model")
        local p = Instance.new("Part")
        p.Name = "PrimaryPart"; p.Size = Vector3.new(5,5,5); p.Shape = Enum.PartType.Ball
        p.Material = Enum.Material.Neon; p.Color = TIER_COLORS[tier] or TIER_COLORS["Common"]
        p.Parent = preview; preview.PrimaryPart = p
    end
    
    preview.Name = modelName
    local primaryPart = preview.PrimaryPart or preview:FindFirstChildWhichIsA("BasePart")
    if primaryPart then primaryPart.Anchored = true; primaryPart.CanCollide = false end

    -- 2. Apply Visual Mutations (Scaling, Particles, Colors)
    MutationManager.applyMutation(preview, tier, isShiny)

    -- 3. Billboard UI for info
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(12, 0, 4, 0)
    bb.StudsOffset = Vector3.new(0, 8, 0)
    bb.AlwaysOnTop = true
    bb.Parent = primaryPart
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.45, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = (isShiny and "✨ SHINY ✨\n" or "") .. modelName
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.Font = Enum.Font.FredokaOne
    nameLabel.TextScaled = true
    nameLabel.Parent = bb
    Instance.new("UIStroke", nameLabel).Thickness = 3

    local tierLabel = Instance.new("TextLabel")
    tierLabel.Size = UDim2.new(1, 0, 0.3, 0)
    tierLabel.Position = UDim2.new(0, 0, 0.5, 0)
    tierLabel.BackgroundTransparency = 1
    tierLabel.Text = string.upper(tier)
    tierLabel.TextColor3 = TIER_COLORS[tier] or Color3.new(1,1,1)
    tierLabel.Font = Enum.Font.FredokaOne
    tierLabel.TextScaled = true
    tierLabel.Parent = bb
    Instance.new("UIStroke", tierLabel).Thickness = 2

    return preview
end

local function runEggOpeningAnimation(data)
    if isAnimating then return end
    isAnimating = true
    
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    
    if not root or not hum then 
        isAnimating = false 
        return 
    end
    
    -- Capture original speed to restore later
    local originalSpeed = hum.WalkSpeed

    local activeAnimationModels = {}

    local function cleanup()
        CameraManager.unlock("EggOpening")
        if hum then 
            -- Restore original speed instead of resetting to hardcoded values
            hum.WalkSpeed = originalSpeed
        end
        
        -- Final safety cleanup: Destroy all tracked models that still exist
        for _, model in ipairs(activeAnimationModels) do
            if model and model.Parent then
                model:Destroy()
            end
        end
        activeAnimationModels = {}
        
        isAnimating = false
    end

    -- Run with safety pcall
    local success, err = pcall(function()
        hum.WalkSpeed = 0
        
        local amount = data.amount or #data.results
        local results = data.results
        local possibilities = data.possibilities or {}
        
        -- 1. Setup Scene positions
        local towerPos = root.Position + root.CFrame.LookVector * CONFIG.FocusDistance + Vector3.new(0, CONFIG.BaseHeight, 0)
        local camPos = towerPos - root.CFrame.LookVector * CONFIG.CameraDistance + Vector3.new(0, 15, 0)
        local totalHeight = amount * CONFIG.VerticalSpacing
        local camTarget = towerPos + Vector3.new(0, totalHeight / 2, 0)

        CameraManager.lock("EggOpening", CFrame.new(camPos, camTarget), 0.8)

        -- 2. PHASE 1: SETUP LAYERS (Círculos de ruleta)
        local layers = {}
        local modelsPerLayer = 10
        local layerRadius = 15
        
        for i = 1, amount do
            local layerDummies = {}
            local winnerData = results[i]
            
            -- Each layer has a "winner slot" at angle 0 (relative to camera direction)
            for j = 1, modelsPerLayer do
                local isWinnerSlot = (j == 1)
                local modelData = isWinnerSlot and winnerData or (possibilities[math.random(1, #possibilities)] or {Name = "???", Tier = "Common"})
                local modelName = isWinnerSlot and modelData.resultName or modelData.Name
                local modelTier = isWinnerSlot and modelData.resultTier or modelData.Tier
                local isShiny = isWinnerSlot and modelData.isShiny or false
                
                local model = getModelPreview(modelName, modelTier, isShiny)
                model.Parent = workspace
                table.insert(activeAnimationModels, model)
                
                -- Start hidden (respecting original transparency)
                for _, p in pairs(model:GetDescendants()) do 
                    if p:IsA("BasePart") then 
                        p:SetAttribute("OriginalTransparency", p.Transparency)
                        if p.Transparency < 1 then
                            p.Transparency = 1 
                        end
                    end 
                end
                
                table.insert(layerDummies, {
                    Model = model,
                    AngleOffset = (j - 1) * (math.pi * 2 / modelsPerLayer),
                    IsWinner = isWinnerSlot,
                    ResultData = winnerData
                })
            end
            
            table.insert(layers, {
                Dummies = layerDummies,
                Height = (i - 1) * CONFIG.VerticalSpacing
            })
        end

        -- Fade in all models (restoring original transparency)
        for _, layer in ipairs(layers) do
            for _, d in ipairs(layer.Dummies) do
                for _, p in pairs(d.Model:GetDescendants()) do
                    if p:IsA("BasePart") then 
                        local originalTrans = p:GetAttribute("OriginalTransparency") or 0
                        TweenService:Create(p, TweenInfo.new(0.5), {Transparency = originalTrans}):Play() 
                    end
                end
            end
        end

        -- Create Selection Marker (Vertical Beam)
        local selectionPos = towerPos + Vector3.new(layerRadius, (totalHeight-CONFIG.VerticalSpacing)/2, 0)
        local marker = Instance.new("Part")
        marker.Name = "SelectionMarker"
        marker.Size = Vector3.new(1, totalHeight + 10, 1)
        marker.Position = selectionPos
        marker.Color = Color3.fromRGB(0, 255, 255) -- Cyan Holographic
        marker.Material = Enum.Material.Neon
        marker.Transparency = 0.5
        marker.Anchored = true
        marker.CanCollide = false
        marker.Parent = workspace
        table.insert(activeAnimationModels, marker)

        -- Selection Glow (Aura)
        local light = Instance.new("PointLight")
        light.Color = marker.Color
        light.Brightness = 2
        light.Range = 20
        light.Parent = marker

        -- 3. PHASE 2: UNISON ROTATION (Roulette)
        local spinAngle = 0
        local spinSpeed = CONFIG.SpinSpeed
        local startTime = tick()
        local duration = CONFIG.RouletteDuration
        
        local rotationConn
        rotationConn = RunService.RenderStepped:Connect(function(dt)
            local elapsed = tick() - startTime
            local alpha = math.clamp(elapsed / duration, 0, 1)
            
            -- Slow down towards the end
            local currentSpeed = spinSpeed * (1 - alpha * 0.8)
            spinAngle += currentSpeed * dt
            
            -- Pulsate marker logic
            marker.Transparency = 0.5 + math.sin(tick() * 10) * 0.2
            
            for _, layer in ipairs(layers) do
                local layerPos = towerPos + Vector3.new(0, layer.Height, 0)
                for _, d in ipairs(layer.Dummies) do
                    if not d.Model.Parent then continue end
                    local totalAngle = spinAngle + d.AngleOffset
                    local x = math.cos(totalAngle) * layerRadius
                    local z = math.sin(totalAngle) * layerRadius
                    
                    -- Look at center
                    d.Model:PivotTo(CFrame.new(layerPos + Vector3.new(x, 0, z), layerPos) * CFrame.Angles(0, math.pi, 0))
                end
            end
        end)

        task.wait(duration)
        rotationConn:Disconnect()
        
        -- Fade out marker
        TweenService:Create(marker, TweenInfo.new(0.5), {Transparency = 1, Size = Vector3.new(0, totalHeight + 10, 0)}):Play()
        Debris:AddItem(marker, 0.5)

        -- 4. PHASE 3: SELECTION & REVEAL
        local winnerModels = {}
        
        for i, layer in ipairs(layers) do
            local layerPos = towerPos + Vector3.new(0, layer.Height, 0)
            local winnerDummy = nil
            
            for _, d in ipairs(layer.Dummies) do
                if d.IsWinner then
                    winnerDummy = d
                else
                    -- Fade out non-winners
                    for _, p in pairs(d.Model:GetDescendants()) do
                        if p:IsA("BasePart") then TweenService:Create(p, TweenInfo.new(0.4), {Transparency = 1}):Play() end
                    end
                    Debris:AddItem(d.Model, 0.5)
                end
            end
            
            if winnerDummy and winnerDummy.Model.PrimaryPart then
                table.insert(winnerModels, winnerDummy.Model)
                
                -- Snap winner to tower position with a "Pop"
                local targetCFrame = CFrame.new(towerPos.X, towerPos.Y + layer.Height, towerPos.Z)
                
                -- SFX & Flash per winner reveal (Staggered)
                task.wait(CONFIG.RevealStagger)
                
                local res = results[i]
                local flash = Instance.new("Part")
                flash.Shape = Enum.PartType.Ball
                flash.Size = Vector3.new(1,1,1)
                flash.Material = Enum.Material.Neon
                flash.Color = TIER_COLORS[res.resultTier] or Color3.new(1,1,1)
                flash.Transparency = 0.5
                flash.Anchored = true; flash.CanCollide = false
                flash.Position = targetCFrame.Position
                flash.Parent = workspace
                
                TweenService:Create(flash, TweenInfo.new(0.6), {Size = Vector3.new(30, 30, 30), Transparency = 1}):Play()
                Debris:AddItem(flash, 0.7)
                
                -- Move winner to center
                TweenService:Create(winnerDummy.Model.PrimaryPart, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                    CFrame = targetCFrame
                }):Play()
            end
        end

        task.wait(2) -- Let the user see the results

        -- 5. FINAL PHASE: EQUIP winners and cleanup
        for _, m in ipairs(winnerModels) do
            if m and m.Parent then
                -- Fade out ALL parts, not just PrimaryPart
                for _, p in pairs(m:GetDescendants()) do
                    if p:IsA("BasePart") then
                        TweenService:Create(p, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
                            Transparency = 1
                        }):Play()
                    end
                end
                
                -- Tween size of primary part for "shrinking" effect
                if m.PrimaryPart then
                    TweenService:Create(m.PrimaryPart, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
                        Size = Vector3.new(0,0,0)
                    }):Play()
                end
                
                Debris:AddItem(m, 0.5)
            end
        end
        
        -- Trigger equipment visual (local)
        local lastResult = results[#results]
        if lastResult and char then
            local toolName = "Unit_" .. lastResult.resultName
            local backpack = player:FindFirstChild("Backpack")
            local tool = backpack and backpack:FindFirstChild(toolName)
            if tool then
                hum:EquipTool(tool)
            end
        end

        task.wait(0.6)
    end)

    if not success then
        warn("[EggAnimation] CRITICAL ERROR during animation: " .. tostring(err))
    end
    
    cleanup()
end

EggOpenEvent.OnClientEvent:Connect(function(data)
    if data and data.success then
        runEggOpeningAnimation(data)
    end
end)

print("[EggAnimation] Roulette Gacha System Loaded")
