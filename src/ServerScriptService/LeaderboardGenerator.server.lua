--!strict
-- LeaderboardGenerator.server.lua
-- Skill: roblox-visual-architect
-- Description: Procedurally generates the 3D Leaderboard models based on the provided reference image.
-- Refinements: Added LEGACY STUDS texture and TRANSLUCENCY.

local LeaderboardGen = {}

-- Visual Constants
local BOARD_WIDTH = 14
local BOARD_HEIGHT = 18
local BOARD_THICKNESS = 1.0 -- Thinner for cleaner look
local BORDER_SIZE = 1.2

-- Colors
local COLOR_MONEY_BORDER = Color3.fromRGB(240, 240, 240) 
local COLOR_SPEED_BORDER = Color3.fromRGB(0, 255, 255)   
local COLOR_BG = Color3.fromRGB(20, 20, 20) -- Darker for contrast

local function createSurfaceGui(parentPart: Part, titleText: string, titleColor: Color3)
    local sg = Instance.new("SurfaceGui")
    sg.Name = "LeaderboardUI"
    sg.Face = Enum.NormalId.Front -- Start with Front
    sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    sg.CanvasSize = Vector2.new(600, 800) -- High res
    sg.ClipsDescendants = true
    sg.AlwaysOnTop = false -- Disable transparency through parts
    sg.LightInfluence = 0 -- Keep it bright even in shadows
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = parentPart
    
    local frame = Instance.new("Frame")
    frame.Name = "Frame" -- Explicit name
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1 
    frame.BorderSizePixel = 0
    frame.Parent = sg
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0.12, 0)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundColor3 = COLOR_BG
    title.BackgroundTransparency = 0.3 
    title.Text = titleText:upper()
    title.TextColor3 = titleColor
    title.Font = Enum.Font.GothamBlack
    title.TextScaled = true
    title.ZIndex = 10
    title.Parent = frame
    
    local titlePadding = Instance.new("UIPadding")
    titlePadding.PaddingTop = UDim.new(0, 10)
    titlePadding.PaddingBottom = UDim.new(0, 10)
    titlePadding.Parent = title
    
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 3
    stroke.Color = Color3.new(0,0,0)
    stroke.Parent = title
    
    -- Main Body Background (Translúcido)
    local bodyBg = Instance.new("Frame")
    bodyBg.Name = "BodyBackground"
    bodyBg.Size = UDim2.new(1, 0, 0.88, 0)
    bodyBg.Position = UDim2.new(0, 0, 0.12, 0)
    bodyBg.BackgroundColor3 = COLOR_BG
    bodyBg.BackgroundTransparency = 0.8 
    bodyBg.ZIndex = 1
    bodyBg.Parent = frame
    Instance.new("UICorner", bodyBg).CornerRadius = UDim.new(0, 10)

    -- List
    local list = Instance.new("ScrollingFrame")
    list.Name = "List"
    list.Size = UDim2.new(0.96, 0, 0.84, 0)
    list.Position = UDim2.new(0.02, 0, 0.14, 0)
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 8
    list.ZIndex = 5
    list.Parent = frame
    
    -- Clone to Back face
    local sg2 = sg:Clone()
    sg2.Face = Enum.NormalId.Back
    sg2.Parent = parentPart
end

local function buildBoard(name: string, origin: CFrame, mainColor: Color3, title: string)
    if workspace:FindFirstChild(name) then workspace:FindFirstChild(name):Destroy() end

    local model = Instance.new("Model")
    model.Name = name
    model.Parent = workspace

    local screen = Instance.new("Part")
    screen.Name = "Screen"
    screen.Size = Vector3.new(BOARD_WIDTH, BOARD_HEIGHT, 0.1)
    screen.Color = COLOR_BG
    screen.Material = Enum.Material.Glass
    screen.Transparency = 1 
    screen.Anchored = true
    screen.CanCollide = true 
    screen.CFrame = origin
    screen.Parent = model
    
    local function makeLegoPart(size: Vector3, offset: Vector3)
        local p = Instance.new("Part")
        p.Size = size
        p.CFrame = origin * CFrame.new(offset)
        p.Color = mainColor
        p.Material = Enum.Material.Plastic 
        p.Anchored = true
        p.TopSurface = Enum.SurfaceType.Studs
        p.BottomSurface = Enum.SurfaceType.Inlet 
        p.LeftSurface = Enum.SurfaceType.Studs 
        p.RightSurface = Enum.SurfaceType.Studs
        p.FrontSurface = Enum.SurfaceType.Studs
        p.BackSurface = Enum.SurfaceType.Studs
        p.Parent = model
    end

    makeLegoPart(Vector3.new(BORDER_SIZE, BOARD_HEIGHT + BORDER_SIZE*2, BOARD_THICKNESS), Vector3.new(-(BOARD_WIDTH/2 + BORDER_SIZE/2), 0, 0))
    makeLegoPart(Vector3.new(BORDER_SIZE, BOARD_HEIGHT + BORDER_SIZE*2, BOARD_THICKNESS), Vector3.new((BOARD_WIDTH/2 + BORDER_SIZE/2), 0, 0))
    makeLegoPart(Vector3.new(BOARD_WIDTH + BORDER_SIZE*2, BORDER_SIZE, BOARD_THICKNESS), Vector3.new(0, (BOARD_HEIGHT/2 + BORDER_SIZE/2), 0))
    makeLegoPart(Vector3.new(BOARD_WIDTH + BORDER_SIZE*2, BORDER_SIZE, BOARD_THICKNESS), Vector3.new(0, -(BOARD_HEIGHT/2 + BORDER_SIZE/2), 0))
    
    createSurfaceGui(screen, title, mainColor)
    return model
end

local function createRowTemplate()
    local row = Instance.new("Frame")
    row.Name = "RowTemplate"
    row.Size = UDim2.new(1, 0, 0, 80) 
    row.BackgroundTransparency = 1 
    
    local rankBox = Instance.new("Frame")
    rankBox.Size = UDim2.new(0, 80, 1, 0)
    rankBox.BackgroundColor3 = Color3.fromRGB(0,0,0)
    rankBox.BackgroundTransparency = 0.4 
    rankBox.BorderSizePixel = 0
    rankBox.ZIndex = 5
    rankBox.Parent = row
    
    local rank = Instance.new("TextLabel")
    rank.Name = "RankLabel"
    rank.Size = UDim2.new(1, 0, 1, 0)
    rank.BackgroundTransparency = 1
    rank.Font = Enum.Font.FredokaOne
    rank.TextSize = 40
    rank.TextColor3 = Color3.new(1,1,1)
    rank.ZIndex = 10
    rank.Parent = rankBox
    
    local avatar = Instance.new("ImageLabel")
    avatar.Name = "AvatarIcon"
    avatar.Size = UDim2.new(0, 60, 0, 60)
    avatar.Position = UDim2.new(0, 90, 0.5, 0)
    avatar.AnchorPoint = Vector2.new(0, 0.5)
    avatar.ZIndex = 10
    avatar.Parent = row
    Instance.new("UICorner", avatar).CornerRadius = UDim.new(0, 8)
    
    local name = Instance.new("TextLabel")
    name.Name = "NameLabel"
    name.Size = UDim2.new(1, -345, 1, 0)
    name.Position = UDim2.new(0, 160, 0, 0)
    name.BackgroundTransparency = 1
    name.Font = Enum.Font.GothamBold
    name.TextSize = 24
    name.TextColor3 = Color3.fromRGB(255, 255, 255)
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.ZIndex = 10
    name.Parent = row
    
    local valBg = Instance.new("Frame")
    valBg.Size = UDim2.new(0, 160, 0.7, 0)
    valBg.Position = UDim2.new(1, -180, 0.15, 0)
    valBg.BackgroundColor3 = Color3.fromRGB(0,0,0)
    valBg.BackgroundTransparency = 0.5
    valBg.ZIndex = 5
    valBg.Parent = row
    Instance.new("UICorner", valBg).CornerRadius = UDim.new(0, 8)
    
    local val = Instance.new("TextLabel")
    val.Name = "ValueLabel"
    val.Size = UDim2.new(1, 0, 1, 0)
    val.BackgroundTransparency = 1
    val.Font = Enum.Font.GothamBlack
    val.TextSize = 28
    val.TextColor3 = Color3.new(1,1,1)
    val.ZIndex = 10
    val.Parent = valBg
    
    return row
end

local moneyBoard = buildBoard("Leaderboard_Money", CFrame.new(-147, 12.6, 23.242) * CFrame.Angles(0, math.rad(90), 0), COLOR_MONEY_BORDER, "MOST MONEY $")
local rareBoard = buildBoard("Leaderboard_Rare", CFrame.new(-147, 12.6, 43.242) * CFrame.Angles(0, math.rad(90), 0), COLOR_SPEED_BORDER, "MAX SPEED ⚡")

local managerScript = game:GetService("ServerScriptService"):FindFirstChild("LeaderboardManager")
if managerScript then
    if managerScript:FindFirstChild("RowTemplate") then managerScript.RowTemplate:Destroy() end
    local t = createRowTemplate()
    t.Parent = managerScript
end

print("Leaderboards Generated Successfully (v2 - Translucent + Studs).")
