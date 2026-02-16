-- SimpleShopUI.client.lua
-- Estética: Clean & Vibrant (Leveled Up)
-- Features: Tabs (Sell, Boosts)
-- Refactored for Responsiveness: PURE SCALE (No Offsets)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- MODULES
local BoostManager = require(ReplicatedStorage.Modules:WaitForChild("BoostManager"))
local EconomyLogic = require(ReplicatedStorage.Modules:WaitForChild("EconomyLogic"))

-- REMOTES
local SellAllUnits = ReplicatedStorage:WaitForChild("SellAllUnits", 10)
local SellHandUnit = ReplicatedStorage:WaitForChild("SellHandUnit", 10)
local GetSellValues = ReplicatedStorage:WaitForChild("GetSellValues", 10)
local BuyBoostRemote = ReplicatedStorage:WaitForChild("BuyBoost", 10)

-- PREVENT DUPLICATES
if playerGui:FindFirstChild("BlackMarketShop") then
    playerGui.BlackMarketShop:Destroy()
end

-- UI CREATION
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SimpleShopUI"
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Background Overlay
local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 1
overlay.Visible = false
overlay.Parent = screenGui

-- Main Container
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
-- Scale: 60% Width
mainFrame.Size = UDim2.new(0.6, 0, 0.7, 0) 
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 18, 22)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Parent = screenGui

-- Aspect Ratio
local mainAspect = Instance.new("UIAspectRatioConstraint")
mainAspect.AspectRatio = 1.3 
mainAspect.AspectType = Enum.AspectType.FitWithinMaxSize
mainAspect.Parent = mainFrame

-- MAX SIZE
local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MaxSize = Vector2.new(800, 600)
sizeConstraint.Parent = mainFrame

local uiCorner = Instance.new("UICorner", mainFrame)
uiCorner.CornerRadius = UDim.new(0.04, 0)

local uiStroke = Instance.new("UIStroke", mainFrame)
uiStroke.Color = Color3.fromRGB(0, 255, 150)
uiStroke.Thickness = 2
uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
uiStroke.Parent = mainFrame

-- TABS CONTAINER
local tabsContainer = Instance.new("Frame")
tabsContainer.Name = "Tabs"
tabsContainer.Size = UDim2.new(1, 0, 0.15, 0)
tabsContainer.BackgroundTransparency = 1
tabsContainer.Parent = mainFrame

local contentContainer = Instance.new("Frame")
contentContainer.Name = "Content"
contentContainer.Size = UDim2.new(1, 0, 0.85, 0)
contentContainer.Position = UDim2.new(0, 0, 0.15, 0)
contentContainer.BackgroundTransparency = 1
contentContainer.Parent = mainFrame

-- PAGES
local sellPage = Instance.new("Frame")
sellPage.Name = "SellPage"
sellPage.Size = UDim2.new(1, 0, 1, 0)
sellPage.BackgroundTransparency = 1
sellPage.Visible = true
sellPage.Parent = contentContainer

local boostsPage = Instance.new("ScrollingFrame")
boostsPage.Name = "BoostsPage"
boostsPage.Size = UDim2.new(0.95, 0, 0.95, 0)
boostsPage.Position = UDim2.new(0.025, 0, 0.025, 0)
boostsPage.BackgroundTransparency = 1
boostsPage.Visible = false
boostsPage.ScrollBarThickness = 4
boostsPage.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 150)
boostsPage.Parent = contentContainer

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0.3, 0, 0.45, 0) -- Pure Scale
grid.CellPadding = UDim2.new(0.02, 0, 0.05, 0)
grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
grid.Parent = boostsPage

-- TAB BUTTONS LOGIC
local activeTab = "Sell"
local tabButtons = {}

local function switchTab(name)
    activeTab = name
    sellPage.Visible = (name == "Sell")
    boostsPage.Visible = (name == "Boosts")
    
    for n, btn in pairs(tabButtons) do
        local isActive = (n == name)
        TweenService:Create(btn, TweenInfo.new(0.2), {
            BackgroundColor3 = isActive and Color3.fromRGB(0, 255, 150) or Color3.fromRGB(30, 35, 40),
            TextColor3 = isActive and Color3.new(0,0,0) or Color3.new(1,1,1)
        }):Play()
    end
end

local function createTabButton(name, text, xPos)
    local btn = Instance.new("TextButton")
    btn.Name = name .. "Tab"
    btn.Size = UDim2.new(0.5, 0, 1, 0)
    btn.Position = UDim2.new(xPos, 0, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(30, 35, 40)
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.Font = Enum.Font.GothamBold
    btn.TextScaled = true 
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Parent = tabsContainer
    
    btn.MouseButton1Click:Connect(function()
        switchTab(name)
    end)
    
    tabButtons[name] = btn
    
    local c = Instance.new("UICorner", btn)
    c.CornerRadius = UDim.new(0.2, 0)
end

createTabButton("Sell", "VENDER", 0)
createTabButton("Boosts", "POTENCIADORES", 0.5)

-- ============================================================================
-- PAGE 1: SELL (Black Market Logic)
-- ============================================================================

-- Stats
local statsLabel = Instance.new("TextLabel")
statsLabel.Size = UDim2.new(0.9, 0, 0.1, 0)
statsLabel.Position = UDim2.new(0.05, 0, 0.05, 0)
statsLabel.BackgroundTransparency = 1
statsLabel.Text = "CARGANDO..."
statsLabel.TextColor3 = Color3.fromRGB(180, 200, 190)
statsLabel.Font = Enum.Font.GothamMedium
statsLabel.TextScaled = true
statsLabel.Parent = sellPage

local function createStyledButton(name, text, position, bgColor, parent)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(0.6, 0, 0.15, 0)
    btn.AnchorPoint = Vector2.new(0.5, 0)
    btn.Position = position
    btn.BackgroundColor3 = bgColor
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextScaled = true
    btn.Parent = parent
    
    local corner = Instance.new("UICorner", btn)
    corner.CornerRadius = UDim.new(0.2, 0)
    
    local stroke = Instance.new("UIStroke", btn)
    stroke.Thickness = 1.5
    stroke.Color = Color3.new(1,1,1)
    stroke.Transparency = 0.7
    
    -- Constraint to keep button shape nice
    local aspect = Instance.new("UIAspectRatioConstraint")
    aspect.AspectRatio = 4 -- Wide button
    aspect.Parent = btn
    
    return btn
end

local sellAllBtn = createStyledButton("SellAll", "VENDER TODO", UDim2.new(0.5, 0, 0.3, 0), Color3.fromRGB(0, 150, 80), sellPage)
local sellHandBtn = createStyledButton("SellHand", "VENDER MANO", UDim2.new(0.5, 0, 0.6, 0), Color3.fromRGB(100, 60, 180), sellPage)

local sellAllValue = Instance.new("TextLabel")
sellAllValue.Size = UDim2.new(1, 0, 0.08, 0)
sellAllValue.Position = UDim2.new(0, 0, 0.46, 0)
sellAllValue.BackgroundTransparency = 1
sellAllValue.TextColor3 = Color3.fromRGB(100, 255, 150)
sellAllValue.Font = Enum.Font.GothamBold
sellAllValue.TextScaled = true
sellAllValue.Parent = sellPage

local sellHandValue = Instance.new("TextLabel")
sellHandValue.Size = UDim2.new(1, 0, 0.08, 0)
sellHandValue.Position = UDim2.new(0, 0, 0.76, 0)
sellHandValue.BackgroundTransparency = 1
sellHandValue.TextColor3 = Color3.fromRGB(200, 150, 255)
sellHandValue.Font = Enum.Font.GothamBold
sellHandValue.TextScaled = true
sellHandValue.Parent = sellPage

-- Events
sellAllBtn.MouseButton1Click:Connect(function()
    if SellAllUnits:InvokeServer().success then
        openUI() 
    end
end)
sellHandBtn.MouseButton1Click:Connect(function()
    if SellHandUnit:InvokeServer().success then
        openUI()
    end
end)


-- ============================================================================
-- PAGE 2: BOOSTS
-- ============================================================================

local function populateBoosts()
    for _, child in pairs(boostsPage:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    local boosts = BoostManager.getAllBoosts() -- { {Id=..., Name=...}, ... }
    
    for _, info in pairs(boosts) do
        local item = Instance.new("Frame")
        item.BackgroundColor3 = Color3.fromRGB(25, 30, 35)
        item.Parent = boostsPage
        Instance.new("UICorner", item).CornerRadius = UDim.new(0.1, 0)
        
        -- Aspect Ratio for Boost Item
        local itemAspect = Instance.new("UIAspectRatioConstraint")
        itemAspect.AspectRatio = 0.8
        itemAspect.Parent = item
        
        local icon = Instance.new("ImageLabel")
        icon.Size = UDim2.new(0.6, 0, 0.4, 0)
        icon.Position = UDim2.new(0.2, 0, 0.1, 0)
        icon.BackgroundTransparency = 1
        icon.Image = info.Icon
        icon.Parent = item
        
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.9, 0, 0.15, 0)
        lbl.Position = UDim2.new(0.05, 0, 0.55, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = info.Name
        lbl.TextColor3 = Color3.new(1,1,1)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextScaled = true
        lbl.Parent = item
        
        local cost = Instance.new("TextButton")
        cost.Size = UDim2.new(0.8, 0, 0.15, 0)
        cost.Position = UDim2.new(0.1, 0, 0.78, 0)
        cost.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        cost.Text = "$" .. EconomyLogic.Abbreviate(info.Price)
        cost.Font = Enum.Font.GothamBold
        cost.TextScaled = true
        cost.TextColor3 = Color3.new(0,0,0)
        cost.Parent = item
        Instance.new("UICorner", cost).CornerRadius = UDim.new(0.3, 0)
        
        cost.MouseButton1Click:Connect(function()
            local success, msg = BuyBoostRemote:InvokeServer(info.Id)
            if success then
                -- SFX
                local s = Instance.new("Sound")
                s.SoundId = "rbxassetid://6003664724" -- Magic sound
                s.Parent = SoundService
                s:Play()
                Debris:AddItem(s, 2)
            end
        end)
    end
end

-- ============================================================================
-- SHARED LOGIC
-- ============================================================================

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "Close"
closeBtn.Size = UDim2.new(0.08, 0, 0.08, 0)
closeBtn.Position = UDim2.new(0.92, 0, 0, 0)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.FredokaOne
closeBtn.Parent = mainFrame

-- Aspect constraint for close button
local closeAspect = Instance.new("UIAspectRatioConstraint")
closeAspect.AspectRatio = 1
closeAspect.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function() closeUI() end)

function openUI()
    if mainFrame.Visible then 
        -- Just refresh data
    else
        mainFrame.Visible = true
        overlay.Visible = true
        mainFrame.Size = UDim2.new(0,0,0,0)
        TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Size = UDim2.new(0.6, 0, 0.7, 0)}):Play()
        TweenService:Create(overlay, TweenInfo.new(0.3), {BackgroundTransparency = 0.5}):Play()
    end
    
    -- Load Sell Data
    task.spawn(function()
        local data = GetSellValues:InvokeServer()
        if data then
            statsLabel.Text = data.count .. " UNIDADES"
            -- Format
            sellAllValue.Text = "$" .. EconomyLogic.Abbreviate(data.total)
            sellHandValue.Text = "$" .. EconomyLogic.Abbreviate(data.hand)
        end
    end)
    
    -- Load Boosts if first time or refresh?
    populateBoosts()
    
    switchTab(activeTab)
end

function closeUI()
    TweenService:Create(mainFrame, TweenInfo.new(0.2), {Size = UDim2.new(0,0,0,0)}):Play()
    TweenService:Create(overlay, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
    task.wait(0.2)
    mainFrame.Visible = false
    overlay.Visible = false
end


-- PROXIMITY
local function setupZone(zone)
    if not zone:IsA("BasePart") then return end
    
    local prompt = zone:FindFirstChildWhichIsA("ProximityPrompt") or zone:WaitForChild("ProximityPrompt", 5)
    if prompt then
        prompt.Triggered:Connect(function(u)
            if u == player then openUI() end
        end)
    end
end

for _, z in pairs(CollectionService:GetTagged("SellZone")) do setupZone(z) end
CollectionService:GetInstanceAddedSignal("SellZone"):Connect(setupZone)

print("[UniversalShop] Loaded (Pure Scale).")
