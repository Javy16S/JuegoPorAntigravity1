-- MutationAltarUI.client.lua
-- ULTIMATE PREMIUM OVERHAUL
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local UIManager = require(Modules:WaitForChild("UIManager"))
local EconomyLogic = require(Modules:WaitForChild("EconomyLogic"))

local rerollRemote = ReplicatedStorage:WaitForChild("RerollMutation")
local getInventory = ReplicatedStorage:WaitForChild("GetInventory")

local COST = 500000

-- UTILS
local function create(className, properties)
    local inst = Instance.new(className)
    for k, v in pairs(properties) do
        inst[k] = v
    end
    return inst
end

local function playSound(id, vol, duration) -- v5.3 POLISH
    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://" .. tostring(id)
    s.Volume = vol or 0.5
    s.Parent = game:GetService("SoundService")
    s:Play()
    if duration then
        task.delay(duration, function()
            if s and s.Parent then
                s:Stop()
                s:Destroy()
            end
        end)
    else
        s.Ended:Connect(function() s:Destroy() end)
    end
end

local SOUNDS = {
	SELECT = 6895079853, -- Selection/Click
	SUCCESS = 9126213759, -- Magic Sparkle / Success
	ERROR = 9112765376, -- Buzz/Error
	CLOSE = 6895079853 -- Use Click for close
}

-- UI STRUCTURE
local screenGui = create("ScreenGui", {
    Name = "MutationAltarUI",
    IgnoreGuiInset = true,
    ResetOnSpawn = false,
    DisplayOrder = 100,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
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
    ZIndex = 1,
    Parent = screenGui
})

local mainFrame = create("Frame", {
    Name = "MainFrame",
    Size = UDim2.new(0, 520, 0, 480),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = Color3.fromRGB(20, 10, 35),
    BackgroundTransparency = 0.1,
    Visible = false,
    ZIndex = 2,
    Parent = screenGui
})

create("UICorner", { CornerRadius = UDim.new(0, 24), Parent = mainFrame })
create("UIStroke", { Thickness = 4, Color = Color3.fromRGB(180, 50, 255), Transparency = 0.3, Parent = mainFrame })

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
    Text = "ALTAR MÁGICO",
    TextColor3 = Color3.fromRGB(200, 100, 255),
    Font = Enum.Font.GothamBlack,
    TextSize = 28,
    TextStrokeTransparency = 0.5,
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

-- LIST AREA
local listContainer = create("Frame", {
    Size = UDim2.new(1, -40, 1, -170),
    Position = UDim2.new(0, 20, 0, 80),
    BackgroundColor3 = Color3.new(0,0,0),
    BackgroundTransparency = 0.6,
    ZIndex = 3,
    Parent = mainFrame
})
create("UICorner", { CornerRadius = UDim.new(0, 12), Parent = listContainer })

local scrollFrame = create("ScrollingFrame", {
    Size = UDim2.new(1, -10, 1, -10),
    Position = UDim2.new(0, 5, 0, 5),
    BackgroundTransparency = 1,
    ScrollBarThickness = 6,
    ScrollBarImageColor3 = Color3.fromRGB(200, 100, 255),
    Parent = listContainer
})

create("UIListLayout", { Padding = UDim.new(0, 8), Parent = scrollFrame })

-- FOOTER
local footer = create("Frame", {
    Size = UDim2.new(1, 0, 0, 150), -- Increased height
    Position = UDim2.new(0, 0, 1, -150),
    BackgroundTransparency = 1,
    ZIndex = 5,
    Parent = mainFrame
})

local infoLabel = create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 25),
    Position = UDim2.new(0, 0, 0, 0), -- Top of footer
    Text = "SELECCIONA UN BRAINROT PARA MUTAR",
    TextColor3 = Color3.fromRGB(200, 200, 200),
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    BackgroundTransparency = 1,
    Parent = footer
})

-- LUCK BAR
local luckContainer = create("Frame", {
    Size = UDim2.new(1, -210, 0, 16),
    Position = UDim2.new(0, 20, 0, 30), -- Moved down
    BackgroundColor3 = Color3.new(0,0,0),
    BackgroundTransparency = 0.5,
    ZIndex = 4,
    Parent = footer
})
create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = luckContainer })

local luckFill = create("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundColor3 = Color3.fromRGB(0, 255, 150),
    ZIndex = 5,
    Parent = luckContainer
})
create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = luckFill })

local luckLabel = create("TextLabel", {
    Size = UDim2.new(0, 150, 0, 20),
    Position = UDim2.new(1, -160, 0, 28), -- Aligned with bar
    Text = "SUERTE: 100%",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Right,
    BackgroundTransparency = 1,
    ZIndex = 6,
    Parent = footer
})

local probLabel = create("TextLabel", {
    Size = UDim2.new(0, 200, 0, 20),
    Position = UDim2.new(0.5, 0, 0, 60), -- More space
    AnchorPoint = Vector2.new(0.5, 0),
    Text = "Probabilidad: ---",
    TextColor3 = Color3.fromRGB(200, 200, 200),
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    BackgroundTransparency = 1,
    ZIndex = 6,
    Parent = footer
})

local rerollBtn = create("TextButton", {
    Size = UDim2.new(0, 380, 0, 55),
    Position = UDim2.new(0.5, 0, 0, 85), -- Centered
    AnchorPoint = Vector2.new(0.5, 0),
    BackgroundColor3 = Color3.fromRGB(150, 0, 255),
    Text = "SELECCIONA PARA MUTAR",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBlack,
    TextSize = 18,
    ZIndex = 11,
    Parent = footer
})
create("UICorner", { CornerRadius = UDim.new(0, 12), Parent = rerollBtn })

-- LOGIC
local selectedId = nil
local currentLuck = 100
local currentPrice = 0

-- Local Luck Regen
task.spawn(function()
    while true do
        if currentLuck < 100 then
            currentLuck = math.min(100, currentLuck + (1/10)) -- 1 point per 10s
            luckFill.Size = UDim2.new(currentLuck/100, 0, 1, 0)
            luckLabel.Text = string.format("SUERTE: %d%%", math.floor(currentLuck))
            
            -- Update Probability Color
            if currentLuck > 95 then
                probLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
                probLabel.Text = "Probabilidad: GARANTIZADA"
            elseif currentLuck > 75 then
                probLabel.TextColor3 = Color3.fromRGB(0, 255, 200)
                probLabel.Text = "Probabilidad: MUY ALTA"
            elseif currentLuck > 40 then
                probLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
                probLabel.Text = "Probabilidad: MEDIA"
            else
                probLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
                probLabel.Text = "Probabilidad: BAJA"
            end
        end
        task.wait(1)
    end
end)

local function updateInventory()
    for _, child in pairs(scrollFrame:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    
    local invData = getInventory:InvokeServer()
    if not invData or not invData.Inventory then return end
    
    local zIndex = 1
    for _, unit in ipairs(invData.Inventory) do
        local card = create("TextButton", {
            Size = UDim2.new(1, -10, 0, 50),
            BackgroundColor3 = Color3.fromRGB(50, 30, 70),
            BackgroundTransparency = 0.4,
            Text = "",
            ZIndex = zIndex,
            Parent = scrollFrame
        })
        create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = card })
        
        create("TextLabel", {
            Size = UDim2.new(0.5, -15, 1, 0),
            Position = UDim2.new(0, 15, 0, 0),
            Text = unit.Name,
            TextColor3 = Color3.new(1, 1, 1),
            Font = Enum.Font.GothamBold,
            TextSize = 16,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,
            ZIndex = zIndex + 1,
            Parent = card
        })
        
        create("TextLabel", {
            Size = UDim2.new(0.5, -15, 1, 0),
            Position = UDim2.new(0.5, 0, 0, 0),
            Text = unit.Mutation or "Normal",
            TextColor3 = Color3.fromRGB(200, 150, 255),
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Right,
            BackgroundTransparency = 1,
            ZIndex = zIndex + 1,
            Parent = card
        })
        
        local stroke = create("UIStroke", { Thickness = 2, Color = Color3.fromRGB(200, 100, 255), Enabled = false, Parent = card })
        
        card.MouseButton1Click:Connect(function()
            playSound(SOUNDS.SELECT, 0.4, 0.1) -- Shortened
            selectedId = unit.Id
            
            -- Hide info label when selected
            infoLabel.Visible = false
            
            -- Query Price/Luck
            local ok, info = rerollRemote:InvokeServer(selectedId, "Query")
            if ok and info then
                currentPrice = info.Price
                currentLuck = info.Luck
                rerollBtn.Text = "MUTAR ($" .. EconomyLogic.Abbreviate(currentPrice) .. ")"
                rerollBtn.BackgroundColor3 = Color3.fromRGB(150, 0, 255)
            end
            
            for _, c in pairs(scrollFrame:GetChildren()) do
                if c:IsA("TextButton") then 
                    c.BackgroundColor3 = Color3.fromRGB(50, 30, 70) 
                    if c:FindFirstChildOfClass("UIStroke") then
                        c:FindFirstChildOfClass("UIStroke").Enabled = false
                    end
                end
            end
            card.BackgroundColor3 = Color3.fromRGB(100, 50, 160)
            stroke.Enabled = true
        end)
    end
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, #invData.Inventory * 58)
end

rerollBtn.MouseButton1Click:Connect(function()
    if not selectedId then return end
    
    local success, info = rerollRemote:InvokeServer(selectedId, "Reroll")
    if success and info then
        playSound(SOUNDS.SUCCESS, 0.8)
        
        -- Update state
        currentLuck = info.Luck
        currentPrice = info.Price
        
        -- Refresh visuals
        updateInventory()
        rerollBtn.Text = "MUTAR ($" .. EconomyLogic.Abbreviate(currentPrice) .. ")"
        
        -- Visual Feedback on Luck Bar
        luckFill.Size = UDim2.new(currentLuck/100, 0, 1, 0)
        
        print("[MutationAltar] Reroll success. New Luck:", currentLuck)
    else
        playSound(SOUNDS.ERROR, 0.5)
        local err = info or "Error"
        local oldText = rerollBtn.Text
        rerollBtn.Text = tostring(err):upper()
        task.delay(1.5, function() rerollBtn.Text = oldText end)
    end
end)

closeBtn.MouseButton1Click:Connect(function() UIManager.Close("MutationAltarUI") end)
overlay.MouseButton1Click:Connect(function() UIManager.Close("MutationAltarUI") end)

local function toggle(state)
    print("[MutationAltarUI] Toggle called with state:", state)
    if state then
        playSound(SOUNDS.SELECT, 0.7, 0.1) -- Shortened
        mainFrame.Visible = true
        overlay.Visible = true
        mainFrame.Size = UDim2.new(0, 80, 0, 80)
        mainFrame.BackgroundTransparency = 1
        
        local t = TweenService:Create(mainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back), {Size = UDim2.new(0, 520, 0, 480), BackgroundTransparency = 0.1})
        t:Play()
        TweenService:Create(overlay, TweenInfo.new(0.5), {BackgroundTransparency = 0.5}):Play()
        
        selectedId = nil
        infoLabel.Visible = true
        rerollBtn.Text = "SELECCIONA PARA MUTAR"
        rerollBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
        
        -- Initial Sync: Fetch Luck
        task.spawn(function()
            local success, info = rerollRemote:InvokeServer(nil, "QueryLuck")
            if success and info then
                currentLuck = info.Luck
                luckFill.Size = UDim2.new(currentLuck/100, 0, 1, 0)
                luckLabel.Text = string.format("SUERTE: %d%%", math.floor(currentLuck))
            end
        end)
        
        updateInventory()
    else
        playSound(SOUNDS.CLOSE, 0.5, 0.1) -- Shortened
        local t = TweenService:Create(mainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1})
        t:Play()
        TweenService:Create(overlay, TweenInfo.new(0.35), {BackgroundTransparency = 1}):Play()
        t.Completed:Connect(function()
            mainFrame.Visible = false
            overlay.Visible = false
        end)
    end
end

UIManager.Register("MutationAltarUI", mainFrame, toggle)
print("[MutationAltarUI] ADVANCED MECHANICS LOADED.")
