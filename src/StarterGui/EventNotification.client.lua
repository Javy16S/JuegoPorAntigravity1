-- EventHUD.client.lua
-- Skill: roblox-ui-design
-- Description: Dynamic top-bar notification for game events.
-- Animation: Fluid slide-in with bounce/back effect.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local EventStarted = ReplicatedStorage:WaitForChild("EventStarted", 10)
if not EventStarted then
    warn("[EventHUD] CRITICAL: EventStarted RemoteEvent not found after 10s!")
end

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- CONSTANTS
local HUD_NAME = "EventHUD_v2"
local NOTIFICATION_DURATION = 5.0

-- ASSETS
local SOUND_NORMAL = "rbxassetid://4612375233" -- Alert/Siren Sweep
local SOUND_MAJOR = "rbxassetid://1548303889" -- Epic riser

-- SETUP GUI
local function createEventGui()
    if PlayerGui:FindFirstChild(HUD_NAME) then 
        PlayerGui[HUD_NAME]:Destroy() 
    end
    
    local gui = Instance.new("ScreenGui")
    gui.Name = HUD_NAME
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true 
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 10 -- Always on top
    gui.Parent = PlayerGui
    return gui
end

local screenGui = createEventGui()

local function createGradient(parent)
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
        ColorSequenceKeypoint.new(1, Color3.new(0.8,0.8,0.8))
    })
    grad.Rotation = 90
    grad.Parent = parent
    return grad
end

local function showNotification(title, message, color)
    -- CLEANUP OLD
    for _, child in pairs(screenGui:GetChildren()) do
        if child:IsA("Frame") then
            -- Slide out old one quickly
            TweenService:Create(child, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0, 0, 0, -150)
            }):Play()
            Debris:AddItem(child, 0.3)
        end
    end
    
    -- CONTAINER
    local frame = Instance.new("Frame")
    frame.Name = "NotificationFrame"
    frame.Size = UDim2.new(0.4, 0, 0, 80) -- Narrower, centered
    frame.Position = UDim2.new(0.3, 0, 0, -150) -- Start off-screen (Top)
    frame.BackgroundColor3 = color or Color3.fromRGB(0, 150, 255)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    
    -- STUDS AESTHETIC (Blocky, Industrial)
    -- Remove UICorner
    
    -- Background Texture (Studs)
    local bgParams = Instance.new("ImageLabel")
    bgParams.Name = "StudsTexture"
    bgParams.Size = UDim2.new(1,0,1,0)
    bgParams.BackgroundTransparency = 1
    bgParams.Image = "rbxassetid://6372755229" -- Standard Studs Texture
    bgParams.ScaleType = Enum.ScaleType.Tile
    bgParams.TileSize = UDim2.new(0, 64, 0, 64)
    bgParams.ImageColor3 = Color3.new(0.8, 0.8, 0.8) -- Slight darken
    bgParams.Parent = frame
    
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 4
    stroke.Color = Color3.new(0,0,0)
    stroke.Parent = frame

    -- Top Header (Lego connector style)
    local studs = Instance.new("Frame")
    studs.Size = UDim2.new(1, 0, 0.25, 0)
    studs.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    studs.BorderSizePixel = 0
    studs.Parent = frame
    
    -- Studs Pattern on Header too
    local hTex = bgParams:Clone()
    hTex.ImageColor3 = Color3.new(0.5, 0.5, 0.5)
    hTex.Parent = studs

    -- TITLE
    local lblTitle = Instance.new("TextLabel")
    lblTitle.Name = "Title"
    lblTitle.Size = UDim2.new(1, -20, 0.5, 0)
    lblTitle.Position = UDim2.new(0, 10, 0.1, 0)
    lblTitle.BackgroundTransparency = 1
    lblTitle.Text = title:upper()
    lblTitle.TextColor3 = Color3.new(1,1,1)
    lblTitle.Font = Enum.Font.FredokaOne -- Round, friendly
    lblTitle.TextSize = 28
    lblTitle.TextStrokeColor3 = Color3.new(0,0,0)
    lblTitle.TextStrokeTransparency = 0
    lblTitle.Parent = frame
    
    -- MESSAGE
    local lblMsg = Instance.new("TextLabel")
    lblMsg.Name = "Message"
    lblMsg.Size = UDim2.new(1, -20, 0.4, 0)
    lblMsg.Position = UDim2.new(0, 10, 0.5, 0)
    lblMsg.BackgroundTransparency = 1
    lblMsg.Text = message
    lblMsg.TextColor3 = Color3.new(1,1,1)
    lblMsg.Font = Enum.Font.GothamBold
    lblMsg.TextSize = 18
    lblMsg.TextStrokeColor3 = Color3.new(0,0,0)
    lblMsg.TextStrokeTransparency = 0.5
    lblMsg.Parent = frame
    
    -- SOUND
    local sfx = Instance.new("Sound")
    sfx.Name = "AlertSound"
    sfx.SoundId = (title:find("MAJOR") or title:find("MAYOR")) and SOUND_MAJOR or SOUND_NORMAL
    sfx.Volume = 1
    sfx.Parent = frame
    sfx:Play()
    
    -- ANIMATION: Simple Bounce
    local slideInInfo = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    local slideIn = TweenService:Create(frame, slideInInfo, {
        Position = UDim2.new(0.3, 0, 0.05, 0) -- 5% from top
    })
    slideIn:Play()
    
    -- DISMISS
    task.delay(NOTIFICATION_DURATION, function()
        if not frame or not frame.Parent then return end
        
        -- Slide Up (Exit)
        local slideOutInfo = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In)
        local slideOut = TweenService:Create(frame, slideOutInfo, {
            Position = UDim2.new(0.3, 0, 0, -150)
        })
        slideOut:Play()
        slideOut.Completed:Wait()
        frame:Destroy()
    end)
end

EventStarted.OnClientEvent:Connect(showNotification)

print("[EventHUD_v2] Initialized with Dynamic UI.")
