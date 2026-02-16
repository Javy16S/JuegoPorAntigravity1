-- EggsUI.client.lua
-- Skill: ui-framework
-- Description: Premium UI for Eggs with Multi-Open support. Fixed visibility and added animations.
-- Refactored for Responsiveness: PURE SCALE (No Offsets)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remotes
local PurchaseEgg = ReplicatedStorage:WaitForChild("PurchaseEgg", 10)
local UIManager = require(ReplicatedStorage.Modules:WaitForChild("UIManager"))

-- Egg Data
local EGGS = {
    {
        Id = "BasicEgg",
        Name = "Basic Egg",
        Icon = "🥚",
        Price = 1000,
        Color = Color3.fromRGB(240, 240, 240),
        Description = "Perfecto para empezar.",
        Chances = {
            {"Common", "85%", Color3.fromRGB(200, 200, 200)},
            {"Rare", "12%", Color3.fromRGB(0, 170, 255)},
            {"Epic", "3%", Color3.fromRGB(170, 0, 255)}
        }
    },
    {
        Id = "PremiumEgg",
        Name = "Premium Egg",
        Icon = "✨",
        Price = 50000,
        Color = Color3.fromRGB(0, 170, 255),
        Description = "Mejores ratios de rareza.",
        Chances = {
            {"Rare", "65%", Color3.fromRGB(0, 170, 255)},
            {"Epic", "28%", Color3.fromRGB(170, 0, 255)},
            {"Legendary", "7%", Color3.fromRGB(255, 170, 0)}
        }
    },
    {
        Id = "DivineEgg",
        Name = "Divine Egg",
        Icon = "🌟",
        Price = 10000000,
        Color = Color3.fromRGB(255, 215, 0),
        Description = "Solo para leyendas.",
        Chances = {
            {"Epic", "50%", Color3.fromRGB(170, 0, 255)},
            {"Legendary", "35%", Color3.fromRGB(255, 170, 0)},
            {"Mythic", "15%", Color3.fromRGB(255, 0, 85)}
        }
    }
}

-- Prevent duplicates
if playerGui:FindFirstChild("EggsMainGUI") then
    playerGui.EggsMainGUI:Destroy()
end

-- Create UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EggsMainGUI"
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling 
screenGui.ResetOnSpawn = false
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
mainFrame.Name = "EggFrame"
mainFrame.Size = UDim2.new(0.6, 0, 0.7, 0) -- Scaled size
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false -- START HIDDEN
mainFrame.ZIndex = 2
mainFrame.Parent = screenGui

-- Aspect Ratio Constraint [USER REQUEST: 1.67]
local mainAspect = Instance.new("UIAspectRatioConstraint")
mainAspect.AspectRatio = 1.67 
mainAspect.AspectType = Enum.AspectType.FitWithinMaxSize
mainAspect.DominantAxis = Enum.DominantAxis.Width
mainAspect.Parent = mainFrame

-- MAX SIZE CONSTRAINT (Prevent Giant UI on Desktop)
local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MaxSize = Vector2.new(900, 600)
sizeConstraint.Parent = mainFrame

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0.05, 0) -- Relative styling
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Thickness = 3
mainStroke.Color = Color3.fromRGB(50, 50, 80)
mainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
mainStroke.Parent = mainFrame

-- Top Bar / Title
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0.15, 0) -- 15% Height
topBar.BackgroundTransparency = 1
topBar.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 1, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "✧ GACHA DE BRAINROTS ✧"
titleLabel.TextColor3 = Color3.new(1, 1, 1)
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.TextScaled = true -- Responsive Font
titleLabel.Parent = topBar

-- Close Button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0.06, 0, 0.1, 0) -- Relative to MainFrame
closeBtn.Position = UDim2.new(0.92, 0, 0.02, 0)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextScaled = true
closeBtn.Parent = mainFrame
mainFrame.Visible = false

local closeAspect = Instance.new("UIAspectRatioConstraint")
closeAspect.AspectRatio = 1
closeAspect.Parent = closeBtn

local closeCorner = Instance.new("UICorner"); closeCorner.CornerRadius = UDim.new(1, 0); closeCorner.Parent = closeBtn

-- Cards Container
local cardsContainer = Instance.new("Frame")
cardsContainer.Size = UDim2.new(0.96, 0, 0.8, 0)
cardsContainer.Position = UDim2.new(0.02, 0, 0.18, 0)
cardsContainer.BackgroundTransparency = 1
cardsContainer.Parent = mainFrame

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0.02, 0) -- 2% Spacing
layout.Parent = cardsContainer

local function formatNumber(n)
    if n >= 1e9 then return string.format("%.1fB", n/1e9) end
    if n >= 1e6 then return string.format("%.1fM", n/1e6) end
    if n >= 1e3 then return string.format("%.1fK", n/1e3) end
    return tostring(n)
end

-- Create Cards
for _, egg in ipairs(EGGS) do
    local card = Instance.new("Frame")
    -- Size: ~30% width each (3 cards)
    card.Size = UDim2.new(0.31, 0, 1, 0)
    card.BackgroundColor3 = Color3.fromRGB(30, 30, 48)
    card.Parent = cardsContainer
    
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.05, 0); c.Parent = card
    local s = Instance.new("UIStroke"); s.Thickness = 2; s.Color = egg.Color; s.Parent = card

    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(1, 0, 0.25, 0)
    icon.Position = UDim2.new(0, 0, 0.05, 0)
    icon.BackgroundTransparency = 1; icon.Text = egg.Icon
    icon.TextScaled = true
    icon.Parent = card

    local name = Instance.new("TextLabel")
    name.Size = UDim2.new(0.9, 0, 0.1, 0)
    name.Position = UDim2.new(0.05, 0, 0.35, 0)
    name.BackgroundTransparency = 1; name.Text = egg.Name; name.Font = Enum.Font.GothamBlack; name.TextColor3 = egg.Color
    name.TextScaled = true
    name.Parent = card

    local price = Instance.new("TextLabel")
    price.Size = UDim2.new(0.9, 0, 0.08, 0)
    price.Position = UDim2.new(0.05, 0, 0.45, 0)
    price.BackgroundTransparency = 1; price.Text = "$" .. formatNumber(egg.Price); price.Font = Enum.Font.GothamBold; price.TextColor3 = Color3.fromRGB(0, 255, 127)
    price.TextScaled = true
    price.Parent = card

    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(0.9, 0, 0.12, 0)
    desc.Position = UDim2.new(0.05, 0, 0.55, 0)
    desc.BackgroundTransparency = 1; desc.Text = egg.Description; desc.Font = Enum.Font.Gotham; desc.TextColor3 = Color3.fromRGB(180, 180, 200)
    desc.TextScaled = true
    desc.TextWrapped = true
    desc.Parent = card

    -- Buttons
    local btnStack = Instance.new("Frame")
    btnStack.Size = UDim2.new(0.9, 0, 0.3, 0)
    btnStack.Position = UDim2.new(0.05, 0, 0.68, 0)
    btnStack.BackgroundTransparency = 1
    btnStack.Parent = card
    
    local btnLayout = Instance.new("UIListLayout"); btnLayout.Padding = UDim.new(0.05, 0); btnLayout.Parent = btnStack

    local function createBuyBtn(text, amount)
        local total = egg.Price * amount
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0.28, 0) -- 3 buttons stack
        b.BackgroundColor3 = Color3.fromRGB(45, 45, 70)
        b.Text = text .. " (" .. formatNumber(total) .. ")"
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Font = Enum.Font.GothamBold
        b.TextScaled = true
        b.AutoButtonColor = true
        b.Parent = btnStack
        
        local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0.3, 0); bc.Parent = b
        local bs = Instance.new("UIStroke"); bs.Thickness = 1.5; bs.Color = egg.Color; bs.Transparency = 0.5; bs.Parent = b

        b.MouseButton1Click:Connect(function()
            b.Text = "OPENING..."
            local res = PurchaseEgg:InvokeServer(egg.Id, amount)
            if res and res.success then
                mainFrame.Visible = false
                overlay.Visible = false
            else
                b.Text = res and res.error or "Error!"
                b.TextColor3 = Color3.fromRGB(255, 100, 100)
                task.delay(2, function()
                    b.Text = text .. " (" .. formatNumber(total) .. ")"
                    b.TextColor3 = Color3.new(1, 1, 1)
                end)
            end
        end)
    end

    createBuyBtn("x1", 1)
    createBuyBtn("x3", 3)
    createBuyBtn("x8", 8)
end

-- Toggle Logic
local function toggleUI(state)
    if state == nil then state = not mainFrame.Visible end
    
    if state then
        -- RESET SIZE FOR ESCAPE FROM STUCK STATE
        mainFrame.Size = UDim2.new(0, 0, 0, 0)
        mainFrame.Visible = true
        overlay.Visible = true
        TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back), {Size = UDim2.new(0.6, 0, 0.6, 0)}):Play()
        TweenService:Create(overlay, TweenInfo.new(0.4), {BackgroundTransparency = 0.6}):Play()
    else
        local t = TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quart), {Size = UDim2.new(0, 0, 0, 0)})
        t:Play()
        TweenService:Create(overlay, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
        t.Completed:Connect(function()
            -- Ensure it only hides if still not supposed to be visible (prevents race conditions)
            if UIManager.CurrentOpenUI ~= "EggsUI" then
                mainFrame.Visible = false
                overlay.Visible = false
            end
        end)
    end
end

closeBtn.MouseButton1Click:Connect(function() UIManager.Close("EggsUI") end)
overlay.MouseButton1Click:Connect(function() UIManager.Close("EggsUI") end)

-- REGISTER WITH UIManager
task.defer(function()
    UIManager.Register("EggsUI", mainFrame, toggleUI)
end)

_G.ToggleEggsUI = function(s) UIManager.Toggle("EggsUI") end

print("[EggsUI] PURE SCALE Refactor Loaded")
