-- RebirthGUI.client.lua
-- Skill: ui-design
-- Description: Premium Rebirth (Ascension) UI.
-- Refactored for Responsiveness: PURE SCALE (No Offsets)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UIManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UIManager"))
local DoRebirth = ReplicatedStorage:WaitForChild("DoRebirth")
local EconomyLogic = require(ReplicatedStorage.Modules:WaitForChild("EconomyLogic"))

-- 1. CLEANUP
if playerGui:FindFirstChild("RebirthGui") then
    playerGui.RebirthGui:Destroy()
end

-- 2. CREATE GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RebirthGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 10
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

-- MAIN FRAME
local frame = Instance.new("Frame")
frame.Name = "MainFrame"
-- Scale: 40% width, height auto by aspect
frame.Size = UDim2.new(0.4, 0, 0.5, 0)
frame.Position = UDim2.new(0.5, 0, 0.5, 0)
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
frame.BorderSizePixel = 0
frame.Visible = false
frame.ZIndex = 2
frame.Parent = screenGui

-- Aspect Ratio
local frameAspect = Instance.new("UIAspectRatioConstraint")
frameAspect.AspectRatio = 1.15 
frameAspect.AspectType = Enum.AspectType.FitWithinMaxSize
frameAspect.Parent = frame

-- MAX SIZE CONSTRAINT
local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MaxSize = Vector2.new(500, 450)
sizeConstraint.Parent = frame

local corner = Instance.new("UICorner", frame)
corner.CornerRadius = UDim.new(0.05, 0)

local stroke = Instance.new("UIStroke", frame)
stroke.Thickness = 3
stroke.Color = Color3.fromRGB(100, 0, 255)
stroke.Transparency = 0.5

-- GRADIENT
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 45)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 15, 20))
})
gradient.Rotation = 90
gradient.Parent = frame

-- SHADOW/GLOW
local shadow = Instance.new("ImageLabel")
shadow.Name = "Shadow"
shadow.Size = UDim2.new(1.1, 0, 1.1, 0)
shadow.Position = UDim2.new(-0.05, 0, -0.05, 0)
shadow.BackgroundTransparency = 1
shadow.Image = "rbxassetid://1316045217" -- Shadow texture
shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
shadow.ImageTransparency = 0.5
shadow.ZIndex = -1
shadow.Parent = frame

-- CONTENT
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0.18, 0)
header.BackgroundTransparency = 1
header.Parent = frame

local title = Instance.new("TextLabel")
title.Text = "ASCENSIÓN"
title.Font = Enum.Font.FredokaOne
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(200, 100, 255)
title.Size = UDim2.new(1, 0, 0.8, 0)
title.Position = UDim2.new(0, 0, 0.1, 0)
title.BackgroundTransparency = 1
title.Parent = header

-- Stats Section
local infoFrame = Instance.new("Frame")
infoFrame.Name = "Info"
infoFrame.Size = UDim2.new(0.9, 0, 0.22, 0)
infoFrame.Position = UDim2.new(0.05, 0, 0.2, 0)
infoFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
infoFrame.BackgroundTransparency = 0.6
infoFrame.Parent = frame
Instance.new("UICorner", infoFrame).CornerRadius = UDim.new(0.15, 0)

local currentStats = Instance.new("TextLabel")
currentStats.Name = "Stats"
currentStats.Text = "Rebirths: 0\nBono: +0%"
currentStats.Font = Enum.Font.FredokaOne
currentStats.TextScaled = true
currentStats.TextColor3 = Color3.new(1, 1, 1)
currentStats.Size = UDim2.new(0.9, 0, 0.8, 0)
currentStats.Position = UDim2.new(0.05, 0, 0.1, 0)
currentStats.BackgroundTransparency = 1
currentStats.Parent = infoFrame

-- Warning
local warning = Instance.new("TextLabel")
warning.Text = "⚠️ Se perderá el dinero\n(Mantienes Unidades)"
warning.Font = Enum.Font.FredokaOne
warning.TextScaled = true
warning.TextColor3 = Color3.fromRGB(255, 100, 100)
warning.Size = UDim2.new(0.9, 0, 0.14, 0)
warning.Position = UDim2.new(0.05, 0, 0.45, 0)
warning.BackgroundTransparency = 1
warning.Parent = frame

-- Next Rebirth Bonus
local nextBonus = Instance.new("TextLabel")
nextBonus.Name = "NextBonus"
nextBonus.Text = "Bono: +50%"
nextBonus.Font = Enum.Font.FredokaOne
nextBonus.TextScaled = true
nextBonus.TextColor3 = Color3.fromRGB(0, 255, 150)
nextBonus.Size = UDim2.new(0.9, 0, 0.1, 0)
nextBonus.Position = UDim2.new(0.05, 0, 0.6, 0)
nextBonus.BackgroundTransparency = 1
nextBonus.Parent = frame

-- CONFIRM BUTTON
local confirmBtn = Instance.new("TextButton")
confirmBtn.Name = "ConfirmBtn"
confirmBtn.Size = UDim2.new(0.8, 0, 0.18, 0)
confirmBtn.Position = UDim2.new(0.1, 0, 0.75, 0)
confirmBtn.BackgroundColor3 = Color3.fromRGB(100, 0, 255)
confirmBtn.Text = "RENACER"
confirmBtn.Font = Enum.Font.FredokaOne
confirmBtn.TextScaled = true
confirmBtn.TextColor3 = Color3.new(1, 1, 1)
confirmBtn.Parent = frame

Instance.new("UICorner", confirmBtn).CornerRadius = UDim.new(0.25, 0)
local btnStroke = Instance.new("UIStroke", confirmBtn)
btnStroke.Thickness = 2
btnStroke.Color = Color3.new(1, 1, 1)
btnStroke.Transparency = 0.5

-- Close Button
local closeBtn = Instance.new("TextButton")
closeBtn.Text = "✕"
closeBtn.Font = Enum.Font.FredokaOne
closeBtn.TextScaled = true
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.BackgroundTransparency = 1
closeBtn.Size = UDim2.new(0.1, 0, 0.1, 0)
closeBtn.Position = UDim2.new(0.88, 0, 0.02, 0)
closeBtn.Parent = frame

local closeAspect = Instance.new("UIAspectRatioConstraint")
closeAspect.AspectRatio = 1
closeAspect.Parent = closeBtn

-- LOGIC
local function updateUI()
    local rebirths = player:GetAttribute("Rebirths") or 0
    local bonus = (EconomyLogic.calculateRebirthMultiplier(rebirths) - 1) * 100
    local cost = EconomyLogic.calculateRebirthCost(rebirths)
    
    currentStats.Text = string.format("Rebirths: %d\nBono: +%d%%", rebirths, bonus)
    confirmBtn.Text = string.format("ASCENDER ($%s)", EconomyLogic.Abbreviate(cost))
    
    local cash = player.leaderstats and player.leaderstats.Cash.Value or 0
    if cash >= cost then
        confirmBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100) -- Green when affordable
        confirmBtn.AutoButtonColor = true
        confirmBtn.TextTransparency = 0
        confirmBtn.TextStrokeTransparency = 0.5
    else
        confirmBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        confirmBtn.AutoButtonColor = false
        confirmBtn.TextTransparency = 0.5
        confirmBtn.TextStrokeTransparency = 1
    end
end

-- TWEEN HELPERS (Standardized)
local function toggleUI(state)
    if state == nil then state = not frame.Visible end
    
    if state then
        frame.Size = UDim2.new(0, 0, 0, 0)
        frame.Visible = true
        overlay.Visible = true
        TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Back), {Size = UDim2.new(0.4, 0, 0.5, 0)}):Play()
        TweenService:Create(overlay, TweenInfo.new(0.4), {BackgroundTransparency = 0.5}):Play()
        updateUI()
    else
        local t = TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quart), {Size = UDim2.new(0, 0, 0, 0)})
        t:Play()
        TweenService:Create(overlay, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
        t.Completed:Connect(function()
            if UIManager.CurrentOpenUI ~= "RebirthUI" then
                frame.Visible = false
                overlay.Visible = false
            end
        end)
    end
end

-- Click overlay to close
overlay.MouseButton1Click:Connect(function()
    UIManager.Close("RebirthUI")
end)

closeBtn.MouseButton1Click:Connect(function()
    UIManager.Close("RebirthUI")
end)

-- REGISTER WITH UIManager
task.defer(function()
    UIManager.Register("RebirthUI", frame, toggleUI)
end)

confirmBtn.MouseButton1Click:Connect(function()
    local rebirths = player:GetAttribute("Rebirths") or 0
    local cost = EconomyLogic.calculateRebirthCost(rebirths)
    local cash = player.leaderstats and player.leaderstats.Cash.Value or 0
    
    if cash < cost then return end
    
    confirmBtn.Text = "..."
    confirmBtn.Active = false
    
    local success, result = DoRebirth:InvokeServer()
    if success then
        -- Ascension Effects
        local flash = Instance.new("Frame")
        flash.Size = UDim2.new(1, 0, 1, 0)
        flash.BackgroundColor3 = Color3.new(1, 1, 1)
        flash.ZIndex = 1000
        flash.Parent = screenGui
        
        TweenService:Create(flash, TweenInfo.new(1), {BackgroundTransparency = 1}):Play()
        Debris:AddItem(flash, 1)
        
        local s = Instance.new("Sound")
        s.SoundId = "rbxassetid://9061614264"
        s.Volume = 1
        s.Parent = SoundService
        s:Play()
        Debris:AddItem(s, 5)
        
        UIManager.Close("RebirthUI")
        task.wait(0.5)
        frame.Visible = false -- Concrete fallback
    else
        confirmBtn.Text = "ERR"
        task.wait(2)
        updateUI()
    end
    
    confirmBtn.Active = true -- Always restore activity
end)

-- Loop for real-time cost check
task.spawn(function()
    while true do
        if frame.Visible then updateUI() end
        task.wait(1)
    end
end)
