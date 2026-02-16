-- BaseUpgradeUI.client.lua
-- Skill: roblox-ui-design
-- Description: Polished UI for Upgrading Base Stats (Capacity).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local OpenEvent = ReplicatedStorage:WaitForChild("OpenBaseUpgradeUI", 10)
local UpgradeFunc = ReplicatedStorage:WaitForChild("Remotes", 10):WaitForChild("UpgradeBaseFunc", 10)
local EconomyLogic = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("EconomyLogic"))

-- Check Remote
if not UpgradeFunc then
    -- It might not exist yet, we will handle it gracefully or wait
end

-- UI CONSTANTS
local UI_NAME = "BaseUpgradeHUD"
local COLOR_GOLD = Color3.fromRGB(255, 200, 0)
local COLOR_BLUE = Color3.fromRGB(0, 150, 255)
local COLOR_BG = Color3.fromRGB(20, 20, 20)

local currentTycoon = nil

local function createUpgradeUI()
    if PlayerGui:FindFirstChild(UI_NAME) then PlayerGui[UI_NAME]:Destroy() end
    
    local sg = Instance.new("ScreenGui")
    sg.Name = UI_NAME
    sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.ResetOnSpawn = false
    sg.Parent = PlayerGui
    sg.Enabled = false
    
    local overlay = Instance.new("Frame")
    overlay.Name = "Overlay"
    overlay.Size = UDim2.new(1,0,1,0)
    overlay.BackgroundColor3 = Color3.new(0,0,0)
    overlay.BackgroundTransparency = 1
    overlay.ZIndex = 1
    overlay.Parent = sg
    
    local main = Instance.new("Frame")
    main.Name = "MainPanel"
    main.Size = UDim2.new(0, 400, 0, 500)
    main.Position = UDim2.new(0.5, 0, 0.5, 0)
    main.AnchorPoint = Vector2.new(0.5, 0.5)
    main.BackgroundColor3 = COLOR_BG
    main.BorderSizePixel = 0
    main.ClipsDescendants = true
    main.ZIndex = 2
    main.Parent = overlay
    
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 16)
    
    -- STUDS BG
    local studs = Instance.new("ImageLabel")
    studs.Size = UDim2.new(1,0,1,0)
    studs.BackgroundTransparency = 1
    studs.Image = "rbxassetid://6372755229" -- Studs texture
    studs.ImageTransparency = 0.9
    studs.TileSize = UDim2.new(0, 64, 0, 64)
    studs.ScaleType = Enum.ScaleType.Tile
    studs.Parent = main
    
    -- HEADER
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1,0,0.15,0)
    header.BackgroundColor3 = COLOR_BLUE
    header.BorderSizePixel = 0
    header.Parent = main
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1,0,1,0)
    title.BackgroundTransparency = 1
    title.Text = "MEJORA DE BASE"
    title.Font = Enum.Font.FredokaOne
    title.TextColor3 = Color3.new(1,1,1)
    title.TextSize = 32
    title.Parent = header
    
    -- CONTENT
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -40, 0.65, 0)
    content.Position = UDim2.new(0, 20, 0.2, 0)
    content.BackgroundTransparency = 1
    content.Parent = main
    
    local function createStatRow(name, valCurrent, valNext, yPos)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1,0,0.25,0)
        frame.Position = UDim2.new(0,0,yPos,0)
        frame.BackgroundColor3 = Color3.fromRGB(30,30,30)
        frame.Parent = content
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
        
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.4, 0, 1, 0)
        lbl.Position = UDim2.new(0.05, 0, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = name
        lbl.TextColor3 = Color3.fromRGB(200,200,200)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextSize = 18
        lbl.Parent = frame
        
        local val = Instance.new("TextLabel")
        val.Size = UDim2.new(0.5, 0, 1, 0)
        val.Position = UDim2.new(0.45, 0, 0, 0)
        val.BackgroundTransparency = 1
        val.Text = valCurrent .. " ➤ " .. valNext
        val.TextColor3 = Color3.new(1,1,1)
        val.Font = Enum.Font.GothamBlack
        val.TextXAlignment = Enum.TextXAlignment.Right
        val.TextSize = 20
        val.Parent = frame
        
        -- Color the change green
        val.RichText = true
        val.Text = valCurrent .. " <font color=\"rgb(0,255,100)\">➤ " .. valNext .. "</font>"
    end
    
    -- Rows (Dynamic text, we will update these on open)
    local row1 = Instance.new("Frame") -- Placeholder
    
    -- BUY BUTTON
    local btn = Instance.new("TextButton")
    btn.Name = "BuyButton"
    btn.Size = UDim2.new(0.8, 0, 0.12, 0)
    btn.Position = UDim2.new(0.1, 0, 0.85, 0)
    btn.BackgroundColor3 = COLOR_GOLD
    btn.Text = "MEJORAR ($??)"
    btn.Font = Enum.Font.FredokaOne
    btn.TextColor3 = Color3.new(1,1,1)
    btn.TextSize = 24
    btn.Parent = main
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 100)
    
    -- CLOSE BUTTON
    local close = Instance.new("TextButton")
    close.Size = UDim2.new(0, 40, 0, 40)
    close.Position = UDim2.new(1, -50, 0, 5)
    close.BackgroundTransparency = 1
    close.Text = "X"
    close.TextColor3 = Color3.new(1,1,1)
    close.Font = Enum.Font.FredokaOne
    close.TextSize = 28
    close.Parent = main -- Put on main, safer zindex
    close.ZIndex = 5
    
    return sg, main, content, btn, close
end

local gui, mainFrame, contentFrame, buyBtn, closeBtn = createUpgradeUI()

local function updateUI(stats)
    -- Clear content
    for _, c in pairs(contentFrame:GetChildren()) do c:Destroy() end
    
    -- Rebuild Rows
    local function createRow(name, cur, nxt, yOrder, isMax)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1,0,0.20,0)
        f.Position = UDim2.new(0,0, (yOrder-1)*0.25, 0)
        f.BackgroundColor3 = Color3.fromRGB(30,30,30)
        f.Parent = contentFrame
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
        
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(0.5,0,1,0)
        l.Position = UDim2.new(0.05,0,0,0)
        l.BackgroundTransparency=1
        l.Text=name
        l.TextColor3=Color3.fromRGB(180,180,180)
        l.Font=Enum.Font.GothamBold
        l.TextXAlignment=Enum.TextXAlignment.Left
        l.Parent=f
        
        local v = Instance.new("TextLabel")
        v.Size = UDim2.new(0.4,0,1,0)
        v.Position = UDim2.new(0.55,0,0,0)
        v.BackgroundTransparency=1
        v.RichText=true
        if isMax then
            v.Text = cur
        else
            v.Text = cur .. " <font color=\"rgb(100,255,100)\">➜ " .. nxt .. "</font>"
        end
        v.TextColor3=Color3.new(1,1,1)
        v.Font=Enum.Font.GothamBlack
        v.TextXAlignment=Enum.TextXAlignment.Right
        v.Parent=f
    end
    
    createRow("Nivel Base", stats.Level, stats.NextLevel, 1, stats.IsMax)
    createRow("Capacidad Slots", stats.Slots, stats.NextSlots, 2, stats.IsMax)
    createRow("Mult. Ingresos", "x"..stats.Mult, "x"..(stats.NextMult), 3, stats.IsMax)
    
    if stats.IsMax then
        buyBtn.Text = "NIVEL MÁXIMO"
        buyBtn.Active = false
    else
        buyBtn.Text = "MEJORAR ($" .. EconomyLogic.Abbreviate(stats.Cost) .. ")"
        buyBtn.Active = true
    end
end

local function toggle(state)
    gui.Enabled = state
    if state then
        mainFrame.Size = UDim2.new(0,0,0,0)
        TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0,400,0,500)}):Play()
        gui.Overlay.BackgroundTransparency = 1
        TweenService:Create(gui.Overlay, TweenInfo.new(0.4), {BackgroundTransparency = 0.5}):Play()
    end
end

if OpenEvent then
    print("[BaseUpgradeUI] Listener active for OpenBaseUpgradeUI")
    OpenEvent.OnClientEvent:Connect(function(tycoon)
        print("[BaseUpgradeUI] Received Open Event for: " .. tycoon.Name)
        currentTycoon = tycoon
        local lvl = tycoon:GetAttribute("BaseLevel") or 1
        
        -- COST CALC (EXTREME SHIELD - Matches Server)
        local COSTS = {
            [1] = 1e9,    -- Billion
            [2] = 1e15,   -- Quadrillion
            [3] = 1e21,   -- Sextillion
            [4] = 1e27    -- Octillion
        }
        local cost = COSTS[lvl] or 1e33
        
        local isMax = lvl >= 5
        
        local stats = {
            Level = lvl,
            NextLevel = isMax and lvl or (lvl + 1),
            Slots = lvl * 10,
            NextSlots = (lvl + 1) * 10,
            Mult = 1.0 + (lvl-1)*0.5,
            NextMult = 1.0 + (lvl)*0.5,
            Cost = cost,
            IsMax = isMax
        }
        
        updateUI(stats)
        
        if isMax then
            buyBtn.Text = "NIVEL MÁXIMO"
            buyBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
            buyBtn.AutoButtonColor = false
        else
            buyBtn.BackgroundColor3 = Color3.fromRGB(255, 170, 0) -- Gold
            buyBtn.AutoButtonColor = true
        end
        
        toggle(true)
    end)
end

closeBtn.Activated:Connect(function() toggle(false) end)
gui.Overlay.InputBegan:Connect(function(input) 
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        toggle(false)
    end
end)

buyBtn.Activated:Connect(function()
    if not currentTycoon then return end
    
    local success, msg = UpgradeFunc:InvokeServer(currentTycoon)
    if success then
        -- Play sound or FX?
        print("Upgrade Success: " .. tostring(msg))
    else
        warn("Upgrade Failed: " .. tostring(msg))
    end
    toggle(false)
end)
