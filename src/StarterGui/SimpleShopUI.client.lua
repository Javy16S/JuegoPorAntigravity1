-- SimpleShopUI.client.lua
-- Estética: Clean & Vibrant (Legibilidad Premium)
-- Skill: roblox-ui-design, roblox-scripting-expert

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- REMOTES
local SellAllUnits = ReplicatedStorage:WaitForChild("SellAllUnits", 10)
local SellHandUnit = ReplicatedStorage:WaitForChild("SellHandUnit", 10)
local GetSellValues = ReplicatedStorage:WaitForChild("GetSellValues", 10)

-- PREVENT DUPLICATES
if playerGui:FindFirstChild("BlackMarketShop") then
    playerGui.BlackMarketShop:Destroy()
end

-- UI CREATION
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BlackMarketShop"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 15
screenGui.Parent = playerGui

-- Background Overlay (Minimalist)
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
mainFrame.Size = UDim2.new(0.35, 0, 0.4, 0) -- Slightly smaller/cleaner
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(10, 15, 12)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Parent = screenGui

local uiCorner = Instance.new("UICorner", mainFrame)
uiCorner.CornerRadius = UDim.new(0.06, 0)

local uiStroke = Instance.new("UIStroke", mainFrame)
uiStroke.Color = Color3.fromRGB(0, 255, 150) -- Mint Cyan
uiStroke.Thickness = 2 -- Thinner per request
uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local uiGradient = Instance.new("UIGradient", mainFrame)
uiGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 25, 20)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 15, 12))
})
uiGradient.Rotation = 90

local aspect = Instance.new("UIAspectRatioConstraint", mainFrame)
aspect.AspectRatio = 1.3

-- TITLE
local header = Instance.new("TextLabel")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0.18, 0)
header.BackgroundTransparency = 1
header.Text = "MERCADO NEGRO"
header.TextColor3 = Color3.fromRGB(0, 255, 180)
header.Font = Enum.Font.GothamSemibold -- Less thick
header.TextScaled = true
header.Parent = mainFrame

local titleStroke = Instance.new("UIStroke", header)
titleStroke.Thickness = 1.5
titleStroke.Color = Color3.new(0,0,0)
titleStroke.Transparency = 0.5

-- SUBTITLE / STATS
local statsLabel = Instance.new("TextLabel")
statsLabel.Name = "Stats"
statsLabel.Size = UDim2.new(0.9, 0, 0.08, 0)
statsLabel.Position = UDim2.new(0.05, 0, 0.2, 0)
statsLabel.BackgroundTransparency = 1
statsLabel.Text = "CARGANDO..."
statsLabel.TextColor3 = Color3.fromRGB(180, 200, 190)
statsLabel.Font = Enum.Font.GothamMedium
statsLabel.TextScaled = true
statsLabel.Parent = mainFrame

-- BUTTONS
local function createStyledButton(name, text, position, bgColor)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(0.8, 0, 0.15, 0)
    btn.Position = position
    btn.BackgroundColor3 = bgColor -- Solid color, no gradient
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextScaled = true
    btn.AutoButtonColor = false
    btn.Parent = mainFrame
    
    local corner = Instance.new("UICorner", btn)
    corner.CornerRadius = UDim.new(0.2, 0)
    
    local stroke = Instance.new("UIStroke", btn)
    stroke.Thickness = 1.5
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Transparency = 0.7
    
    -- Text outline for better readability
    local textStroke = Instance.new("UIStroke", btn)
    textStroke.Thickness = 1
    textStroke.Color = Color3.new(0, 0, 0)
    textStroke.Transparency = 0.3
    
    -- Subtle hover effects
    local originalColor = bgColor
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.new(
                math.min(originalColor.R * 1.2, 1),
                math.min(originalColor.G * 1.2, 1),
                math.min(originalColor.B * 1.2, 1)
            )
        }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.15), {Transparency = 0.3}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = originalColor}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.15), {Transparency = 0.7}):Play()
    end)
    
    return btn
end

-- Clean solid colors (no gradients)
local sellAllBtn = createStyledButton("SellAll", "VENDER TODO", UDim2.new(0.1, 0, 0.38, 0), Color3.fromRGB(0, 150, 80))
local sellHandBtn = createStyledButton("SellHand", "VENDER MANO", UDim2.new(0.1, 0, 0.58, 0), Color3.fromRGB(100, 60, 180))
local closeBtn = createStyledButton("Close", "CERRAR", UDim2.new(0.1, 0, 0.8, 0), Color3.fromRGB(50, 50, 55))
closeBtn.Size = UDim2.new(0.8, 0, 0.12, 0)

-- Value labels (separate from buttons for clarity)
local sellAllValue = Instance.new("TextLabel")
sellAllValue.Name = "SellAllValue"
sellAllValue.Size = UDim2.new(0.8, 0, 0.06, 0)
sellAllValue.Position = UDim2.new(0.1, 0, 0.54, 0)
sellAllValue.BackgroundTransparency = 1
sellAllValue.Text = "$0"
sellAllValue.TextColor3 = Color3.fromRGB(100, 255, 150)
sellAllValue.Font = Enum.Font.GothamBold
sellAllValue.TextScaled = true
sellAllValue.Parent = mainFrame

local sellHandValue = Instance.new("TextLabel")
sellHandValue.Name = "SellHandValue"
sellHandValue.Size = UDim2.new(0.8, 0, 0.06, 0)
sellHandValue.Position = UDim2.new(0.1, 0, 0.74, 0)
sellHandValue.BackgroundTransparency = 1
sellHandValue.Text = "$0"
sellHandValue.TextColor3 = Color3.fromRGB(200, 150, 255)
sellHandValue.Font = Enum.Font.GothamBold
sellHandValue.TextScaled = true
sellHandValue.Parent = mainFrame

-----------------------------------------------------------
-- LOGIC
-----------------------------------------------------------

local function playMoneySfx()
    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://5150824006" -- Valid Cash Register Sound
    s.Volume = 0.5
    s.Parent = SoundService
    s:Play()
    Debris:AddItem(s, 1)
end

function openUI()
    if mainFrame.Visible then return end
    
    mainFrame.Visible = true
    overlay.Visible = true
    
    -- Smooth Animation
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    overlay.BackgroundTransparency = 1
    
    TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0.35, 0, 0.4, 0)}):Play()
    TweenService:Create(overlay, TweenInfo.new(0.4), {BackgroundTransparency = 0.8}):Play()
    
    -- Data Loading
    task.spawn(function()
        local data = GetSellValues:InvokeServer()
        if data and mainFrame.Visible then
            statsLabel.Text = data.count .. " UNIDADES DISPONIBLES"
            
            -- Update buttons and separate value labels
            sellAllBtn.Text = "VENDER TODO"
            sellHandBtn.Text = "VENDER MANO"
            
            -- Format values with commas for readability
            local function formatMoney(n)
                local s = tostring(n)
                local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
                return formatted:match("^,?(.+)$") -- Remove leading comma if any
            end
            
            sellAllValue.Text = "$" .. formatMoney(data.total)
            sellHandValue.Text = "$" .. formatMoney(data.hand)
            
            -- Enable/disable based on value
            sellAllBtn.Active = data.total > 0
            local trans = data.total > 0 and 0 or 0.5
            sellAllBtn.BackgroundTransparency = trans
            sellAllBtn.TextTransparency = trans
            sellAllValue.TextTransparency = trans
            
            sellHandBtn.Active = data.hand > 0
            local hTrans = data.hand > 0 and 0 or 0.5
            sellHandBtn.BackgroundTransparency = hTrans
            sellHandBtn.TextTransparency = hTrans
            sellHandValue.TextTransparency = hTrans
        end
    end)
end

function closeUI()
    if not mainFrame.Visible then return end
    
    TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0)}):Play()
    TweenService:Create(overlay, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
    task.wait(0.3)
    mainFrame.Visible = false
    overlay.Visible = false
end

-- BUTTON EVENTS
sellAllBtn.MouseButton1Click:Connect(function()
    sellAllBtn.Text = "..."
    local res = SellAllUnits:InvokeServer()
    if res and res.success then
        playMoneySfx()
        closeUI()
    end
end)

sellHandBtn.MouseButton1Click:Connect(function()
    sellHandBtn.Text = "..."
    local res = SellHandUnit:InvokeServer()
    if res and res.success then
        playMoneySfx()
        closeUI()
    end
end)

closeBtn.MouseButton1Click:Connect(closeUI)

-----------------------------------------------------------
-- PRESENCE & INTERACTION SYSTEM
-----------------------------------------------------------
local function checkDistance()
    task.spawn(function()
        while mainFrame.Visible do
            local char = player.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then break end
            
            local hrpPos = char.HumanoidRootPart.Position
            local inZone = false
            
            for _, zone in pairs(CollectionService:GetTagged("SellZone")) do
                local dist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) - Vector3.new(zone.Position.X, 0, zone.Position.Z)).Magnitude
                if dist < 15 then -- Wider grace area
                    inZone = true
                    break
                end
            end
            
            if not inZone then
                closeUI()
                break
            end
            task.wait(0.3)
        end
    end)
end

local function setupZone(zone)
    if zone:IsA("BasePart") then
        -- Robust Prompt Finding
        local prompt = zone:FindFirstChildWhichIsA("ProximityPrompt")
        if not prompt then
             prompt = zone:WaitForChild("ProximityPrompt", 10) -- Increased timeout
        end
        
        if prompt then
            prompt.Triggered:Connect(function(user)
                if user == player then
                    openUI()
                    checkDistance()
                end
            end)
        else
            warn("[SimpleShopUI] No prompt found in zone:", zone.Name)
            -- Retry listener
            zone.ChildAdded:Connect(function(child)
                if child:IsA("ProximityPrompt") then
                    child.Triggered:Connect(function(user)
                        if user == player then
                            openUI()
                            checkDistance()
                        end
                    end)
                end
            end)
        end
    end
end

for _, zone in pairs(CollectionService:GetTagged("SellZone")) do
    setupZone(zone)
end
CollectionService:GetInstanceAddedSignal("SellZone"):Connect(setupZone)

print("[SimpleShopUI] Modern Black Market Ready.")
