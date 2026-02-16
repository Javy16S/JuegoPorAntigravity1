-- FusionUI.client.lua
-- Skill: ui-framework
-- Description: Interactive Fusion UI with 3D model previews (Debug Mode)
-- Refactored for Responsiveness: PURE SCALE (No Offsets) & FIXED LAYOUT

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remotes
local GetInventory = ReplicatedStorage:WaitForChild("GetInventory", 10)
local FuseUnits = ReplicatedStorage:WaitForChild("FuseUnits", 10)
local FusionPreview = ReplicatedStorage:WaitForChild("FusionPreview", 10)
local UIManager = require(ReplicatedStorage.Modules:WaitForChild("UIManager"))

if not GetInventory then warn("[FusionUI] CRITICAL: GetInventory RemoteFunction missing!") end

-- Config
local TIER_COLORS = {
    ["Common"] = Color3.fromRGB(200, 200, 200),
    ["Rare"] = Color3.fromRGB(0, 170, 255),
    ["Epic"] = Color3.fromRGB(170, 0, 255),
    ["Legendary"] = Color3.fromRGB(255, 170, 0),
    ["Mythic"] = Color3.fromRGB(255, 0, 85),
    ["Divine"] = Color3.fromRGB(255, 255, 255)
}

-- State
local selectedSlots = {nil, nil, nil}
local inventoryData = {}
local slotFrames = {}

-- Forward declarations
local refreshInventory
local updateSlotVisual
local updateFuseButton

-- Prevent duplicates
if playerGui:FindFirstChild("FusionMainGUI") then
    playerGui.FusionMainGUI:Destroy()
end

-- Create UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FusionMainGUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Background overlay
local overlay = Instance.new("TextButton")
overlay.Name = "Overlay"
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 1
overlay.Text = ""
overlay.Visible = false
overlay.ZIndex = 1
overlay.Parent = screenGui

-- MAIN CONTAINER
local mainFrame = Instance.new("Frame")
mainFrame.Name = "FusionFrame"
mainFrame.Size = UDim2.new(0.6, 0, 0.7, 0) -- Scaled size
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false -- START HIDDEN
mainFrame.ZIndex = 2
mainFrame.Parent = screenGui

local mainAspect = Instance.new("UIAspectRatioConstraint")
mainAspect.AspectRatio = 1.3 -- Boxy logic
mainAspect.AspectType = Enum.AspectType.FitWithinMaxSize
mainAspect.DominantAxis = Enum.DominantAxis.Width -- Ensure it fits width first
mainAspect.Parent = mainFrame

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MaxSize = Vector2.new(1000, 800)
sizeConstraint.Parent = mainFrame

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0.05, 0) -- Relative corner
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Thickness = 3
mainStroke.Color = Color3.fromRGB(255, 100, 50)
mainStroke.Parent = mainFrame

-- Toggle Logic
local function toggleUI(state)
    if state == nil then state = not mainFrame.Visible end
    
    if state then
        mainFrame.Size = UDim2.new(0, 0, 0, 0)
        mainFrame.Visible = true
        overlay.Visible = true
        TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back), {Size = UDim2.new(0.75, 0, 0.75, 0)}):Play()
        TweenService:Create(overlay, TweenInfo.new(0.4), {BackgroundTransparency = 0.5}):Play()
        
        refreshInventory()
        -- Clear selection
        selectedSlots = {nil, nil, nil}
        for i = 1, 3 do
            updateSlotVisual(i)
        end
        updateFuseButton()
        
        -- Auto Refresh Loop while visible
        task.spawn(function()
            while mainFrame.Visible do
                task.wait(3)
                if mainFrame.Visible then
                    refreshInventory()
                end
            end
        end)
    else
        local t = TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quart), {Size = UDim2.new(0, 0, 0, 0)})
        t:Play()
        TweenService:Create(overlay, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
        t.Completed:Connect(function()
            if UIManager.CurrentOpenUI ~= "FusionUI" then
                mainFrame.Visible = false
                overlay.Visible = false
            end
        end)
    end
end

-- Click overlay to close
overlay.MouseButton1Click:Connect(function()
    UIManager.Close("FusionUI")
end)

-- REGISTER WITH UIManager
task.defer(function()
    UIManager.Register("FusionUI", mainFrame, toggleUI)
end)

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0.1, 0)
title.BackgroundTransparency = 1
title.Text = "🔥 MESA DE FUSIÓN 🔥"
title.TextColor3 = Color3.fromRGB(255, 200, 100)
title.Font = Enum.Font.GothamBlack
title.TextScaled = true -- Responsive
title.ZIndex = 2
title.Parent = mainFrame

-- Subtitle
local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, 0, 0.05, 0)
subtitle.Position = UDim2.new(0, 0, 0.09, 0)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Combina 3 unidades del MISMO TIER"
subtitle.TextColor3 = Color3.fromRGB(150, 150, 150)
subtitle.Font = Enum.Font.Gotham
subtitle.TextScaled = true
subtitle.ZIndex = 2
subtitle.Parent = mainFrame

-- Close Button
-- Close Button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0.08, 0, 0.08, 0)
closeBtn.Position = UDim2.new(0.9, 0, 0.02, 0)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextScaled = true
closeBtn.ZIndex = 3
closeBtn.Parent = mainFrame

closeBtn.MouseButton1Click:Connect(function()
    UIManager.Close("FusionUI")
end)
    
local closeAspect = Instance.new("UIAspectRatioConstraint")
closeAspect.AspectRatio = 1
closeAspect.Parent = closeBtn

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0.2, 0)
closeCorner.Parent = closeBtn

-- Fusion Slots Container
-- Increased width to 95% to give more room, centered
local slotsContainer = Instance.new("Frame")
slotsContainer.Size = UDim2.new(0.95, 0, 0.35, 0) 
slotsContainer.Position = UDim2.new(0.025, 0, 0.15, 0) -- Below title
slotsContainer.BackgroundTransparency = 1
slotsContainer.ZIndex = 2
slotsContainer.Parent = mainFrame

-- Use Layout that fits perfectly
-- 3 Slots + 2 Pluses = 5 items.
-- Gaps: 4 gaps.
-- Formula: 
-- Padding = 0.02 (2%) * 4 = 8% total
-- Plus = 0.05 (5%) * 2 = 10% total
-- Remaining for slots = 100% - 18% = 82%
-- Slot Width = 82% / 3 = 27.3%
-- We use 25% for slots to be safe and use extra space for margins.

local slotsLayout = Instance.new("UIListLayout")
slotsLayout.FillDirection = Enum.FillDirection.Horizontal
slotsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
slotsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
slotsLayout.Padding = UDim.new(0.02, 0) 
slotsLayout.Parent = slotsContainer

-- Helper: Get Model Template
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

-- Helper: Create ViewportFrame for 3D model preview
local function createViewportModel(parent, modelName, tierName, isShiny, mutationName)
    local viewport = parent:FindFirstChild("Viewport")
    if viewport then viewport:Destroy() end
    
    viewport = Instance.new("ViewportFrame")
    viewport.Name = "Viewport"
    viewport.Size = UDim2.new(1, 0, 1, 0)
    viewport.BackgroundTransparency = 1
    viewport.ZIndex = 3
    viewport.Parent = parent
    
    -- Use robust lookup
    local model = getModelTemplate(modelName)
    
    if model then
        local clone = model:Clone()
        for _, v in pairs(clone:GetDescendants()) do
            if v:IsA("Script") or v:IsA("LocalScript") then v:Destroy() end
        end
        
        pcall(function()
             local MutationManager = require(ReplicatedStorage.Modules.MutationManager)
             MutationManager.applyTierEffects(clone, tierName or "Common", isShiny or false, true)
             if mutationName then MutationManager.applyMutation(clone, mutationName) end
        end)
        
        clone.Parent = viewport
        
        local cf, size = clone:GetBoundingBox()
        local maxDim = math.max(size.X, size.Y, size.Z)
        if maxDim < 0.1 then maxDim = 4 end
        
        local distance = maxDim * 0.8
        local modelCenter = cf.Position
        
        local camera = Instance.new("Camera")
        local camPos = modelCenter + Vector3.new(-distance, distance * 0.5, distance)
        camera.CFrame = CFrame.lookAt(camPos, modelCenter)
        
        camera.Parent = viewport
        viewport.CurrentCamera = camera
        viewport.Ambient = Color3.fromRGB(200, 200, 200)
        viewport.LightColor = Color3.fromRGB(255, 255, 255)
        viewport.LightDirection = Vector3.new(-1, -1, -1)
    else
        local placeholder = Instance.new("TextLabel")
        placeholder.Size = UDim2.new(1, 0, 1, 0)
        placeholder.BackgroundTransparency = 1
        placeholder.Text = "🔮"
        placeholder.TextScaled = true
        placeholder.Parent = viewport
    end
    return viewport
end


-- Create fusion slot
local function createFusionSlot(index)
    local slot = Instance.new("Frame")
    slot.Name = "Slot_" .. index
    -- Size: 25% width ensures 3 fit easily with padding
    slot.Size = UDim2.new(0.25, 0, 1, 0) 
    slot.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    slot.LayoutOrder = index * 2 - 1
    slot.ZIndex = 2
    slot.Parent = slotsContainer
    
    -- Aspect Ratio Constraint INSIDE the slot to keep it rectangular vertical
    local slotAspect = Instance.new("UIAspectRatioConstraint")
    slotAspect.AspectRatio = 0.8 
    slotAspect.AspectType = Enum.AspectType.FitWithinMaxSize
    slotAspect.Parent = slot
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.1, 0)
    corner.Parent = slot
    
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 3
    stroke.Color = Color3.fromRGB(100, 100, 100)
    stroke.Name = "SlotStroke"
    stroke.Parent = slot
    
    -- Model preview area
    local previewFrame = Instance.new("Frame")
    previewFrame.Name = "PreviewFrame"
    previewFrame.Size = UDim2.new(0.9, 0, 0.6, 0)
    previewFrame.Position = UDim2.new(0.05, 0, 0.05, 0)
    previewFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    previewFrame.ZIndex = 2
    previewFrame.Parent = slot
    
    local previewCorner = Instance.new("UICorner")
    previewCorner.CornerRadius = UDim.new(0.2, 0)
    previewCorner.Parent = previewFrame
    
    -- Empty placeholder
    local emptyLabel = Instance.new("TextLabel")
    emptyLabel.Name = "EmptyLabel"
    emptyLabel.Size = UDim2.new(1, 0, 1, 0)
    emptyLabel.BackgroundTransparency = 1
    emptyLabel.Text = "?"
    emptyLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
    emptyLabel.Font = Enum.Font.GothamBlack
    emptyLabel.TextScaled = true
    emptyLabel.ZIndex = 3
    emptyLabel.Parent = previewFrame
    
    -- Name label
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(0.95, 0, 0.15, 0)
    nameLabel.Position = UDim2.new(0.025, 0, 0.68, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = "Vacío"
    nameLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextScaled = true
    nameLabel.ZIndex = 2
    nameLabel.Parent = slot
    
    -- Tier label
    local tierLabel = Instance.new("TextLabel")
    tierLabel.Name = "TierLabel"
    tierLabel.Size = UDim2.new(0.95, 0, 0.12, 0)
    tierLabel.Position = UDim2.new(0.025, 0, 0.85, 0)
    tierLabel.BackgroundTransparency = 1
    tierLabel.Text = ""
    tierLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
    tierLabel.Font = Enum.Font.Gotham
    tierLabel.TextScaled = true
    tierLabel.ZIndex = 2
    tierLabel.Parent = slot
    
    -- Click to remove
    local removeBtn = Instance.new("TextButton")
    removeBtn.Size = UDim2.new(1, 0, 1, 0)
    removeBtn.BackgroundTransparency = 1
    removeBtn.Text = ""
    removeBtn.ZIndex = 5
    removeBtn.Parent = slot
    
    removeBtn.MouseButton1Click:Connect(function()
        if selectedSlots[index] then
            selectedSlots[index] = nil
            updateSlotVisual(index)
            updateFuseButton()
        end
    end)
    
    slotFrames[index] = slot
    return slot
end

-- Plus sign between slots
local function createPlusSign(order)
    local plus = Instance.new("TextLabel")
    -- Size: 5% Width
    plus.Size = UDim2.new(0.05, 0, 0.5, 0)
    plus.BackgroundTransparency = 1
    plus.Text = "+"
    plus.TextColor3 = Color3.fromRGB(255, 200, 100)
    plus.Font = Enum.Font.GothamBlack
    plus.TextScaled = true
    plus.LayoutOrder = order
    plus.ZIndex = 2
    plus.Parent = slotsContainer
    return plus
end

createFusionSlot(1)
createPlusSign(2)
createFusionSlot(2)
createPlusSign(4)
createFusionSlot(3)

-- Update slot visual
function updateSlotVisual(index)
    local slot = slotFrames[index]
    if not slot then return end
    
    local unit = selectedSlots[index]
    local previewFrame = slot:FindFirstChild("PreviewFrame")
    local emptyLabel = previewFrame and previewFrame:FindFirstChild("EmptyLabel")
    local nameLabel = slot:FindFirstChild("NameLabel")
    local tierLabel = slot:FindFirstChild("TierLabel")
    local stroke = slot:FindFirstChild("SlotStroke")
    
    if previewFrame then
        local existingViewport = previewFrame:FindFirstChild("Viewport")
        if existingViewport then existingViewport:Destroy() end
    end
    
    if unit then
        if emptyLabel then emptyLabel.Visible = false end
        
        -- Create 3D preview
        createViewportModel(previewFrame, unit.Name, unit.Tier, unit.Shiny, unit.Mutation)
        
        if nameLabel then 
            nameLabel.Text = unit.Name:gsub("Unit_", ""):gsub("_", " ")
            nameLabel.TextColor3 = Color3.new(1, 1, 1)
        end
        if tierLabel then 
            tierLabel.Text = unit.Tier .. (unit.Shiny and " ✨" or "")
            tierLabel.TextColor3 = TIER_COLORS[unit.Tier] or Color3.new(1, 1, 1)
        end
        if stroke then
            stroke.Color = TIER_COLORS[unit.Tier] or Color3.fromRGB(100, 100, 100)
        end
    else
        if emptyLabel then 
            emptyLabel.Visible = true 
            emptyLabel.Text = "?"
        end
        if nameLabel then 
            nameLabel.Text = "Vacío"
            nameLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        end
        if tierLabel then tierLabel.Text = "" end
        if stroke then stroke.Color = Color3.fromRGB(100, 100, 100) end
    end
end

-- Fuse Button
local fuseBtn = Instance.new("TextButton")
fuseBtn.Size = UDim2.new(0.4, 0, 0.12, 0)
fuseBtn.Position = UDim2.new(0.5, 0, 0.55, 0) -- Moved down slightly
fuseBtn.AnchorPoint = Vector2.new(0.5, 0)
fuseBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
fuseBtn.Text = "Selecciona 3 unidades"
fuseBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
fuseBtn.Font = Enum.Font.GothamBlack
fuseBtn.TextScaled = true
fuseBtn.ZIndex = 2
fuseBtn.Parent = mainFrame

local fuseCorner = Instance.new("UICorner")
fuseCorner.CornerRadius = UDim.new(0.2, 0)
fuseCorner.Parent = fuseBtn

local fuseStroke = Instance.new("UIStroke")
fuseStroke.Thickness = 2
fuseStroke.Color = Color3.fromRGB(50, 50, 50)
fuseStroke.Parent = fuseBtn

function updateFuseButton()
    local count = 0
    local commonTier = nil
    local valid = true
    
    for _, unit in pairs(selectedSlots) do
        if unit then
            count += 1
            if commonTier == nil then
                commonTier = unit.Tier
            elseif commonTier ~= unit.Tier then
                valid = false
            end
        end
    end
    
    if count == 3 and valid then
        fuseBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 50)
        fuseBtn.Text = "🔥 ¡FUSIONAR! 🔥"
        fuseBtn.TextColor3 = Color3.new(1, 1, 1)
        fuseStroke.Color = Color3.fromRGB(200, 50, 0)
    elseif count == 3 and not valid then
        fuseBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        fuseBtn.Text = "⚠️ Deben ser del mismo Tier"
        fuseBtn.TextColor3 = Color3.new(1, 1, 1)
        fuseStroke.Color = Color3.fromRGB(100, 30, 30)
    else
        fuseBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        fuseBtn.Text = "Selecciona " .. (3 - count) .. " más"
        fuseBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
        fuseStroke.Color = Color3.fromRGB(50, 50, 50)
    end
end

fuseBtn.MouseButton1Click:Connect(function()
    local count = 0
    local commonTier = nil
    local valid = true
    local unitIds = {}
    
    for _, unit in pairs(selectedSlots) do
        if unit then
            count += 1
            table.insert(unitIds, unit.Id)
            if commonTier == nil then
                commonTier = unit.Tier
            elseif commonTier ~= unit.Tier then
                valid = false
            end
        end
    end
    
    if count == 3 and valid then
        fuseBtn.Text = "Fusionando..."
        fuseBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        
        local result = FuseUnits:InvokeServer(unitIds)
        
        if result and result.success then
            selectedSlots = {nil, nil, nil}
            for i = 1, 3 do
                updateSlotVisual(i)
            end
            mainFrame.Visible = false
            overlay.Visible = false
            
            task.delay(5, function()
                refreshInventory()
            end)
        else
            fuseBtn.Text = result and result.error or "¡Error!"
            task.delay(2, updateFuseButton)
        end
    end
end)

-- Inventory Section
local invTitle = Instance.new("TextLabel")
invTitle.Size = UDim2.new(1, 0, 0.08, 0)
invTitle.Position = UDim2.new(0, 0, 0.70, 0)
invTitle.BackgroundTransparency = 1
invTitle.Text = "📦 Tu Inventario (click para seleccionar)"
invTitle.TextColor3 = Color3.new(1, 1, 1)
invTitle.Font = Enum.Font.GothamBold
invTitle.TextScaled = true
invTitle.ZIndex = 2
invTitle.Parent = mainFrame

local invContainer = Instance.new("ScrollingFrame")
invContainer.Size = UDim2.new(0.95, 0, 0.20, 0)
invContainer.Position = UDim2.new(0.025, 0, 0.78, 0)
invContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
invContainer.BackgroundTransparency = 0.3
invContainer.ScrollBarThickness = 8
invContainer.ScrollBarImageColor3 = Color3.fromRGB(255, 100, 50)
invContainer.ZIndex = 2
invContainer.Parent = mainFrame

local invCorner = Instance.new("UICorner")
invCorner.CornerRadius = UDim.new(0.1, 0)
invCorner.Parent = invContainer

local invGrid = Instance.new("UIGridLayout")
-- Cell Size: PURE SCALE (Defaults for 8 per row)
invGrid.CellSize = UDim2.new(0.115, 0, 0.2, 0) 
invGrid.CellPadding = UDim2.new(0.005, 0, 0.01, 0) 
invGrid.SortOrder = Enum.SortOrder.LayoutOrder
invGrid.Parent = invContainer

local invPadding = Instance.new("UIPadding")
invPadding.PaddingLeft = UDim.new(0.02, 0)
invPadding.PaddingTop = UDim.new(0.05, 0)
invPadding.PaddingRight = UDim.new(0.02, 0)
invPadding.Parent = invContainer

-- Create inventory item with ViewportFrame
local function createInventoryItem(unit, index)
    local cell = Instance.new("Frame")
    cell.Name = "Cell_" .. index
    cell.BackgroundTransparency = 1
    cell.LayoutOrder = index
    cell.Parent = invContainer
    
    -- Inner Card (Maintains Aspect Ratio visually)
    local item = Instance.new("Frame")
    item.Name = "Card"
    item.Size = UDim2.new(1, 0, 1, 0)
    item.AnchorPoint = Vector2.new(0.5, 0.5)
    item.Position = UDim2.new(0.5, 0, 0.5, 0)
    item.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    item.ZIndex = 3
    item.Parent = cell
    
    -- Constraint the CARD, not the cell
    -- REMOVED: aspect ratio here was causing horizontal gaps
    item.Parent = cell
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.1, 0)
    corner.Parent = item
    
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = TIER_COLORS[unit.Tier] or Color3.fromRGB(100, 100, 100)
    stroke.Parent = item
    
    -- Model preview
    local previewFrame = Instance.new("Frame")
    previewFrame.Size = UDim2.new(0.9, 0, 0.5, 0)
    previewFrame.Position = UDim2.new(0.05, 0, 0.05, 0)
    previewFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    previewFrame.ZIndex = 3
    previewFrame.Parent = item
    
    local previewCorner = Instance.new("UICorner")
    previewCorner.CornerRadius = UDim.new(0.2, 0)
    previewCorner.Parent = previewFrame
    
    task.spawn(function()
        createViewportModel(previewFrame, unit.Name, unit.Tier, unit.Shiny, unit.Mutation)
    end)
    
    -- Name
    local name = Instance.new("TextLabel")
    name.Size = UDim2.new(0.9, 0, 0.2, 0)
    name.Position = UDim2.new(0.05, 0, 0.55, 0)
    name.BackgroundTransparency = 1
    name.Text = unit.Name:gsub("Unit_", ""):gsub("_", " ")
    name.TextColor3 = Color3.new(1, 1, 1)
    name.Font = Enum.Font.GothamBold
    name.TextScaled = true
    name.ZIndex = 3
    name.Parent = item
    
    -- Tier
    local tier = Instance.new("TextLabel")
    tier.Size = UDim2.new(1, 0, 0.15, 0)
    tier.Position = UDim2.new(0, 0, 0.8, 0)
    tier.BackgroundTransparency = 1
    tier.Text = unit.Tier .. (unit.Shiny and " ✨" or "")
    tier.TextColor3 = TIER_COLORS[unit.Tier] or Color3.new(1, 1, 1)
    tier.Font = Enum.Font.Gotham
    tier.TextScaled = true
    tier.ZIndex = 3
    tier.Parent = item
    
    -- Click to select (Full Cell coverage)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.ZIndex = 5
    btn.Parent = cell -- Button covers cell
    
    btn.MouseButton1Click:Connect(function()
        for i = 1, 3 do
            if selectedSlots[i] == nil then
                local alreadySelected = false
                for j = 1, 3 do
                    if selectedSlots[j] and selectedSlots[j].Id == unit.Id then
                        alreadySelected = true
                        break
                    end
                end
                
                if not alreadySelected then
                    selectedSlots[i] = unit
                    updateSlotVisual(i)
                    updateFuseButton()
                    stroke.Color = Color3.fromRGB(100, 255, 100)
                    task.delay(0.2, function()
                        stroke.Color = TIER_COLORS[unit.Tier] or Color3.fromRGB(100, 100, 100)
                    end)
                end
                break
            end
        end
    end)
    
    -- Hover effect on Card
    btn.MouseEnter:Connect(function()
        TweenService:Create(item, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(60, 60, 70)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(item, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(45, 45, 55)}):Play()
    end)
    
    return cell
end

function refreshInventory()
    for _, child in pairs(invContainer:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    local success, inventory = pcall(function() return GetInventory:InvokeServer() end)
    if not success then return end
    
    local response = inventory or {}
    inventoryData = response.Inventory or {}
    
    if #inventoryData == 0 and type(inventoryData) == "table" then
        local newArr = {}
        for _, v in pairs(inventoryData) do table.insert(newArr, v) end
        inventoryData = newArr
    end

    for i, unit in ipairs(inventoryData) do
        if type(unit) ~= "table" then continue end 
        createInventoryItem(unit, i)
    end
    
    -- DYNAMIC CANVAS SCALING (Pure Scale)
    -- Start with default canvas (0,0,0,0) = Automagic? No.
    -- We must set CanvasSize to scroll.
    -- Items per row = 5.
    local rows = math.ceil(#inventoryData / 5)
    if rows < 4 then rows = 4 end
    
    -- We want each row to be roughly 25% of the VIEWPORT height visually.
    -- But in Scale logic, CanvasSize Y = 1 means Scrollable Area = Viewport Height.
    -- If we have 10 rows, and we want 4 visible at once:
    -- CanvasSize Y = 10 / 4 = 2.5.
    
    local visibleRows = 3 -- How many rows visible at once
    local scaleY = rows / visibleRows
    
    invContainer.CanvasSize = UDim2.new(0, 0, scaleY, 0)
    
    -- AND update grid cell size.
    -- Grid Cell Scale Y is relative to CANVAS Height.
    -- We want the cell to be 1/rows high (roughly).
    -- Actually 1/rows * scaleY = 1/visibleRows = 0.33
    
    -- If Canvas is 2.5 (250% view height).
    -- Cell Y Scale 0.1 means 10% of 250% = 25% of view height.
    -- So Cell Y Scale = 1 / rows? No.
    
    -- Let's stick to fixed small Scale Y
    -- UIGridLayout CellSize is relative to ScrollingFrame CANVAS.
    -- If we change CanvasSize, the ABSOLUTE size of cells changes if Scale is used.
    -- If Canvas grows to 10.0, and Cell is 0.1, Cell becomes 1.0 screen height. Too big.
    
    -- Correct Math:
    -- Target: Cell Height = 1/visibleRows of Viewport.
    -- Canvas Height = (rows / visibleRows) of Viewport.
    -- Cell Scale Y = Target / Canvas Height
    --              = (1/visibleRows) / (rows/visibleRows)
    --              = 1 / rows.
    
    -- Update CanvasSize (PURE SCALE FIXED HEIGHT)
    local itemsPerRow = 8
    local rowCount = math.ceil(#inventoryData / itemsPerRow)
    if rowCount < 1 then rowCount = 1 end
    
    local visibleRows = 4 -- Higher density in Fusion
    local scaleY = rowCount / visibleRows
    if scaleY < 1 then scaleY = 1 end
    
    invContainer.CanvasSize = UDim2.new(0, 0, scaleY, 0)
    
    -- ADJUST CELL HEIGHT 
    local paddingY = invGrid.CellPadding.Y.Scale
    local adjustedCellY = (1 - (rowCount * paddingY)) / rowCount
    
    invGrid.CellSize = UDim2.new(0.115, 0, adjustedCellY, 0)
end

print("[FusionUI] Loaded (Corrected Scale Layout)")
