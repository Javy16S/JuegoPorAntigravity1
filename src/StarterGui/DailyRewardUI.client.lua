-- DailyRewardUI.client.lua
-- ULTIMATE PREMIUM OVERHAUL v6 (Progress + Donor Levels)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local UIManager = require(Modules:WaitForChild("UIManager"))
local EconomyLogic = require(Modules:WaitForChild("EconomyLogic"))

local claimRemote = ReplicatedStorage:WaitForChild("ClaimDailyReward")
local infoRemote = ReplicatedStorage:WaitForChild("GetDailyRewardInfo")

local SOUNDS = {
	SELECT = 6895079853,
	SUCCESS = 154811833,
	ERROR = 9112765376,
	CLOSE = 6895079853
}

local function create(className, properties)
    local inst = Instance.new(className)
    for k, v in pairs(properties) do
        inst[k] = v
    end
    return inst
end

local function playSound(id, vol, duration)
    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://" .. tostring(id)
    s.Volume = vol or 0.5
    s.Parent = SoundService
    s:Play()
    if duration then
        task.delay(duration, function()
            if s and s.Parent then s:Stop(); s:Destroy() end
        end)
    else
        s.Ended:Connect(function() s:Destroy() end)
    end
end

-- UI STRUCTURE
local screenGui = create("ScreenGui", {
    Name = "DailyRewardUI",
    IgnoreGuiInset = true,
    ResetOnSpawn = false,
    DisplayOrder = 100,
    Parent = PlayerGui
})

local overlay = create("TextButton", {
    Name = "Overlay",
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 1,
    Text = "",
    Visible = false,
    AutoButtonColor = false,
    Parent = screenGui
})

local mainFrame = create("Frame", {
    Name = "MainFrame",
    Size = UDim2.new(0, 500, 0, 420),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = Color3.fromRGB(15, 15, 20),
    BackgroundTransparency = 0.1,
    Visible = false,
    Parent = screenGui
})

create("UICorner", { CornerRadius = UDim.new(0, 24), Parent = mainFrame })
create("UIStroke", { Thickness = 4, Color = Color3.fromRGB(255, 215, 0), Transparency = 0.3, Parent = mainFrame })

-- HEADER
local header = create("Frame", {
    Name = "Header",
    Size = UDim2.new(1, 0, 0, 70),
    BackgroundTransparency = 1,
    ZIndex = 5,
    Parent = mainFrame
})

create("TextLabel", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "DAILY REWARD",
    TextColor3 = Color3.fromRGB(255, 220, 50),
    Font = Enum.Font.GothamBlack,
    TextSize = 32,
    Parent = header
})

local closeBtn = create("TextButton", {
    Name = "CloseButton",
    Size = UDim2.new(0, 40, 0, 40),
    Position = UDim2.new(1, -15, 0, 15),
    AnchorPoint = Vector2.new(1, 0),
    BackgroundColor3 = Color3.fromRGB(250, 50, 50),
    Text = "×",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBlack,
    TextSize = 30,
    ZIndex = 11,
    Parent = header
})
create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = closeBtn })

-- CONTENT
local content = create("Frame", {
    Name = "Content",
    Size = UDim2.new(1, -60, 1, -100),
    Position = UDim2.new(0, 30, 0, 80),
    BackgroundTransparency = 1,
    Parent = mainFrame
})

local rewardBox = create("Frame", {
    Size = UDim2.new(1, 0, 0, 140),
    BackgroundColor3 = Color3.fromRGB(30, 30, 40),
    BackgroundTransparency = 0.5,
    Parent = content
})
create("UICorner", { CornerRadius = UDim.new(0, 15), Parent = rewardBox })

local amountLabel = create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 60),
    Position = UDim2.new(0, 0, 0, 15),
    BackgroundTransparency = 1,
    Text = "$0",
    TextColor3 = Color3.fromRGB(100, 255, 100),
    Font = Enum.Font.GothamBlack,
    TextSize = 48,
    Parent = rewardBox
})

local itemLabel = create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 30),
    Position = UDim2.new(0, 0, 0, 80),
    BackgroundTransparency = 1,
    Text = "+ Rare Lucky Block",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 22,
    Parent = rewardBox
})

-- DONOR PROGRESS
local donorSection = create("Frame", {
    Name = "DonorSection",
    Size = UDim2.new(1, 0, 0, 80),
    Position = UDim2.new(0, 0, 0, 160),
    BackgroundTransparency = 1,
    Parent = content
})

local progressLabel = create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 25),
    BackgroundTransparency = 1,
    Text = "Next Level: Legendary (0/499 R$)",
    TextColor3 = Color3.fromRGB(200, 200, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = donorSection
})

local barBg = create("Frame", {
    Name = "BarBg",
    Size = UDim2.new(1, 0, 0, 20),
    Position = UDim2.new(0, 0, 0, 30),
    BackgroundColor3 = Color3.fromRGB(10, 10, 15),
    Parent = donorSection
})
create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = barBg })

local barFill = create("Frame", {
    Name = "BarFill",
    Size = UDim2.new(0, 0, 1, 0),
    BackgroundColor3 = Color3.fromRGB(0, 150, 255),
    Parent = barBg
})
create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = barFill })

local claimBtn = create("TextButton", {
    Name = "ClaimButton",
    Size = UDim2.new(1, 0, 0, 60),
    Position = UDim2.new(0, 0, 1, 0),
    AnchorPoint = Vector2.new(0, 1),
    BackgroundColor3 = Color3.fromRGB(0, 220, 100),
    Text = "CLAIM NOW",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBlack,
    TextSize = 24,
    Parent = content
})
create("UICorner", { CornerRadius = UDim.new(0, 12), Parent = claimBtn })

-- LOGIC
local function update()
    local info = infoRemote:InvokeServer()
    if not info then return end
    
    amountLabel.Text = "$" .. EconomyLogic.Abbreviate(info.CurrentReward)
    itemLabel.Text = "+ " .. tostring(info.RewardItem)
    
    -- Progress Bar
    if info.NextGoal then
        progressLabel.Text = string.format("Next: %s (%d/%d R$)", info.NextLevelName, info.RobuxSpent, info.NextGoal)
        TweenService:Create(barFill, TweenInfo.new(1), {Size = UDim2.new(info.Progress, 0, 1, 0)}):Play()
        barFill.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    else
        progressLabel.Text = "MAX DONOR LEVEL REACHED! 🏆"
        barFill.Size = UDim2.new(1, 0, 1, 0)
        barFill.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
    end
    
    local now = os.time()
    local last = info.LastClaim or 0
    local diff = now - last
    
    if diff < info.Cooldown then
        claimBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
        claimBtn.AutoButtonColor = false
        
        task.spawn(function()
            while mainFrame.Visible and (os.time() - last) < info.Cooldown do
                local rem = info.Cooldown - (os.time() - last)
                local h = math.floor(rem / 3600)
                local m = math.floor((rem % 3600) / 60)
                local s = rem % 60
                claimBtn.Text = string.format("AVAILABLE IN %02d:%02d:%02d", h, m, s)
                task.wait(1)
            end
            if mainFrame.Visible then update() end
        end)
    else
        claimBtn.BackgroundColor3 = Color3.fromRGB(0, 220, 100)
        claimBtn.AutoButtonColor = true
        claimBtn.Text = "CLAIM NOW"
    end
end

local function toggle(state)
    if state then
        playSound(SOUNDS.SELECT, 0.7, 0.1)
        mainFrame.Visible = true
        overlay.Visible = true
        mainFrame.Size = UDim2.new(0, 50, 0, 50)
        mainFrame.BackgroundTransparency = 1
        TweenService:Create(mainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back), {Size = UDim2.new(0, 500, 0, 420), BackgroundTransparency = 0.1}):Play()
        TweenService:Create(overlay, TweenInfo.new(0.5), {BackgroundTransparency = 0.5}):Play()
        update()
    else
        playSound(SOUNDS.CLOSE, 0.5, 0.1)
        local t = TweenService:Create(mainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1})
        t:Play()
        TweenService:Create(overlay, TweenInfo.new(0.35), {BackgroundTransparency = 1}):Play()
        t.Completed:Connect(function()
            mainFrame.Visible = false
            overlay.Visible = false
        end)
    end
end

claimBtn.MouseButton1Click:Connect(function()
    if claimBtn.BackgroundColor3 == Color3.fromRGB(60, 60, 70) then 
        playSound(SOUNDS.ERROR, 0.4, 0.5)
        return 
    end
    local success, res = claimRemote:InvokeServer()
    if success then
        playSound(SOUNDS.SUCCESS, 0.8)
        toggle(false)
    else
        playSound(SOUNDS.ERROR, 0.5)
        update()
    end
end)

closeBtn.MouseButton1Click:Connect(function() UIManager.Close("DailyRewardUI") end)
overlay.MouseButton1Click:Connect(function() UIManager.Close("DailyRewardUI") end)

UIManager.Register("DailyRewardUI", mainFrame, toggle)
