-- MapManager.server.lua (Refactored for Simulator)
-- Skill: environment-design
-- Description: Generates the high-fidelity "Brainrot Room" with yellow tiles, neon racks, and lighting.
-- Refinements: MAX WIDTH (Slope 160->200, Lobby 520->640).

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")

-- CONFIG
local UNIFIED_SIZE = Vector3.new(300, 1, 150)

-- Helper
-- Helper
local function createPart(name, size, pos, color, mat, parent)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.Position = pos
    p.Color = color
    p.Material = mat or Enum.Material.Plastic
    p.TopSurface = Enum.SurfaceType.Studs
    p.BottomSurface = Enum.SurfaceType.Inlet
    p.Anchored = true
    p.CastShadow = false
    p.Parent = parent
    return p
end

local function createFloatingLabel(parent, text, color)
    local bg = Instance.new("BillboardGui")
    bg.Name = "FloatingLabel"
    bg.Size = UDim2.new(8, 0, 1.5, 0) -- Scaled size in Studs
    bg.StudsOffset = Vector3.new(0, 8, 0)
    bg.AlwaysOnTop = false
    bg.LightInfluence = 0
    bg.MaxDistance = 150
    bg.Parent = parent
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Parent = bg
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color
    label.TextStrokeTransparency = 0
    label.TextScaled = true
    label.Font = Enum.Font.GothamBlack
    label.Parent = frame
    
    return bg
end

local function generateBase(index, centerPos, mapFolder)
    local baseName = "TycoonBase_" .. index
    local ServerStorage = game:GetService("ServerStorage")
    local UnitManager = require(ServerScriptService.UnitManager)

    -- 1. GET TEMPLATE
    -- BaseBrainrots is the container (Folder/Model) cloned from Workspace
    local prefabs = ServerStorage:FindFirstChild("BaseBrainrots") or Workspace:FindFirstChild("BaseBrainrots")
    
    -- RETRY / WAIT (If Organizer is still migrating)
    local startWait = os.clock()
    while not prefabs and (os.clock() - startWait < 5) do
        task.wait(0.5)
        prefabs = ServerStorage:FindFirstChild("BaseBrainrots") or Workspace:FindFirstChild("BaseBrainrots")
    end
    
    local template = prefabs and (prefabs:FindFirstChild("BaseBasica") or prefabs)
    
    local baseModel
    if template and template ~= prefabs then
        baseModel = template:Clone()
        baseModel.Name = baseName
        if not baseModel.PrimaryPart then
            baseModel.PrimaryPart = baseModel:FindFirstChild("Suelo") or baseModel:FindFirstChildWhichIsA("BasePart")
        end
    else
        warn("[MapManager] BaseBasica template NOT FOUND in BaseBrainrots. Using fallback.")
        baseModel = Instance.new("Model")
        baseModel.Name = baseName
        local prim = Instance.new("Part")
        prim.Name = "BaseOrigin"
        prim.Size = Vector3.new(1,1,1)
        prim.Transparency = 1
        prim.CastShadow = false
        prim.Parent = baseModel
        baseModel.PrimaryPart = prim
    end

    -- 2. POSITION
    baseModel.Parent = mapFolder
    baseModel:PivotTo(CFrame.new(centerPos) * CFrame.Angles(0, math.pi, 0))

    -- 3. SETUP COMPONENTS
    UnitManager.createTycoonSlots(baseModel)
    
    -- RESTORE BASE OWNER & UPGRADER (Try from prefabs first)
    local ownerTemplate = prefabs:FindFirstChild("BaseOwner") or Workspace:FindFirstChild("BaseOwner")
    local upgraderTemplate = prefabs:FindFirstChild("BaseUpgrader") or Workspace:FindFirstChild("BaseUpgrader")
    
    if ownerTemplate and not baseModel:FindFirstChild("BaseOwner") then
        local op = ownerTemplate:Clone()
        op.Name = "BaseOwner"
        op.Parent = baseModel
        -- Position relative to base (Lowered to 4.5)
        op:PivotTo(baseModel:GetPivot() * CFrame.new(0, 4.5, -25))
    elseif not baseModel:FindFirstChild("BaseOwner") then
        local ownerPart = Instance.new("Part")
        ownerPart.Name = "BaseOwner"
        ownerPart.Size = Vector3.new(10, 5, 0.5)
        ownerPart.Transparency = 1
        ownerPart.CanCollide = false
        ownerPart.CastShadow = false
        ownerPart.Anchored = true
        ownerPart.Parent = baseModel
        ownerPart:PivotTo(baseModel:GetPivot() * CFrame.new(0, 6, -25))
    end
    
    if upgraderTemplate and not baseModel:FindFirstChild("BaseUpgrader") then
        local up = upgraderTemplate:Clone()
        up.Name = "BaseUpgrader"
        up.Parent = baseModel
        -- Position on the side, AT THE FRONT (Z -20) and ROTATED 180 deg to face correctly
        up:PivotTo(baseModel:GetPivot() * CFrame.new(15, 2, -20) * CFrame.Angles(0, math.pi, 0))
        
        -- ANCHOR EVERYTHING
        for _, p in pairs(up:GetDescendants()) do
            if p:IsA("BasePart") then
                p.Anchored = true
            end
        end
    end

    return baseModel
end

local function generateMap()
    -- 0. PRESERVE TEMPLATES FROM EXISTING MAP
    local UpgraderTemplate = nil
    
    if Workspace:FindFirstChild("SimulatorMap") then
        local oldMap = Workspace.SimulatorMap
        -- Try to find an existing Upgrader to clone
        -- Check first base
        local firstBase = oldMap:FindFirstChild("TycoonBase_0") or oldMap:FindFirstChild("TycoonBase_1") -- Check 0 or 1
        if not firstBase then
             -- Loop to find any base
             for _, child in pairs(oldMap:GetChildren()) do
                 if child.Name:match("TycoonBase") then
                     firstBase = child
                     break
                 end
             end
        end
        
        if firstBase then
            local existingUpgrader = firstBase:FindFirstChild("BaseUpgrader")
            if existingUpgrader then
                UpgraderTemplate = existingUpgrader:Clone()
                print("[MapManager] Preserved 'BaseUpgrader' template from existing map.")
            end
        end
        
        oldMap:Destroy()
    end

    local mapFolder = Instance.new("Folder")
    mapFolder.Name = "SimulatorMap"
    mapFolder.Parent = Workspace
    
    local platformFolder = Instance.new("Folder")
    platformFolder.Name = "Platform"
    platformFolder.Parent = mapFolder
    
    local wallsFolder = Instance.new("Folder")
    wallsFolder.Name = "Walls"
    wallsFolder.Parent = mapFolder
    
    -- 1. UNIFIED PLATFORM
    local floor = createPart("UnifiedFloor", UNIFIED_SIZE, Vector3.new(0, -0.5, 0), BrickColor.new("Bright green").Color, Enum.Material.Plastic, platformFolder)
    
    -- 0. TEMPLATE SEARCH REMOVED (UnitManager handles templates via BaseBrainrots)

    local function createGridLine(x, z, sizeX, sizeZ)
        local line = Instance.new("Part")
        line.Name = "TechLine"
        line.Size = Vector3.new(sizeX, 0.2, sizeZ)
        line.Position = floor.Position + Vector3.new(x, 0.55, z)
        line.Anchored = true
        line.CanCollide = false
        line.CastShadow = false
        line.Transparency = 1 
        line.Parent = floor 
    end

    createGridLine(0, 0, UNIFIED_SIZE.X, 2) 
    createGridLine(0, 0, 2, UNIFIED_SIZE.Z) 
    
    -- Borders
    local wallHeight = 60 
    local wallThickness = 6 
    local gapWidth = 200 -- SYNCED: Match SLOPE_WIDTH
    
    local WALL_COLOR_MAIN = Color3.fromRGB(124, 92, 70) 
    local RIM_COLOR = BrickColor.new("Bright yellow").Color 
    
    local function createWall(x, z, sizeX, sizeZ)
        local wall = createPart("BaseWall", Vector3.new(sizeX, wallHeight, sizeZ), floor.Position + Vector3.new(x, wallHeight/2 + 0.5, z), WALL_COLOR_MAIN, Enum.Material.Plastic, wallsFolder)
        
        wall.LeftSurface = Enum.SurfaceType.Studs
        wall.RightSurface = Enum.SurfaceType.Studs
        wall.FrontSurface = Enum.SurfaceType.Studs
        wall.BackSurface = Enum.SurfaceType.Studs
        
        local strip = Instance.new("Part")
        strip.Name = "GrassTop"
        strip.Size = Vector3.new(sizeX, 2, sizeZ)
        
        local isXAxis = sizeX > sizeZ
        if isXAxis then strip.Size = Vector3.new(sizeX, 2, wallThickness + 2) else strip.Size = Vector3.new(wallThickness + 2, 2, sizeZ) end
        
        strip.CFrame = wall.CFrame * CFrame.new(0, wallHeight/2 + 1, 0)
        strip.Material = Enum.Material.Plastic
        strip.Color = BrickColor.new("Bright green").Color 
        strip.TopSurface = Enum.SurfaceType.Studs
        strip.Anchored = true
        strip.CanCollide = false
        strip.CastShadow = false
        strip.Parent = wall
    end
    
    createWall(0, -UNIFIED_SIZE.Z/2, UNIFIED_SIZE.X, wallThickness)
    createWall(-UNIFIED_SIZE.X/2, 0, wallThickness, UNIFIED_SIZE.Z)
    createWall(UNIFIED_SIZE.X/2, 0, wallThickness, UNIFIED_SIZE.Z)
    
    local sideWallLen = (UNIFIED_SIZE.X - gapWidth) / 2
    createWall(-UNIFIED_SIZE.X/2 + sideWallLen/2, UNIFIED_SIZE.Z/2, sideWallLen, wallThickness)
    createWall(UNIFIED_SIZE.X/2 - sideWallLen/2, UNIFIED_SIZE.Z/2, sideWallLen, wallThickness)
    
    -- 2. Generate 8 Bases
    local BACK_Z = -50 -- CLOSER (Was -60, advancing 10 studs)
    local SPACING = 35 -- MORE COMPACT (Was 45)
    local START_X = -(SPACING * 3.5) 
    
    local offsets = {}
    for i = 0, 7 do
        table.insert(offsets, Vector3.new(START_X + (i * SPACING), 0, BACK_Z))
    end
    
    for i, offset in ipairs(offsets) do
        generateBase(i, offset, mapFolder)
    end
    
    -- 5. AUTO-SECURE
    local BrainrotData = require(ServerScriptService.BrainrotData)
    local processingTools = {} 
    floor.Touched:Connect(function(hit)
        local player = game.Players:GetPlayerFromCharacter(hit.Parent)
        if player then
            local function secureIn(container)
                if not container then return end
                for _, tool in pairs(container:GetChildren()) do
                    if tool:IsA("Tool") and (tool:GetAttribute("Tier") or string.sub(tool.Name, 1, 5) == "Unit_") then
                        if not tool:GetAttribute("Secured") and not processingTools[tool] then
                            processingTools[tool] = true 
                            local name = tool.Name
                            if string.sub(name, 1, 5) == "Unit_" then name = string.sub(name, 6) end
                            local tier = tool:GetAttribute("Tier") or "Common"
                            local shiny = tool:GetAttribute("IsShiny") or false
                            local level = tool:GetAttribute("Level") or 1
                            local valueMult = tool:GetAttribute("ValueMultiplier") 
                            local unitData = BrainrotData.addUnitAdvanced(player, name, tier, shiny, true, level, nil, valueMult)
                            if unitData then
                                tool:SetAttribute("Secured", true)
                                tool:SetAttribute("UnitId", unitData.Id)
                                tool:SetAttribute("ValueMultiplier", unitData.ValueMultiplier) 
                            end
                            task.delay(1, function() processingTools[tool] = nil end)
                        end
                    end
                end
            end
            secureIn(player.Character)
            secureIn(player.Backpack)
        end
    end)

    -- 3. SELL ZONE
    local safeZone = Instance.new("Part")
    safeZone.Name = "SellZone"
    safeZone.Shape = Enum.PartType.Cylinder
    safeZone.Size = Vector3.new(0.5, 18, 18) 
    safeZone.CFrame = CFrame.new(-79.631, 0.3, 60.485) * CFrame.Angles(0, 0, math.rad(90))
    safeZone.Anchored = true
    safeZone.CanCollide = false
    safeZone.Transparency = 0.5
    safeZone.Color = BrickColor.new("Bright green").Color 
    safeZone.Material = Enum.Material.Glass 
    safeZone.CastShadow = false
    safeZone.Parent = mapFolder
    
    local szCore = safeZone:Clone()
    szCore.Size = Vector3.new(0.6, 14, 14)
    szCore.Transparency = 0.2
    szCore.Material = Enum.Material.Neon
    szCore.CFrame = safeZone.CFrame
    szCore.CastShadow = false
    szCore.Parent = mapFolder
    
    CollectionService:AddTag(safeZone, "SellZone")
    
    -- 3b. UPGRADE ZONE
    local upgradeZone = Instance.new("Part")
    upgradeZone.Name = "UpgradeZone"
    upgradeZone.Shape = Enum.PartType.Cylinder
    upgradeZone.Size = Vector3.new(0.5, 18, 18)
    upgradeZone.CFrame = CFrame.new(81.631, -0.2, 60.514) * CFrame.Angles(0, 0, math.rad(90))
    upgradeZone.Anchored = true
    upgradeZone.CanCollide = false
    upgradeZone.Transparency = 0.5
    upgradeZone.Color = Color3.fromRGB(170, 0, 255) 
    upgradeZone.Material = Enum.Material.Glass
    upgradeZone.CastShadow = false
    upgradeZone.Parent = mapFolder
    
    local uzCore = upgradeZone:Clone()
    uzCore.Size = Vector3.new(0.6, 14, 14)
    uzCore.Transparency = 0.2
    uzCore.Material = Enum.Material.Neon
    uzCore.CFrame = upgradeZone.CFrame
    uzCore.CastShadow = false
    uzCore.Parent = mapFolder
    
    CollectionService:AddTag(upgradeZone, "UpgradeZone")
    
    -- 3c. LUCKYBLOCK STALL (Daily Reward)
    local lbStall = Instance.new("Part")
    lbStall.Name = "LuckyBlockStall"
    lbStall.Size = Vector3.new(12, 1, 12)
    lbStall.Position = Vector3.new(-125, 0.5, 10)
    lbStall.Color = Color3.fromRGB(255, 215, 0)
    lbStall.Material = Enum.Material.Neon
    lbStall.Anchored = true
    lbStall.CanCollide = false -- OPTIMIZATION (v4.9)
    lbStall.Parent = mapFolder
    
    local lbVisual = createPart("LuckyBlockVisual", Vector3.new(6, 6, 6), lbStall.Position + Vector3.new(0, 4, 0), Color3.fromRGB(255, 255, 0), Enum.Material.Glass, mapFolder)
    lbVisual.CastShadow = true
    
    local lbPrompt = Instance.new("ProximityPrompt")
    lbPrompt.ActionText = "Claim Reward"
    lbPrompt.ObjectText = "Lucky Daily"
    lbPrompt.HoldDuration = 0.5
    lbPrompt.MaxActivationDistance = 15
    lbPrompt.Parent = lbVisual -- MOVED TO FLOATING PART
    
    CollectionService:AddTag(lbVisual, "LuckyBlockClaim") 
    
    createFloatingLabel(lbVisual, "LUCKY DAILY", Color3.fromRGB(255, 215, 0))
    local sub = createFloatingLabel(lbVisual, "[E] INTERACTUAR", Color3.fromRGB(255, 255, 255))
    sub.Name = "FloatingLabelSub" -- Unique name for time countdown
    sub.StudsOffset = Vector3.new(0, 6.5, 0)
    sub.Size = UDim2.new(6, 0, 1.2, 0)

    -- 3d. MUTATION ALTAR (Mutation Reroll)
    local altarBase = createPart("MutationAltar", Vector3.new(15, 2, 15), Vector3.new(125, 0.5, 10), Color3.fromRGB(150, 0, 255), Enum.Material.Marble, mapFolder)
    altarBase.CanCollide = false -- OPTIMIZATION (v4.9)
    
    -- Decorative Pillars
    local pillarGroup = Instance.new("Model")
    pillarGroup.Name = "MutationPillars"
    pillarGroup.Parent = altarBase

    for i = 1, 4 do
        local angle = (i-1) * (math.pi/2)
        local pillarPos = altarBase.Position + Vector3.new(math.cos(angle)*6, 5, math.sin(angle)*6)
        
        local pModel = Instance.new("Model")
        pModel.Name = "Pillar_" .. i
        pModel.Parent = pillarGroup
        CollectionService:AddTag(pModel, "MutationPillar")

        local pillar = createPart("AltarPillar", Vector3.new(2, 10, 2), pillarPos, Color3.fromRGB(100, 0, 200), Enum.Material.Marble, pModel)
        pillar.CanCollide = false
        pModel.PrimaryPart = pillar
        
        local crystal = createPart("AltarCrystal", Vector3.new(1.5, 3, 1.5), pillarPos + Vector3.new(0, 6, 0), Color3.fromRGB(200, 100, 255), Enum.Material.Neon, pModel)
        crystal.CanCollide = false
    end
    
    local rerollPrompt = Instance.new("ProximityPrompt")
    rerollPrompt.ActionText = "Abrir Altar de Mutaciones"
    rerollPrompt.ObjectText = "Altar"
    rerollPrompt.HoldDuration = 2
    rerollPrompt.MaxActivationDistance = 15
    rerollPrompt.Parent = altarBase
    CollectionService:AddTag(altarBase, "MutationAltar")
    
    createFloatingLabel(altarBase, "ALTAR MÁGICO", Color3.fromRGB(200, 0, 255))
    local subA = createFloatingLabel(altarBase, "[E] INTERACTUAR", Color3.fromRGB(0, 255, 0))
    subA.StudsOffset = Vector3.new(0, 6.5, 0)
    subA.Size = UDim2.new(6, 0, 1.2, 0)

    -- 4. VOLCANO SLOPE (Restored Width)
    local SLOPE_ANGLE = 25 
    local SLOPE_LENGTH = 1500 
    local SLOPE_WIDTH = 200 -- RESTORED: Was 200
    local SLOPE_START_Z = 75 
    
    local rad = math.rad(SLOPE_ANGLE)
    local hDist = SLOPE_LENGTH * math.cos(rad)
    local vDist = SLOPE_LENGTH * math.sin(rad)
    
    local p1 = Vector3.new(0, -0.5, SLOPE_START_Z) 
    local p2 = Vector3.new(0, vDist - 0.5, SLOPE_START_Z + hDist)
    
    local slope = createPart("VolcanoSlope", Vector3.new(SLOPE_WIDTH, 4, SLOPE_LENGTH), Vector3.new(), BrickColor.new("Bright green").Color, Enum.Material.Plastic, mapFolder)
    slope.CFrame = CFrame.new((p1 + p2)/2, p2)
    
    print("[MapManager] Generated Main Slope.")

    -- 5. EVENT RAMP EXTENSION
    local EVENT_SLOPE_LENGTH = 400 
    
    local hDistExt = EVENT_SLOPE_LENGTH * math.cos(rad)
    local vDistExt = EVENT_SLOPE_LENGTH * math.sin(rad)
    
    local p3 = Vector3.new(0, (vDist + vDistExt) - 0.5, (SLOPE_START_Z + hDist + hDistExt))
    
    local eventSlope = createPart("EventSlope", Vector3.new(SLOPE_WIDTH, 4, EVENT_SLOPE_LENGTH), Vector3.new(), BrickColor.new("Bright green").Color, Enum.Material.Plastic, mapFolder)
    eventSlope.CFrame = CFrame.new((p2 + p3)/2, p3) 
    eventSlope.TopSurface = Enum.SurfaceType.Studs
    
    CollectionService:AddTag(eventSlope, "EventZone")
    
    -- Event Walls (IMPROVED SAFETY)
    local EVENT_WALL_COLOR = BrickColor.new("Reddish brown").Color 
    local EV_WALL_HEIGHT = 80 -- TALLER (Was 60)
    local WALL_THICKNESS = 60 -- THICKER (Was 40)
    
    for side = -1, 1, 2 do
        local wPos = eventSlope.CFrame * CFrame.new((SLOPE_WIDTH/2 + WALL_THICKNESS/2) * side, EV_WALL_HEIGHT/2, 0)
        local evWall = createPart("EventWall", Vector3.new(WALL_THICKNESS, EV_WALL_HEIGHT, EVENT_SLOPE_LENGTH), wPos.Position, EVENT_WALL_COLOR, Enum.Material.Plastic, wallsFolder)
        evWall.CFrame = wPos
        evWall.LeftSurface = Enum.SurfaceType.Studs
        evWall.RightSurface = Enum.SurfaceType.Studs
        evWall.FrontSurface = Enum.SurfaceType.Studs
        evWall.BackSurface = Enum.SurfaceType.Studs
    end
    
    local eventSpawn = Instance.new("Part")
    eventSpawn.Name = "EventSpawnPoint"
    eventSpawn.Size = Vector3.new(2, 2, 2)
    eventSpawn.CFrame = eventSlope.CFrame * CFrame.new(0, 10, EVENT_SLOPE_LENGTH/2 - 10) 
    eventSpawn.Transparency = 1
    eventSpawn.Anchored = true; eventSpawn.CanCollide = false
    eventSpawn.CastShadow = false
    eventSpawn.Parent = mapFolder
    CollectionService:AddTag(eventSpawn, "EventSpawn")
    
    print("[MapManager] Generated Event Extension Zone.")
    
    -- 6. TIMER BOARD
    local boardPos = CFrame.new(3.147, 65.278, 107.324) * CFrame.Angles(math.rad(-15), 0, 0)
    
    local boardFrame = createPart("TimerBoardStructure", Vector3.new(60, 30, 5), boardPos.Position, Color3.fromRGB(30, 30, 30), Enum.Material.Metal, mapFolder)
    boardFrame.CFrame = boardPos
    boardFrame.TopSurface = Enum.SurfaceType.Smooth
    
    local boardRim = createPart("BoardRim", Vector3.new(62, 32, 4), boardPos.Position, Color3.fromRGB(124, 92, 70), Enum.Material.CorrodedMetal, mapFolder)
    boardRim.CFrame = boardPos
    
    local function createIndustrialBeam(name, cframe, length)
        local beamColor = Color3.fromRGB(50, 50, 50)
        local main = createPart(name.."_Main", Vector3.new(length, 4, 4), Vector3.new(), beamColor, Enum.Material.Metal, mapFolder)
        main.CFrame = cframe
        
        local top = createPart(name.."_Top", Vector3.new(length, 1, 6), Vector3.new(), beamColor, Enum.Material.Metal, mapFolder)
        top.CFrame = cframe * CFrame.new(0, 2, 0)
        local bot = createPart(name.."_Bot", Vector3.new(length, 1, 6), Vector3.new(), beamColor, Enum.Material.Metal, mapFolder)
        bot.CFrame = cframe * CFrame.new(0, -2, 0)
        
        for i = -length/2 + 5, length/2 - 5, 10 do
            local brace = createPart(name.."_Brace", Vector3.new(2, 3.8, 4.2), Vector3.new(), Color3.fromRGB(80, 80, 80), Enum.Material.DiamondPlate, mapFolder)
            brace.CFrame = cframe * CFrame.new(i, 0, 0)
            brace.CastShadow = false
        end
    end
    
    -- Supports pushed even further
    createIndustrialBeam("SupportLeft", boardPos * CFrame.new(-90, 0, 0), 100) -- Was 70/80
    createIndustrialBeam("SupportRight", boardPos * CFrame.new(90, 0, 0), 100) 

    local guiPart = createPart("TimerDisplay", Vector3.new(52, 26, 0.5), boardFrame.Position, Color3.fromRGB(0, 0, 0), Enum.Material.Neon, mapFolder)
    guiPart.CFrame = boardFrame.CFrame * CFrame.new(0, 0, 2.6) 
    guiPart.CastShadow = false
    
    local sg = Instance.new("SurfaceGui")
    sg.Name = "EventTimerGUI"
    sg.Face = Enum.NormalId.Front
    sg.Adornee = guiPart
    sg.Parent = guiPart
    sg.AlwaysOnTop = true 
    
    local lb1 = Instance.new("TextLabel")
    lb1.Name = "MajorTimer"
    lb1.Size = UDim2.new(1, 0, 0.45, 0)
    lb1.Position = UDim2.new(0, 0, 0.05, 0)
    lb1.Text = "JACKPOT: --:--"
    lb1.TextColor3 = Color3.fromRGB(255, 170, 0) 
    lb1.BackgroundTransparency = 1
    lb1.TextScaled = true
    lb1.Font = Enum.Font.GothamBlack
    lb1.Parent = sg
    
    local lb2 = Instance.new("TextLabel")
    lb2.Name = "MinorTimer"
    lb2.Size = UDim2.new(1, 0, 0.35, 0)
    lb2.Position = UDim2.new(0, 0, 0.55, 0)
    lb2.Text = "Evento: --:--"
    lb2.TextColor3 = Color3.fromRGB(255, 255, 255)
    lb2.BackgroundTransparency = 1
    lb2.TextScaled = true
    lb2.Font = Enum.Font.GothamBold
    lb2.Parent = sg
    
    CollectionService:AddTag(guiPart, "EventTimerBoard")

    -- 4b. WALLS
    local ALCOVE_COUNT = 6 
    local TOTAL_WALL_HEIGHT = 100
    local SILL_HEIGHT = 5
    local LINTEL_HEIGHT = 40
    local PILLAR_HEIGHT = TOTAL_WALL_HEIGHT - SILL_HEIGHT - LINTEL_HEIGHT
    local WALL_THICKNESS = 40
    local alcoveWidth = 35
    local segmentSpacing = SLOPE_LENGTH / (ALCOVE_COUNT + 1)
    
    for side = -1, 1, 2 do
        local lintelPos = slope.CFrame * CFrame.new((SLOPE_WIDTH/2 + WALL_THICKNESS/2) * side, TOTAL_WALL_HEIGHT - LINTEL_HEIGHT/2 - 10, 0)
        local lintel = createPart("VolcanoWall_Top", Vector3.new(WALL_THICKNESS, LINTEL_HEIGHT, SLOPE_LENGTH), lintelPos.Position, WALL_COLOR_MAIN, Enum.Material.Plastic, wallsFolder)
        lintel.CFrame = lintelPos
        -- ...
        
        -- SAFETY FIX: Add Back Wall to Alcoves
        -- Using 'SafetyAlcove' creation loop below
        lintel.CastShadow = false
        lintel.LeftSurface = Enum.SurfaceType.Studs
        lintel.RightSurface = Enum.SurfaceType.Studs
        lintel.FrontSurface = Enum.SurfaceType.Studs
        lintel.BackSurface = Enum.SurfaceType.Studs
        
        local sillPos = slope.CFrame * CFrame.new((SLOPE_WIDTH/2 + WALL_THICKNESS/2) * side, -5, 0)
        local sill = createPart("VolcanoWall_Bottom", Vector3.new(WALL_THICKNESS, 10, SLOPE_LENGTH), sillPos.Position, WALL_COLOR_MAIN, Enum.Material.Plastic, wallsFolder)
        sill.CFrame = sillPos
        sill.CastShadow = false
        sill.LeftSurface = Enum.SurfaceType.Studs
        sill.RightSurface = Enum.SurfaceType.Studs
        sill.FrontSurface = Enum.SurfaceType.Studs
        sill.BackSurface = Enum.SurfaceType.Studs

        local lastDist = 0
        for i = 1, ALCOVE_COUNT + 1 do
            local currentDist = i * segmentSpacing
            local pillarLen = (currentDist - lastDist) - (i <= ALCOVE_COUNT and alcoveWidth or 0)
            
            if pillarLen > 0 then
                local midDist = lastDist + (pillarLen / 2)
                local pillarPos = slope.CFrame * CFrame.new((SLOPE_WIDTH/2 + WALL_THICKNESS/2) * side, SILL_HEIGHT + PILLAR_HEIGHT/2 - 5, -SLOPE_LENGTH/2 + midDist)
                local pillar = createPart("VolcanoWall_Pillar", Vector3.new(WALL_THICKNESS, PILLAR_HEIGHT, pillarLen), pillarPos.Position, WALL_COLOR_MAIN, Enum.Material.Plastic, wallsFolder)
                pillar.CFrame = pillarPos
                pillar.CastShadow = false
                pillar.LeftSurface = Enum.SurfaceType.Studs
                pillar.RightSurface = Enum.SurfaceType.Studs
                pillar.FrontSurface = Enum.SurfaceType.Studs
                pillar.BackSurface = Enum.SurfaceType.Studs
            end
            
            if i <= ALCOVE_COUNT then
                local aDist = currentDist - (alcoveWidth / 2)
                local aPos = slope.CFrame * CFrame.new((SLOPE_WIDTH/2 + 10) * side, 0.1, -SLOPE_LENGTH/2 + aDist)
                local alcove = createPart("SafetyAlcove", Vector3.new(30, 2, alcoveWidth), aPos.Position, WALL_COLOR_MAIN, Enum.Material.Plastic, wallsFolder)
                alcove.CFrame = aPos
                alcove.CastShadow = false
                alcove.LeftSurface = Enum.SurfaceType.Studs
                
                -- BACK WALL for Safety
                local backSafe = createPart("AgSafetyWall", Vector3.new(5, 50, alcoveWidth), alcove.Position, WALL_COLOR_MAIN, Enum.Material.Plastic, wallsFolder)
                -- Place it "Behind" the alcove (Relative to Slope Axis)
                -- Alcove is at X = (SLOPE_WIDTH/2 + 10) * side.
                -- We want it further out? Or blocking the 'Back' (Z)?
                -- "Te caes al no haber pared que te pueda frenar" usually means sliding down.
                -- So we need a wall at the Z-min or Z-max of the alcove?
                -- Or implies the alcove has no back?
                -- Alcove is a floor.
                -- Let's put a wall at the "Outer" side to prevent falling off the world?
                -- Side * (Width/2 + something).
                backSafe.CFrame = alcove.CFrame * CFrame.new(15 * side, 25, 0) -- Outer edge
                backSafe.CastShadow = false
                alcove.LeftSurface = Enum.SurfaceType.Studs
                alcove.RightSurface = Enum.SurfaceType.Studs
                alcove.FrontSurface = Enum.SurfaceType.Studs
                alcove.BackSurface = Enum.SurfaceType.Studs
                
                local glow = createPart("SafeGlow", Vector3.new(15, 0.1, alcoveWidth - 6), alcove.Position, RIM_COLOR, Enum.Material.Neon, wallsFolder)
                glow.CFrame = alcove.CFrame * CFrame.new(0, 1.1, 0)
                glow.Transparency = 0.5; glow.CanCollide = false
                glow.CastShadow = false
            end
            lastDist = currentDist
        end
    end

    -- 5. Load Shops
    local ss = game:GetService("ServerStorage")
    local savedShops = ss:WaitForChild("Shops", 2)
    local finalShops = nil

    if savedShops then
        if Workspace:FindFirstChild("Shops") then Workspace.Shops:Destroy() end
        finalShops = savedShops:Clone()
        finalShops.Name = "Shops"
    else
        finalShops = Workspace:FindFirstChild("Shops")
    end
    
    if finalShops then
        for _, desc in pairs(finalShops:GetDescendants()) do
            if desc:IsA("Script") or desc:IsA("LocalScript") then desc:Destroy() end
        end
        
        local function placeShop(name, pos, angle)
            local shopModel = finalShops:FindFirstChild(name)
            if shopModel then
                 if not shopModel.PrimaryPart then
                     local sb = shopModel:FindFirstChild("ShopBuild")
                     if sb and sb:IsA("Model") then shopModel.PrimaryPart = sb.PrimaryPart or sb:FindFirstChildWhichIsA("BasePart", true) end
                     if not shopModel.PrimaryPart then shopModel.PrimaryPart = shopModel:FindFirstChildWhichIsA("BasePart", true) end
                 end
                 
                 if shopModel.PrimaryPart then
                     shopModel:SetPrimaryPartCFrame(CFrame.new(pos) * CFrame.Angles(0, math.rad(angle), 0))
                 end
                 
                  -- DISABLE COLLISIONS (v4.9)
                  for _, p in pairs(shopModel:GetDescendants()) do
                      if p:IsA("BasePart") then
                          p.CanCollide = false
                      end
                  end
             end
        end
        
        placeShop("Shop", Vector3.new(-84.874, 0.5, 65.284), 58.81)
        placeShop("RobuxShop", Vector3.new(84.181, 0, 65.267), 109.476)
        
        finalShops.Parent = Workspace
    else
         warn("No Shops Found")
    end

    print("[MapManager] Generated Volcano Map with 4 Bases")
end

-- Start
generateMap()
