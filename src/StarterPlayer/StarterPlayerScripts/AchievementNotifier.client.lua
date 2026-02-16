-- AchievementNotifier.client.lua
-- Description: Displays a nice UI notification when an achievement is unlocked.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local AchievementUnlocked = ReplicatedStorage:WaitForChild("AchievementUnlocked")
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- CREATE SCREEN GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AchievementGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = PlayerGui

local Container = Instance.new("Frame")
Container.Name = "NotificationContainer"
Container.Size = UDim2.new(0, 300, 1, 0)
Container.Position = UDim2.new(0, 20, 0.8, 0) -- Bottom Left
Container.BackgroundTransparency = 1
Container.Parent = ScreenGui

local ListLayout = Instance.new("UIListLayout")
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
ListLayout.Padding = UDim.new(0, 10)
ListLayout.Parent = Container

local function showNotification(id, title, imageId)
    -- NOTIFICATION FRAME
    local frame = Instance.new("Frame")
    frame.Name = "Notif_" .. id
    frame.Size = UDim2.new(1, 0, 0, 80)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    frame.BorderSizePixel = 0
    frame.BackgroundTransparency = 1 -- Start invisible
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = frame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 200, 50) -- Gold stroke
    stroke.Thickness = 2
    stroke.Transparency = 1
    stroke.Parent = frame
    
    -- ICON
    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.new(0, 60, 0, 60)
    icon.Position = UDim2.new(0, 10, 0.5, -30)
    icon.BackgroundTransparency = 1
    icon.Image = imageId or "rbxassetid://13583569479"
    icon.ImageTransparency = 1
    icon.Parent = frame
    
    -- TITLE
    local lblTitle = Instance.new("TextLabel")
    lblTitle.Size = UDim2.new(0, 200, 0, 25)
    lblTitle.Position = UDim2.new(0, 80, 0, 15)
    lblTitle.BackgroundTransparency = 1
    lblTitle.Text = "ACHIEVEMENT!"
    lblTitle.TextColor3 = Color3.fromRGB(255, 200, 50)
    lblTitle.Font = Enum.Font.GothamBlack
    lblTitle.TextSize = 14
    lblTitle.TextXAlignment = Enum.TextXAlignment.Left
    lblTitle.TextTransparency = 1
    lblTitle.Parent = frame
    
    -- DESC (Achievement Name)
    local lblName = Instance.new("TextLabel")
    lblName.Size = UDim2.new(0, 200, 0, 25)
    lblName.Position = UDim2.new(0, 80, 0, 40)
    lblName.BackgroundTransparency = 1
    lblName.Text = title
    lblName.TextColor3 = Color3.fromRGB(255, 255, 255)
    lblName.Font = Enum.Font.GothamBold
    lblName.TextSize = 18
    lblName.TextXAlignment = Enum.TextXAlignment.Left
    lblName.TextTransparency = 1
    lblName.Parent = frame
    
    frame.Parent = Container
    
    -- SOUND
    local sfx = Instance.new("Sound")
    sfx.SoundId = "rbxassetid://6035656607" -- Victory/Success Fanfare
    sfx.Parent = frame
    sfx:Play()
    
    -- ANIMATION: Slide In + Fade In
    local info = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    
    TweenService:Create(frame, info, {BackgroundTransparency = 0.1}):Play()
    TweenService:Create(stroke, info, {Transparency = 0}):Play()
    TweenService:Create(icon, info, {ImageTransparency = 0}):Play()
    TweenService:Create(lblTitle, info, {TextTransparency = 0}):Play()
    TweenService:Create(lblName, info, {TextTransparency = 0}):Play()
    
    -- Wait then Fade Out
    task.delay(4, function()
        if not frame.Parent then return end
        local outInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        
        TweenService:Create(frame, outInfo, {BackgroundTransparency = 1}):Play()
        TweenService:Create(stroke, outInfo, {Transparency = 1}):Play()
        TweenService:Create(icon, outInfo, {ImageTransparency = 1}):Play()
        TweenService:Create(lblTitle, outInfo, {TextTransparency = 1}):Play()
        TweenService:Create(lblName, outInfo, {TextTransparency = 1}):Play()
        
        task.wait(0.5)
        frame:Destroy()
    end)
end

AchievementUnlocked.OnClientEvent:Connect(showNotification)
