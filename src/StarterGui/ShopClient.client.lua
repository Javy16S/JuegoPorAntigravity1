-- ShopClient.client.lua
-- Rediseño Profesional: Basado en Scale, TweenService y Gradientes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Prevent duplicates
if playerGui:FindFirstChild("BrainrotShop") then
    playerGui.BrainrotShop:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BrainrotShop"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 10
screenGui.Parent = playerGui

-- UTILS: Common Tweens
local function fade(obj, goalTrans, duration)
    TweenService:Create(obj, TweenInfo.new(duration or 0.3), {BackgroundTransparency = goalTrans}):Play()
end

-- Overlay
local overlay = Instance.new("TextButton")
overlay.Name = "Overlay"
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 1
overlay.Text = ""
overlay.Visible = false
overlay.Parent = screenGui

-- Main Frame (Responsive)
local mainFrame = Instance.new("Frame")
mainFrame.Name = "ShopFrame"
mainFrame.Size = UDim2.new(0.6, 0, 0.7, 0)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.Visible = false
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 20, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0.05, 0)
uiCorner.Parent = mainFrame

local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 30, 50)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 10, 25))
})
grad.Rotation = 45
grad.Parent = mainFrame

local uiStroke = Instance.new("UIStroke")
uiStroke.Color = Color3.fromRGB(255, 200, 50)
uiStroke.Thickness = 4
uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
uiStroke.Parent = mainFrame

local aspect = Instance.new("UIAspectRatioConstraint")
aspect.AspectRatio = 1.5
aspect.Parent = mainFrame

-- Header
local header = Instance.new("Frame")
header.Size = UDim2.new(1,0,0.15,0)
header.BackgroundTransparency = 1
header.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Text = "⚡ MEJORAS DE VELOCIDAD ⚡"
title.Size = UDim2.new(1, 0, 0.8, 0)
title.Position = UDim2.new(0,0,0.1,0)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 220, 80)
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.Parent = header

local titleStroke = Instance.new("UIStroke")
titleStroke.Thickness = 2
titleStroke.Color = Color3.new(0,0,0)
titleStroke.Parent = title

-- Content
local content = Instance.new("ScrollingFrame")
content.Size = UDim2.new(0.9, 0, 0.75, 0)
content.Position = UDim2.new(0.05, 0, 0.2, 0)
content.BackgroundTransparency = 1
content.CanvasSize = UDim2.new(0,0,0,0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.ScrollBarThickness = 6
content.ScrollBarImageColor3 = Color3.fromRGB(255, 200, 50)
content.Parent = mainFrame

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0.3, 0, 0.45, 0)
grid.CellPadding = UDim2.new(0.03, 0, 0.03, 0)
grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
grid.Parent = content

-- CARD FACTORY
local GetUpgradeData = ReplicatedStorage:WaitForChild("GetUpgradeData")
local PurchaseSkill = ReplicatedStorage:WaitForChild("PurchaseSkill")

local function createCard(id, name, price, icon, descText, isMaxed)
    local card = Instance.new("Frame")
    card.BackgroundColor3 = Color3.fromRGB(45, 35, 60)
    card.BorderSizePixel = 0
    card.Parent = content
    
    Instance.new("UICorner", card).CornerRadius = UDim.new(0.1, 0)
    local cardStroke = Instance.new("UIStroke", card)
    cardStroke.Color = Color3.fromRGB(255, 255, 255)
    cardStroke.Transparency = 0.8
    
    local iconLbl = Instance.new("TextLabel")
    iconLbl.Size = UDim2.new(0.8,0,0.4,0)
    iconLbl.Position = UDim2.new(0.1,0,0.05,0)
    iconLbl.BackgroundTransparency = 1
    iconLbl.Text = icon
    iconLbl.TextScaled = true
    iconLbl.Parent = card
    
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(0.9, 0, 0.12, 0)
    nameLbl.Position = UDim2.new(0.05, 0, 0.45, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = name:upper()
    nameLbl.TextColor3 = Color3.new(1,1,1)
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextScaled = true
    nameLbl.Parent = card
    
    local descLbl = Instance.new("TextLabel")
    descLbl.Size = UDim2.new(0.85, 0, 0.15, 0)
    descLbl.Position = UDim2.new(0.075, 0, 0.58, 0)
    descLbl.BackgroundTransparency = 1
    descLbl.Text = descText
    descLbl.TextColor3 = Color3.fromRGB(200, 200, 220)
    descLbl.Font = Enum.Font.Gotham
    descLbl.TextScaled = true
    descLbl.Parent = card
    
    local buyBtn = Instance.new("TextButton")
    buyBtn.Size = UDim2.new(0.85, 0, 0.18, 0)
    buyBtn.Position = UDim2.new(0.075, 0, 0.76, 0)
    buyBtn.BackgroundColor3 = isMaxed and Color3.fromRGB(60,60,60) or Color3.fromRGB(0, 180, 255)
    buyBtn.Text = isMaxed and "MAX" or ("$ " .. (price or 0))
    buyBtn.TextColor3 = Color3.new(1,1,1)
    buyBtn.Font = Enum.Font.GothamBlack
    buyBtn.TextScaled = true
    buyBtn.Parent = card
    Instance.new("UICorner", buyBtn).CornerRadius = UDim.new(0.2, 0)
    
    local btnGrad = Instance.new("UIGradient", buyBtn)
    btnGrad.Color = ColorSequence.new(Color3.new(1,1,1), Color3.fromRGB(200, 200, 255))
    btnGrad.Rotation = 90

    -- Interactivity
    if not isMaxed then
        buyBtn.MouseEnter:Connect(function()
            TweenService:Create(buyBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(50, 200, 255)}):Play()
            TweenService:Create(cardStroke, TweenInfo.new(0.2), {Transparency = 0, Thickness = 2}):Play()
        end)
        buyBtn.MouseLeave:Connect(function()
            TweenService:Create(buyBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(0, 180, 255)}):Play()
            TweenService:Create(cardStroke, TweenInfo.new(0.2), {Transparency = 0.8, Thickness = 1}):Play()
        end)
        
        buyBtn.MouseButton1Click:Connect(function()
            buyBtn.Text = "..."
            local success, msg = PurchaseSkill:InvokeServer(id)
            if success then
                buyBtn.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
                buyBtn.Text = "✔"
                task.wait(0.5)
                refreshShop()
            else
                buyBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
                buyBtn.Text = msg or "X"
                task.wait(1)
                refreshShop()
            end
        end)
    end
end

function refreshShop()
    for _, child in pairs(content:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    local data = GetUpgradeData:InvokeServer()
    local cLvl = data and data.Level or 0
    local nPrice = data and data.Price or 2500
    
    createCard("SpeedUpgrade", "Velocidad Lvl " .. (cLvl + 1), nPrice, "⚡", "+2 Caminata Permanente", false)
    createCard("DoubleJump", "Doble Salto", 2500, "👟", "Permite saltar en el aire", false)
    createCard("BackpackUpgrade", "Mochila Premium", 15000, "🎒", "+1 Ranura de Almacén", false)
end

-- ANIMATIONS
function openShop()
    print("[ShopClient] Opening Shop...")
    refreshShop()
    mainFrame.Visible = true
    overlay.Visible = true
    
    -- Reset state for animation
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    overlay.BackgroundTransparency = 1
    
    TweenService:Create(mainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {Size = UDim2.new(0.6, 0, 0.7, 0)}):Play()
    TweenService:Create(overlay, TweenInfo.new(0.5), {BackgroundTransparency = 0.6}):Play()
end

function closeShop()
    print("[ShopClient] Closing Shop...")
    TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0)}):Play()
    TweenService:Create(overlay, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
    task.wait(0.3)
    mainFrame.Visible = false
    overlay.Visible = false
end

-- HOOKS (Touch Activation & Auto-Close)
local CollectionService = game:GetService("CollectionService")
local isOpening = false

local function checkDistance()
    task.spawn(function()
        while mainFrame.Visible do
            local char = player.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then break end
            
            local inZone = false
            local hrpPos = char.HumanoidRootPart.Position
            
            for _, zone in pairs(CollectionService:GetTagged("UpgradeZone")) do
                local dist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) - Vector3.new(zone.Position.X, 0, zone.Position.Z)).Magnitude
                if dist < 12 then -- Margin for stability
                    inZone = true
                    break
                end
            end
            
            if not inZone then
                closeShop()
                break
            end
            task.wait(0.2)
        end
    end)
end

local function onTouched(hit)
    local char = hit.Parent
    if char and Players:GetPlayerFromCharacter(char) == player then
        if not mainFrame.Visible and not isOpening then
            isOpening = true
            openShop()
            checkDistance()
            task.wait(0.4) -- Faster debounce
            isOpening = false
        end
    end
end

-- Connect to existing and future zones
local function setupZone(zone)
    if zone:IsA("BasePart") then
        zone.Touched:Connect(onTouched)
    end
end

for _, zone in pairs(CollectionService:GetTagged("UpgradeZone")) do
    setupZone(zone)
end
CollectionService:GetInstanceAddedSignal("UpgradeZone"):Connect(setupZone)

overlay.MouseButton1Click:Connect(closeShop)
print("[ShopClient] Auto-Presence System Ready.")
