-- TradeGUI.client.lua
-- Skill: ui-design
-- Description: Trading Interface (Premium Dark Theme). 
-- Corrected for visibility, filtering, and flow.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UIManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UIManager"))
local Maid = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Maid"))
local tradeMaid = Maid.new()

local Remotes = ReplicatedStorage:WaitForChild("TradeRemotes", 10)
if not Remotes then return end

local GetInvRemote = ReplicatedStorage:WaitForChild("GetInventory", 5)
local RequestTradeRemote = Remotes:WaitForChild("RequestTrade", 10)

-- 1. GUI SETUP
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TradeGui"
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

-- MAIN CONTAINER
local mainFrame = Instance.new("Frame")
mainFrame.Name = "TradeFrame"
mainFrame.Size = UDim2.new(0.6, 0, 0.7, 0) -- Scaled size
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false -- START HIDDEN
mainFrame.ZIndex = 2
mainFrame.Parent = screenGui

local frame = mainFrame -- Compatibility

-- Add Aspect Ratio
local ratio = Instance.new("UIAspectRatioConstraint")
ratio.AspectRatio = 1.5
ratio.AspectType = Enum.AspectType.FitWithinMaxSize
ratio.Parent = mainFrame

Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 16)
local stroke = Instance.new("UIStroke")
stroke.Thickness = 2
stroke.Color = Color3.fromRGB(60, 60, 70)
stroke.Parent = frame

-- HEADER
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 50)
header.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
header.BorderSizePixel = 0
header.Parent = frame
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 16)

local titleLbl = Instance.new("TextLabel")
titleLbl.Text = "SECURE TRADING"
titleLbl.Font = Enum.Font.GothamBlack
titleLbl.TextSize = 20
titleLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
titleLbl.Size = UDim2.new(1, 0, 1, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.ZIndex = 2
titleLbl.Parent = header

local subtitleLbl = Instance.new("TextLabel")
subtitleLbl.Name = "OpponentName"
subtitleLbl.Text = "TRADING WITH: ..."
subtitleLbl.Font = Enum.Font.GothamMedium
subtitleLbl.TextSize = 12
subtitleLbl.TextColor3 = Color3.fromRGB(150, 150, 150)
subtitleLbl.Size = UDim2.new(1, 0, 0, 20)
subtitleLbl.Position = UDim2.new(0, 0, 1, -20)
subtitleLbl.BackgroundTransparency = 1
subtitleLbl.ZIndex = 2
subtitleLbl.Parent = header

-- CLOSE BUTTON
local closeBtn = Instance.new("TextButton")
closeBtn.Text = "X"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 18
closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -45, 0.5, -20)
closeBtn.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
closeBtn.ZIndex = 3
closeBtn.Parent = header
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

-- PANES
local function createPane(name, pos, titleText)
    local container = Instance.new("Frame")
    container.Name = name .. "Container"
    container.Size = UDim2.new(0.42, 0, 0.65, 0)
    container.Position = pos
    container.BackgroundTransparency = 1
    container.Parent = frame

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Text = titleText
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = Color3.fromRGB(150, 150, 160)
    title.BackgroundTransparency = 1
    title.Parent = container

    local f = Instance.new("Frame")
    f.Name = "Content"
    f.Size = UDim2.new(1, 0, 1, -35)
    f.Position = UDim2.new(0, 0, 0, 35)
    f.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    f.Parent = container
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)
    
    local fStroke = Instance.new("UIStroke")
    fStroke.Color = Color3.fromRGB(40, 40, 50)
    fStroke.Thickness = 1.5
    fStroke.Parent = f

    local list = Instance.new("ScrollingFrame")
    list.Name = "List"
    list.Size = UDim2.new(1, -10, 1, -10)
    list.Position = UDim2.new(0, 5, 0, 5)
    list.BackgroundTransparency = 1
    list.ScrollBarThickness = 4
    list.Parent = f
    
    local gl = Instance.new("UIGridLayout")
    gl.CellSize = UDim2.new(0.48, 0, 0.3, 0) -- 2 items per row
    gl.CellPadding = UDim2.new(0.04, 0, 0.04, 0)
    gl.Parent = list
    
    -- OVERLAY
    local sOverlay = Instance.new("Frame")
    sOverlay.Name = "StatusOverlay"
    sOverlay.Size = UDim2.new(1,0,1,0)
    sOverlay.BackgroundColor3 = Color3.new(0,0,0)
    sOverlay.BackgroundTransparency = 0.3
    sOverlay.Visible = false
    sOverlay.ZIndex = 5
    sOverlay.Parent = f
    Instance.new("UICorner", sOverlay).CornerRadius = UDim.new(0, 8)
    
    local txt = Instance.new("TextLabel")
    txt.Name = "StatusText"
    txt.Text = "READY"
    txt.Font = Enum.Font.GothamBlack
    txt.TextSize = 24
    txt.Size = UDim2.new(1,0,1,0)
    txt.BackgroundTransparency = 1
    txt.Parent = sOverlay
    
    return container
end

local myPane = createPane("MyOffer", UDim2.new(0.05, 0, 0.15, 0), "YOU")
local theirPane = createPane("TheirOffer", UDim2.new(0.53, 0, 0.15, 0), "OPPONENT")

-- ACTIONS AREA
local actionsFrame = Instance.new("Frame")
actionsFrame.Size = UDim2.new(1, 0, 0, 80)
actionsFrame.Position = UDim2.new(0, 0, 1, -80)
actionsFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
actionsFrame.BorderSizePixel = 0
actionsFrame.Parent = frame
Instance.new("UICorner", actionsFrame).CornerRadius = UDim.new(0, 16)

-- ADD ITEMS BUTTON
local pickerBtn = Instance.new("TextButton")
pickerBtn.Text = "+ Add Items"
pickerBtn.Font = Enum.Font.GothamBold
pickerBtn.TextSize = 16
pickerBtn.Size = UDim2.new(0.3, 0, 0, 50)
pickerBtn.Position = UDim2.new(0.05, 0, 0.5, -25)
pickerBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
pickerBtn.TextColor3 = Color3.new(1,1,1)
pickerBtn.Parent = actionsFrame
Instance.new("UICorner", pickerBtn).CornerRadius = UDim.new(0, 8)
local pStroke = Instance.new("UIStroke")
pStroke.Color = Color3.fromRGB(70, 70, 80)
pStroke.Thickness = 1
pStroke.Parent = pickerBtn

-- LOCK/CONFIRM BUTTON
local lockBtn = Instance.new("TextButton")
lockBtn.Name = "LockBtn"
lockBtn.Text = "LOCK OFFER"
lockBtn.Font = Enum.Font.GothamBlack
lockBtn.TextSize = 18
lockBtn.Size = UDim2.new(0.4, 0, 0, 60)
lockBtn.Position = UDim2.new(0.55, 0, 0.5, -30)
lockBtn.BackgroundColor3 = Color3.fromRGB(255, 170, 0) -- Orange init
lockBtn.TextColor3 = Color3.new(0,0,0)
lockBtn.Parent = actionsFrame
Instance.new("UICorner", lockBtn).CornerRadius = UDim.new(0, 100) -- Capsule

-- === PICKER FRAME ===
local picker = Instance.new("Frame")
picker.Name = "InventoryPicker"
picker.Size = UDim2.new(0, 320, 0, 450)
picker.AnchorPoint = Vector2.new(0.5, 0.5)
picker.Position = UDim2.new(0.5, 0, 0.5, 0) -- Centered
picker.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
picker.Visible = false
picker.ZIndex = 20
picker.Parent = frame 
Instance.new("UICorner", picker).CornerRadius = UDim.new(0, 12)
local pkStroke = Instance.new("UIStroke")
pkStroke.Thickness = 2
pkStroke.Color = Color3.fromRGB(60, 60, 70)
pkStroke.Parent = picker

local pkTitle = Instance.new("TextLabel")
pkTitle.Text = "YOUR INVENTORY"
pkTitle.Font = Enum.Font.GothamBold
pkTitle.TextSize = 16
pkTitle.TextColor3 = Color3.new(1,1,1)
pkTitle.Size = UDim2.new(1,0,0,40)
pkTitle.BackgroundTransparency = 1
pkTitle.Parent = picker

local closePicker = Instance.new("TextButton")
closePicker.Text = "X"
closePicker.Size = UDim2.new(0, 30, 0, 30)
closePicker.Position = UDim2.new(1, -35, 0, 5)
closePicker.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
closePicker.TextColor3 = Color3.fromRGB(255, 100, 100)
closePicker.Parent = picker
Instance.new("UICorner", closePicker).CornerRadius = UDim.new(0, 6)

closePicker.MouseButton1Click:Connect(function()
    picker.Visible = false
end)

local pickerList = Instance.new("ScrollingFrame")
pickerList.Name = "List"
pickerList.Size = UDim2.new(0.9, 0, 0.85, 0)
pickerList.Position = UDim2.new(0.05, 0, 0.1, 0)
pickerList.BackgroundTransparency = 1
pickerList.Parent = picker
Instance.new("UIGridLayout", pickerList).CellSize = UDim2.new(0.3, 0, 0.3, 0)

-- === LOBBY BROWSER ===
local lobbyFrame = Instance.new("Frame")
lobbyFrame.Name = "LobbyFrame"
lobbyFrame.Size = UDim2.new(0, 250, 0, 300)
lobbyFrame.Position = UDim2.new(0, 130, 0.5, -150)
lobbyFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
lobbyFrame.Visible = false
lobbyFrame.Parent = screenGui
Instance.new("UICorner", lobbyFrame).CornerRadius = UDim.new(0, 12)
local lfStroke = Instance.new("UIStroke")
lfStroke.Thickness = 2
lfStroke.Color = Color3.fromRGB(60, 60, 70)
lfStroke.Parent = lobbyFrame

local lTitle = Instance.new("TextLabel")
lTitle.Text = "ACTIVE PLAYERS"
lTitle.Font = Enum.Font.GothamBold
lTitle.TextSize = 14
lTitle.TextColor3 = Color3.fromRGB(150, 150, 160)
lTitle.Size = UDim2.new(1, 0, 0, 30)
lTitle.BackgroundTransparency = 1
lTitle.Parent = lobbyFrame

local closeLobby = Instance.new("TextButton")
closeLobby.Text = "X"
closeLobby.Size = UDim2.new(0, 25, 0, 25)
closeLobby.Position = UDim2.new(1, -30, 0, 2)
closeLobby.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
closeLobby.TextColor3 = Color3.fromRGB(255, 100, 100)
closeLobby.Parent = lobbyFrame
Instance.new("UICorner", closeLobby).CornerRadius = UDim.new(0, 4)

local playerListF = Instance.new("ScrollingFrame")
playerListF.Size = UDim2.new(1, -10, 1, -40)
playerListF.Position = UDim2.new(0, 5, 0, 35)
playerListF.BackgroundTransparency = 1
playerListF.Parent = lobbyFrame
Instance.new("UIGridLayout", playerListF).CellSize = UDim2.new(1, 0, 0, 40)

-- === REQUEST NOTIFICATION ===
local requestFrame = Instance.new("Frame")
requestFrame.Size = UDim2.new(0, 350, 0, 120)
requestFrame.Position = UDim2.new(0.5, -175, 0, -200) 
requestFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
requestFrame.Visible = false 
requestFrame.Parent = screenGui
Instance.new("UICorner", requestFrame).CornerRadius = UDim.new(0, 12)
local rStroke = Instance.new("UIStroke")
rStroke.Thickness = 2
rStroke.Color = Color3.fromRGB(0, 170, 255)
rStroke.Parent = requestFrame

local reqText = Instance.new("TextLabel")
reqText.Size = UDim2.new(1,0,0.5,0)
reqText.Text = "Incoming Trade Request"
reqText.Font = Enum.Font.GothamBold
reqText.TextSize = 18
reqText.TextColor3 = Color3.new(1,1,1)
reqText.BackgroundTransparency = 1
reqText.Parent = requestFrame

local accBtn = Instance.new("TextButton")
accBtn.Text = "ACCEPT"
accBtn.Size = UDim2.new(0.4, 0, 0.3, 0)
accBtn.Position = UDim2.new(0.05, 0, 0.55, 0)
accBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
accBtn.TextColor3 = Color3.new(1,1,1)
accBtn.Font = Enum.Font.GothamBold
accBtn.Parent = requestFrame
Instance.new("UICorner", accBtn).CornerRadius = UDim.new(0, 6)

local decBtn = Instance.new("TextButton")
decBtn.Text = "DECLINE"
decBtn.Size = UDim2.new(0.4, 0, 0.3, 0)
decBtn.Position = UDim2.new(0.55, 0, 0.55, 0)
decBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
decBtn.TextColor3 = Color3.new(1,1,1)
decBtn.Font = Enum.Font.GothamBold
decBtn.Parent = requestFrame
Instance.new("UICorner", decBtn).CornerRadius = UDim.new(0, 6)

-- === CONFIRM CANCEL FRAME ===
local confirmFrame = Instance.new("Frame")
confirmFrame.Name = "ConfirmCancel"
confirmFrame.Size = UDim2.new(0, 300, 0, 150)
confirmFrame.Position = UDim2.new(0.5, -150, 0.5, -75)
confirmFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
confirmFrame.Visible = false
confirmFrame.ZIndex = 100
confirmFrame.Parent = screenGui
Instance.new("UICorner", confirmFrame).CornerRadius = UDim.new(0, 12)
Instance.new("UIStroke", confirmFrame).Thickness = 2

local cTitle = Instance.new("TextLabel")
cTitle.Text = "CANCEL TRADE?"
cTitle.Font = Enum.Font.GothamBlack
cTitle.TextSize = 18
cTitle.TextColor3 = Color3.new(1,1,1)
cTitle.Size = UDim2.new(1, 0, 0, 50)
cTitle.BackgroundTransparency = 1
cTitle.Parent = confirmFrame

local yesBtn = Instance.new("TextButton")
yesBtn.Text = "CONFIRM"
yesBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
yesBtn.Size = UDim2.new(0.4, 0, 0, 40)
yesBtn.Position = UDim2.new(0.05, 0, 0.6, 0)
yesBtn.TextColor3 = Color3.new(1,1,1)
yesBtn.Font = Enum.Font.GothamBold
yesBtn.Parent = confirmFrame
Instance.new("UICorner", yesBtn).CornerRadius = UDim.new(0, 6)

local noBtn = Instance.new("TextButton")
noBtn.Text = "BACK"
noBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
noBtn.Size = UDim2.new(0.4, 0, 0, 40)
noBtn.Position = UDim2.new(0.55, 0, 0.6, 0)
noBtn.TextColor3 = Color3.new(1,1,1)
noBtn.Font = Enum.Font.GothamBold
noBtn.Parent = confirmFrame
Instance.new("UICorner", noBtn).CornerRadius = UDim.new(0, 6)

-- LOGIC & STATE
local isSessionActive = false -- TRACKER FOR HUD 
_G.IsTradeActive = function() return isSessionActive end -- Global hook for HUDManager

local currentSession = nil
local myInventory = {}
local currentOfferIds = {} -- Track items currently in trade for filtering

-- Forward declarations
local updateView

local function toggleUI(state)
    if state == nil then state = not mainFrame.Visible end
    
    if state then
        mainFrame.Size = UDim2.new(0, 0, 0, 0)
        mainFrame.Visible = true
        overlay.Visible = true
        TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back), {Size = UDim2.new(0.6, 0, 0.7, 0)}):Play()
        TweenService:Create(overlay, TweenInfo.new(0.4), {BackgroundTransparency = 0.5}):Play()
    else
        local t = TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quart), {Size = UDim2.new(0, 0, 0, 0)})
        t:Play()
        TweenService:Create(overlay, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
        t.Completed:Connect(function()
            if UIManager.CurrentOpenUI ~= "TradeUI" then
                mainFrame.Visible = false
                overlay.Visible = false
            end
        end)
    end
end

-- Click overlay DISABLED as per UX request (v3)
-- overlay.MouseButton1Click:Connect(function()
--     UIManager.Close("TradeUI")
-- end)

function updateView(state)
    isSessionActive = (state.Status == "Active")
    
    -- Ensure UI is open when state updates
    if not mainFrame.Visible and state.Status ~= "Completed" then
        UIManager.Open("TradeUI")
    end
    
    local amI_P1 = (state.P1 == player.Name)
    local myData = amI_P1 and {Offer=state.Offer1Details, Locked=state.Locked1, Confirmed=state.Confirmed1} or {Offer=state.Offer2Details, Locked=state.Locked2, Confirmed=state.Confirmed2}
    local theirData = amI_P1 and {Name=state.P2, Offer=state.Offer2Details, Locked=state.Locked2, Confirmed=state.Confirmed2} or {Name=state.P1, Offer=state.Offer1Details, Locked=state.Locked1, Confirmed=state.Confirmed1}
    
    myPane.Title.Text = "YOU"
    theirPane.Title.Text = string.upper(theirData.Name)
    subtitleLbl.Text = "TRADING WITH: " .. string.upper(theirData.Name)

    -- Update offer IDs for filtering
    currentOfferIds = {}
    for _, item in pairs(myData.Offer) do
        currentOfferIds[item.Id] = true
    end

    -- Item Filler
    local function fill(container, items)
        local list = container.Content.List
        for _, c in pairs(list:GetChildren()) do if c:IsA("Frame") or c:IsA("TextButton") then c:Destroy() end end
        
        for _, item in pairs(items) do
            local card = Instance.new("TextButton")
            card.Text = ""
            card.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
            card.Parent = list
            Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
            
            local icon = Instance.new("TextLabel")
            icon.Text = (item.Shiny and "✨" or "📦")
            icon.TextSize = 20
            icon.Size = UDim2.new(1,0,0.7,0)
            icon.BackgroundTransparency = 1
            icon.ZIndex = 2
            icon.Parent = card
            
            local lbl = Instance.new("TextLabel")
            lbl.Text = string.upper(item.Name)
            lbl.Size = UDim2.new(1,0,0.3,0)
            lbl.Position = UDim2.new(0,0,0.7,0)
            lbl.BackgroundTransparency = 1
            lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
            lbl.Font = Enum.Font.GothamBold
            lbl.TextSize = 9
            lbl.ZIndex = 2
            lbl.Parent = card

            -- CLICK TO REMOVE (Only for MY pane)
            if container == myPane then
                card.MouseButton1Click:Connect(function()
                    Remotes.ModifyOffer:InvokeServer("Remove", item.Id)
                end)
            end
        end
    end
    
    fill(myPane, myData.Offer)
    fill(theirPane, theirData.Offer)
    
    -- Overlays
    local myOverlay = myPane.Content.StatusOverlay
    myOverlay.Visible = myData.Locked
    myOverlay.StatusText.Text = myData.Confirmed and "READY" or "LOCKED"
    myOverlay.StatusText.TextColor3 = myData.Confirmed and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 170, 0)
    
    local theirOverlay = theirPane.Content.StatusOverlay
    theirOverlay.Visible = theirData.Locked
    theirOverlay.StatusText.Text = theirData.Confirmed and "READY" or "LOCKED"
    theirOverlay.StatusText.TextColor3 = theirData.Confirmed and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 170, 0)
    
    -- Main Button State
    if myData.Confirmed then
        lockBtn.Text = "WAITING..."
        lockBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
    elseif myData.Locked then
        lockBtn.Text = "CONFIRM TRADE!"
        lockBtn.BackgroundColor3 = Color3.fromRGB(0, 220, 100)
    else
        lockBtn.Text = "LOCK OFFER"
        lockBtn.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
    end
    
    if state.Status == "Completed" then
        isSessionActive = false
        mainFrame.Visible = false
        overlay.Visible = false
        picker.Visible = false
        if lobbyFrame then lobbyFrame.Visible = false end
        requestFrame.Visible = false
        confirmFrame.Visible = false
    end
end

-- EVENTS
local inviteMaid = Maid.new()
tradeMaid:Give(Remotes.TradeInvite.OnClientEvent:Connect(function(fromPlayer)
    inviteMaid:DoCleaning()
    
    reqText.Text = fromPlayer.Name .. " wants to trade!"
    requestFrame.Visible = true
    requestFrame:TweenPosition(UDim2.new(0.5, -175, 0, 50), "Out", "Back", 0.5)
    
    inviteMaid:Give(accBtn.MouseButton1Click:Connect(function()
        Remotes.AcceptTrade:InvokeServer(fromPlayer)
        requestFrame:TweenPosition(UDim2.new(0.5, -175, 0, -200), "In", "Quad", 0.3)
        task.delay(0.3, function() requestFrame.Visible = false end)
        inviteMaid:DoCleaning()
    end))

    inviteMaid:Give(decBtn.MouseButton1Click:Connect(function()
        requestFrame:TweenPosition(UDim2.new(0.5, -175, 0, -200), "In", "Quad", 0.3)
        task.delay(0.3, function() requestFrame.Visible = false end)
        inviteMaid:DoCleaning()
    end))
end))

Remotes.UpdateTradeState.OnClientEvent:Connect(function(state)
    updateView(state)
end)

Remotes.TradeClosed.OnClientEvent:Connect(function(reason)
    isSessionActive = false
    mainFrame.Visible = false
    overlay.Visible = false
    picker.Visible = false
    if lobbyFrame then lobbyFrame.Visible = false end
    confirmFrame.Visible = false
    print("Trade Closed: " .. reason)
end)

-- CLOSE BUTTON WITH CONFIRMATION
closeBtn.MouseButton1Click:Connect(function()
    if isSessionActive then
        confirmFrame.Visible = true
    else
        UIManager.Close("TradeUI")
        Remotes.TradeClosed:FireServer("Cancelled by user")
    end
end)

yesBtn.MouseButton1Click:Connect(function()
    confirmFrame.Visible = false
    UIManager.Close("TradeUI")
    Remotes.TradeClosed:FireServer("Cancelled by user")
end)

noBtn.MouseButton1Click:Connect(function()
    confirmFrame.Visible = false
end)

-- REGISTER WITH UIManager
task.defer(function()
    UIManager.Register("TradeUI", mainFrame, toggleUI)
    
    local function toggleLobby(state)
        if state == nil then state = not lobbyFrame.Visible end
        if state then
            lobbyFrame.Size = UDim2.new(0, 0, 0, 0)
            lobbyFrame.Visible = true
            TweenService:Create(lobbyFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back), {Size = UDim2.new(0, 250, 0, 300)}):Play()
        else
            lobbyFrame.Visible = false
        end
    end
    UIManager.Register("LobbyUI", lobbyFrame, toggleLobby)
end)

-- PICKER LOGIC
pickerBtn.MouseButton1Click:Connect(function()
    picker.Visible = not picker.Visible
    if picker.Visible and GetInvRemote then
        picker.Active = true
        local syncData = GetInvRemote:InvokeServer()
        myInventory = syncData.Inventory or {}
        local list = picker.List
        for _, c in pairs(list:GetChildren()) do if c:IsA("Frame") or c:IsA("TextButton") then c:Destroy() end end
        
        for _, item in pairs(myInventory) do
            if currentOfferIds[item.Id] then continue end -- FILTERING
            
            local btn = Instance.new("TextButton")
            btn.BackgroundColor3 = Color3.fromRGB(40,40,50)
            btn.Parent = list
            btn.Text = ""
            btn.BorderSizePixel = 0
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
            
            local nameL = Instance.new("TextLabel")
            nameL.Text = item.Name
            nameL.Font = Enum.Font.GothamBold
            nameL.Size = UDim2.new(1,0,0.5,0)
            nameL.TextColor3 = Color3.new(1,1,1)
            nameL.BackgroundTransparency = 1
            nameL.TextScaled = true
            nameL.Parent = btn
            
            local tierL = Instance.new("TextLabel")
            tierL.Text = item.Tier
            tierL.Size = UDim2.new(1,0,0.3,0)
            tierL.Position = UDim2.new(0,0,0.6,0)
            tierL.TextColor3 = Color3.fromRGB(150,150,255) 
            tierL.BackgroundTransparency = 1
            tierL.TextScaled = true
            tierL.Parent = btn
            
            btn.MouseButton1Click:Connect(function()
                Remotes.ModifyOffer:InvokeServer("Add", item.Id)
                btn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
                task.wait(0.1)
                if btn and btn.Parent then btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50) end
            end)
        end
    end
end)

lockBtn.MouseButton1Click:Connect(function()
    if lockBtn.Text == "LOCK OFFER" then
        Remotes.SetLock:InvokeServer(true)
    elseif lockBtn.Text == "CONFIRM TRADE!" then
        Remotes.ConfirmTrade:InvokeServer()
    elseif lockBtn.Text == "WAITING..." then
        Remotes.SetLock:InvokeServer(false)
    end
end)

-- LOBBY LOGIC
local function refreshLobby()
    for _, c in pairs(playerListF:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    
    local count = 0
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player then
            count = count + 1
            local row = Instance.new("Frame")
            row.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
            row.Parent = playerListF
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
            
            local nameL = Instance.new("TextLabel")
            nameL.Text = p.Name
            nameL.Font = Enum.Font.GothamSemibold
            nameL.TextSize = 14
            nameL.TextColor3 = Color3.new(1,1,1)
            nameL.Size = UDim2.new(0.6, 0, 1, 0)
            nameL.Position = UDim2.new(0.05, 0, 0, 0)
            nameL.TextXAlignment = Enum.TextXAlignment.Left
            nameL.BackgroundTransparency = 1
            nameL.Parent = row
            
            local reqBtn = Instance.new("TextButton")
            reqBtn.Text = "REQUEST"
            reqBtn.Font = Enum.Font.GothamBold
            reqBtn.TextSize = 10
            reqBtn.Size = UDim2.new(0.3, 0, 0.7, 0)
            reqBtn.Position = UDim2.new(0.65, 0, 0.15, 0)
            reqBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 100)
            reqBtn.TextColor3 = Color3.new(1,1,1)
            reqBtn.Parent = row
            Instance.new("UICorner", reqBtn).CornerRadius = UDim.new(0, 4)
            
            reqBtn.MouseButton1Click:Connect(function()
                reqBtn.Text = "SENT..."
                reqBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                RequestTradeRemote:InvokeServer(p)
                task.delay(2, function()
                    if reqBtn and reqBtn.Parent then
                        reqBtn.Text = "REQUEST"
                        reqBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 100)
                    end
                end)
            end)
        end
    end
    
    if count == 0 then
        local empty = Instance.new("TextLabel")
        empty.Text = "No other players"
        empty.Size = UDim2.new(1,0,0,30)
        empty.BackgroundTransparency = 1
        empty.TextColor3 = Color3.fromRGB(100,100,100)
        empty.Parent = playerListF
    end
end

tradeMaid:Give(lobbyFrame:GetPropertyChangedSignal("Visible"):Connect(function()
    if lobbyFrame.Visible then
        refreshLobby()
    end
end))

tradeMaid:Give(closeLobby.MouseButton1Click:Connect(function()
    lobbyFrame.Visible = false
end))

tradeMaid:Give(Players.PlayerAdded:Connect(function() if lobbyFrame.Visible then refreshLobby() end end))
tradeMaid:Give(Players.PlayerRemoving:Connect(function() if lobbyFrame.Visible then refreshLobby() end end))
