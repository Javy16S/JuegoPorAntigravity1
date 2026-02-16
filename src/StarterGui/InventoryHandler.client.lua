-- InventoryHandler.client.lua
-- Skill: ui-framework
-- Description: Replaces default Roblox inventory with a custom "Brainrot" style hotbar AND Extended Inventory.
-- Refinements: Nuclear Statue Fix + Locked=true + Massless Enforcement + Drag & Drop Support.
-- Refactored for Responsiveness
local function playSound(id, vol, duration) -- v5.3 POLISH
    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://" .. tostring(id)
    s.Volume = vol or 0.5
    s.Parent = game:GetService("SoundService")
    s:Play()
    if duration then
        task.delay(duration, function()
            if s and s.Parent then
                s:Stop()
                s:Destroy()
            end
        end)
    else
        s.Ended:Connect(function() s:Destroy() end)
    end
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")

local MutationManager = nil
pcall(function()
    MutationManager = require(ReplicatedStorage:WaitForChild("Modules", 5):WaitForChild("MutationManager", 5))
end)

-- 0. Bindable for external triggers
local toggleInv = ReplicatedStorage:FindFirstChild("ToggleInventory") or Instance.new("BindableEvent")
toggleInv.Name = "ToggleInventory"
toggleInv.Parent = ReplicatedStorage

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local UIManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UIManager"))

-- Configuration
local HOTBAR_SLOTS = 9
local PADDING = 0.015 -- Relative padding
local EXTENDED_KEY = Enum.KeyCode.Backquote 

-- FIX: Rotation offset for R15 Right Hand
local ROTATION_OFFSET = CFrame.Angles(math.rad(-90), 0, 0)

-- 1. Disable Default Backpack
pcall(function()
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

-- 2. Clean previous GUI
for _, gui in pairs(playerGui:GetChildren()) do
    if gui.Name == "InventarioGui" then gui:Destroy() end
end

-- 3. Main GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "InventarioGui"
screenGui.ResetOnSpawn = false 
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 100
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling 
screenGui.Parent = playerGui

-- STATE
local slots = {} 
local extendedSlots = {} 
local currentSearch = ""
local currentVisualModel = nil 

-- DRAG STATE
local isDragging = false
local dragGhost = nil
local draggingTool = nil
local dragSourceIndex = nil      -- Index in source (1-9 for Hotbar, 1-N for Extended)
local dragSourceType = nil       -- "Hotbar" or "Extended"

local hotbarAssignment = {}      -- [1..9] -> ToolInstance
local allToolsList = {}          -- Sorted list of tools in Extended Inventory

local lastInputPosition = Vector2.new(0, 0)  
local inputStartTime = 0
local inputStartPosition = Vector2.new(0, 0)
local pendingDrag = false
local DRAG_THRESHOLD_TIME = 0.25 -- seconds
local DRAG_THRESHOLD_DIST = 10 -- pixels
local updateInventory -- Pre-declared for scoping

local updateHotbarRemote = ReplicatedStorage:WaitForChild("UpdateHotbar")

local function syncHotbarToServer()
    local map = {}
    for slot, tool in pairs(hotbarAssignment) do
        if tool then
            local uId = tool:GetAttribute("UnitId")
            if uId then
                map[tostring(slot)] = uId
            end
        end
    end
    updateHotbarRemote:FireServer(map)
end

local EnumKeys = {
    Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three,
    Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six,
    Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine
}

-- ============================================================================
-- UI CONSTRUCTION
-- ============================================================================
local hotbarFrame = Instance.new("Frame")
hotbarFrame.Name = "HotbarFrame"
-- Scale: 55% width, 12% height. Centered bottom.
hotbarFrame.Size = UDim2.new(0.55, 0, 0.12, 0)
hotbarFrame.Position = UDim2.new(0.5, 0, 0.98, 0) -- 2% from bottom
hotbarFrame.AnchorPoint = Vector2.new(0.5, 1)
hotbarFrame.BackgroundTransparency = 1
hotbarFrame.ZIndex = 2 
hotbarFrame.Parent = screenGui

-- Hotbar Aspect Ratio (Keep it rectangular and prevent squashing on mobile)
local hotbarAspect = Instance.new("UIAspectRatioConstraint")
hotbarAspect.AspectRatio = 6.5 -- Wide rectangle
hotbarAspect.AspectType = Enum.AspectType.FitWithinMaxSize
hotbarAspect.DominantAxis = Enum.DominantAxis.Width
hotbarAspect.Parent = hotbarFrame

local hotbarLayout = Instance.new("UIListLayout")
hotbarLayout.FillDirection = Enum.FillDirection.Horizontal
hotbarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
hotbarLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
hotbarLayout.Padding = UDim.new(PADDING, 0) 
hotbarLayout.Parent = hotbarFrame

-- Overlay
local overlayBtn = Instance.new("TextButton")
overlayBtn.Name = "ClickOverlay"
overlayBtn.Size = UDim2.new(1, 0, 1, 0)
overlayBtn.BackgroundTransparency = 0.5
overlayBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlayBtn.Text = ""
overlayBtn.Visible = false
overlayBtn.ZIndex = 1 
overlayBtn.Parent = screenGui

local extendedFrame = Instance.new("Frame")
extendedFrame.Name = "ExtendedInventory"
-- Scale: 60% width, 60% height. Centered.
extendedFrame.Size = UDim2.new(0.6, 0, 0.6, 0)
extendedFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
extendedFrame.AnchorPoint = Vector2.new(0.5, 0.5)
extendedFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
extendedFrame.BackgroundTransparency = 0.15
extendedFrame.ZIndex = 3 
extendedFrame.Visible = false 
extendedFrame.Parent = screenGui

-- Extend Aspect Ratio (Cinematic Drawer)
local extAspect = Instance.new("UIAspectRatioConstraint")
extAspect.AspectRatio = 2 -- WIDE
extAspect.Parent = extendedFrame

Instance.new("UICorner", extendedFrame).CornerRadius = UDim.new(0.05, 0)
local extStroke = Instance.new("UIStroke")
extStroke.Color = Color3.fromRGB(0, 255, 100)
extStroke.Thickness = 2
extStroke.Parent = extendedFrame

local extTitle = Instance.new("TextLabel")
extTitle.Size = UDim2.new(0.4, 0, 0.1, 0)
extTitle.Position = UDim2.new(0.05, 0, 0, 0)
extTitle.BackgroundTransparency = 1
extTitle.Text = "MOCHILA"
extTitle.TextColor3 = Color3.fromRGB(0, 255, 150)
extTitle.Font = Enum.Font.GothamBlack
extTitle.TextScaled = true -- Responsive text
extTitle.TextXAlignment = Enum.TextXAlignment.Left
extTitle.ZIndex = 5
extTitle.Parent = extendedFrame

local searchBar = Instance.new("TextBox")
searchBar.Name = "SearchBar"
searchBar.Text = "" 
searchBar.Size = UDim2.new(0.35, 0, 0.08, 0)
searchBar.Position = UDim2.new(0.95, 0, 0.02, 0)
searchBar.AnchorPoint = Vector2.new(1, 0)
searchBar.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
searchBar.BackgroundTransparency = 0.3
searchBar.TextColor3 = Color3.new(1, 1, 1)
searchBar.PlaceholderText = "Buscar..."
searchBar.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
searchBar.Font = Enum.Font.Gotham
searchBar.TextScaled = true -- Responsive Text
searchBar.ZIndex = 5
searchBar.Parent = extendedFrame

Instance.new("UICorner", searchBar).CornerRadius = UDim.new(0.2, 0)

local scrollContainer = Instance.new("ScrollingFrame")
scrollContainer.Size = UDim2.new(0.95, 0, 0.85, 0)
scrollContainer.Position = UDim2.new(0.025, 0, 0.12, 0)
scrollContainer.BackgroundTransparency = 1
scrollContainer.ScrollBarThickness = 6
scrollContainer.ZIndex = 5
scrollContainer.Parent = extendedFrame

local gridLayout = Instance.new("UIGridLayout")
-- Cell Size: PURE SCALE (v5.4 Fixed Row Height)
gridLayout.CellSize = UDim2.new(0.115, 0, 0.23, 0) -- 8 items per row, fixed height
gridLayout.CellPadding = UDim2.new(0.005, 0, 0.01, 0) 
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.StartCorner = Enum.StartCorner.TopLeft -- v5.4 FIX
gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top -- v5.4 FIX
gridLayout.Parent = scrollContainer

local gridPadding = Instance.new("UIPadding")
gridPadding.PaddingLeft = UDim.new(0.02, 0)
gridPadding.PaddingTop = UDim.new(0.02, 0)
gridPadding.Parent = scrollContainer

overlayBtn.MouseButton1Click:Connect(function()
    UIManager.Close("InventoryUI")
end)

-- Register with UIManager
UIManager.Register("InventoryUI", extendedFrame, {
    OnOpen = function()
        overlayBtn.Visible = true
        task.defer(updateInventory)
    end,
    OnClose = function()
        overlayBtn.Visible = false
    end
})

-- ============================================================================
-- HELPERS
-- ============================================================================

local function getTierColor(tierName)
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
    return TIER_COLORS[tierName] or TIER_COLORS["Common"]
end

local function tween(obj, props, duration)
    TweenService:Create(obj, TweenInfo.new(duration or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function getModelTemplate(name)
    local ST = game:GetService("ReplicatedStorage"):FindFirstChild("BrainrotModels")
    if not ST then return nil end
    local cleanName = string.gsub(name, "Unit_", ""):gsub("Unit", ""):gsub("_", " ") -- Improved cleaning
    local t = ST:FindFirstChild(cleanName, true)
    if not t then
        -- fallback search
        for _, child in pairs(ST:GetDescendants()) do
            if child.Name == cleanName and (child:IsA("Model") or child:IsA("BasePart")) then
                return child
            end
        end
    end
    return t
end

-- UPDATED: Better Camera Zoom
local function updateViewport(viewFrame, tool)
    viewFrame:ClearAllChildren()
    if not tool then return end
    
    local template = getModelTemplate(tool.Name)
    
    if template then
        local clone = template:Clone()
        for _, v in pairs(clone:GetDescendants()) do
             if v:IsA("LuaSourceContainer") or v:IsA("Clothing") or v:IsA("ShirtGraphic") or v:IsA("CharacterMesh") 
                or v:IsA("Humanoid") or v:IsA("Decal") or v:IsA("Texture") or v:IsA("BodyColors")
                or v:IsA("GuiBase3d") or v:IsA("SpecialMesh") then 
                v:Destroy() 
             end
        end
        
        -- Apply Visuals
        local tier = tool:GetAttribute("Tier")
        local isShiny = tool:GetAttribute("IsShiny")
        if MutationManager then
            if tier then MutationManager.applyTierEffects(clone, tier, isShiny, true) end
            
            local mutation = tool:GetAttribute("Mutation")
            if mutation then
                MutationManager.applyMutation(clone, mutation)
            end
        end
        
        local worldModel = Instance.new("WorldModel")
        worldModel.Parent = viewFrame
        clone.Parent = worldModel
        
        local camera = Instance.new("Camera")
        viewFrame.CurrentCamera = camera
        camera.Parent = viewFrame
        
        -- Lighting Fix for Viewports (High Visibility)
        viewFrame.Ambient = Color3.fromRGB(200, 200, 200)
        viewFrame.LightColor = Color3.fromRGB(255, 255, 255)
        viewFrame.LightDirection = Vector3.new(-1, -1, -1)
        
        local cf, size
        if clone:IsA("Model") then
             cf, size = clone:GetBoundingBox()
        else
             cf, size = clone.CFrame, clone.Size
        end
        
        local maxDim = math.max(size.X, size.Y, size.Z)
        if maxDim < 0.1 then maxDim = 4 end 
        
        local dist = maxDim * 0.8 -- Zoomed In
        local center = cf.Position
        local camPos = center + Vector3.new(-dist, dist * 0.5, dist)
        camera.CFrame = CFrame.lookAt(camPos, center)
    end
end

-- ============================================================================
-- TOOL VISUALS (Simplified)
-- ============================================================================

local function connectEvents(char)
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        backpack.ChildAdded:Connect(function() task.defer(updateInventory) end)
        backpack.ChildRemoved:Connect(function() task.defer(updateInventory) end)
    end
    
    char.ChildAdded:Connect(function(c) 
        if c:IsA("Tool") then 
            task.defer(function() updateInventory() end) 
        end 
    end)
    char.ChildRemoved:Connect(function(c) 
        if c:IsA("Tool") then 
            task.defer(function() updateInventory() end) 
        end 
    end)
end

local function equipToolSafe(tool)
    if not tool or not tool.Parent then return end
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    if tool.Parent == char then
        humanoid:UnequipTools()
    else
        humanoid:EquipTool(tool)
    end
end

-- Handle Input Data (Bound to Keys 1-9)
local function handleHotbarAction(actionName, inputState, inputObject)
    if inputState == Enum.UserInputState.Begin then
        local index = tonumber(string.sub(actionName, 5)) 
        if index then
            local tool = hotbarAssignment[index]
            if tool then
                equipToolSafe(tool)
            end
        end
    end
end

local function createSlotUI(layoutIndex, context) -- context: "Hotbar" or "Extended"
    local slot = Instance.new("Frame")
    slot.Name = "Slot"
    slot.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    slot.BackgroundTransparency = 0.4 
    slot.BorderSizePixel = 0
    
    -- Slot Aspect Ratio (Portrait for icons)
    local aspect = Instance.new("UIAspectRatioConstraint")
    aspect.AspectRatio = 0.8
    aspect.AspectType = Enum.AspectType.FitWithinMaxSize
    aspect.Parent = slot
    
    if context == "Hotbar" then
        slot.Size = UDim2.new(0.1, 0, 1, 0)
        slot.Parent = hotbarFrame
        slot.LayoutOrder = layoutIndex
    else
        slot.Parent = scrollContainer
        slot.LayoutOrder = layoutIndex
    end

    local highlight = Instance.new("Frame")
    highlight.Name = "HighlightFrame"
    highlight.Size = UDim2.new(1.05, 0, 1.05, 0) -- Slight overflow
    highlight.Position = UDim2.new(0.5, 0, 0.5, 0)
    highlight.AnchorPoint = Vector2.new(0.5, 0.5)
    highlight.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    highlight.BackgroundTransparency = 1
    highlight.ZIndex = 0
    highlight.Parent = slot
    Instance.new("UICorner", highlight).CornerRadius = UDim.new(0.15, 0)

    Instance.new("UICorner", slot).CornerRadius = UDim.new(0.15, 0)
    local stroke = Instance.new("UIStroke")
    stroke.Name = "SelectionStroke"
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Transparency = 1
    stroke.Thickness = 2
    stroke.Parent = slot

    if context == "Hotbar" and layoutIndex <= 9 then
        local numLabel = Instance.new("TextLabel")
        numLabel.Size = UDim2.new(0.25, 0, 0.25, 0)
        numLabel.Position = UDim2.new(0, 3, 0, 2)
        numLabel.BackgroundTransparency = 1
        numLabel.Text = tostring(layoutIndex)
        numLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        numLabel.Font = Enum.Font.GothamBold
        numLabel.TextScaled = true
        numLabel.Parent = slot

        local emptyIcon = Instance.new("TextLabel")
        emptyIcon.Name = "EmptyIcon"
        emptyIcon.Size = UDim2.new(0.5, 0, 0.5, 0)
        emptyIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
        emptyIcon.AnchorPoint = Vector2.new(0.5, 0.5)
        emptyIcon.BackgroundTransparency = 1
        emptyIcon.Text = "+"
        emptyIcon.TextColor3 = Color3.fromRGB(40, 40, 50)
        emptyIcon.Font = Enum.Font.GothamBold
        emptyIcon.TextScaled = true
        emptyIcon.Visible = false
        emptyIcon.Parent = slot
    end

    local viewport = Instance.new("ViewportFrame")
    viewport.Name = "Viewport"
    viewport.Size = UDim2.new(0.9, 0, 0.7, 0)
    viewport.Position = UDim2.new(0.05, 0, 0.05, 0)
    viewport.BackgroundTransparency = 1
    viewport.ZIndex = 2
    viewport.Parent = slot
    
    local infoFrame = Instance.new("Frame")
    infoFrame.Name = "InfoFrame"
    infoFrame.Size = UDim2.new(1, 0, 0.25, 0) -- 25% height at bottom
    infoFrame.Position = UDim2.new(0, 0, 0.75, 0)
    infoFrame.BackgroundColor3 = Color3.fromRGB(5, 5, 10)
    infoFrame.BackgroundTransparency = 0.6
    infoFrame.ZIndex = 3
    infoFrame.Parent = slot
    Instance.new("UICorner", infoFrame).CornerRadius = UDim.new(0.2, 0)

    local tierLabel = Instance.new("TextLabel")
    tierLabel.Name = "TierLabel"
    tierLabel.Size = UDim2.new(0.95, 0, 0.4, 0)
    tierLabel.Position = UDim2.new(0.025, 0, 0.1, 0)
    tierLabel.BackgroundTransparency = 1
    tierLabel.Font = Enum.Font.GothamBold
    tierLabel.Text = ""
    tierLabel.TextScaled = true
    tierLabel.TextXAlignment = Enum.TextXAlignment.Left
    tierLabel.ZIndex = 4
    tierLabel.Parent = infoFrame

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(0.95, 0, 0.4, 0)
    nameLabel.Position = UDim2.new(0.025, 0, 0.5, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamMedium
    nameLabel.Text = ""
    nameLabel.TextScaled = true
    nameLabel.ClipsDescendants = true
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.ZIndex = 4
    nameLabel.TextColor3 = Color3.new(1,1,1)
    nameLabel.Parent = infoFrame
    
    return slot
end

local function applyDataToSlot(slot, tool, context)
    local info = slot:FindFirstChild("InfoFrame")
    if not info then return end

    local name = string.gsub(tool.Name, "Unit_", ""):gsub("_", " ")
    local tier = tool:GetAttribute("Tier") or "Common"
    local isShiny = tool:GetAttribute("IsShiny") or false
    local tierColor = getTierColor(tier)
    
    info.NameLabel.Text = name
    info.TierLabel.Text = isShiny and ("✨ " .. tier) or tier
    info.TierLabel.TextColor3 = tierColor
    
    updateViewport(slot.Viewport, tool)
    
    local oldBtn = slot:FindFirstChild("Btn")
    if oldBtn then oldBtn:Destroy() end
    
    local btn = Instance.new("TextButton")
    btn.Name = "Btn"
    btn.Size = UDim2.new(1,0,1,0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.ZIndex = 10 
    btn.Parent = slot
    
    -- INTERACTION LOGIC (v4.8 - Click vs Drag)
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if tool then
                inputStartTime = os.clock()
                inputStartPosition = Vector2.new(input.Position.X, input.Position.Y)
                lastInputPosition = inputStartPosition
                pendingDrag = true
                draggingTool = tool
                dragSourceIndex = slot.LayoutOrder 
                dragSourceType = context
            end
        end
    end)
end

local updateDebounce = false
function updateInventory()
    if updateDebounce then return end
    updateDebounce = true
    
    task.delay(0.1, function()
        updateDebounce = false
        -- ACTUAL UPDATE LOGIC START
    
        -- SYNC HOTBAR ASSIGNMENT
        -- 1. Gather tools
    local availableTools = {}
    local char = player.Character
    if char then
        local t = char:FindFirstChildWhichIsA("Tool")
        if t then table.insert(availableTools, t) end
    end
    if player:FindFirstChild("Backpack") then
        for _, t in pairs(player.Backpack:GetChildren()) do
             if t:IsA("Tool") then table.insert(availableTools, t) end
        end
    end
     
    -- 2. Fill Hotbar (Preserve assignments if valid)
    local usedTools = {}
    for i = 1, HOTBAR_SLOTS do
        local tool = hotbarAssignment[i]
        if tool and tool.Parent then
             usedTools[tool] = true
        else
             hotbarAssignment[i] = nil -- Lost/Unequipped?
        end
    end
    
    -- 3. Auto-Assign new tools to empty slots
    -- DISABLED: To allow empty slots and strict manual organization.
    
    -- 4. Rebuild UI
    for i = 1, HOTBAR_SLOTS do
        pcall(function() ContextActionService:UnbindAction("Slot" .. i) end)
        
        local tool = hotbarAssignment[i]
        
        if not slots[i] then slots[i] = { Frame = createSlotUI(i, "Hotbar") } end
        local slotFrame = slots[i].Frame
        local emptyIcon = slotFrame:FindFirstChild("EmptyIcon")
        
        if tool then
            if emptyIcon then emptyIcon.Visible = false end
            ContextActionService:BindAction("Slot" .. i, handleHotbarAction, false, EnumKeys[i])
            slotFrame.Visible = true
            applyDataToSlot(slotFrame, tool, "Hotbar")
            
             -- Selection State
            local isEquipped = (tool.Parent == char)
            tween(slotFrame.SelectionStroke, { Transparency = isEquipped and 0 or 1 })
            tween(slotFrame, { BackgroundTransparency = isEquipped and 0.3 or 0.4 })
        else
            if emptyIcon then emptyIcon.Visible = true end
            slotFrame.Visible = true -- Show empty slots effectively
            slotFrame.Viewport:ClearAllChildren()
            local info = slotFrame:FindFirstChild("InfoFrame")
            if info then 
                info.NameLabel.Text = "" 
                info.TierLabel.Text = "" 
            end
            tween(slotFrame.SelectionStroke, { Transparency = 1 })
            tween(slotFrame, { BackgroundTransparency = 0.8 })
            
             -- Maintain a button for DRAG TARGETING if needed (though loop handles it)
             -- We want to allow dragging from one hotbar slot to an empty one.
             if not slotFrame:FindFirstChild("Btn") then
                local btn = Instance.new("TextButton")
                btn.Name = "Btn"
                btn.Size = UDim2.new(1,0,1,0)
                btn.BackgroundTransparency = 1
                btn.Text = ""
                btn.ZIndex = 10 
                btn.Parent = slotFrame
             end
        end
    end
    
    -- 5. Extended Inventory
    allToolsList = {}
    for _, tool in pairs(availableTools) do
         if not usedTools[tool] then
             table.insert(allToolsList, tool)
         end
    end
    -- Sort Extended by name
    table.sort(allToolsList, function(a,b) return a.Name < b.Name end)
    
    local extendedItems = {}
    for _, tool in ipairs(allToolsList) do
         local name = tool.Name:lower()
         if currentSearch == "" or name:find(currentSearch:lower()) then
             table.insert(extendedItems, tool)
         end
    end
    
    for i, tool in ipairs(extendedItems) do
        if not extendedSlots[i] then extendedSlots[i] = createSlotUI(i, "Extended") end
        local slot = extendedSlots[i]
        slot.Visible = true
        applyDataToSlot(slot, tool, "Extended")
        
        local isEquipped = tool.Parent == char
        if isEquipped then
             slot.SelectionStroke.Transparency = 0
             slot.BackgroundColor3 = Color3.fromRGB(40,40,50)
        else
             slot.SelectionStroke.Transparency = 1
             slot.BackgroundColor3 = Color3.fromRGB(15,15,20)
        end
    end
    
    for i = #extendedItems + 1, #extendedSlots do
        extendedSlots[i].Visible = false
    end

    -- Update CanvasSize dynamically (v5.4 Fixed Scaling)
    local itemsPerRow = 8 
    local rowCount = math.ceil(#extendedItems / itemsPerRow)
    if rowCount < 1 then rowCount = 1 end
    
    local rowHeight = 0.23 -- Fixed height per row (relative to container)
    local paddingY = gridLayout.CellPadding.Y.Scale
    
    local totalRequiredHeight = rowCount * (rowHeight + paddingY)
    scrollContainer.CanvasSize = UDim2.new(0, 0, math.max(1, totalRequiredHeight), 0)
    
    -- MAINTAIN FIXED CELL HEIGHT (v5.4 FIX)
    gridLayout.CellSize = UDim2.new(0.115, 0, rowHeight, 0)
    end)
end

-- ============================================================================
-- EVENT BINDING
-- ============================================================================

local function resyncHotbar()
    task.spawn(function()
        local getInv = ReplicatedStorage:WaitForChild("GetInventory", 5)
        if getInv then
            local invData = getInv:InvokeServer() -- Get Map { ["1"] = "UUID" }
            if invData and invData.Hotbar then
                 
                 -- Retry finding tools for up to 3 seconds (in case of replication lag)
                 local attempts = 0
                 while attempts < 15 do
                     local toolsFound = 0
                     local available = {}
                     
                     local char = player.Character
                     local backpack = player:FindFirstChild("Backpack")
                     
                     if char then for _, t in pairs(char:GetChildren()) do if t:IsA("Tool") then table.insert(available, t) end end end
                     if backpack then for _, t in pairs(backpack:GetChildren()) do if t:IsA("Tool") then table.insert(available, t) end end end
                     
                     local tempAssignment = {}
                     local limit = 0
                     for _, _ in pairs(invData.Hotbar) do limit += 1 end
                     
                     local foundCount = 0
                     
                     for slotId, uId in pairs(invData.Hotbar) do
                         local slotNum = tonumber(slotId)
                         if slotNum then
                             for _, tool in pairs(available) do
                                 if tool:GetAttribute("UnitId") == uId then
                                     tempAssignment[slotNum] = tool
                                     foundCount += 1
                                     break
                                 end
                             end
                         end
                     end
                     
                     -- If we found all expected tools or a good expected amount, apply and break
                     if foundCount >= limit or foundCount > 0 then
                         for s, t in pairs(tempAssignment) do
                             hotbarAssignment[s] = t
                         end
                         updateInventory()
                         if foundCount >= limit then 
                             print("[InventoryHandler] Full hotbar sync complete (" .. foundCount .. "/" .. limit .. ")")
                             break 
                         end 
                     end
                     
                     attempts += 1
                     task.wait(0.2)
                 end
                 updateInventory()
            end
        end
    end)
end

-- NEW: Listen for Server-Push Hotbar updates
if updateHotbarRemote then
    updateHotbarRemote.OnClientEvent:Connect(function()
        -- print("[InventoryHandler] Server PUSHED hotbar update. Resyncing...")
        resyncHotbar()
    end)
end

-- ============================================================================
-- INITIALIZATION & BINDINGS
-- ============================================================================

-- Robust CoreGui Disabling (Loop to ensure it sticks)
local function disableDefaultBackpack()
    local success = false
    while not success do
        success = pcall(function()
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
        end)
        if success then break end
        task.wait(2)
    end
end
task.spawn(disableDefaultBackpack)

-- Handle Respawn
player.CharacterAdded:Connect(function(newChar)
    hotbarAssignment = {} -- Clear old tool references
    
    task.defer(function()
        connectEvents(newChar)
        resyncHotbar()     -- Re-map new tool instances
        disableDefaultBackpack()
    end)
end)

-- Initial Execution
if player.Character then
    task.defer(function()
        connectEvents(player.Character)
        resyncHotbar()
    end)
else
    -- Fallback for first load if character isn't ready
    task.spawn(resyncHotbar)
end

-- Search Functionality
searchBar:GetPropertyChangedSignal("Text"):Connect(function()
    currentSearch = searchBar.Text
    updateInventory()
end)

-- Toggle Inventory Key
UserInputService.InputBegan:Connect(function(input, gpe)
    if input.KeyCode == EXTENDED_KEY and not gpe then 
        UIManager.Toggle("InventoryUI")
    end
end)

-- External Toggles
toggleInv.Event:Connect(function(forceState)
    if forceState == true then
        UIManager.Open("InventoryUI")
    elseif forceState == false then
        UIManager.Close("InventoryUI")
    else
        UIManager.Toggle("InventoryUI")
    end
end)

-- Global Drag Tracking (Same logic as before, ensuring it works with new UI)
UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        lastInputPosition = Vector2.new(input.Position.X, input.Position.Y)
        
        -- Elevate Pending Drag to Active Drag
        if pendingDrag and not isDragging and draggingTool then
            local dist = (lastInputPosition - inputStartPosition).Magnitude
            local duration = os.clock() - inputStartTime
            
            if dist > DRAG_THRESHOLD_DIST or duration > DRAG_THRESHOLD_TIME then
                isDragging = true
                -- START THE VISUAL DRAG (Ghost creation moved here from InputBegan)
                if dragGhost then dragGhost:Destroy() end
                
                -- Need to find the physical slot to clone it
                local sourceSlot = nil
                if dragSourceType == "Hotbar" then
                    sourceSlot = slots[dragSourceIndex] and slots[dragSourceIndex].Frame
                else
                    sourceSlot = extendedSlots[dragSourceIndex]
                end

                if sourceSlot then
                    dragGhost = sourceSlot:Clone()
                    dragGhost.Name = "Ghost"
                    dragGhost.Size = UDim2.new(0, 70, 0, 85)
                    dragGhost.BackgroundTransparency = 1
                    dragGhost.ZIndex = 3000 -- Extra priority
                    dragGhost.Active = false 
                    dragGhost.Parent = screenGui
                    
                    -- CLEANUP GHOST
                    for _, c in pairs(dragGhost:GetChildren()) do 
                        if c.Name ~= "Viewport" and c.Name ~= "InfoFrame" then c:Destroy() end
                    end
                    for _, d in pairs(dragGhost:GetDescendants()) do
                        if d:IsA("GuiObject") and d.Name ~= "Viewport" and d.Name ~= "InfoFrame" and d.Name ~= "TierLabel" and d.Name ~= "NameLabel" then
                            if d:IsA("ImageLabel") or d:IsA("ImageButton") then d:Destroy() end
                        end
                    end
                    
                    dragGhost.Position = UDim2.new(0, lastInputPosition.X - 35, 0, lastInputPosition.Y - 42)
                    local gViewport = dragGhost:FindFirstChild("Viewport")
                    if gViewport then
                        local cam = gViewport:FindFirstChildOfClass("Camera")
                        if cam then gViewport.CurrentCamera = cam end
                    end
                    tween(dragGhost, { BackgroundTransparency = 0.8 })
                    
                    -- Audio Feedback
                    task.spawn(function() playSound(6895079853, 0.4, 0.1) end) -- v5.3 Shortened
                end
            end
        end

        if isDragging and dragGhost then
            dragGhost.Position = UDim2.new(0, lastInputPosition.X - 35, 0, lastInputPosition.Y - 42)
        end
    end
end)

local function getSlotUnderPosition(pos)
    -- Check Hotbar
    for i, slot in pairs(slots) do
        if slot and slot.Frame and slot.Frame.Visible then
            local absPos = slot.Frame.AbsolutePosition
            local absSize = slot.Frame.AbsoluteSize
            if pos.X >= absPos.X and pos.X <= absPos.X + absSize.X and
               pos.Y >= absPos.Y and pos.Y <= absPos.Y + absSize.Y then
                   return i, "Hotbar"
            end
        end
    end
    
    -- Check Extended Inventory Area (ScrollContainer)
    local invPos = scrollContainer.AbsolutePosition
    local invSize = scrollContainer.AbsoluteSize
    if pos.X >= invPos.X and pos.X <= invPos.X + invSize.X and
       pos.Y >= invPos.Y and pos.Y <= invPos.Y + invSize.Y then
        return nil, "Extended"
    end

    return nil, nil
end

UserInputService.InputEnded:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
        if isDragging then
            isDragging = false
            pendingDrag = false
            if dragGhost then dragGhost:Destroy() dragGhost = nil end
            
            local targetIndex, targetType = getSlotUnderPosition(lastInputPosition)
            
            if targetType == "Hotbar" and draggingTool and targetIndex then
                -- SWAP OR MOVE LOGIC
                local oldTargetTool = hotbarAssignment[targetIndex]
                
                hotbarAssignment[targetIndex] = draggingTool
                
                if dragSourceType == "Hotbar" and dragSourceIndex ~= targetIndex then
                     -- Moving from one hotbar slot to another
                     hotbarAssignment[dragSourceIndex] = oldTargetTool -- Swap! (Can be nil)
                end
                
                updateInventory()
                syncHotbarToServer()
                task.spawn(function() playSound(6895079853, 0.6, 0.1) end) -- v5.3 Shortened
            elseif targetType == "Extended" and dragSourceType == "Hotbar" then
                -- REMOVE FROM HOTBAR (Dropped back into inventory)
                if hotbarAssignment[dragSourceIndex] == draggingTool then
                    hotbarAssignment[dragSourceIndex] = nil
                    updateInventory()
                    syncHotbarToServer()
                    task.spawn(function() playSound(6895079853, 0.6, 0.1) end) -- v5.3 Shortened
                end
            end
            
            draggingTool = nil
            dragSourceIndex = nil
            dragSourceType = nil
        elseif pendingDrag then
            -- TREATED AS A CLICK (TAP)
            pendingDrag = false
            if draggingTool then
                equipToolSafe(draggingTool)
            end
            draggingTool = nil
            dragSourceIndex = nil
            dragSourceType = nil
        end
    end
end)

print("[InventoryHandler] Loaded Responsive Inventory System")
