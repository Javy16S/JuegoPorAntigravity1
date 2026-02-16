-- FloorCustomizer.client.lua
-- Description: Client-side UI for customizing tycoon base floor colors.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local UpdateFloorColorEvent = ReplicatedStorage:WaitForChild("UpdateFloorColor")

-- CONFIG
local COLORS = {
    {Name = "Black", Color = Color3.fromRGB(27, 42, 53)},
    {Name = "Red", Color = Color3.fromRGB(136, 62, 62)},
    {Name = "Blue", Color = Color3.fromRGB(82, 124, 174)},
    {Name = "Yellow", Color = Color3.fromRGB(226, 155, 64)},
    {Name = "White", Color = Color3.fromRGB(163, 162, 165)}
}

-- UI SETUP
local sg = Instance.new("ScreenGui")
sg.Name = "FloorCustomizerUI"
sg.ResetOnSpawn = false
sg.Enabled = false
sg.Parent = player:WaitForChild("PlayerGui")

-- 1. TOGGLE BUTTON (Open/Close) - Moved to bottom-right
local openBtn = Instance.new("TextButton")
openBtn.Name = "OpenButton"
openBtn.Size = UDim2.new(0.06, 0, 0.08, 0) -- Responsive sizing
openBtn.Position = UDim2.new(0.9, 0, 0.85, 0)
openBtn.AnchorPoint = Vector2.new(1, 1)
openBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
openBtn.Text = "🎨"
openBtn.TextColor3 = Color3.new(1, 1, 1)
openBtn.Font = Enum.Font.GothamBold
openBtn.TextScaled = true
openBtn.Visible = false
openBtn.Parent = sg

local opCorner = Instance.new("UICorner")
opCorner.CornerRadius = UDim.new(1, 0)
opCorner.Parent = openBtn

local opStroke = Instance.new("UIStroke")
opStroke.Thickness = 2
opStroke.Color = Color3.new(1, 1, 1)
opStroke.Parent = openBtn

-- 2. MAIN MENU FRAME (Right side)
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0.2, 0, 0.4, 0)
mainFrame.Position = UDim2.new(0.92, 0, 0.75, 0)
mainFrame.AnchorPoint = Vector2.new(1, 1)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BackgroundTransparency = 0.3
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Parent = sg

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 15)
uiCorner.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0.15, 0)
title.Position = UDim2.new(0, 0, 0.05, 0)
title.BackgroundTransparency = 1
title.Text = "PERSONALIZAR PISOS"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextScaled = true
title.Parent = mainFrame

-- FLOOR SELECTOR (Sub-container)
local floorLabel = Instance.new("TextLabel")
floorLabel.Size = UDim2.new(1, 0, 0.1, 0)
floorLabel.Position = UDim2.new(0, 0, 0.22, 0)
floorLabel.BackgroundTransparency = 1
floorLabel.Text = "SELECCIONAR PISO:"
floorLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
floorLabel.Font = Enum.Font.GothamBold
floorLabel.TextScaled = true
floorLabel.Parent = mainFrame

local floorContainer = Instance.new("ScrollingFrame")
floorContainer.Name = "FloorContainer"
floorContainer.Size = UDim2.new(0.85, 0, 0.12, 0) -- Even smaller as requested
floorContainer.Position = UDim2.new(0.075, 0, 0.38, 0)
floorContainer.BackgroundTransparency = 1
floorContainer.ScrollBarThickness = 0 
floorContainer.CanvasSize = UDim2.new(1.5, 0, 0, 0)
floorContainer.Parent = mainFrame

local floorGrid = Instance.new("UIGridLayout")
floorGrid.FillDirection = Enum.FillDirection.Horizontal
floorGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
floorGrid.CellPadding = UDim2.new(0.04, 0, 0, 0)
floorGrid.CellSize = UDim2.new(0.18, 0, 1, 0)
floorGrid.Parent = floorContainer

-- ASPECT RATIO: Ensure buttons aren't stretched
local arc = Instance.new("UIAspectRatioConstraint")
arc.AspectRatio = 1
arc.AspectType = Enum.AspectType.ScaleWithParentSize
arc.Parent = floorGrid

-- COLOR SELECTOR (Sub-container)
local buttonContainer = Instance.new("Frame")
buttonContainer.Name = "ButtonContainer"
buttonContainer.Size = UDim2.new(0.9, 0, 0.22, 0)
buttonContainer.Position = UDim2.new(0.05, 0, 0.62, 0)
buttonContainer.BackgroundTransparency = 1
buttonContainer.Parent = mainFrame

local uiList = Instance.new("UIListLayout")
uiList.FillDirection = Enum.FillDirection.Horizontal
uiList.HorizontalAlignment = Enum.HorizontalAlignment.Center
uiList.Padding = UDim.new(0.06, 0)
uiList.Parent = buttonContainer

-- STATE
local currentTycoon = nil
local currentFloorName = "Floor_0"
local menuOpen = false

-- LOGIC
local function clearFloorButtons()
    for _, child in pairs(floorContainer:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
end

local function selectFloor(name)
    currentFloorName = name
    for _, child in pairs(floorContainer:GetChildren()) do
        if child:IsA("TextButton") then
            child.BackgroundColor3 = (child.Name == name) and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(60, 60, 60)
            child.TextColor3 = (child.Name == name) and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
            -- Highlight stroke
            local st = child:FindFirstChild("UIStroke")
            if st then st.Enabled = (child.Name == name) end
        end
    end
end

local function updateFloorButtons()
    if not currentTycoon then return end
    clearFloorButtons()
    
    local level = currentTycoon:GetAttribute("BaseLevel") or 1
    for i = 0, level - 1 do
        local fName = "Floor_" .. i
        local btn = Instance.new("TextButton")
        btn.Name = fName
        btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        btn.Text = tostring(i + 1)
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.GothamBold
        btn.TextScaled = true
        btn.Parent = floorContainer
        
        local corner = Instance.new("UICorner", btn)
        corner.CornerRadius = UDim.new(0.3, 0)
        
        local st = Instance.new("UIStroke")
        st.Thickness = 2
        st.Color = Color3.new(1, 1, 1)
        st.Enabled = false
        st.Parent = btn
        
        btn.MouseButton1Click:Connect(function()
            selectFloor(fName)
        end)
    end
    selectFloor(currentFloorName)
end

openBtn.MouseButton1Click:Connect(function()
    menuOpen = not menuOpen
    mainFrame.Visible = menuOpen
    openBtn.Text = menuOpen and "✕" or "🎨"
    if menuOpen then updateFloorButtons() end
end)

local function updateCurrentFloor()
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    -- Check ZONE (Z < 75 is Platform/Lobby)
    local inSafeZone = hrp.Position.Z < 75
    
    if not inSafeZone or not currentTycoon then
        sg.Enabled = false
        menuOpen = false
        mainFrame.Visible = false
        openBtn.Text = "🎨"
        return
    end
    
    sg.Enabled = true
    openBtn.Visible = true
    
    -- Automatic detection as a hint (if menu is not open yet or just opened)
    if not menuOpen then
        local relativeY = hrp.Position.Y - currentTycoon:GetPivot().Position.Y
        local floorIdx = math.floor((relativeY + 5) / 18) 
        if floorIdx < 0 then floorIdx = 0 end
        currentFloorName = "Floor_" .. floorIdx
    end
end

-- Create buttons
for _, data in ipairs(COLORS) do
    local btn = Instance.new("TextButton")
    btn.Name = data.Name
    btn.Size = UDim2.new(0, 40, 0, 40)
    btn.BackgroundColor3 = data.Color
    btn.Text = ""
    btn.Parent = buttonContainer
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(1, 0)
    btnCorner.Parent = btn
    
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = Color3.new(1, 1, 1)
    stroke.Transparency = 0.5
    stroke.Parent = btn
    
    btn.MouseButton1Click:Connect(function()
        if currentTycoon and currentFloorName then
            UpdateFloorColorEvent:FireServer(currentTycoon, currentFloorName, data.Color)
            
            -- Small animation
            local originalSize = btn.Size
            btn:TweenSize(UDim2.new(0, 45, 0, 45), "Out", "Quad", 0.1, true, function()
                btn:TweenSize(originalSize, "In", "Quad", 0.1, true)
            end)
        end
    end)
end

-- Track tycoon ownership
RunService.Heartbeat:Connect(function()
    local foundTycoon = nil
    for _, t in pairs(Workspace:GetDescendants()) do
        if t:IsA("Model") and t.Name:match("TycoonBase_") and t:GetAttribute("OwnerUserId") == player.UserId then
            foundTycoon = t
            break
        end
    end
    
    currentTycoon = foundTycoon
    updateCurrentFloor()
end)

print("[FloorCustomizer] Client UI initialized.")
