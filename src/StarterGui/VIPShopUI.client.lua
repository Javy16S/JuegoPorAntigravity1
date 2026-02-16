-- VIPShopUI.client.lua
-- Skill: ui-framework
-- Description: Manages the VIP Shop UI using the pre-built VIPShopGui.
-- Includes Rainbow Gradients and 3D ViewportFrame previews for Lucky Blocks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- CONSTANTS
local RAINBOW_SPEED = 0.5 -- Speed of rainbow cycle
local THEME_ACCENT = Color3.fromRGB(255, 215, 0)

-- DEPENDENCIES
local Modules = ReplicatedStorage:WaitForChild("Modules", 10)
local ShopData = require(Modules:WaitForChild("ShopData"))
local UIManager = require(Modules:WaitForChild("UIManager"))

-- REMOTES
local PurchaseSkill = ReplicatedStorage:WaitForChild("PurchaseSkill")
local MarketplaceService = game:GetService("MarketplaceService")

-- STATE
local isShopOpen = false
local shopGui = nil
local mainFrame = nil
local overlay = nil
local rainbowConnections = {}
local viewportConnections = {}

local DISPLAY_NAMES = {
    ["lb_legendary"] = "LEGENDARY LUCKYBLOCK",
    ["lb_divine"] = "DIVINE LUCKYBLOCK",
    ["lb_celestial"] = "CELESTIAL LUCKYBLOCK",
    ["lb_abuse"] = "LUCKY BLOCK ABUSE",
    ["starter_bundle"] = "STARTER PACK"
}

-- FIND GUI
local function getShopGui()
	if shopGui and shopGui.Parent and mainFrame and mainFrame:FindFirstChild("ContentFrame") then 
        return shopGui 
    end
	
	-- 1. Try to find the "Official" version in Workspace first (Highest Priority as per User)
    local workspaceTemplate = Workspace:FindFirstChild("VIPShopGui") or Workspace:FindFirstChild("VIPShopUI")
    
    -- If not found immediately, wait a bit for replication
    if not workspaceTemplate then
        workspaceTemplate = Workspace:WaitForChild("VIPShopGui", 5) or Workspace:WaitForChild("VIPShopUI", 2)
    end
    
    -- 2. Check PlayerGui for an existing instance
	shopGui = PlayerGui:FindFirstChild("VIPShopUI")
    
    -- 3. If PlayerGui version is broken/missing, but Workspace has it, migrate from Workspace
    if workspaceTemplate and (not shopGui or not shopGui:FindFirstChild("MainFrame") or not shopGui.MainFrame:FindFirstChild("ContentFrame")) then
        if shopGui then 
            print("[VIPShopUI] Replacing incomplete/old UI in PlayerGui")
            shopGui:Destroy() 
        end
        
        print("[VIPShopUI] Replicating from Workspace...")
        shopGui = workspaceTemplate:Clone()
        shopGui.Name = "VIPShopUI"
        shopGui.IgnoreGuiInset = true
        shopGui.ResetOnSpawn = false
        shopGui.Parent = PlayerGui
    end
	
	-- 4. Backup: Check StarterGui / Templates
	if not shopGui or not shopGui:FindFirstChild("MainFrame") then
        if not shopGui then
            local starterGui = game:GetService("StarterGui")
            local template = starterGui:FindFirstChild("VIPShopUI") or starterGui:FindFirstChild("VIPShopGui")
            if template then
                shopGui = template:Clone()
                shopGui.Name = "VIPShopUI"
                shopGui.IgnoreGuiInset = true
                shopGui.ResetOnSpawn = false
                shopGui.Parent = PlayerGui
            end
        end
	end
	
	if not shopGui then
		warn("[VIPShopUI] CRITICAL: VIPShopGui template not found anywhere!")
		shopGui = Instance.new("ScreenGui")
		shopGui.Name = "VIPShopUI"
		shopGui.IgnoreGuiInset = true
		shopGui.ResetOnSpawn = false
		shopGui.Parent = PlayerGui
	end
	
	-- Setup References
	mainFrame = shopGui:FindFirstChild("MainFrame")
	if not mainFrame then
        warn("[VIPShopUI] MainFrame missing in cloned UI! Creating fallback.")
		mainFrame = Instance.new("Frame")
		mainFrame.Name = "MainFrame"
		mainFrame.Size = UDim2.new(0, 0, 0, 0)
		mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
		mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
		mainFrame.Visible = false
		mainFrame.Parent = shopGui
	end

	overlay = shopGui:FindFirstChild("Overlay")
	if not overlay then
		overlay = Instance.new("Frame")
		overlay.Name = "Overlay"
		overlay.Size = UDim2.new(1, 0, 1, 0)
		overlay.BackgroundColor3 = Color3.new(0,0,0)
		overlay.BackgroundTransparency = 1
		overlay.Visible = false
		overlay.ZIndex = 1
		overlay.Parent = shopGui
		
		local clickDetector = Instance.new("TextButton")
		clickDetector.Size = UDim2.new(1,0,1,0)
		clickDetector.Parent = overlay
		clickDetector.BackgroundTransparency = 1
		clickDetector.Text = ""
		clickDetector.MouseButton1Click:Connect(function()
			UIManager.Close("VIPShopUI")
		end)
	end
	
    -- ENFORCE RESPONSIVE
    if not mainFrame:FindFirstChild("ResponsiveRatio") then
        local ratio = Instance.new("UIAspectRatioConstraint")
        ratio.Name = "ResponsiveRatio"
        ratio.AspectRatio = 1.6
        ratio.Parent = mainFrame
    end
	
	return shopGui
end

-- HELPER: Synchronized Rainbow (Professional Studio Look)
local function applyRainbowGradient(canvasGroup)
	if not canvasGroup then return end
	
	local gradient = canvasGroup:FindFirstChildOfClass("UIGradient")
	if not gradient then
		gradient = Instance.new("UIGradient")
		gradient.Parent = canvasGroup
	end
	
    -- Professional Rainbow Sequence (Red -> Orange -> Yellow -> Green -> Cyan -> Blue -> Violet)
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
        ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 255, 0)),
        ColorSequenceKeypoint.new(0.4, Color3.fromRGB(0, 255, 0)),
        ColorSequenceKeypoint.new(0.6, Color3.fromRGB(0, 255, 255)),
        ColorSequenceKeypoint.new(0.8, Color3.fromRGB(0, 0, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 255))
    })

	local connection = RunService.RenderStepped:Connect(function(dt)
        -- Shifting rotation for a smooth flow
		gradient.Rotation = (tick() * 45) % 360
	end)
	
	table.insert(rainbowConnections, connection)
end

-- HELPER: Improved Model Search
local function findModelExhaustive(id)
    local target = id:lower()
    local trimmed = target:gsub("^lb_", "")
    
    local candidates = {}
    local function search(current, depth)
        if depth > 10 then return end
        
        if current:IsA("Model") or current:IsA("BasePart") then
            local curName = current.Name:lower()
            if curName == target then return current, 100 end
            if curName == trimmed then return current, 90 end
            if curName:find(trimmed) or trimmed:find(curName) then 
                table.insert(candidates, {m = current, s = 50}) 
            end
        end
        
        for _, child in ipairs(current:GetChildren()) do
            local res, score = search(child, depth + 1)
            if res then return res, score end
        end
        return nil
    end

    local rsModels = ReplicatedStorage:FindFirstChild("BrainrotModels")
    if rsModels then
        local found = search(rsModels, 0)
        if found then return found end
    end

    local rsLB = ReplicatedStorage:FindFirstChild("LuckyBlocks")
    if rsLB then
        local found = search(rsLB, 0)
        if found then return found end
    end

    local lbFolder = Workspace:FindFirstChild("LuckyBlocks")
    if lbFolder then
        local found = search(lbFolder, 0)
        if found then return found end
    end

    if #candidates > 0 then
        table.sort(candidates, function(a,b) return a.s > b.s end)
        return candidates[1].m
    end

    return nil
end

-- HELPER: Setup ViewportFrame (Original Working Version + Rotation Fix)
local function setupLuckyBlockViewport(containerFrame, blockId)
	if not containerFrame then return end
	
    local viewport = containerFrame:FindFirstChild("ViewportFrame") or containerFrame:FindFirstChild("BlockViewport")
    
    if not viewport then
        viewport = Instance.new("ViewportFrame")
        viewport.Name = "BlockViewport"
        viewport.Size = UDim2.new(0.85, 0, 0.65, 0)
        viewport.Position = UDim2.new(0.5, 0, 0.45, 0)
        viewport.AnchorPoint = Vector2.new(0.5, 0.5)
        viewport.BackgroundTransparency = 1
        viewport.Parent = containerFrame
        viewport.ZIndex = 2
    end
    
    -- Cleanup old children
    local worldModel = viewport:FindFirstChildOfClass("WorldModel")
    if worldModel then worldModel:Destroy() end
    
    worldModel = Instance.new("WorldModel")
    worldModel.Parent = viewport
    
    -- Lighting setup (Premium)
    viewport.Ambient = Color3.fromRGB(120, 120, 130)
    viewport.LightColor = Color3.fromRGB(240, 240, 255)
    viewport.LightDirection = Vector3.new(-1, -1, -0.5)
    
	local sourceModel = findModelExhaustive(blockId)
	if not sourceModel then
		sourceModel = Instance.new("Part")
		sourceModel.Name = blockId
		sourceModel.Color = Color3.fromRGB(255, 0, 255)
		sourceModel.Material = Enum.Material.Neon
        sourceModel.Size = Vector3.new(2, 2, 2)
    end
	
	local clone = nil
    if sourceModel:IsA("Model") then
        clone = sourceModel:Clone()
    else
        clone = Instance.new("Model")
        local p = sourceModel:Clone()
        p.Parent = clone
        clone.PrimaryPart = p
    end
    
    -- Strip non-visuals
    for _, v in pairs(clone:GetDescendants()) do
        if v:IsA("Script") or v:IsA("LocalScript") or v:IsA("Sound") or v:IsA("ParticleEmitter") then 
            v:Destroy() 
        elseif v:IsA("BasePart") then 
            v.Anchored = true 
            v.CanCollide = false
            v.CastShadow = false
        end
    end
    
	clone.Parent = worldModel
	
    -- Place clone at origin with ZERO rotation
    local _, modelSize = clone:GetBoundingBox()
    clone:PivotTo(CFrame.new(0, 0, 0))
    
    local radius = modelSize.Magnitude / 2
    
    local camera = viewport:FindFirstChildOfClass("Camera")
    if not camera then
        camera = Instance.new("Camera")
        viewport.CurrentCamera = camera
        camera.Parent = viewport
    end
    
    local FOV = 25
    camera.FieldOfView = FOV
    local distance = radius / math.tan(math.rad(FOV / 2)) * 0.7
    
    -- Clear old connections
    if viewportConnections[containerFrame] then
        viewportConnections[containerFrame]:Disconnect()
    end
    
    -- Simple orbiting camera looking at origin
    viewportConnections[containerFrame] = RunService.RenderStepped:Connect(function()
        if not viewport or not viewport.Parent then 
            if viewportConnections[containerFrame] then
                viewportConnections[containerFrame]:Disconnect()
                viewportConnections[containerFrame] = nil
            end
            return 
        end
        
        local angle = tick() * 0.8
        local x = math.sin(angle) * distance
        local z = math.cos(angle) * distance
        local y = distance * 0.3
        local heightOffset = radius * 1.0 -- shift entire view upward
        camera.CFrame = CFrame.lookAt(Vector3.new(x, y + heightOffset, z), Vector3.new(0, heightOffset, 0))
    end)
end


-- HELPER: Setup Starter Pack with side-by-side viewports and labels
local STARTER_ITEMS = {
    {id = "lb_legendary", label = "Legendary"},
    {id = "lb_divine",    label = "Divine"},
    {id = "lb_celestial", label = "Celestial"}
}

local function setupStarterPackDisplay(containerFrame)
    if not containerFrame then return end
    
    -- Remove any old starter display
    local old = containerFrame:FindFirstChild("StarterPackDisplay")
    if old then old:Destroy() end
    
    local holder = Instance.new("Frame")
    holder.Name = "StarterPackDisplay"
    holder.Size = UDim2.new(0.95, 0, 0.55, 0)
    holder.Position = UDim2.new(0.5, 0, 0.48, 0)
    holder.AnchorPoint = Vector2.new(0.5, 0.5)
    holder.BackgroundTransparency = 1
    holder.ZIndex = 2
    holder.Parent = containerFrame
    
    -- Grid layout: evenly spaced columns
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0.02, 0)
    layout.Parent = holder
    
    for _, item in ipairs(STARTER_ITEMS) do
        local cell = Instance.new("Frame")
        cell.Name = item.id
        cell.Size = UDim2.new(0.3, 0, 1, 0)
        cell.BackgroundTransparency = 1
        cell.ZIndex = 2
        cell.Parent = holder
        
        -- Individual viewport for each item
        setupLuckyBlockViewport(cell, item.id)
        
        -- Resize viewport to fill cell
        local vp = cell:FindFirstChild("BlockViewport") or cell:FindFirstChild("ViewportFrame")
        if vp then
            vp.Size = UDim2.new(1, 0, 0.8, 0)
            vp.Position = UDim2.new(0.5, 0, 0.35, 0)
            vp.AnchorPoint = Vector2.new(0.5, 0.5)
        end
        
        -- Small label below viewport
        local lbl = Instance.new("TextLabel")
        lbl.Name = "ItemLabel"
        lbl.Size = UDim2.new(1, 0, 0.18, 0)
        lbl.Position = UDim2.new(0.5, 0, 0.88, 0)
        lbl.AnchorPoint = Vector2.new(0.5, 0.5)
        lbl.BackgroundTransparency = 1
        lbl.Text = item.label
        lbl.TextColor3 = Color3.fromRGB(220, 220, 230)
        lbl.Font = Enum.Font.FredokaOne
        lbl.TextScaled = true
        lbl.ZIndex = 3
        lbl.Parent = cell
    end
end

-- HELPER: Style a buy button with premium text outline look
local function stylePremiumButton(btn)
    if not btn then return end
    btn.Font = Enum.Font.FredokaOne
    btn.TextScaled = true
    btn.TextXAlignment = Enum.TextXAlignment.Center
    btn.TextYAlignment = Enum.TextYAlignment.Center
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.BackgroundTransparency = 1
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.Position = UDim2.new(0, 0, 0, 0)
    btn.ZIndex = 10
    btn.BorderSizePixel = 0
    
    -- Text outline stroke (readable against rainbow)
    if not btn:FindFirstChildOfClass("UIStroke") then
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(0, 0, 0)
        stroke.Transparency = 0.1
        stroke.Thickness = 2
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
        stroke.Parent = btn
    end
end

-- HELPER: Handle Purchase Click
local function handlePurchase(itemData, specificProductId)
    local prodId = specificProductId or itemData.ProductId or 0
    
    if prodId == 0 then
        warn("[VIPShop] CLICKED: " .. itemData.Name .. ". No ID configured!")
        return
    end
    
    if itemData.Type == "GamePass" then
        MarketplaceService:PromptGamePassPurchase(Player, prodId)
    else
        MarketplaceService:PromptProductPurchase(Player, prodId)
    end
end

-- SETUP LOGIC
local function setupShop()
	local gui = getShopGui()
	if not gui or not mainFrame then return end
	
	local contentFrame = mainFrame:WaitForChild("ContentFrame", 2)
    if not contentFrame then warn("[VIPShopUI] ContentFrame missing!") return end

	local scrollFrame = contentFrame:WaitForChild("ScrollingFrame", 2)
	local titleFrame = mainFrame:FindFirstChild("TitleFrame")
	local exitBtn = titleFrame and titleFrame:FindFirstChild("CloseButton")
	
	for _, conn in ipairs(rainbowConnections) do conn:Disconnect() end
	rainbowConnections = {}
	
    if scrollFrame then
        for i = 1, 2 do
            local frameName = "BuyPackFrame" .. i
            local frame = scrollFrame:FindFirstChild(frameName)
            
            if frame then
                local data = ShopData.VIP_PACKAGES[i]
                if data then
                    -- Robust Title Setup (PLACED AT TOP)
                    local nameLabel = frame:FindFirstChild("ItemName") or frame:FindFirstChild("TitleLabel")
                    
                    if not nameLabel then
                        local skipFrame = frame:FindFirstChild("SingleUnitSoldFrame")
                        for _, v in ipairs(frame:GetDescendants()) do
                            if v:IsA("TextLabel") and (not skipFrame or not v:IsDescendantOf(skipFrame)) then
                                if v.Name:lower():find("name") or v.Name:lower():find("title") then
                                    nameLabel = v
                                    break
                                end
                            end
                        end
                    end
                    
                    if not nameLabel then
                        nameLabel = Instance.new("TextLabel")
                        nameLabel.Name = "TitleLabel"
                        nameLabel.Size = UDim2.new(0.9, 0, 0.15, 0)
                        nameLabel.Position = UDim2.new(0.5, 0, 0.05, 0)
                        nameLabel.AnchorPoint = Vector2.new(0.5, 0)
                        nameLabel.BackgroundTransparency = 1
                        nameLabel.TextColor3 = Color3.fromRGB(255, 235, 180)
                        nameLabel.Font = Enum.Font.FredokaOne
                        nameLabel.TextScaled = true
                        nameLabel.ZIndex = 20
                        nameLabel.Parent = frame
                    end

                    -- CUSTOM NAME MAPPING + Premium Font
                    nameLabel.Text = (DISPLAY_NAMES[data.ID] or data.Name):upper()
                    nameLabel.Font = Enum.Font.FredokaOne
                    nameLabel.TextColor3 = Color3.fromRGB(255, 235, 180)
                    nameLabel.ZIndex = 10
                    nameLabel.Visible = true

                    local singleFrame = frame:WaitForChild("SingleUnitSoldFrame", 1)
                    if singleFrame then
                        singleFrame.ZIndex = 10
                        singleFrame.Size = UDim2.new(0.55, 0, 0.12, 0)
                        singleFrame.Position = UDim2.new(0.5, 0, 0.88, 0)
                        singleFrame.AnchorPoint = Vector2.new(0.5, 0.5)
                        singleFrame.BackgroundTransparency = 1
                        
                        local buyBtn = singleFrame:WaitForChild("TextButton", 1)
                        if buyBtn then
                            buyBtn.Text = data.Price .. " R$"
                            stylePremiumButton(buyBtn)
                            if not buyBtn:GetAttribute("Connected") then
                                buyBtn:SetAttribute("Connected", true)
                                buyBtn.MouseButton1Click:Connect(function() handlePurchase(data) end)
                            end
                        end
                    end
                    
                    local bgFrame = frame:FindFirstChild("BackgroundFrame")
                    if bgFrame then
                        local canvas = bgFrame:FindFirstChild("CanvasGroup") 
                        if canvas then applyRainbowGradient(canvas) end
                    end
                    
                    -- BUNDLE LOGIC: Side-by-side display for Starter Pack
                    if data.ID == "starter_bundle" then
                        setupStarterPackDisplay(frame)
                    elseif data.ID == "lb_abuse" then 
                        setupLuckyBlockViewport(frame, data.ID) 
                    end
                else
                    frame.Visible = false
                end
            end
        end
        
        for i = 1, 3 do
            local frameName = "LuckyBlockFrame" .. i
            local frame = scrollFrame:FindFirstChild(frameName)
            if frame then
                local data = ShopData.LUCKY_BLOCKS[i]
                if data then
                    -- Robust Title Setup (PLACED AT TOP)
                    local nameLabel = frame:FindFirstChild("ItemName") or frame:FindFirstChild("TitleLabel")
                    
                    if not nameLabel then
                        local skipFrame = frame:FindFirstChild("SingleUnitSoldFrame") or frame:FindFirstChild("PackUnitSoldFrame")
                        for _, v in ipairs(frame:GetDescendants()) do
                            if v:IsA("TextLabel") and (not skipFrame or not v:IsDescendantOf(skipFrame)) then
                                if v.Name:lower():find("name") or v.Name:lower():find("title") then
                                    nameLabel = v
                                    break
                                end
                            end
                        end
                    end
                    
                    if not nameLabel then
                        nameLabel = Instance.new("TextLabel")
                        nameLabel.Name = "TitleLabel"
                        nameLabel.Size = UDim2.new(0.9, 0, 0.12, 0)
                        nameLabel.Position = UDim2.new(0.5, 0, 0.05, 0)
                        nameLabel.AnchorPoint = Vector2.new(0.5, 0)
                        nameLabel.BackgroundTransparency = 1
                        nameLabel.TextColor3 = Color3.fromRGB(255, 235, 180)
                        nameLabel.Font = Enum.Font.FredokaOne
                        nameLabel.TextScaled = true
                        nameLabel.ZIndex = 20
                        nameLabel.Parent = frame
                    end

                    -- CUSTOM NAME MAPPING + Premium Font
                    nameLabel.Text = (DISPLAY_NAMES[data.ID] or data.Name):upper()
                    nameLabel.Font = Enum.Font.FredokaOne
                    nameLabel.TextColor3 = Color3.fromRGB(255, 235, 180)
                    nameLabel.ZIndex = 10
                    nameLabel.Visible = true

                    local singleFrame = frame:WaitForChild("SingleUnitSoldFrame", 1)
                    if singleFrame then
                        singleFrame.ZIndex = 10
                        singleFrame.Size = UDim2.new(0.45, 0, 0.11, 0)
                        singleFrame.Position = UDim2.new(0.27, 0, 0.88, 0)
                        singleFrame.AnchorPoint = Vector2.new(0.5, 0.5)
                        singleFrame.BackgroundTransparency = 1
                        
                        local buyBtn = singleFrame:WaitForChild("TextButton", 1)
                        if buyBtn then
                            buyBtn.Text = data.Price .. " R$"
                            stylePremiumButton(buyBtn)
                            if not buyBtn:GetAttribute("Connected") then
                                buyBtn:SetAttribute("Connected", true)
                                buyBtn.MouseButton1Click:Connect(function() handlePurchase(data, data.ProductId) end)
                            end
                        end
                    end
                    
                    local packFrame = frame:WaitForChild("PackUnitSoldFrame", 1)
                    if packFrame then
                        packFrame.ZIndex = 10
                        packFrame.Size = UDim2.new(0.45, 0, 0.11, 0)
                        packFrame.Position = UDim2.new(0.73, 0, 0.88, 0)
                        packFrame.AnchorPoint = Vector2.new(0.5, 0.5)
                        packFrame.BackgroundTransparency = 1
                        
                        local buyPackBtn = packFrame:WaitForChild("TextButton", 1)
                        if buyPackBtn then
                            buyPackBtn.Text = "x3 " .. (data.Price * 3) .. " R$"
                            stylePremiumButton(buyPackBtn)
                            if not buyPackBtn:GetAttribute("Connected") then
                                buyPackBtn:SetAttribute("Connected", true)
                                buyPackBtn.MouseButton1Click:Connect(function() handlePurchase(data, data.ProductIdPack) end)
                            end
                        end
                    end
                    
                    local bgFrame = frame:FindFirstChild("BackgroundFrame")
                    if bgFrame then
                        local canvas = bgFrame:FindFirstChild("CanvasGroup")
                        if canvas then applyRainbowGradient(canvas) end
                    end
                    setupLuckyBlockViewport(frame, data.ID)
                else
                    frame.Visible = false
                end
            end
        end
    end
	
    if exitBtn and not exitBtn:GetAttribute("Connected") then
        exitBtn:SetAttribute("Connected", true)
        
        -- Style the existing close button
        exitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        exitBtn.ZIndex = 50
        
        -- Text outline for readability
        if not exitBtn:FindFirstChildOfClass("UIStroke") then
            local stroke = Instance.new("UIStroke")
            stroke.Color = Color3.fromRGB(0, 0, 0)
            stroke.Transparency = 0.2
            stroke.Thickness = 1.5
            stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
            stroke.Parent = exitBtn
        end
        
        exitBtn.MouseButton1Click:Connect(function() UIManager.Close("VIPShopUI") end)
    end
end

-- TOGGLE LOGIC
local function toggleShop(state)
    print("[VIPShopUI] Toggle called:", state)
    local gui = getShopGui()
    if not gui or not mainFrame or not overlay then 
        warn("[VIPShopUI] Toggle failed: missing components!", mainFrame, overlay)
        return 
    end

    if state == nil then state = not mainFrame.Visible end
    
    if state then
        isShopOpen = true
        mainFrame.Visible = true
        overlay.Visible = true
        local t = TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back), {Size = UDim2.new(0.65, 0, 0.75, 0)})
        t:Play()
        TweenService:Create(overlay, TweenInfo.new(0.4), {BackgroundTransparency = 0.5}):Play()
        
        task.spawn(function()
            setupShop()
            print("[VIPShopUI] Setup complete")
        end)
    else
        isShopOpen = false
        local t = TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quart), {Size = UDim2.new(0,0,0,0)})
        t:Play()
        TweenService:Create(overlay, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
        t.Completed:Connect(function()
            if UIManager.CurrentOpenUI ~= "VIPShopUI" then
                mainFrame.Visible = false
                overlay.Visible = false
                for _, conn in ipairs(rainbowConnections) do conn:Disconnect() end
                rainbowConnections = {}
            end
        end)
    end
end

-- INITIALIZE
for _, v in pairs(PlayerGui:GetChildren()) do
    if (v.Name == "VIPShopUI" or v.Name == "VIPShopGui") and v:IsA("ScreenGui") then
        print("[VIPShopUI] Cleaning up old instance:", v.Name)
        v:Destroy()
    end
end

getShopGui()
UIManager.Register("VIPShopUI", mainFrame, toggleShop)

-- Legacy Hook
_G.OpenVIPShop = function() UIManager.Open("VIPShopUI") end

print("[VIPShopUI] System Loaded with Unified Naming & Registration")
