-- ShopClient.client.lua
-- PREMIUM SPEED SHOP UI (Glassmorphism & Bulk Buy)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local EconomyLogic = require(ReplicatedStorage.Modules:WaitForChild("EconomyLogic"))

-- CONSTANTS
local THEME = {
	Background = Color3.fromRGB(15, 15, 20),
	Accent = Color3.fromRGB(0, 255, 255), -- Cyan
	Text = Color3.fromRGB(255, 255, 255),
	GlassTransparency = 0.2,
	CornerRadius = UDim.new(0, 20)
}

-- REMOTES
local GetUpgradeData = ReplicatedStorage:WaitForChild("GetUpgradeData")
local PurchaseSkill = ReplicatedStorage:WaitForChild("PurchaseSkill")
local zoneCheckConn = nil -- v5.0
local isRefreshing = false -- v5.1

local function playSound(id, vol, duration) -- v5.3 POLISH
    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://" .. tostring(id)
    s.Volume = vol or 0.5
    s.Parent = game:GetService("SoundService")
    s:Play()
    if duration then
        task.delay(duration, function()
            if s and s.Parent then s:Stop() s:Destroy() end
        end)
    else
        s.Ended:Connect(function() s:Destroy() end)
    end
end

-- 1. SETUP UI
if playerGui:FindFirstChild("SpeedShopUI") then
	playerGui.SpeedShopUI:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SpeedShopUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 15
screenGui.Parent = playerGui

-- OVERLAY
local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.new(0,0,0)
overlay.BackgroundTransparency = 1
overlay.Visible = false
overlay.ZIndex = 1
overlay.Parent = screenGui

-- BLUR
local blur = Instance.new("BlurEffect")
blur.Size = 0
blur.Parent = game:GetService("Lighting")

-- MAIN FRAME
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0.5, 0, 0.6, 0)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = THEME.Background
mainFrame.BackgroundTransparency = THEME.GlassTransparency
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Parent = screenGui

local uiCorner = Instance.new("UICorner", mainFrame)
uiCorner.CornerRadius = THEME.CornerRadius

local uiStroke = Instance.new("UIStroke", mainFrame)
uiStroke.Color = THEME.Accent
uiStroke.Thickness = 2
uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- HEADER
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0.15, 0)
header.BackgroundTransparency = 1
header.Parent = mainFrame

local titleIcon = Instance.new("ImageLabel")
titleIcon.Size = UDim2.new(0.1, 0, 0.8, 0)
titleIcon.Position = UDim2.new(0.02, 0, 0.1, 0)
titleIcon.BackgroundTransparency = 1
titleIcon.Image = "rbxassetid://6034509993" -- Speed Icon
titleIcon.ScaleType = Enum.ScaleType.Fit
titleIcon.Parent = header

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(0.7, 0, 1, 0)
titleLbl.Position = UDim2.new(0.12, 0, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "MEJORAS DE VELOCIDAD"
titleLbl.Font = Enum.Font.GothamBlack
titleLbl.TextColor3 = THEME.Accent
titleLbl.TextSize = 24
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0.08, 0, 0.6, 0)
closeBtn.Position = UDim2.new(0.9, 0, 0.2, 0)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextScaled = true
closeBtn.Parent = header
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0.3, 0)

closeBtn.MouseButton1Click:Connect(function()
	closeShop()
end)

-- CONTENT
local content = Instance.new("ScrollingFrame")
content.Size = UDim2.new(0.96, 0, 0.82, 0)
content.Position = UDim2.new(0.02, 0, 0.16, 0)
content.BackgroundTransparency = 1
content.ScrollBarThickness = 6
content.ScrollBarImageColor3 = THEME.Accent
content.Parent = mainFrame

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 10)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = content

-- UTILS
local function calculateCumulativePrice(baseLevel, amount)
	local total = 0
	local mock = baseLevel
	for i = 1, amount do
		total = total + math.floor(2500 * math.pow(1.5, mock))
		mock = mock + 1
	end
	return total
end

-- CARD CREATION
local function createCard(id, name, level, icon, desc, canBulk)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0.25, 0)
	card.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	card.BackgroundTransparency = 0.3
	card.Parent = content
	
	Instance.new("UICorner", card).CornerRadius = UDim.new(0.1, 0)
	local cardStroke = Instance.new("UIStroke", card)
	cardStroke.Color = Color3.fromRGB(255,255,255)
	cardStroke.Transparency = 0.9
	cardStroke.Thickness = 1
	
	-- Icon
	local iconImg = Instance.new("TextLabel") -- Emoji or Image
	iconImg.Size = UDim2.new(0.15, 0, 0.8, 0)
	iconImg.Position = UDim2.new(0.02, 0, 0.1, 0)
	iconImg.BackgroundTransparency = 1
	iconImg.Text = icon
	iconImg.TextScaled = true
	iconImg.Parent = card
	
	-- Info
	local infoFrame = Instance.new("Frame")
	infoFrame.Size = UDim2.new(0.4, 0, 0.8, 0)
	infoFrame.Position = UDim2.new(0.18, 0, 0.1, 0)
	infoFrame.BackgroundTransparency = 1
	infoFrame.Parent = card
	
	local nameL = Instance.new("TextLabel")
	nameL.Size = UDim2.new(1, 0, 0.4, 0)
	nameL.BackgroundTransparency = 1
	nameL.Text = name .. (level and (" LVL " .. level) or "")
	nameL.TextColor3 = Color3.new(1,1,1)
	nameL.Font = Enum.Font.GothamBold
	nameL.TextScaled = true
	nameL.TextXAlignment = Enum.TextXAlignment.Left
	nameL.Parent = infoFrame
	
	local descL = Instance.new("TextLabel")
	descL.Size = UDim2.new(1, 0, 0.4, 0)
	descL.Position = UDim2.new(0, 0, 0.5, 0)
	descL.BackgroundTransparency = 1
	descL.Text = desc
	descL.TextColor3 = Color3.fromRGB(200, 200, 200)
	descL.TextScaled = true
	descL.TextXAlignment = Enum.TextXAlignment.Left
	descL.Font = Enum.Font.Gotham
	descL.Parent = infoFrame
	
	-- Buttons Container (Right)
	local btnContainer = Instance.new("Frame")
	btnContainer.Size = UDim2.new(0.4, 0, 0.9, 0)
	btnContainer.Position = UDim2.new(0.58, 0, 0.05, 0)
	btnContainer.BackgroundTransparency = 1
	btnContainer.Parent = card
	
	local btnLayout = Instance.new("UIListLayout")
	btnLayout.FillDirection = Enum.FillDirection.Horizontal
	btnLayout.Padding = UDim.new(0, 5)
	btnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	btnLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	btnLayout.Parent = btnContainer
	
	local function createBuyBtn(amount, color)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0.3, 0, 0.8, 0)
		btn.BackgroundColor3 = color
		btn.Text = ""
		btn.Parent = btnContainer
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0.2, 0)
		
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 0.4, 0)
		lbl.Position = UDim2.new(0, 0, 0.1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = "x" .. amount
		lbl.Font = Enum.Font.GothamBlack
		lbl.TextColor3 = Color3.new(0,0,0)
		lbl.TextScaled = true
		lbl.Parent = btn
		
		local priceLbl = Instance.new("TextLabel")
		priceLbl.Size = UDim2.new(1, 0, 0.4, 0)
		priceLbl.Position = UDim2.new(0, 0, 0.5, 0)
		priceLbl.BackgroundTransparency = 1
		
		-- Price Calc
		local price = 0
		if id == "SpeedUpgrade" then
			price = calculateCumulativePrice(level, amount)
		elseif id == "DoubleJump" or id == "BackpackUpgrade" then
			-- Fixed items logic
			if amount > 1 and id == "DoubleJump" then 
				btn.Visible = false -- Unique item, no bulk
				return 
			end
			-- Fixed prices ref
			local base = (id=="DoubleJump" and 1000) or 7500
			price = base * amount
		end
		
		priceLbl.Text = "$" .. EconomyLogic.Abbreviate(price)
		priceLbl.Font = Enum.Font.GothamBold
		priceLbl.TextColor3 = Color3.new(0,0,0)
		priceLbl.TextScaled = true
		priceLbl.Parent = btn
		
		btn.MouseButton1Click:Connect(function()
			local success, msg = PurchaseSkill:InvokeServer(id, amount)
			if success then
				refreshShop()
			else
				btn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
				btn.Text = "No $!"
				task.wait(1)
				btn.Text = ""
				btn.BackgroundColor3 = color
			end
		end)
	end
	
	if canBulk then
		createBuyBtn(1, Color3.fromRGB(100, 255, 150))
		createBuyBtn(5, Color3.fromRGB(246, 222, 10))
		createBuyBtn(10, Color3.fromRGB(0, 150, 255))
	else
		-- Single Buy for unique items
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0.6, 0, 0.6, 0)
		btn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
		btn.Text = "COMPRAR ($" .. EconomyLogic.Abbreviate( (id=="DoubleJump" and 1000) or 7500 ) .. ")"
		btn.Font = Enum.Font.GothamBold
		btn.Parent = btnContainer
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0.2, 0)
		
		btn.MouseButton1Click:Connect(function()
			local success, msg = PurchaseSkill:InvokeServer(id, 1)
			if success then refreshShop() end
		end)
	end
end

function refreshShop()
	if isRefreshing then return end
	isRefreshing = true
	
	-- CLEAR ALL CONTENT RELIABLY (v5.2 - More aggressive)
	for _, child in pairs(content:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	
	-- Fetch Data
	local success, data = pcall(function() return GetUpgradeData:InvokeServer() end)
	if not success or not data then 
		isRefreshing = false
		return 
	end
	
	local spdLvl = data.Level or 0
	
	-- Double Check before adding (v5.2)
	local currentCount = 0
	for _, c in pairs(content:GetChildren()) do
		if c:IsA("Frame") then currentCount = currentCount + 1 end
	end
	
	if currentCount == 0 then
		createCard("SpeedUpgrade", "Velocidad Humana", spdLvl, "⚡", "+1 Base Speed por nivel", true)
		createCard("DoubleJump", "Doble Salto", nil, "👟", "Habilidad Aérea", false)
	end
    
	isRefreshing = false
end

-- ANIMATION
function openShop()
	mainFrame.Visible = true -- Set immediately to prevent re-triggering (v5.1)
	overlay.Visible = true
	playSound(6895079853, 0.7, 0.1) -- SNAPPY CLICK (v5.3)
	
	refreshShop()
	
	TweenService:Create(blur, TweenInfo.new(0.5), {Size = 20}):Play()
	
	mainFrame.Size = UDim2.new(0, 0, 0, 0)
	TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0.5, 0, 0.6, 0)}):Play()
	TweenService:Create(overlay, TweenInfo.new(0.4), {BackgroundTransparency = 0.5}):Play()

	-- Zone Exit Detection (v5.0)
	if zoneCheckConn then zoneCheckConn:Disconnect() end
	zoneCheckConn = RunService.Heartbeat:Connect(function()
		if not mainFrame.Visible then 
			if zoneCheckConn then zoneCheckConn:Disconnect() zoneCheckConn = nil end
			return 
		end
		
		local char = player.Character
		if not char or not char.PrimaryPart then return end
		
		local inRange = false
		local zones = CollectionService:GetTagged("UpgradeZone")
		for _, zone in pairs(zones) do
			if zone:IsA("BasePart") then
				local dist = (char.PrimaryPart.Position - zone.Position).Magnitude
				if dist < 20 then -- Studs threshold
					inRange = true
					break
				end
			end
		end
		
		if not inRange then
			closeShop()
		end
	end)
end

function closeShop()
	if zoneCheckConn then 
		zoneCheckConn:Disconnect() 
		zoneCheckConn = nil 
	end
	playSound(6895079853, 0.5, 0.1) -- SNAPPY CLICK (v5.3)

	TweenService:Create(blur, TweenInfo.new(0.3), {Size = 0}):Play()
	TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.In), {Size = UDim2.new(0,0,0,0)}):Play()
	TweenService:Create(overlay, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
	task.wait(0.3)
	mainFrame.Visible = false
	overlay.Visible = false
end

-- ZONES
local function setupZone(zone)
	if zone:IsA("BasePart") then
		zone.Touched:Connect(function(hit)
			if hit.Parent and Players:GetPlayerFromCharacter(hit.Parent) == player then
				if not mainFrame.Visible then openShop() end
			end
		end)
	end
end

for _, z in pairs(CollectionService:GetTagged("UpgradeZone")) do setupZone(z) end
CollectionService:GetInstanceAddedSignal("UpgradeZone"):Connect(setupZone)

print("[SpeedShopUI] Loaded Glassmorphism UI.")
