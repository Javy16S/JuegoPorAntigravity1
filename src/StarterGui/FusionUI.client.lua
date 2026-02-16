-- FusionUI.client.lua
-- Skill: ui-framework
-- Description: Interactive Fusion UI with 3D model previews using ViewportFrame

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

-- Prevent duplicates
if playerGui:FindFirstChild("FusionMainGUI") then
    playerGui.FusionMainGUI:Destroy()
end

-- Create UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FusionMainGUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 10
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Background overlay for click-outside-to-close
local overlay = Instance.new("TextButton")
overlay.Name = "Overlay"
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 0.5
overlay.Text = ""
overlay.Visible = false
overlay.ZIndex = 1
overlay.Parent = screenGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0.75, 0, 0.85, 0)
mainFrame.Position = UDim2.new(0.125, 0, 0.075, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
mainFrame.BackgroundTransparency = 0.05
mainFrame.Visible = false
mainFrame.ZIndex = 10 -- High ZIndex
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 20)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Thickness = 3
mainStroke.Color = Color3.fromRGB(255, 100, 50)
mainStroke.Parent = mainFrame

-- Click overlay to close
overlay.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
    overlay.Visible = false
end)

-- Sync visibility
mainFrame:GetPropertyChangedSignal("Visible"):Connect(function()
    overlay.Visible = mainFrame.Visible
    if mainFrame.Visible then
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
                    -- Only refresh if count changed or crude check?
                    -- For now, full refresh is safer but maybe laggy. 
                    -- Optimize: check count?
                    refreshInventory()
                end
            end
        end)
    end
end)

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 60)
title.BackgroundTransparency = 1
title.Text = "🔥 MESA DE FUSIÓN 🔥"
title.TextColor3 = Color3.fromRGB(255, 200, 100)
title.Font = Enum.Font.GothamBlack
title.TextSize = 32
title.ZIndex = 2
title.Parent = mainFrame

-- Subtitle
local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, 0, 0, 25)
subtitle.Position = UDim2.new(0, 0, 0, 50)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Combina 3 unidades del MISMO TIER para obtener una mejor"
subtitle.TextColor3 = Color3.fromRGB(150, 150, 150)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 14
subtitle.ZIndex = 2
subtitle.Parent = mainFrame

-- Close Button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -50, 0, 10)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 20
closeBtn.ZIndex = 3
closeBtn.Parent = mainFrame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 10)
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
    overlay.Visible = false
end)

-- Fusion Slots Container
local slotsContainer = Instance.new("Frame")
slotsContainer.Size = UDim2.new(1, 0, 0, 180)
slotsContainer.Position = UDim2.new(0, 0, 0, 85)
slotsContainer.BackgroundTransparency = 1
slotsContainer.ZIndex = 2
slotsContainer.Parent = mainFrame

local slotsLayout = Instance.new("UIListLayout")
slotsLayout.FillDirection = Enum.FillDirection.Horizontal
slotsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
slotsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
slotsLayout.Padding = UDim.new(0, 20)
slotsLayout.Parent = slotsContainer

-- Helper: Create ViewportFrame for 3D model preview
local function createViewportModel(parent, modelName, tierColor)
    local viewport = parent:FindFirstChild("Viewport")
    if viewport then viewport:Destroy() end
    
    viewport = Instance.new("ViewportFrame")
    viewport.Name = "Viewport"
    viewport.Size = UDim2.new(1, 0, 1, 0)
    viewport.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    viewport.BackgroundTransparency = 0
    viewport.ZIndex = 3
    viewport.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = viewport
    
    -- Wait briefly for ModelReplicator to sync models
    local brainrotModels = ReplicatedStorage:FindFirstChild("BrainrotModels")
    if not brainrotModels then
        -- Try waiting a bit
        brainrotModels = ReplicatedStorage:WaitForChild("BrainrotModels", 2)
    end
    
    local foundModel = false
    if brainrotModels then
        for _, tierFolder in pairs(brainrotModels:GetChildren()) do
            local model = tierFolder:FindFirstChild(modelName)
            if model then
                local clone = model:Clone()
                clone.Parent = viewport
                
                -- Calculate model bounds for camera positioning
                local cf, size = clone:GetBoundingBox()
                local maxSize = math.max(size.X, size.Y, size.Z)
                local distance = maxSize * 1.5
                
                -- Center model at origin
                local modelCenter = cf.Position
                for _, part in pairs(clone:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CFrame = part.CFrame * CFrame.new(-modelCenter)
                    end
                end
                
                -- Camera looking at model from angle
                local camera = Instance.new("Camera")
                camera.CFrame = CFrame.new(Vector3.new(distance * 0.7, distance * 0.5, distance * 0.7), Vector3.new(0, 0, 0))
                camera.Parent = viewport
                viewport.CurrentCamera = camera
                
                -- Ambient lighting for viewport
                viewport.Ambient = Color3.fromRGB(200, 200, 200)
                viewport.LightColor = Color3.fromRGB(255, 255, 255)
                viewport.LightDirection = Vector3.new(-1, -1, -1)
                
                foundModel = true
                break
            end
        end
    end
    
    -- Fallback: Show styled placeholder with tier color
    if not foundModel then
        local placeholder = Instance.new("Frame")
        placeholder.Size = UDim2.new(1, 0, 1, 0)
        placeholder.BackgroundTransparency = 1
        placeholder.ZIndex = 4
        placeholder.Parent = viewport
        
        local icon = Instance.new("TextLabel")
        icon.Size = UDim2.new(1, 0, 0.6, 0)
        icon.BackgroundTransparency = 1
        icon.Text = "🔮"
        icon.TextColor3 = tierColor or Color3.new(1, 1, 1)
        icon.Font = Enum.Font.SourceSansBold
        icon.TextSize = 35
        icon.ZIndex = 4
        icon.Parent = placeholder
        
        -- Show abbreviated model name
        local shortName = modelName:gsub("_", " "):sub(1, 12)
        local nameHint = Instance.new("TextLabel")
        nameHint.Size = UDim2.new(1, 0, 0.4, 0)
        nameHint.Position = UDim2.new(0, 0, 0.6, 0)
        nameHint.BackgroundTransparency = 1
        nameHint.Text = shortName
        nameHint.TextColor3 = Color3.fromRGB(120, 120, 120)
        nameHint.Font = Enum.Font.Gotham
        nameHint.TextSize = 10
        nameHint.TextTruncate = Enum.TextTruncate.AtEnd
        nameHint.ZIndex = 4
        nameHint.Parent = placeholder
    end
    
    return viewport
end


-- Create fusion slot
local function createFusionSlot(index)
    local slot = Instance.new("Frame")
    slot.Name = "Slot_" .. index
    slot.Size = UDim2.new(0, 140, 0, 170)
    slot.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    slot.LayoutOrder = index * 2 - 1
    slot.ZIndex = 2
    slot.Parent = slotsContainer
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 15)
    corner.Parent = slot
    
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 3
    stroke.Color = Color3.fromRGB(100, 100, 100)
    stroke.Name = "SlotStroke"
    stroke.Parent = slot
    
    -- Model preview area
    local previewFrame = Instance.new("Frame")
    previewFrame.Name = "PreviewFrame"
    previewFrame.Size = UDim2.new(1, -20, 0, 100)
    previewFrame.Position = UDim2.new(0, 10, 0, 10)
    previewFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    previewFrame.ZIndex = 2
    previewFrame.Parent = slot
    
    local previewCorner = Instance.new("UICorner")
    previewCorner.CornerRadius = UDim.new(0, 10)
    previewCorner.Parent = previewFrame
    
    -- Empty placeholder
    local emptyLabel = Instance.new("TextLabel")
    emptyLabel.Name = "EmptyLabel"
    emptyLabel.Size = UDim2.new(1, 0, 1, 0)
    emptyLabel.BackgroundTransparency = 1
    emptyLabel.Text = "?"
    emptyLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
    emptyLabel.Font = Enum.Font.GothamBlack
    emptyLabel.TextSize = 50
    emptyLabel.ZIndex = 3
    emptyLabel.Parent = previewFrame
    
    -- Name label
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, -10, 0, 25)
    nameLabel.Position = UDim2.new(0, 5, 0, 115)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = "Vacío"
    nameLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 13
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.ZIndex = 2
    nameLabel.Parent = slot
    
    -- Tier label
    local tierLabel = Instance.new("TextLabel")
    tierLabel.Name = "TierLabel"
    tierLabel.Size = UDim2.new(1, 0, 0, 20)
    tierLabel.Position = UDim2.new(0, 0, 0, 140)
    tierLabel.BackgroundTransparency = 1
    tierLabel.Text = ""
    tierLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
    tierLabel.Font = Enum.Font.Gotham
    tierLabel.TextSize = 12
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
    plus.Size = UDim2.new(0, 40, 0, 170)
    plus.BackgroundTransparency = 1
    plus.Text = "+"
    plus.TextColor3 = Color3.fromRGB(255, 200, 100)
    plus.Font = Enum.Font.GothamBlack
    plus.TextSize = 48
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
    
    -- Clear existing viewport
    if previewFrame then
        local existingViewport = previewFrame:FindFirstChild("Viewport")
        if existingViewport then existingViewport:Destroy() end
    end
    
    if unit then
        if emptyLabel then emptyLabel.Visible = false end
        
        -- Create 3D preview
        createViewportModel(previewFrame, unit.Name, TIER_COLORS[unit.Tier])
        
        if nameLabel then 
            nameLabel.Text = unit.Name:gsub("_", " ")
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
fuseBtn.Size = UDim2.new(0, 280, 0, 55)
fuseBtn.Position = UDim2.new(0.5, -140, 0, 275)
fuseBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
fuseBtn.Text = "Selecciona 3 unidades"
fuseBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
fuseBtn.Font = Enum.Font.GothamBlack
fuseBtn.TextSize = 18
fuseBtn.ZIndex = 2
fuseBtn.Parent = mainFrame

local fuseCorner = Instance.new("UICorner")
fuseCorner.CornerRadius = UDim.new(0, 12)
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
invTitle.Size = UDim2.new(1, 0, 0, 35)
invTitle.Position = UDim2.new(0, 0, 0, 340)
invTitle.BackgroundTransparency = 1
invTitle.Text = "📦 Tu Inventario (click para seleccionar)"
invTitle.TextColor3 = Color3.new(1, 1, 1)
invTitle.Font = Enum.Font.GothamBold
invTitle.TextSize = 18
invTitle.ZIndex = 2
invTitle.Parent = mainFrame

local invContainer = Instance.new("ScrollingFrame")
invContainer.Size = UDim2.new(1, -40, 1, -395)
invContainer.Position = UDim2.new(0, 20, 0, 380)
invContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
invContainer.BackgroundTransparency = 0.3
invContainer.ScrollBarThickness = 8
invContainer.ScrollBarImageColor3 = Color3.fromRGB(255, 100, 50)
invContainer.ZIndex = 2
invContainer.Parent = mainFrame

local invCorner = Instance.new("UICorner")
invCorner.CornerRadius = UDim.new(0, 15)
invCorner.Parent = invContainer

local invGrid = Instance.new("UIGridLayout")
invGrid.CellSize = UDim2.new(0, 100, 0, 130)
invGrid.CellPadding = UDim2.new(0, 12, 0, 12)
invGrid.SortOrder = Enum.SortOrder.LayoutOrder
invGrid.Parent = invContainer

local invPadding = Instance.new("UIPadding")
invPadding.PaddingLeft = UDim.new(0, 12)
invPadding.PaddingTop = UDim.new(0, 12)
invPadding.PaddingRight = UDim.new(0, 12)
invPadding.Parent = invContainer

-- Create inventory item with ViewportFrame
local function createInventoryItem(unit, index)
    local item = Instance.new("Frame")
    item.Name = "Item_" .. index
    item.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    item.LayoutOrder = index
    item.ZIndex = 3
    item.Parent = invContainer
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = item
    
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = TIER_COLORS[unit.Tier] or Color3.fromRGB(100, 100, 100)
    stroke.Parent = item
    
    -- Model preview
    local previewFrame = Instance.new("Frame")
    previewFrame.Size = UDim2.new(1, -12, 0, 65)
    previewFrame.Position = UDim2.new(0, 6, 0, 6)
    previewFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    previewFrame.ZIndex = 3
    previewFrame.Parent = item
    
    local previewCorner = Instance.new("UICorner")
    previewCorner.CornerRadius = UDim.new(0, 8)
    previewCorner.Parent = previewFrame
    
    -- Create 3D preview or placeholder
    createViewportModel(previewFrame, unit.Name, TIER_COLORS[unit.Tier])
    
    -- Name
    local name = Instance.new("TextLabel")
    name.Size = UDim2.new(1, -8, 0, 28)
    name.Position = UDim2.new(0, 4, 0, 73)
    name.BackgroundTransparency = 1
    name.Text = unit.Name:gsub("_", " ")
    name.TextColor3 = Color3.new(1, 1, 1)
    name.Font = Enum.Font.GothamBold
    name.TextSize = 11
    name.TextTruncate = Enum.TextTruncate.AtEnd
    name.ZIndex = 3
    name.Parent = item
    
    -- Tier
    local tier = Instance.new("TextLabel")
    tier.Size = UDim2.new(1, 0, 0, 20)
    tier.Position = UDim2.new(0, 0, 0, 100)
    tier.BackgroundTransparency = 1
    tier.Text = unit.Tier .. (unit.Shiny and " ✨" or "")
    tier.TextColor3 = TIER_COLORS[unit.Tier] or Color3.new(1, 1, 1)
    tier.Font = Enum.Font.Gotham
    tier.TextSize = 11
    tier.ZIndex = 3
    tier.Parent = item
    
    -- Click to select
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.ZIndex = 5
    btn.Parent = item
    
    btn.MouseButton1Click:Connect(function()
        for i = 1, 3 do
            if selectedSlots[i] == nil then
                -- Check if already selected
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
                    
                    -- Feedback
                    stroke.Color = Color3.fromRGB(100, 255, 100)
                    task.delay(0.2, function()
                        stroke.Color = TIER_COLORS[unit.Tier] or Color3.fromRGB(100, 100, 100)
                    end)
                end
                break
            end
        end
    end)
    
    -- Hover
    btn.MouseEnter:Connect(function()
        TweenService:Create(item, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(60, 60, 70)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(item, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(45, 45, 55)}):Play()
    end)
    
    return item
end

-- Refresh inventory
function refreshInventory()
    for _, child in pairs(invContainer:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    local inventory = GetInventory:InvokeServer()
    inventoryData = inventory or {}
    
    for i, unit in ipairs(inventoryData) do
        createInventoryItem(unit, i)
    end
    
    local cols = 5
    local rows = math.ceil(#inventoryData / cols)
    invContainer.CanvasSize = UDim2.new(0, 0, 0, rows * 142 + 24)
end

print("[FusionUI] Loaded with ViewportFrame support")
