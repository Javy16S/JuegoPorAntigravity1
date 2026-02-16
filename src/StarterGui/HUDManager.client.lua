-- HUDManager.client.lua
-- Skill: ui-framework
-- Description: Generates the premium Left Sidebar and Bottom HUDs.
-- Refactored for Responsiveness (Scale + AspectRatio)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local EconomyLogic = require(ReplicatedStorage.Modules:WaitForChild("EconomyLogic"))
local Maid = require(ReplicatedStorage.Modules:WaitForChild("Maid"))
local UIManager = require(ReplicatedStorage.Modules:WaitForChild("UIManager"))

local hudMaid = Maid.new()

-- CONSTANTS
local COLORS = {
    Shop = ColorSequence.new(Color3.fromRGB(255, 170, 0), Color3.fromRGB(255, 100, 0)),
    Trade = ColorSequence.new(Color3.fromRGB(0, 170, 255), Color3.fromRGB(0, 100, 255)),
    Index = ColorSequence.new(Color3.fromRGB(0, 255, 100), Color3.fromRGB(0, 150, 50)),
    VIP = ColorSequence.new(Color3.fromRGB(255, 215, 0), Color3.fromRGB(184, 134, 11)),
    Rebirth = ColorSequence.new(Color3.fromRGB(200, 200, 200), Color3.fromRGB(100, 100, 100)),
    Invite = ColorSequence.new(Color3.fromRGB(255, 255, 0), Color3.fromRGB(255, 200, 0)),
    -- NEW: Fusion & Eggs
    Fusion = ColorSequence.new(Color3.fromRGB(255, 100, 50), Color3.fromRGB(200, 50, 0)),
    Eggs = ColorSequence.new(Color3.fromRGB(255, 200, 100), Color3.fromRGB(255, 150, 50))
}

-- 1. Create Main ScreenGui
-- Fix: Prevent duplicates on respawn
if playerGui:FindFirstChild("MainHUD") then
    playerGui.MainHUD:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MainHUD"
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- 2. Left Menu Container (RESPONSIVE)
local leftMenu = Instance.new("Frame")
leftMenu.Name = "LeftMenu"
-- Scale: 15% width, 60% height. Positioned at 2% from left, centered vertically
leftMenu.Size = UDim2.new(0.15, 0, 0.6, 0) 
leftMenu.Position = UDim2.new(0.02, 0, 0.5, 0)
leftMenu.AnchorPoint = Vector2.new(0, 0.5)
leftMenu.BackgroundTransparency = 1
leftMenu.Parent = screenGui

-- Constraint to prevent it from getting too wide/narrow on extreme screens
local menuAspect = Instance.new("UIAspectRatioConstraint")
menuAspect.AspectRatio = 0.35 -- Keep it roughly vertical rectangular
menuAspect.AspectType = Enum.AspectType.ScaleWithParentSize
menuAspect.DominantAxis = Enum.DominantAxis.Height
menuAspect.Parent = leftMenu

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0.02, 0) -- Relative padding
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
layout.Parent = leftMenu

-- HELPER: Create Button
local function createMenuButton(name, text, colorSeq, order)
    local btn = Instance.new("Frame")
    btn.Name = name
    -- Size: 100% width of container, height automatic based on AspectRatio
    btn.Size = UDim2.new(1, 0, 0.12, 0) 
    btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    btn.BorderSizePixel = 0
    btn.Parent = leftMenu
    btn.LayoutOrder = order

    local gradient = Instance.new("UIGradient")
    gradient.Color = colorSeq
    gradient.Rotation = 45
    gradient.Parent = btn

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.2, 0) -- Relative corner
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = Color3.fromRGB(0, 0, 0)
    stroke.Parent = btn
    
    -- Aspect Ratio for Button integrity (prevents squashing)
    local aspect = Instance.new("UIAspectRatioConstraint")
    aspect.AspectRatio = 3.5 -- Width is 3.5x Height (Rectangular button)
    aspect.AspectType = Enum.AspectType.FitWithinMaxSize
    aspect.DominantAxis = Enum.DominantAxis.Width
    aspect.Parent = btn

    local label = Instance.new("TextLabel")
    label.Text = text
    label.Size = UDim2.new(0.9, 0, 0.8, 0)
    label.Position = UDim2.new(0.05, 0, 0.1, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.FredokaOne
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0
    label.TextScaled = true -- CRITICAL for responsiveness
    label.ZIndex = 1
    label.Parent = btn

    -- Hover Effect
    local scale = Instance.new("UIScale")
    scale.Parent = btn
    
    local textBtn = Instance.new("TextButton")
    textBtn.Size = UDim2.new(1, 0, 1, 0)
    textBtn.BackgroundTransparency = 1
    textBtn.Text = "" 
    textBtn.ZIndex = 2 
    textBtn.Parent = btn
    
    textBtn.MouseEnter:Connect(function()
        TweenService:Create(scale, TweenInfo.new(0.1), {Scale = 1.1}):Play()
    end)
    textBtn.MouseLeave:Connect(function()
        TweenService:Create(scale, TweenInfo.new(0.1), {Scale = 1.0}):Play()
    end)
    
    return textBtn
end

-- Solo menús funcionales (quitados Trade, VIP, Rebirth, Invite por ahora)
local shopBtn = createMenuButton("Shop", "🛒 Tienda", COLORS.Shop, 1)
local invBtn = createMenuButton("Inventory", "🎒 Mochila", COLORS.Index, 2) -- Using Index color or similar
local eggsBtn = createMenuButton("Eggs", "🥚 Eggs", COLORS.Eggs, 3)
local fusionBtn = createMenuButton("Fusion", "🔥 Fusión", COLORS.Fusion, 4)
local indexBtn = createMenuButton("Index", "📖 Índice", COLORS.Index, 5)
local tradeBtn = createMenuButton("Trade", "🤝 Trade", COLORS.Trade, 6)
local rebirthBtn = createMenuButton("Rebirth", "↻ Rebirth", COLORS.Rebirth, 7)

-- Optimize padding/size for many buttons (Dynamic now thanks to Stack Layout)

-- Shop Button Handler
hudMaid:Give(shopBtn.MouseButton1Click:Connect(function()
    print("[HUD] Shop button clicked")
    UIManager.Toggle("VIPShopUI")
end))

-- Inventory Button Handler
hudMaid:Give(invBtn.MouseButton1Click:Connect(function()
    print("[HUD] Inventory button clicked")
    UIManager.Toggle("InventoryUI")
end))

-- Rebirth Button Handler
hudMaid:Give(rebirthBtn.MouseButton1Click:Connect(function()
    print("[HUD] Rebirth button clicked")
    UIManager.Toggle("RebirthUI")
end))

-- Eggs Button Handler
hudMaid:Give(eggsBtn.MouseButton1Click:Connect(function()
    print("[HUD] Eggs button clicked")
    UIManager.Toggle("EggsUI")
end))

-- Trade Button Handler
hudMaid:Give(tradeBtn.MouseButton1Click:Connect(function()
    print("[HUD] Trade button clicked")
    
    -- Smart Redirect: If a trade is already active (minimized), reopen it.
    -- Otherwise, open the Lobby Browser to start a new one.
    if _G.IsTradeActive and _G.IsTradeActive() then
        UIManager.Toggle("TradeUI")
    else
        UIManager.Toggle("LobbyUI")
    end
end))

-- Fusion Button Handler
hudMaid:Give(fusionBtn.MouseButton1Click:Connect(function()
    print("[HUD] Fusion button clicked")
    UIManager.Toggle("FusionUI")
end))

-- Index Button Handler
hudMaid:Give(indexBtn.MouseButton1Click:Connect(function()
    print("[HUD] Index button clicked")
    UIManager.Toggle("IndexUI")
end))

-- 3. Bottom HUD (Currency)
local currencyFrame = Instance.new("Frame")
currencyFrame.Name = "CurrencyFrame"
-- Scale: 20% width, 8% height. Bottom-Left anchored.
currencyFrame.Size = UDim2.new(0.2, 0, 0.08, 0)
currencyFrame.Position = UDim2.new(0.02, 0, 0.95, 0) -- 5% margin from bottom
currencyFrame.AnchorPoint = Vector2.new(0, 1)
currencyFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
currencyFrame.BackgroundTransparency = 0.5
currencyFrame.Parent = screenGui

local cCorner = Instance.new("UICorner")
cCorner.CornerRadius = UDim.new(0.2, 0)
cCorner.Parent = currencyFrame

-- Aspect Ratio Maintenance
local cAspect = Instance.new("UIAspectRatioConstraint")
cAspect.AspectRatio = 3.5 -- Ensure it doesn't get too thin
cAspect.Parent = currencyFrame

local cashIcon = Instance.new("TextLabel")
cashIcon.Text = "💵"
cashIcon.Size = UDim2.new(0.25, 0, 1, 0)
cashIcon.BackgroundTransparency = 1
cashIcon.TextScaled = true
cashIcon.Parent = currencyFrame

local cashLabel = Instance.new("TextLabel")
cashLabel.Name = "CashLabel"
cashLabel.Text = "$0"
cashLabel.Size = UDim2.new(0.7, 0, 0.8, 0)
cashLabel.Position = UDim2.new(0.25, 0, 0.1, 0)
cashLabel.BackgroundTransparency = 1
cashLabel.Font = Enum.Font.FredokaOne
cashLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
cashLabel.TextScaled = true
cashLabel.TextXAlignment = Enum.TextXAlignment.Left
cashLabel.Parent = currencyFrame

-- Update Cash
local leaderstats = player:WaitForChild("leaderstats", 10)
if leaderstats then
    local cashVal = leaderstats:WaitForChild("Cash")
    
    hudMaid:Give(cashVal.Changed:Connect(function(val)
        cashLabel.Text = "$" .. EconomyLogic.Abbreviate(val)
    end))
    -- Init
    cashLabel.Text = "$" .. EconomyLogic.Abbreviate(cashVal.Value)
end



-- 4. Speed HUD (Above Currency)
local speedFrame = Instance.new("Frame")
speedFrame.Name = "SpeedFrame"
-- Scale: 15% width, 6% height. Above Currency.
speedFrame.Size = UDim2.new(0.15, 0, 0.06, 0)
speedFrame.Position = UDim2.new(0.02, 0, 0.86, 0) -- Above currency
speedFrame.AnchorPoint = Vector2.new(0, 1)
speedFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
speedFrame.BackgroundTransparency = 0.5
speedFrame.Parent = screenGui

local sCorner = Instance.new("UICorner")
sCorner.CornerRadius = UDim.new(0.2, 0)
sCorner.Parent = speedFrame

local sAspect = Instance.new("UIAspectRatioConstraint")
sAspect.AspectRatio = 3
sAspect.Parent = speedFrame

local speedIcon = Instance.new("TextLabel")
speedIcon.Text = "⚡"
speedIcon.Size = UDim2.new(0.25, 0, 1, 0)
speedIcon.BackgroundTransparency = 1
speedIcon.TextScaled = true
speedIcon.Parent = speedFrame

local speedLabel = Instance.new("TextLabel")
speedLabel.Name = "SpeedLabel"
speedLabel.Text = "16 SPD"
speedLabel.Size = UDim2.new(0.7, 0, 0.8, 0)
speedLabel.Position = UDim2.new(0.25, 0, 0.1, 0)
speedLabel.BackgroundTransparency = 1
speedLabel.Font = Enum.Font.FredokaOne
speedLabel.TextColor3 = Color3.fromRGB(0, 255, 255) 
speedLabel.TextScaled = true
speedLabel.TextXAlignment = Enum.TextXAlignment.Left
speedLabel.Parent = speedFrame

-- Update Loop (Visual)
local RunService = game:GetService("RunService")
hudMaid:Give(RunService.Heartbeat:Connect(function()
    if player.Character then
        local hum = player.Character:FindFirstChild("Humanoid")
        if hum then
            speedLabel.Text = math.floor(hum.WalkSpeed) .. " SPD"
        end
    end
end))

-- SYNC SPEED TO SERVER (For Leaderboard)
task.spawn(function()
    local syncRemote = ReplicatedStorage:WaitForChild("SyncSpeed", 5)
    while true do
        task.wait(2)
        if player.Character and syncRemote then
            local hum = player.Character:FindFirstChild("Humanoid")
            if hum then
                syncRemote:FireServer(hum.WalkSpeed)
            end
        end
    end
end)

print("[HUDManager] Loaded Premium Responsive HUD")
