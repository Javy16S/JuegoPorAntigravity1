-- HUDManager.client.lua
-- Skill: ui-framework
-- Description: Generates the premium Left Sidebar and Bottom HUDs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

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
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- 2. Left Menu Container
local leftMenu = Instance.new("Frame")
leftMenu.Name = "LeftMenu"
leftMenu.Size = UDim2.new(0, 250, 0.6, 0)
leftMenu.Position = UDim2.new(0, 10, 0.2, 0)
leftMenu.BackgroundTransparency = 1
leftMenu.Parent = screenGui

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 10)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = leftMenu

-- HELPER: Create Button
local function createMenuButton(name, text, colorSeq, order)
    local btn = Instance.new("Frame")
    btn.Name = name
    btn.Size = UDim2.new(0, 160, 0, 50)
    btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    btn.BorderSizePixel = 0
    btn.Parent = leftMenu
    btn.LayoutOrder = order

    local gradient = Instance.new("UIGradient")
    gradient.Color = colorSeq
    gradient.Rotation = 45
    gradient.Parent = btn

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = Color3.fromRGB(0, 0, 0)
    stroke.Parent = btn

    local label = Instance.new("TextLabel")
    label.Text = text
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.FredokaOne
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0
    label.TextSize = 20
    label.ZIndex = 1
    label.Parent = btn

    -- Hover Effect
    local scale = Instance.new("UIScale")
    scale.Parent = btn
    
    -- FIX: TextButton must be COMPLETELY invisible
    local textBtn = Instance.new("TextButton")
    textBtn.Size = UDim2.new(1, 0, 1, 0)
    textBtn.BackgroundTransparency = 1
    textBtn.Text = "" -- IMPORTANT: Empty text!
    textBtn.ZIndex = 2 -- Above the label
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
local eggsBtn = createMenuButton("Eggs", "🥚 Eggs", COLORS.Eggs, 2)
local fusionBtn = createMenuButton("Fusion", "🔥 Fusión", COLORS.Fusion, 3)
local indexBtn = createMenuButton("Index", "📖 Índice", COLORS.Index, 4)


shopBtn.MouseButton1Click:Connect(function()
    print("[HUD] Shop button clicked")
    local shopGui = playerGui:FindFirstChild("BrainrotShop")
    if shopGui then 
        local frame = shopGui:FindFirstChild("ShopFrame")
        if frame then
            print("[HUD] Toggling ShopFrame visibility: " .. tostring(not frame.Visible))
            frame.Visible = not frame.Visible
        else
            warn("[HUD] ShopFrame not found in BrainrotShop")
        end
    else
        warn("[HUD] BrainrotShop ScreenGui not found!")
    end
end)

-- NEW: Eggs Button Handler
eggsBtn.MouseButton1Click:Connect(function()
    print("[HUD] Eggs button clicked")
    local eggsGui = playerGui:FindFirstChild("EggsMainGUI") -- New Name
    if eggsGui then
        local frame = eggsGui:FindFirstChild("MainFrame")
        if frame then
            frame.Visible = not frame.Visible
            if frame.Visible then eggsGui.DisplayOrder = 20 else eggsGui.DisplayOrder = 10 end
        else
            warn("[HUD] MainFrame not found in EggsMainGUI")
        end
    else
        warn("[HUD] EggsMainGUI not found (Check name collision with script?)")
    end
end)

-- NEW: Fusion Button Handler
fusionBtn.MouseButton1Click:Connect(function()
    print("[HUD] Fusion button clicked")
    local fusionGui = playerGui:FindFirstChild("FusionMainGUI") -- New Name
    if fusionGui then
        local frame = fusionGui:FindFirstChild("MainFrame")
        if frame then
            frame.Visible = not frame.Visible
            if frame.Visible then fusionGui.DisplayOrder = 20 else fusionGui.DisplayOrder = 10 end
        end
    else
        warn("[HUD] FusionMainGUI not found")
    end
end)

-- NEW: Index Button Handler
indexBtn.MouseButton1Click:Connect(function()
    print("[HUD] Index button clicked")
    local indexGui = playerGui:FindFirstChild("IndexMainGUI") -- New Name (was BrainrotIndex)
    if indexGui then
        local frame = indexGui:FindFirstChild("MainFrame")
        if frame then
            frame.Visible = not frame.Visible
            if frame.Visible then indexGui.DisplayOrder = 20 else indexGui.DisplayOrder = 10 end
        end
    else
        warn("[HUD] IndexMainGUI not found")
    end
end)

-- 3. Bottom HUD (Currency)
local currencyFrame = Instance.new("Frame")
currencyFrame.Name = "CurrencyFrame"
currencyFrame.Size = UDim2.new(0, 200, 0, 60)
currencyFrame.Position = UDim2.new(0, 20, 1, -80)
currencyFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
currencyFrame.BackgroundTransparency = 0.5
currencyFrame.Parent = screenGui

local cCorner = Instance.new("UICorner")
cCorner.CornerRadius = UDim.new(0, 15)
cCorner.Parent = currencyFrame

local cashIcon = Instance.new("TextLabel")
cashIcon.Text = "💵"
cashIcon.Size = UDim2.new(0, 50, 1, 0)
cashIcon.BackgroundTransparency = 1
cashIcon.TextSize = 30
cashIcon.Parent = currencyFrame

local cashLabel = Instance.new("TextLabel")
cashLabel.Name = "CashLabel"
cashLabel.Text = "$0"
cashLabel.Size = UDim2.new(1, -60, 1, 0)
cashLabel.Position = UDim2.new(0, 60, 0, 0)
cashLabel.BackgroundTransparency = 1
cashLabel.Font = Enum.Font.FredokaOne
cashLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
cashLabel.TextSize = 28
cashLabel.TextXAlignment = Enum.TextXAlignment.Left
cashLabel.Parent = currencyFrame

-- Update Cash
local leaderstats = player:WaitForChild("leaderstats", 10)
if leaderstats then
    local cashVal = leaderstats:WaitForChild("Cash")
    
    local function formatNumber(n)
        if n >= 1e9 then return string.format("%.2f B", n/1e9) end
        if n >= 1e6 then return string.format("%.2f M", n/1e6) end
        if n >= 1e3 then return string.format("%.2f K", n/1e3) end
        return tostring(n)
    end
    
    cashVal.Changed:Connect(function(val)
        cashLabel.Text = "$" .. formatNumber(val)
    end)
    -- Init
    cashLabel.Text = "$" .. formatNumber(cashVal.Value)
end



-- 4. Speed HUD (Above Currency)
local speedFrame = Instance.new("Frame")
speedFrame.Name = "SpeedFrame"
speedFrame.Size = UDim2.new(0, 150, 0, 40)
speedFrame.Position = UDim2.new(0, 20, 1, -150) -- Above cash
speedFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
speedFrame.BackgroundTransparency = 0.5
speedFrame.Parent = screenGui

local sCorner = Instance.new("UICorner")
sCorner.CornerRadius = UDim.new(0, 10)
sCorner.Parent = speedFrame

local speedIcon = Instance.new("TextLabel")
speedIcon.Text = "⚡"
speedIcon.Size = UDim2.new(0, 40, 1, 0)
speedIcon.BackgroundTransparency = 1
speedIcon.TextSize = 24
speedIcon.Parent = speedFrame

local speedLabel = Instance.new("TextLabel")
speedLabel.Name = "SpeedLabel"
speedLabel.Text = "16 SPD"
speedLabel.Size = UDim2.new(1, -50, 1, 0)
speedLabel.Position = UDim2.new(0, 50, 0, 0)
speedLabel.BackgroundTransparency = 1
speedLabel.Font = Enum.Font.FredokaOne
speedLabel.TextColor3 = Color3.fromRGB(0, 255, 255) -- Cyan
speedLabel.TextSize = 20
speedLabel.TextXAlignment = Enum.TextXAlignment.Left
speedLabel.Parent = speedFrame

-- Update Loop
local RunService = game:GetService("RunService")
RunService.Heartbeat:Connect(function()
    if player.Character then
        local hum = player.Character:FindFirstChild("Humanoid")
        if hum then
            speedLabel.Text = math.floor(hum.WalkSpeed) .. " SPD"
        end
    end
end)

print("[HUDManager] Loaded Premium HUD")
