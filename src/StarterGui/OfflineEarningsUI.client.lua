-- OfflineEarningsUI.client.lua
-- Concept: Shows a prompt when player joins if they have offline earnings
-- Options: Collect (Wallet) or Distribute (Slots)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Remote = ReplicatedStorage:WaitForChild("NotifyOfflineEarnings", 10)
if not Remote then 
    warn("[OfflineEarningsUI] Remote 'NotifyOfflineEarnings' not found!")
    return 
end

local ResolveFunc = ReplicatedStorage:WaitForChild("ResolveOfflineEarnings", 10)

-- UI CONSTANTS
local UI_NAME = "OfflineEarningsGUI"
local THEME_COLOR = Color3.fromRGB(0, 255, 170) -- Tech Green
local BG_COLOR = Color3.fromRGB(20, 20, 25)

local function createUI(earnings, timeAway)
    -- Cleanup existing
    local existing = playerGui:FindFirstChild(UI_NAME)
    if existing then existing:Destroy() end
    
    local gui = Instance.new("ScreenGui")
    gui.Name = UI_NAME
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = playerGui
    
    -- Blur Effect
    local blur = Instance.new("BlurEffect")
    blur.Size = 0
    blur.Parent = game:GetService("Lighting")
    TweenService:Create(blur, TweenInfo.new(0.5), {Size = 20}):Play()
    
    -- Main Frame (Center)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.3, 0, 0.35, 0)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = BG_COLOR
    frame.BorderSizePixel = 0
    frame.BackgroundTransparency = 1 -- Start invisible
    frame.Parent = gui
    
    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0.05, 0)
    uiCorner.Parent = frame
    
    local uiStroke = Instance.new("UIStroke")
    uiStroke.Color = THEME_COLOR
    uiStroke.Thickness = 2
    uiStroke.Transparency = 1
    uiStroke.Parent = frame
    
    -- CONTENT LAYOUT
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0.05, 0)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = frame
    
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0.1, 0)
    padding.PaddingBottom = UDim.new(0.1, 0)
    padding.PaddingLeft = UDim.new(0.1, 0)
    padding.PaddingRight = UDim.new(0.1, 0)
    padding.Parent = frame
    
    -- 1. TITLE
    local title = Instance.new("TextLabel")
    title.LayoutOrder = 1
    title.Size = UDim2.new(1, 0, 0.2, 0)
    title.BackgroundTransparency = 1
    title.Text = "WELCOME BACK!"
    title.Font = Enum.Font.GothamBlack
    title.TextColor3 = Color3.new(1,1,1)
    title.TextScaled = true
    title.Parent = frame
    
    -- 2. INFO TEXT
    local info = Instance.new("TextLabel")
    info.LayoutOrder = 2
    info.Size = UDim2.new(1, 0, 0.15, 0)
    info.BackgroundTransparency = 1
    info.Text = string.format("You were away for %d min", math.floor(timeAway/60))
    info.Font = Enum.Font.GothamMedium
    info.TextColor3 = Color3.fromRGB(200, 200, 200)
    info.TextScaled = true
    info.Parent = frame
    
    -- 3. EARNINGS DISPLAY
    local amount = Instance.new("TextLabel")
    amount.LayoutOrder = 3
    amount.Size = UDim2.new(1, 0, 0.25, 0)
    amount.BackgroundTransparency = 1
    amount.Text = "$" .. require(ReplicatedStorage.Modules.EconomyLogic).Abbreviate(earnings)
    amount.Font = Enum.Font.GothamBold
    amount.TextColor3 = THEME_COLOR
    amount.TextScaled = true
    amount.Parent = frame
    
    -- 4. BUTTONS CONTAINER
    local btns = Instance.new("Frame")
    btns.LayoutOrder = 4
    btns.Size = UDim2.new(1, 0, 0.25, 0)
    btns.BackgroundTransparency = 1
    btns.Parent = frame
    
    local btnLayout = Instance.new("UIListLayout")
    btnLayout.FillDirection = Enum.FillDirection.Horizontal
    btnLayout.Padding = UDim.new(0.05, 0)
    btnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    btnLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    btnLayout.Parent = btns
    
    -- Helper for Buttons
    local function createBtn(text, color, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.45, 0, 1, 0)
        btn.BackgroundColor3 = color
        btn.Text = text
        btn.Font = Enum.Font.GothamBold
        btn.TextColor3 = Color3.new(0,0,0) -- Dark text on colored btn
        btn.TextScaled = true
        btn.AutoButtonColor = true
        btn.Parent = btns
        
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0.2, 0)
        c.Parent = btn
        
        btn.MouseButton1Click:Connect(function()
            -- Sound
            local sfx = Instance.new("Sound")
            sfx.SoundId = "rbxassetid://6895079853" -- Click
            sfx.Parent = SoundService
            sfx:Play()
            
            -- Action
            callback()
            
            -- Close Anim
            TweenService:Create(frame, TweenInfo.new(0.3), {Size = UDim2.new(0,0,0,0), BackgroundTransparency = 1}):Play()
            TweenService:Create(blur, TweenInfo.new(0.3), {Size = 0}):Play()
            task.wait(0.3)
            gui:Destroy()
            blur:Destroy()
        end)
    end
    
    createBtn("COLLECT", THEME_COLOR, function()
        print("[OfflineEarningsUI] Clicked COLLECT")
        if ResolveFunc then
            local result = ResolveFunc:InvokeServer("Collect")
            print("[OfflineEarningsUI] COLLECT Result:", result)
        end
    end)
    
    createBtn("TO SLOTS", Color3.fromRGB(255, 200, 50), function()
        print("[OfflineEarningsUI] Clicked TO SLOTS")
        if ResolveFunc then
            local result = ResolveFunc:InvokeServer("ToSlots")
            print("[OfflineEarningsUI] TO SLOTS Result:", result)
        end
    end)
    
    -- Open Animation
    TweenService:Create(frame, TweenInfo.new(0.5, Enum.EasingStyle.Back), {BackgroundTransparency = 0.1}):Play()
    TweenService:Create(uiStroke, TweenInfo.new(0.5), {Transparency = 0}):Play()
    
    -- Scale fix for aspect ratio (force scale)
    local aspect = Instance.new("UIAspectRatioConstraint")
    aspect.AspectRatio = 1.5
    aspect.Parent = frame
end

Remote.OnClientEvent:Connect(createUI)
