-- MapManager.server.lua (Refactored for Simulator)
-- Skill: environment-design
-- Description: Generates the high-fidelity "Brainrot Room" with yellow tiles, neon racks, and lighting.

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")

local MapManager = {}

-- CONFIG
local BASE_SIZE = Vector3.new(80, 20, 100) -- Logical size
local UNIFIED_SIZE = Vector3.new(400, 1, 240) -- Massive Floor (Wider)
local BASE_OFFSET = 70 

-- COLORS
local COLOR_YELLOW = Color3.fromRGB(255, 220, 0) -- Closer together on the grid

-- COLORS
local COLOR_YELLOW = Color3.fromRGB(255, 220, 0)
local COLOR_NEON_GREEN = Color3.fromRGB(0, 255, 50)
local COLOR_DARK_PURPLE = Color3.fromRGB(50, 0, 100)

-- Helper
local function createPart(name, size, pos, color, mat, parent)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.Position = pos
    p.Color = color
    p.Material = Enum.Material.Plastic -- Forced to Plastic for Classic Look
    -- Classic Surfaces
    p.TopSurface = Enum.SurfaceType.Studs
    p.BottomSurface = Enum.SurfaceType.Inlet
    
    p.Anchored = true
    p.CastShadow = false -- Disable shadows globally for map
    p.Parent = parent
    return p
end

local function generateBase(index, centerPos, mapFolder)
    local baseName = "TycoonBase_" .. index
    local baseModel = Instance.new("Model")
    baseModel.Name = baseName
    
    -- Primary Part for pivoting/referencing
    local prim = Instance.new("Part")
    prim.Name = "BaseOrigin"
    prim.Size = Vector3.new(1,1,1)
    prim.Position = centerPos
    prim.Anchored = true
    prim.Transparency = 1
    prim.CanCollide = false
    prim.CastShadow = false
    prim.Parent = baseModel
    baseModel.PrimaryPart = prim
    
    baseModel.Parent = mapFolder
    
    -- Removed Individual Floor/Walls/ExtractionZone as requested
    
    -- 4. Spawn Location REMOVED per User Request ("cada uno aparecerá en su base")
    -- Logic handling spawning is in UnitManager/GameManager typically, relying on Player.RespawnLocation which we set to the Base's spawn usually.
    -- Wait, if I remove the physical Part, RespawnLocation won't work.
    -- User said "quita la spawnlocation que hay default because each will spawn in their base". 
    -- This implies removing the *Global* spawn.
    -- But this function creates a spawn *per base*.
    -- If I remove this, players might not spawn at their tycoon.
    -- INTERPRETATION: Use invisible/non-default looking spawn OR remove the initial "Lobby" spawn if it exists.
    -- However, this code creates a spawn *in the base*.
    -- Correct interpretation: "Each one will spawn in their base" -> implying they ALREADY do or will.
    -- "Remove the default spawn" might refer to a `SpawnLocation` in the workspace (checked generateMap, doesn't generate global one).
    -- I'll keep the base spawn but make it invisible/functional only to ensure "spawn in their base" works. 
    -- Update: User might mean the gray block spawn.
    -- I will keep it functional but ensure it's invisible.
    
    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "SpawnLocation"
    spawn.Size = Vector3.new(8, 0.2, 8)
    spawn.Position = centerPos + Vector3.new(0, 0.1, 0) -- Centered in base
    spawn.Anchored = true
    spawn.CanCollide = false
    spawn.Transparency = 1 -- Invisible
    spawn.Enabled = true
    spawn.Duration = 0
    spawn.CastShadow = false
    spawn.Parent = baseModel
    
    -- 5. Generate Slots (UnitManager)
    local UnitManager = require(ServerScriptService.UnitManager)
    UnitManager.createTycoonSlots(baseModel)
    
    return baseModel
end

function MapManager.generateMap()
    -- Cleanup
    if Workspace:FindFirstChild("SimulatorMap") then
        Workspace.SimulatorMap:Destroy()
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
    
    -- 1. UNIFIED PLATFORM (Classic Lego Base)
    -- Color: Bright Green (Classic Grass)
    local floor = createPart("UnifiedFloor", UNIFIED_SIZE, Vector3.new(0, -0.5, 0), BrickColor.new("Bright green").Color, Enum.Material.Plastic, platformFolder)
    
    -- Tech Grid (Neon Lines) -> HIDDEN for Cleaner Look (Reference Match)
    local function createGridLine(x, z, sizeX, sizeZ)
        local line = Instance.new("Part")
        line.Name = "TechLine"
        line.Size = Vector3.new(sizeX, 0.2, sizeZ)
        line.Position = floor.Position + Vector3.new(x, 0.55, z)
        line.Anchored = true
        line.CanCollide = false
        line.CastShadow = false
        line.Transparency = 1 -- Hidden per new aesthetic
        line.Parent = floor 
    end

    -- Create a simple grid pattern
    createGridLine(0, 0, UNIFIED_SIZE.X, 2) -- Center Z
    createGridLine(0, 0, 2, UNIFIED_SIZE.Z) -- Center X
    
    -- Borders turned into WALLS (Classic Fortress)
    local wallHeight = 150 -- Taller walls like in reference
    local wallThickness = 6 
    local gapWidth = 140 
    
    local WALL_COLOR_MAIN = BrickColor.new("Nougat").Color -- Requested specific color
    local RIM_COLOR = BrickColor.new("Bright yellow").Color -- Classic pop color
    
    local function createWall(x, z, sizeX, sizeZ)
        local wall = createPart("BaseWall", Vector3.new(sizeX, wallHeight, sizeZ), floor.Position + Vector3.new(x, wallHeight/2 + 0.5, z), WALL_COLOR_MAIN, Enum.Material.Plastic, wallsFolder)
        
        -- LEGO WALLS: Studs on all sides to make texture visible
        wall.LeftSurface = Enum.SurfaceType.Studs
        wall.RightSurface = Enum.SurfaceType.Studs
        wall.FrontSurface = Enum.SurfaceType.Studs
        wall.BackSurface = Enum.SurfaceType.Studs
        
        -- Magma Glow Strip (Now Green Trim like reference grass top?)
        -- Reference images often have a "Grass" top on walls. Let's make the rim Green.
        local strip = Instance.new("Part")
        strip.Name = "GrassTop"
        strip.Size = Vector3.new(sizeX, 2, sizeZ)
        -- Determine axis for orientation adjustments
        local isXAxis = sizeX > sizeZ
        
        if isXAxis then strip.Size = Vector3.new(sizeX, 2, wallThickness + 2) else strip.Size = Vector3.new(wallThickness + 2, 2, sizeZ) end
        
        strip.CFrame = wall.CFrame * CFrame.new(0, wallHeight/2 + 1, 0)
        strip.Material = Enum.Material.Plastic
        strip.Color = BrickColor.new("Bright green").Color -- Matching floor
        strip.TopSurface = Enum.SurfaceType.Studs
        strip.Anchored = true
        strip.CanCollide = false
        strip.CastShadow = false
        strip.Parent = wall
        strip.Anchored = true
        strip.CanCollide = false
        strip.CastShadow = false
        strip.Parent = wall
        
        -- PILLARS REMOVED PER USER REQUEST ("Quita los pilares negros")
    end
    
    -- Generate Walls with Gap for Slope
    -- Z- Walls (Far side away from volcano)
    createWall(0, -UNIFIED_SIZE.Z/2, UNIFIED_SIZE.X, wallThickness)
    
    -- X Walls (Sides)
    createWall(-UNIFIED_SIZE.X/2, 0, wallThickness, UNIFIED_SIZE.Z)
    createWall(UNIFIED_SIZE.X/2, 0, wallThickness, UNIFIED_SIZE.Z)
    
    -- Z+ Walls (Slope side - split in two)
    local sideWallLen = (UNIFIED_SIZE.X - gapWidth) / 2
    createWall(-UNIFIED_SIZE.X/2 + sideWallLen/2, UNIFIED_SIZE.Z/2, sideWallLen, wallThickness)
    createWall(UNIFIED_SIZE.X/2 - sideWallLen/2, UNIFIED_SIZE.Z/2, sideWallLen, wallThickness)

    -- AUTO-SECURE LOGIC: When stepping back onto the Unified Floor from the Corridor
    local BrainrotData = require(ServerScriptService.BrainrotData)
    local processingTools = {} -- Temp lock
    
    floor.Touched:Connect(function(hit)
        local player = game.Players:GetPlayerFromCharacter(hit.Parent)
        if player then
            local function secureIn(container)
                if not container then return end
                for _, tool in pairs(container:GetChildren()) do
                    -- Check for "Tier" attribute OR Legacy "Unit_" prefix
                    if tool:IsA("Tool") and (tool:GetAttribute("Tier") or string.sub(tool.Name, 1, 5) == "Unit_") then
                        if not tool:GetAttribute("Secured") and not processingTools[tool] then
                            processingTools[tool] = true -- Lock
                            
                            local name = tool.Name
                            if string.sub(name, 1, 5) == "Unit_" then name = string.sub(name, 6) end
                            
                            local tier = tool:GetAttribute("Tier") or "Common"
                            local shiny = tool:GetAttribute("IsShiny") or false
                            local level = tool:GetAttribute("Level") or 1
                            local valueMult = tool:GetAttribute("ValueMultiplier") -- May be nil for new loot
                            
                            -- Move to persistent data (Skip Tool generation, preserve ValueMultiplier)
                            local unitData = BrainrotData.addUnitAdvanced(player, name, tier, shiny, true, level, nil, valueMult)
                            if unitData then
                                tool:SetAttribute("Secured", true)
                                tool:SetAttribute("UnitId", unitData.Id)
                                tool:SetAttribute("ValueMultiplier", unitData.ValueMultiplier) -- Update tool with final value
                                
                                -- Notify
                                print("SECURED: " .. name .. " (x" .. string.format("%.1f", unitData.ValueMultiplier) .. " mult)")
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
    
    -- 2. Generate 8 Bases (High Capacity Session)
    -- Position: "Pegadas a los muros traseros" (Walls are at Z = -120)
    -- So we place them at Z = -90 to be close but allowing space for the base model itself.
    
    local BACK_Z = -90 
    local SPACING = 45 -- Tight packing for 8 players
    local START_X = -157.5 -- Center the group of 8
    
    local offsets = {}
    for i = 0, 7 do
        table.insert(offsets, Vector3.new(START_X + (i * SPACING), 0, BACK_Z))
    end
    
    for i, offset in ipairs(offsets) do
        generateBase(i, offset, mapFolder)
    end
    
    -- 3. SELL ZONE (Holographic Cyber-Pad)
    -- RESTORING ORIGINAL GEOMETRY AND POSITION PER USER REQUEST
    local safeZone = Instance.new("Part")
    safeZone.Name = "SellZone"
    safeZone.Shape = Enum.PartType.Cylinder
    safeZone.Size = Vector3.new(0.5, 18, 18) 
    safeZone.CFrame = CFrame.new(-79.631, 0.3, 86.485) * CFrame.Angles(0, 0, math.rad(90))
    safeZone.Anchored = true
    safeZone.CanCollide = false
    safeZone.Transparency = 0.5
    safeZone.Color = BrickColor.new("Bright green").Color -- Updated color
    safeZone.Material = Enum.Material.Glass 
    safeZone.CastShadow = false
    safeZone.Parent = mapFolder
    
    -- Inner Core (Neon)
    local szCore = safeZone:Clone()
    szCore.Size = Vector3.new(0.6, 14, 14)
    szCore.Transparency = 0.2
    szCore.Material = Enum.Material.Neon
    szCore.CFrame = safeZone.CFrame
    szCore.CastShadow = false
    szCore.Parent = mapFolder
    
    -- TAG FOR SHOP SYSTEM
    CollectionService:AddTag(safeZone, "SellZone")
    
    -- 3b. UPGRADE ZONE (Holographic Cyber-Pad)
    local upgradeZone = Instance.new("Part")
    upgradeZone.Name = "UpgradeZone"
    upgradeZone.Shape = Enum.PartType.Cylinder
    upgradeZone.Size = Vector3.new(0.5, 18, 18)
    upgradeZone.CFrame = CFrame.new(81.631, -0.2, 92.514) * CFrame.Angles(0, 0, math.rad(90))
    upgradeZone.Anchored = true
    upgradeZone.CanCollide = false
    upgradeZone.Transparency = 0.5
    upgradeZone.Color = Color3.fromRGB(170, 0, 255) 
    upgradeZone.Material = Enum.Material.Glass
    upgradeZone.CastShadow = false
    upgradeZone.Parent = mapFolder
    
    -- Inner Core
    local uzCore = upgradeZone:Clone()
    uzCore.Size = Vector3.new(0.6, 14, 14)
    uzCore.Transparency = 0.2
    uzCore.Material = Enum.Material.Neon
    uzCore.CFrame = upgradeZone.CFrame
    uzCore.CastShadow = false
    uzCore.Parent = mapFolder
    
    CollectionService:AddTag(upgradeZone, "UpgradeZone")

    -- 4. VOLCANO SLOPE (Inclined Path)
    local SLOPE_ANGLE = 25 -- Reduced from 35 to prevent "flying off"
    local SLOPE_LENGTH = 1500 -- Reverted to original stable length
    local SLOPE_WIDTH = 120
    local SLOPE_START_Z = 120 -- Starts where unified floor ends
    
    local rad = math.rad(SLOPE_ANGLE)
    local hDist = SLOPE_LENGTH * math.cos(rad)
    local vDist = SLOPE_LENGTH * math.sin(rad)
    
    local p1 = Vector3.new(0, 0, SLOPE_START_Z)
    local p2 = Vector3.new(0, vDist, SLOPE_START_Z + hDist)
    
    local slope = createPart("VolcanoSlope", Vector3.new(SLOPE_WIDTH, 2, SLOPE_LENGTH), 
        (p1 + p2)/2, BrickColor.new("Bright green").Color, Enum.Material.Plastic, mapFolder)
    
    slope.CFrame = CFrame.lookAt((p1 + p2)/2, p2)
    
    -- Rock Texture for Volcano REMOVED for Classic Look
    
    -- 4b. MULTI-LAYER SOLID WALLS
    local ALCOVE_COUNT = 6 
    local TOTAL_WALL_HEIGHT = 100
    local SILL_HEIGHT = 5
    local LINTEL_HEIGHT = 40
    local PILLAR_HEIGHT = TOTAL_WALL_HEIGHT - SILL_HEIGHT - LINTEL_HEIGHT
    local WALL_THICKNESS = 40
    local alcoveWidth = 35
    local segmentSpacing = SLOPE_LENGTH / (ALCOVE_COUNT + 1)
    
    for side = -1, 1, 2 do
        -- Continuous Top/Bottom
        local lintelPos = slope.CFrame * CFrame.new((SLOPE_WIDTH/2 + WALL_THICKNESS/2) * side, TOTAL_WALL_HEIGHT - LINTEL_HEIGHT/2 - 10, 0)
        local lintel = createPart("VolcanoWall_Top", Vector3.new(WALL_THICKNESS, LINTEL_HEIGHT, SLOPE_LENGTH), lintelPos.Position, WALL_COLOR_MAIN, Enum.Material.Plastic, wallsFolder)
        lintel.CFrame = lintelPos
        lintel.CastShadow = false
        -- Lego Sides
        lintel.LeftSurface = Enum.SurfaceType.Studs
        lintel.RightSurface = Enum.SurfaceType.Studs
        lintel.FrontSurface = Enum.SurfaceType.Studs
        lintel.BackSurface = Enum.SurfaceType.Studs
        
        local sillPos = slope.CFrame * CFrame.new((SLOPE_WIDTH/2 + WALL_THICKNESS/2) * side, -5, 0)
        local sill = createPart("VolcanoWall_Bottom", Vector3.new(WALL_THICKNESS, 10, SLOPE_LENGTH), sillPos.Position, WALL_COLOR_MAIN, Enum.Material.Plastic, wallsFolder)
        sill.CFrame = sillPos
        sill.CastShadow = false
        -- Lego Sides
        sill.LeftSurface = Enum.SurfaceType.Studs
        sill.RightSurface = Enum.SurfaceType.Studs
        sill.FrontSurface = Enum.SurfaceType.Studs
        sill.BackSurface = Enum.SurfaceType.Studs

        -- Pillars & Alcoves
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
                -- Lego Sides
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
                -- Lego Sides
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

    print("[MapManager] Multi-Layered Canyon Complete.")

    -- 5. Load Shops (User Coordinates)
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
                 -- Setup PrimaryPart (Condensed logic)
                 if not shopModel.PrimaryPart then
                     local sb = shopModel:FindFirstChild("ShopBuild")
                     if sb and sb:IsA("Model") then shopModel.PrimaryPart = sb.PrimaryPart or sb:FindFirstChildWhichIsA("BasePart", true) end
                     if not shopModel.PrimaryPart then shopModel.PrimaryPart = shopModel:FindFirstChildWhichIsA("BasePart", true) end
                 end
                 
                 if shopModel.PrimaryPart then
                     shopModel:SetPrimaryPartCFrame(CFrame.new(pos) * CFrame.Angles(0, math.rad(angle), 0))
                 end
            end
        end
        
        -- Exact User Coordinates (Updated Request 02:12)
        placeShop("Shop", Vector3.new(-84.874, 0.5, 94.284), 58.81)
        placeShop("RobuxShop", Vector3.new(84.181, 0, 101.267), 109.476)
        
        finalShops.Parent = Workspace
    else
         warn("No Shops Found")
    end

    print("[MapManager] Generated Volcano Map with 4 Bases")
end


-- Auto-Generate
MapManager.generateMap()

return MapManager
