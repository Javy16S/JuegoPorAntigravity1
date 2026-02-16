-- BrainrotIndex.client.lua
-- Skill: ui-framework
-- Description: Catalogue of all discovered brainrots with 3D model previews

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Tier config (All 11 tiers - auto-detected from models)
local TIER_ORDER = {
    "Common", "Rare", "Epic", "Legendary", "Mythic",
    "Divine", "Celestial", "Cosmic", "Eternal", "Transcendent", "Infinite"
}
local TIER_COLORS = {
    -- Standard
    ["Common"] = Color3.fromRGB(200, 200, 200),
    ["Rare"] = Color3.fromRGB(0, 170, 255),
    ["Epic"] = Color3.fromRGB(170, 0, 255),
    ["Legendary"] = Color3.fromRGB(255, 170, 0),
    ["Mythic"] = Color3.fromRGB(255, 0, 85),
    
    -- SUPREME
    ["Divine"] = Color3.fromRGB(255, 255, 100),
    ["Celestial"] = Color3.fromRGB(100, 255, 255),
    ["Cosmic"] = Color3.fromRGB(200, 100, 255),
    ["Eternal"] = Color3.fromRGB(255, 255, 255),
    ["Transcendent"] = Color3.fromRGB(255, 100, 200),
    ["Infinite"] = Color3.fromRGB(50, 255, 150),
}

-- Prevent duplicates
if playerGui:FindFirstChild("IndexMainGUI") then
    playerGui.IndexMainGUI:Destroy()
end

-- Create UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "IndexMainGUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 10
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Overlay for click-outside-to-close
local overlay = Instance.new("TextButton")
overlay.Name = "Overlay"
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 0.5
overlay.Text = ""
overlay.Visible = false
overlay.ZIndex = 1
overlay.Parent = screenGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0.8, 0, 0.85, 0)
mainFrame.Position = UDim2.new(0.1, 0, 0.075, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
mainFrame.BackgroundTransparency = 0.02
mainFrame.Visible = false
mainFrame.ZIndex = 10 -- High ZIndex
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 20)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Thickness = 3
mainStroke.Color = Color3.fromRGB(0, 255, 100)
mainStroke.Parent = mainFrame

-- Click overlay to close
overlay.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
    overlay.Visible = false
end)

-- Forward declarations for functions defined later
local fetchData
local createDynamicTabs
local populateGrid

-- Deferred: Connect visibility handler after functions are defined
local function onIndexOpen()
    overlay.Visible = mainFrame.Visible
    if mainFrame.Visible then
        fetchData()
        createDynamicTabs()
        populateGrid()
    end
end

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 55)
title.BackgroundTransparency = 1
title.Text = "📖 ÍNDICE DE BRAINROTS 📖"
title.TextColor3 = Color3.fromRGB(0, 255, 150)
title.Font = Enum.Font.GothamBlack
title.TextSize = 28
title.ZIndex = 2
title.Parent = mainFrame

-- Stats
local statsLabel = Instance.new("TextLabel")
statsLabel.Name = "StatsLabel"
statsLabel.Size = UDim2.new(1, 0, 0, 22)
statsLabel.Position = UDim2.new(0, 0, 0, 48)
statsLabel.BackgroundTransparency = 1
statsLabel.Text = "Descubiertos: 0 / ?"
statsLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
statsLabel.Font = Enum.Font.Gotham
statsLabel.TextSize = 14
statsLabel.ZIndex = 2
statsLabel.Parent = mainFrame

-- Close Button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -50, 0, 10)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 20
closeBtn.ZIndex = 3
closeBtn.Parent = mainFrame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 10)
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
    overlay.Visible = false
end)

-- Tier Tabs
local tabsScroll = Instance.new("ScrollingFrame")
tabsScroll.Size = UDim2.new(1, -40, 0, 45)
tabsScroll.Position = UDim2.new(0, 20, 0, 78)
tabsScroll.BackgroundTransparency = 1
tabsScroll.ScrollBarThickness = 4
tabsScroll.ScrollingDirection = Enum.ScrollingDirection.X
tabsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
tabsScroll.ZIndex = 15 -- High ZIndex for visibility
tabsScroll.Parent = mainFrame

local tabsLayout = Instance.new("UIListLayout")
tabsLayout.FillDirection = Enum.FillDirection.Horizontal
tabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
tabsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabsLayout.Padding = UDim.new(0, 6)
tabsLayout.Parent = tabsScroll

local currentTier = "Common"
local tabButtons = {}

-- Function to dynamically create tabs based on available models
createDynamicTabs = function()
    -- Clear existing tabs
    for _, child in pairs(tabsScroll:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    tabButtons = {}
    
    -- Show ALL tiers from TIER_ORDER (tabs always visible)
    -- tiers without models will just be empty when selected
    local availableTiers = {}
    
    -- Check which tiers actually have models in ReplicatedStorage
    local brainrotModels = ReplicatedStorage:FindFirstChild("BrainrotModels")
    if brainrotModels then
        for _, tier in ipairs(TIER_ORDER) do
            local tierFolder = brainrotModels:FindFirstChild(tier)
            if tierFolder and #tierFolder:GetChildren() > 0 then
                table.insert(availableTiers, tier)
            end
        end
    end
    
    -- Fallback: show first 5 standard tiers if nothing found
    if #availableTiers == 0 then
        availableTiers = {"Common", "Rare", "Epic", "Legendary", "Mythic"}
    end
    
    -- Create tabs dynamically
    for i, tier in ipairs(availableTiers) do
        local tab = Instance.new("TextButton")
        tab.Name = tier
        tab.Size = UDim2.new(0, 80, 0, 32)
        tab.BackgroundColor3 = TIER_COLORS[tier] or Color3.fromRGB(100, 100, 100)
        tab.BackgroundTransparency = tier == currentTier and 0.1 or 0.7
        tab.Text = tier
        tab.TextColor3 = Color3.new(1, 1, 1)
        tab.Font = Enum.Font.GothamBold
        tab.TextSize = 11
        tab.LayoutOrder = i
        tab.ZIndex = 10 -- Higher ZIndex to ensure visibility
        tab.Parent = tabsScroll
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = tab
        
        tabButtons[tier] = tab
        
        tab.MouseButton1Click:Connect(function()
            currentTier = tier
            updateTabVisuals()
            populateGrid()
        end)
    end
    
    -- Adjust canvas size for scrolling
    local totalWidth = #availableTiers * 86
    tabsScroll.CanvasSize = UDim2.new(0, totalWidth, 0, 0)
    
    -- Reset to first tier if current is not available
    if not tabButtons[currentTier] and #availableTiers > 0 then
        currentTier = availableTiers[1]
    end
    
    updateTabVisuals()
end

function updateTabVisuals()
    for tier, btn in pairs(tabButtons) do
        btn.BackgroundTransparency = tier == currentTier and 0.1 or 0.7
    end
end

-- Content Grid
local contentContainer = Instance.new("ScrollingFrame")
contentContainer.Name = "ContentContainer"
contentContainer.Size = UDim2.new(1, -40, 1, -140)
contentContainer.Position = UDim2.new(0, 20, 0, 125)
contentContainer.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
contentContainer.BackgroundTransparency = 0.3
contentContainer.ScrollBarThickness = 8
contentContainer.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 100)
contentContainer.ZIndex = 5 -- Lower than tabs
contentContainer.Parent = mainFrame

local contentCorner = Instance.new("UICorner")
contentCorner.CornerRadius = UDim.new(0, 15)
contentCorner.Parent = contentContainer

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0, 115, 0, 140)
grid.CellPadding = UDim2.new(0, 12, 0, 12)
grid.SortOrder = Enum.SortOrder.Name
grid.Parent = contentContainer

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 15)
padding.PaddingTop = UDim.new(0, 15)
padding.PaddingRight = UDim.new(0, 15)
padding.Parent = contentContainer

-- Storage
local allBrainrots = {}
local discoveredBrainrots = {}

-- Helper: Create ViewportFrame for 3D model
local function createViewportModel(parent, modelName, tier, isDiscovered)
    local viewport = Instance.new("ViewportFrame")
    viewport.Name = "Viewport"
    viewport.Size = UDim2.new(1, 0, 1, 0)
    viewport.BackgroundColor3 = isDiscovered and Color3.fromRGB(30, 30, 40) or Color3.fromRGB(15, 15, 20)
    viewport.BackgroundTransparency = 0
    viewport.ZIndex = 3
    viewport.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = viewport
    
    -- Try to load 3D model (for BOTH discovered and locked)
    local brainrotModels = ReplicatedStorage:FindFirstChild("BrainrotModels")
    if not brainrotModels then
        brainrotModels = ReplicatedStorage:WaitForChild("BrainrotModels", 2)
    end
    
    local foundModel = false
    if brainrotModels then
        local tierFolder = brainrotModels:FindFirstChild(tier)
        if tierFolder then
            local model = tierFolder:FindFirstChild(modelName)
            if model then
                local clone = model:Clone()
                clone.Parent = viewport
                
                -- Calculate bounds
                local cf, size = clone:GetBoundingBox()
                local maxSize = math.max(size.X, size.Y, size.Z)
                local distance = maxSize * 1.5
                
                -- Center model
                local modelCenter = cf.Position
                for _, part in pairs(clone:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CFrame = part.CFrame * CFrame.new(-modelCenter)
                        
                        -- SILHOUETTE EFFECT for locked items
                        if not isDiscovered then
                            part.Color = Color3.fromRGB(20, 20, 30) -- Dark silhouette
                            part.Material = Enum.Material.SmoothPlastic
                            part.Transparency = 0.1
                        end
                    end
                    
                    -- Remove effects for locked
                    if not isDiscovered then
                        if part:IsA("Decal") or part:IsA("Texture") then
                            part:Destroy()
                        end
                        if part:IsA("ParticleEmitter") or part:IsA("PointLight") or part:IsA("Trail") then
                            part:Destroy()
                        end
                    end
                end
                
                -- Camera
                local camera = Instance.new("Camera")
                camera.CFrame = CFrame.new(Vector3.new(distance * 0.7, distance * 0.5, distance * 0.7), Vector3.new(0, 0, 0))
                camera.Parent = viewport
                viewport.CurrentCamera = camera
                
                -- Lighting: Normal for discovered, dark for locked
                if isDiscovered then
                    viewport.Ambient = Color3.fromRGB(200, 200, 200)
                    viewport.LightColor = Color3.fromRGB(255, 255, 255)
                    
                    -- APPLY SUPREME VFX (Procedural)
                    local SUPREME_TIERS = {
                        ["Divine"] = true, ["Celestial"] = true, ["Cosmic"] = true,
                        ["Eternal"] = true, ["Transcendent"] = true, ["Infinite"] = true
                    }
                    
                    if SUPREME_TIERS[tier] then
                        -- Find a central part for effects
                        local centerPart = clone.PrimaryPart or clone:FindFirstChild("HumanoidRootPart") or clone:FindFirstChildWhichIsA("BasePart")
                        
                        if centerPart then
                            local tierColor = TIER_COLORS[tier]
                            
                            -- Light
                            local light = Instance.new("PointLight")
                            light.Color = tierColor
                            light.Brightness = 2
                            light.Range = 15
                            light.Parent = centerPart
                            
                            -- Particles
                            local particles = Instance.new("ParticleEmitter")
                            particles.Color = ColorSequence.new(tierColor)
                            particles.Size = NumberSequence.new({
                                NumberSequenceKeypoint.new(0, 0.3),
                                NumberSequenceKeypoint.new(0.5, 0.6),
                                NumberSequenceKeypoint.new(1, 0)
                            })
                            particles.Lifetime = NumberRange.new(0.5, 1.2)
                            particles.Rate = 20
                            particles.Speed = NumberRange.new(2, 4)
                            particles.SpreadAngle = Vector2.new(180, 180)
                            particles.Transparency = NumberSequence.new({
                                NumberSequenceKeypoint.new(0, 0.5),
                                NumberSequenceKeypoint.new(1, 1)
                            })
                            particles.Parent = centerPart
                            
                            -- Special Infinite Rainbow
                            if tier == "Infinite" then
                                particles.Rate = 50
                                task.spawn(function()
                                    while viewport and viewport.Parent do
                                        local t = time() * 2
                                        local rainbow = Color3.fromHSV(t % 1, 1, 1)
                                        light.Color = rainbow
                                        particles.Color = ColorSequence.new(rainbow)
                                        task.wait(0.1)
                                    end
                                end)
                            end
                        end
                    end
                    
                else
                    viewport.Ambient = Color3.fromRGB(30, 30, 50)
                    viewport.LightColor = Color3.fromRGB(60, 60, 80)
                end
                viewport.LightDirection = Vector3.new(-1, -1, -1)
                
                foundModel = true
            end
        end
    end
    
    -- Fallback placeholder
    if not foundModel then
        local placeholder = Instance.new("TextLabel")
        placeholder.Size = UDim2.new(1, 0, 1, 0)
        placeholder.BackgroundTransparency = 1
        placeholder.Text = isDiscovered and "🔮" or "❓"
        placeholder.TextColor3 = isDiscovered and (TIER_COLORS[tier] or Color3.new(1, 1, 1)) or Color3.fromRGB(50, 50, 50)
        placeholder.Font = Enum.Font.SourceSansBold
        placeholder.TextSize = 35
        placeholder.ZIndex = 4
        placeholder.Parent = viewport
    end
    
    -- LOCK OVERLAY for locked items
    if not isDiscovered then
        local lockOverlay = Instance.new("Frame")
        lockOverlay.Size = UDim2.new(1, 0, 1, 0)
        lockOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        lockOverlay.BackgroundTransparency = 0.7
        lockOverlay.ZIndex = 5
        lockOverlay.Parent = viewport
        
        local lockCorner = Instance.new("UICorner")
        lockCorner.CornerRadius = UDim.new(0, 8)
        lockCorner.Parent = lockOverlay
        
        local lockIcon = Instance.new("TextLabel")
        lockIcon.Size = UDim2.new(1, 0, 1, 0)
        lockIcon.BackgroundTransparency = 1
        lockIcon.Text = "🔒"
        lockIcon.TextColor3 = Color3.fromRGB(100, 100, 100)
        lockIcon.Font = Enum.Font.SourceSansBold
        lockIcon.TextSize = 28
        lockIcon.ZIndex = 6
        lockIcon.Parent = lockOverlay
    end
    
    return viewport
end

-- Create brainrot card
local function createBrainrotCard(name, tier, isDiscovered, isShiny)
    local card = Instance.new("Frame")
    card.Name = name
    card.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    card.ZIndex = 3
    card.Parent = contentContainer
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = card
    
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = isDiscovered and TIER_COLORS[tier] or Color3.fromRGB(50, 50, 50)
    stroke.Parent = card
    
    -- Model preview area
    local previewFrame = Instance.new("Frame")
    previewFrame.Size = UDim2.new(1, -14, 0, 75)
    previewFrame.Position = UDim2.new(0, 7, 0, 7)
    previewFrame.BackgroundTransparency = 1
    previewFrame.ZIndex = 3
    previewFrame.Parent = card
    
    createViewportModel(previewFrame, name, tier, isDiscovered)
    
    -- Shiny badge
    if isShiny and isDiscovered then
        local shinyBadge = Instance.new("TextLabel")
        shinyBadge.Size = UDim2.new(0, 22, 0, 22)
        shinyBadge.Position = UDim2.new(1, -28, 0, 5)
        shinyBadge.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
        shinyBadge.Text = "✨"
        shinyBadge.TextSize = 12
        shinyBadge.ZIndex = 5
        shinyBadge.Parent = card
        
        local badgeCorner = Instance.new("UICorner")
        badgeCorner.CornerRadius = UDim.new(1, 0)
        badgeCorner.Parent = shinyBadge
    end
    
    -- Name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -8, 0, 30)
    nameLabel.Position = UDim2.new(0, 4, 0, 85)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextWrapped = true
    nameLabel.ZIndex = 3
    
    if isDiscovered then
        nameLabel.Text = name:gsub("_", " ")
        nameLabel.TextColor3 = Color3.new(1, 1, 1)
    else
        nameLabel.Text = "???"
        nameLabel.TextColor3 = Color3.fromRGB(80, 80, 80)
    end
    
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 11
    nameLabel.Parent = card
    
    -- Tier info
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Size = UDim2.new(1, 0, 0, 18)
    infoLabel.Position = UDim2.new(0, 0, 0, 115)
    infoLabel.BackgroundTransparency = 1
    infoLabel.ZIndex = 3
    
    if isDiscovered then
        infoLabel.Text = tier
        infoLabel.TextColor3 = TIER_COLORS[tier]
    else
        infoLabel.Text = "Bloqueado"
        infoLabel.TextColor3 = Color3.fromRGB(60, 60, 60)
    end
    
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextSize = 10
    infoLabel.Parent = card
    
    -- Hover effect
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.ZIndex = 6
    btn.Parent = card
    
    btn.MouseEnter:Connect(function()
        TweenService:Create(card, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(50, 50, 60)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(card, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(35, 35, 45)}):Play()
    end)
    
    return card
end

-- Populate grid with current tier
populateGrid = function()
    for _, child in pairs(contentContainer:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    local tierBrainrots = allBrainrots[currentTier] or {}
    
    for _, brainrot in ipairs(tierBrainrots) do
        local discovered = discoveredBrainrots[brainrot.Name .. "_" .. currentTier] ~= nil
        -- Use IsShiny from model attribute (set by OrganizerTool)
        local shiny = brainrot.IsShiny or false
        createBrainrotCard(brainrot.Name, currentTier, discovered, shiny)
    end
    
    local count = #tierBrainrots
    local cols = math.floor((contentContainer.AbsoluteSize.X - 30) / 127)
    cols = math.max(cols, 1)
    local rows = math.ceil(count / cols)
    contentContainer.CanvasSize = UDim2.new(0, 0, 0, rows * 152 + 30)
end

-- Fetch data from ReplicatedStorage models
fetchData = function()
    allBrainrots = {}
    
    local brainrotModels = ReplicatedStorage:FindFirstChild("BrainrotModels")
    if not brainrotModels then
        brainrotModels = ReplicatedStorage:WaitForChild("BrainrotModels", 3)
    end
    
    if brainrotModels then
        for _, tierFolder in pairs(brainrotModels:GetChildren()) do
            -- Skip _Deprecated folder
            if tierFolder:IsA("Folder") and tierFolder.Name ~= "_Deprecated" then
                allBrainrots[tierFolder.Name] = {}
                for _, model in pairs(tierFolder:GetChildren()) do
                    if model:IsA("Model") then
                        table.insert(allBrainrots[tierFolder.Name], {
                            Name = model.Name,
                            IsShiny = model:GetAttribute("IsShiny") or false
                        })
                    end
                end
            end
        end
    end
    
    -- Fetch discovered from server
    local rf = ReplicatedStorage:FindFirstChild("GetDiscovered")
    if rf then
        local success, result = pcall(function()
            return rf:InvokeServer()
        end)
        if success and result then
            discoveredBrainrots = result
        else
            warn("[BrainrotIndex] Failed to fetch discovered items")
        end
    end
    
    -- Update stats
    local totalDiscovered = 0
    local totalPossible = 0
    for tier, list in pairs(allBrainrots) do
        totalPossible += #list -- Only count normal variants for now as main stat
    end
    for _ in pairs(discoveredBrainrots) do
        totalDiscovered += 1
    end
    
    statsLabel.Text = string.format("Descubiertos: %d / %d", totalDiscovered, totalPossible)
end

-- Connect the visibility handler now that all functions are defined
mainFrame:GetPropertyChangedSignal("Visible"):Connect(onIndexOpen)

print("[BrainrotIndex] Loaded with ViewportFrame support (Dynamic Tabs)")
