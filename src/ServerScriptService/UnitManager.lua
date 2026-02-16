-- UnitManager.lua
-- Skill: tycoon-mechanics
-- Description: Manages Slots, Unit Placement, Cash Accumulation, and Collection.
-- Converted to ModuleScript to allow require() from ShopLogic.

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")

local BrainrotData = require(ServerScriptService:WaitForChild("BrainrotData"))
local MutationManager = require(ReplicatedStorage:WaitForChild("MutationManager"))
local elModule = ReplicatedStorage:WaitForChild("EconomyLogic", 10)
if not elModule then
    warn("CRITICAL: [UnitManager] EconomyLogic not found in ReplicatedStorage after 10s! Check Diagnostics.")
    error("EconomyLogic missing")
end
local EconomyLogic = require(elModule)

local UnitManager = {}
UnitManager.GLOBAL_MULTIPLIER = 1 -- Global Event Multiplier

-- STATE (Module Level)
local activeUnits = {} -- [slotInstance] = unitModel
local typhoonOwners = {} -- [player] = tycoonModel
local tycoons = {} -- List of all tycoon models
local initialized = false

-- CONFIG
local ACCUMULATION_RATE = 1
local FLOOR_COUNT = 2 -- Vertical Expansion
local SLOTS_PER_FLOOR = 8
local TOTAL_SLOTS = SLOTS_PER_FLOOR * FLOOR_COUNT

local SLOT_SPACING_Z = 12 
local SLOT_SPACING_X = 19 
local FLOOR_HEIGHT = 20 -- High ceilings for epic feel

-- Helper to find unit models
local function findUnitModel(targetName)
    local brainrotFolder = ServerStorage:WaitForChild("BrainrotModels")
    
    -- Robust search: exact, with prefix, without prefix
    local results = {}
    table.insert(results, targetName) -- Try "Skibidi Toilet"
    table.insert(results, (string.gsub(targetName, " ", "_"))) -- Try "Skibidi_Toilet"
    table.insert(results, "Unit_" .. targetName) -- Legacy
    table.insert(results, (string.gsub(targetName, "Unit_", ""))) -- Cleanified
    table.insert(results, (string.gsub(targetName, "_", " "))) -- Try "Ballerina Cappuccina"
    
    for _, nameToTry in ipairs(results) do
        local found = brainrotFolder:FindFirstChild(nameToTry, true)
        if found then return found end
    end
    return nil
end

-- Generator Function (Called by MapManager)
function UnitManager.createTycoonSlots(baseModel)
    if not baseModel or not baseModel.PrimaryPart then return end
    
    table.insert(tycoons, baseModel)

    local slotsFolder = Instance.new("Folder")
    slotsFolder.Name = "TycoonSlots"
    slotsFolder.Parent = baseModel

    -- Structure Generation Helper (Internal)
    local function createStructure(floorNum)
        if floorNum == 1 then return end 
        
        local yLevel = 1.5 + ((floorNum - 1) * FLOOR_HEIGHT)
        local floorWidth = 34 -- Wide enough to hold slots (19 stud spacing + margin)
        local floorLength = 64 -- Long enough for 4 rows
        local zOffset = -2 -- Slight shift to center rows visually
        
        -- 1. MAIN FLOOR PLATE (Replaces narrow catwalk)
        local floorPlate = Instance.new("Part")
        floorPlate.Name = "Floor_F" .. floorNum
        floorPlate.Size = Vector3.new(floorWidth, 1, floorLength) 
        floorPlate.Position = baseModel.PrimaryPart.Position + Vector3.new(0, yLevel - 2, zOffset)
        floorPlate.Anchored = true
        floorPlate.Material = Enum.Material.Metal
        floorPlate.Color = Color3.fromRGB(40, 40, 50)
        floorPlate.Color = Color3.fromRGB(40, 40, 50)
        floorPlate.CastShadow = false
        floorPlate.Parent = slotsFolder
        
        -- Neon Trim (Perimeter)
        local trim = Instance.new("Part")
        trim.Size = Vector3.new(floorWidth + 0.4, 0.4, floorLength + 0.4)
        trim.CFrame = floorPlate.CFrame * CFrame.new(0, -0.2, 0)
        trim.Material = Enum.Material.Neon
        trim.Color = Color3.fromRGB(0, 150, 255) 
        trim.Anchored = true
        trim.CanCollide = false
        trim.CanCollide = false
        trim.CastShadow = false
        trim.Parent = floorPlate
        
        -- Cutout center of trim? No, simple plate is fine for now.
        
        -- 2. CORNER PILLARS (Cube Frame)
        local pillarSize = 1.5
        local pX = (floorWidth / 2) - (pillarSize/2)
        local pZ = (floorLength / 2) - (pillarSize/2)
        
        for xDir = -1, 1, 2 do
            for zDir = -1, 1, 2 do
                local pillar = Instance.new("Part")
                pillar.Name = "Pillar_Support"
                pillar.Size = Vector3.new(pillarSize, FLOOR_HEIGHT, pillarSize)
                -- Position: Corners of the floor, extending DOWN to the floor below
                pillar.Position = floorPlate.Position + Vector3.new(pX * xDir, -FLOOR_HEIGHT/2, pZ * zDir)
                pillar.Anchored = true
                pillar.Material = Enum.Material.Concrete
                pillar.Color = Color3.fromRGB(30, 30, 35)
                pillar.Color = Color3.fromRGB(30, 30, 35)
                pillar.CastShadow = false
                pillar.Parent = slotsFolder
                
                -- Neon Strip on Pillar
                local strip = Instance.new("Part")
                strip.Size = Vector3.new(0.2, FLOOR_HEIGHT, 0.2)
                strip.CFrame = pillar.CFrame * CFrame.new(pillarSize/2 * xDir, 0, pillarSize/2 * zDir) -- Outside corner edge
                strip.Material = Enum.Material.Neon
                strip.Color = Color3.fromRGB(255, 100, 50) -- Orange accent
                strip.Anchored = true
                strip.CanCollide = false
                strip.CanCollide = false
                strip.CastShadow = false
                strip.Parent = pillar
            end
        end

        -- 3. RAMP (Seamless Connection)
        -- Ramp connects from [Current Floor Back Edge] down to [Previous Floor]
        -- Floor Back Edge Z = floorPlate.Z + floorLength/2 = zOffset + 32
        -- Ramp should start there and go BACK (+Z) and DOWN (-Y)
        
        local rampLen = 25
        local rampPart = Instance.new("Part")
        rampPart.Name = "Ramp_F" .. floorNum
        rampPart.Size = Vector3.new(12, 1, rampLen) -- Wide ramp
        rampPart.Anchored = true
        rampPart.Material = Enum.Material.DiamondPlate
        rampPart.Color = Color3.fromRGB(50, 50, 60)
        rampPart.Material = Enum.Material.DiamondPlate
        rampPart.Color = Color3.fromRGB(50, 50, 60)
        rampPart.CastShadow = false
        rampPart.Parent = slotsFolder
        
        -- Math for seamless angle
        -- Height diff = FLOOR_HEIGHT (20)
        -- Horizontal distance = rampLen projected? 
        -- Actually, let's treat it as a hypotenuse for simple visual connectivity.
        -- We place the TOP of the ramp at the EDGE of the floor.
        
        local alignPoint = floorPlate.Position + Vector3.new(0, 0, (floorLength/2)) -- Back Edge Center
        -- We want the ramp's "Top Front" edge to touch 'alignPoint'
        -- Ramp Center would be: alignPoint + (Forward * RampLen/2) + (Down * Height/2) ?
        -- Let's use LookAt.
        
        local topPoint = alignPoint
        local bottomPoint = alignPoint + Vector3.new(0, -FLOOR_HEIGHT, 20) -- 20 studs back, 20 studs down
        
        rampPart.CFrame = CFrame.lookAt(
            (topPoint + bottomPoint) / 2, -- Center matches midpoint
            bottomPoint -- Look at bottom
        )
        
        -- Adjust length to match hipotenuse exactly if we want perfection, 
        -- but fixed size + overlap is safer for Roblox physics usually.
        rampPart.Size = Vector3.new(12, 1, (topPoint - bottomPoint).Magnitude + 2) -- +2 for overlap
    end

    -- SLOT GENERATION LOOP
    local startX = -(SLOT_SPACING_X / 2)
    local startZ = -18 -- Adjusted "Earlier" (Was -20, wait. -20 is "Front". +20 is "Back")
    -- If Z grows towards back... -20 is "Front".
    -- User said "Start a little earlier".
    -- "Platform is displaced... start earlier so slots are distributed".
    -- If Slots are at -23 to +19. Floor is -34 to +30.
    -- This seems centered.
    -- I'll stick to startZ modification if needed, but let's trust the new FloorPlate centers.
    startZ = -22 -- Pushing slots slightly more "North/Front" (Negative Z)
    
    for i = 1, TOTAL_SLOTS do
        local slot = Instance.new("Part")
        slot.Name = "Slot_" .. i
        
        -- Vertical Logic
        local floor = math.ceil(i / SLOTS_PER_FLOOR)
        local iInFloor = (i - 1) % SLOTS_PER_FLOOR + 1
        
        -- GRID LOGIC (Per Floor)
        local row = math.ceil(iInFloor / 2) 
        local col = (iInFloor - 1) % 2 
        
        local xPos = startX + (col * SLOT_SPACING_X)
        local zPos = startZ + ((row - 1) * SLOT_SPACING_Z)
        local yPos = 1.5 + ((floor - 1) * FLOOR_HEIGHT) 
        
        local pos = baseModel.PrimaryPart.Position + Vector3.new(xPos, yPos, zPos)
        
        -- Build Structure for this floor if it's the first slot of the floor
        if iInFloor == 1 then
            createStructure(floor)
        end
        
        local angle = 0
        if iInFloor % 2 == 0 then angle = 90 else angle = -90 end
        
        -- PEDESTAL DESIGN
        slot.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(angle), 0)
        slot.Size = Vector3.new(6, 3, 6) 
        slot.Material = Enum.Material.Metal 
        slot.Color = Color3.fromRGB(25, 25, 30) 
        slot.Anchored = true
        slot.Anchored = true
        slot.CanCollide = true
        slot.CastShadow = false
        slot.Parent = slotsFolder
        
        -- RIM
        local rim = Instance.new("Part")
        rim.Name = "PedestalRim"
        rim.Size = Vector3.new(6.4, 0.4, 6.4)
        rim.CFrame = slot.CFrame * CFrame.new(0, -1.3, 0) 
        rim.Color = Color3.fromRGB(0, 255, 150) 
        rim.Material = Enum.Material.Neon
        rim.Anchored = true
        rim.CanCollide = false
        rim.Anchored = true
        rim.CanCollide = false
        rim.CastShadow = false
        rim.Parent = slot
        
        -- TOP GLOW
        local glow = Instance.new("Part")
        glow.Size = Vector3.new(5.2, 0.1, 5.2) 
        glow.CFrame = slot.CFrame * CFrame.new(0, 1.51, 0)
        glow.Color = Color3.fromRGB(0, 50, 0) -- Dim green when empty
        glow.Material = Enum.Material.Neon
        glow.Anchored = true
        glow.CanCollide = false
        glow.Name = "GlowPad"
        glow.Anchored = true
        glow.CanCollide = false
        glow.CastShadow = false
        glow.Parent = slot

        -- INFO DISPLAY
        local infoParams = Instance.new("Part")
        infoParams.Name = "InfoDisplay"
        infoParams.Size = Vector3.new(3, 0.5, 3) 
        infoParams.CFrame = slot.CFrame * CFrame.new(0, -0.25, -4.5) 
        infoParams.Color = Color3.fromRGB(20, 20, 20)
        infoParams.Anchored = true
        infoParams.CanCollide = true 
        infoParams.Transparency = 1
        infoParams.CanCollide = false
        infoParams.CastShadow = false
        infoParams.Parent = slot
        
        local cd = Instance.new("ClickDetector")
        cd.Parent = infoParams
        
        local sg = Instance.new("SurfaceGui")
        sg.Face = Enum.NormalId.Top
        sg.Parent = infoParams
        
        local txn = Instance.new("TextLabel")
        txn.Size = UDim2.new(1,0,1,0)
        txn.Text = "$0"
        txn.TextColor3 = Color3.new(0,1,0)
        txn.TextScaled = true
        txn.BackgroundTransparency = 1
        txn.Font = Enum.Font.FredokaOne
        txn.Rotation = -90 
        txn.Name = "CashText"
        txn.Parent = sg
        
        -- INTERACTION
        local prompt = Instance.new("ProximityPrompt")
        prompt.Name = "ConfigurePrompt"
        prompt.ActionText = "Deploy Unit"
        prompt.ObjectText = "Slot " .. i
        prompt.RequiresLineOfSight = false 
        prompt.Parent = slot
        
        -- Connect UI touch/click for collection
        local function triggerCollection(player)
            if typhoonOwners[player] == baseModel then
                 UnitManager.collectSlot(player, slot)
            end
        end
        
        infoParams.Touched:Connect(function(hit)
            local character = hit.Parent
            local p = Players:GetPlayerFromCharacter(character)
            if p then triggerCollection(p) end
        end)
        
        cd.MouseClick:Connect(function(player)
            triggerCollection(player)
        end)
        
        -- PROMPT LOGIC
        prompt.Triggered:Connect(function(player)
            -- Verify Ownership
            if typhoonOwners[player] ~= baseModel then return end
            
            local isOccupied = slot:GetAttribute("Occupied")
            
            if isOccupied then
                -- RETRIEVE UNIT
                UnitManager.removeUnit(player, i)
            else
                -- DEPLOY UNIT
                 local character = player.Character
                 if not character then return end
                 
                 local tool = character:FindFirstChildWhichIsA("Tool")
                  if tool and tool:GetAttribute("Tier") then
                       local removedUnit = nil
                       -- Remove from BrainrotData to get full struct
                       removedUnit = BrainrotData.removeUnit(player, tool:GetAttribute("UnitId") or tool.Name)
                       
                       if removedUnit then
                             UnitManager.placeUnit(player, removedUnit.Name, i, removedUnit.Shiny, removedUnit.Level, removedUnit.Id, removedUnit.ValueMultiplier, removedUnit.Tier)
                             tool:Destroy()
                       else
                           warn("Failed to remove unit from data: " .. tool.Name)
                       end
                  end
             end
        end)
    end
end

-- 2. Tycoon Assignment
function UnitManager.assignTycoon(player)
    if typhoonOwners[player] then return typhoonOwners[player] end
    
    -- Find empty tycoon
    for _, tycoon in pairs(tycoons) do
        local ownerAttr = tycoon:GetAttribute("Owner")
        if not ownerAttr then
            -- Claim
            tycoon:SetAttribute("Owner", player.Name)
            typhoonOwners[player] = tycoon
            print("[UnitManager] Assigned " .. tycoon.Name .. " to " .. player.Name)
            
            -- Spawn Player logic 
            local spawnLoc = tycoon:FindFirstChild("SpawnLocation")
            if spawnLoc then
                 player.RespawnLocation = spawnLoc
                 task.delay(0.5, function() 
                     if player and player.Parent == Players then
                         player:LoadCharacter() 
                     end
                 end) 
            end
            return tycoon
        end
    end
    
    warn("[UnitManager] No Tycoons Available for " .. player.Name)
    return nil
end

-- 3. Remove Unit Logic (Pick Up)
function UnitManager.removeUnit(player, slotIndex)
    local tycoon = typhoonOwners[player]
    if not tycoon then return end
    
    local slot = tycoon.TycoonSlots:FindFirstChild("Slot_" .. slotIndex)
    if not slot then return end
    
    if not slot:GetAttribute("Occupied") then return end
    
    local unitName = slot:GetAttribute("UnitName")
    local cleanName = string.gsub(unitName, "Unit_", "")
    
    -- Get attributes
    local tier = "Common"
    local isShiny = false
    local level = 1
    local valueMult = 1.0
    local unitId = nil
    
    local model = activeUnits[slot]
    if not model then
        -- Fallback find
        model = slot:FindFirstChild("Unit_Spawned") or slot:FindFirstChild("UnitModel")
    end
    
    if model then
        tier = model:GetAttribute("Tier") or "Common"
        isShiny = model:GetAttribute("IsShiny") or false
        level = model:GetAttribute("Level") or 1
        valueMult = model:GetAttribute("ValueMultiplier") or 1.0
        unitId = model:GetAttribute("UnitId")
    end
    
    -- Give back to player
    BrainrotData.addUnit(player, cleanName, tier, isShiny, level, unitId, valueMult)
    
    -- Destroy Model
    local foundModel = slot:FindFirstChild("Unit_Spawned") 
        or slot:FindFirstChild("UnitModel") 
        or slot:FindFirstChild("Placeholder_" .. tostring(unitName))
    
    if foundModel then 
        foundModel:Destroy() 
    else
        for _, child in pairs(slot:GetChildren()) do
            if child:IsA("Model") then child:Destroy() end
        end
    end
    
    -- Reset Slot
    slot:SetAttribute("Occupied", nil)
    slot:SetAttribute("UnitName", nil)
    slot:SetAttribute("Income", nil)
    activeUnits[slot] = nil -- Clean state
    
    -- Clear Persistence
    BrainrotData.setPlacedUnit(player, slotIndex, nil)
    
    -- Reset Prompt
    local prompt = slot:FindFirstChild("ConfigurePrompt")
    if prompt then
        prompt.ActionText = "Deploy Unit"
    end
    
    local upgradePrompt = slot:FindFirstChild("UpgradePrompt")
    if upgradePrompt then
        upgradePrompt.Enabled = false
    end
    
    -- Play Sound
    local sfx = Instance.new("Sound")
    sfx.SoundId = "rbxassetid://4676738150" 
    sfx.Parent = slot
    sfx:Play()
    Debris:AddItem(sfx, 1)
end

-- 4. Place Unit Logic
function UnitManager.placeUnit(player, unitName, slotIndex, isShiny, level, unitId, valueMultiplier, tierOverride)
    local tycoon = typhoonOwners[player]
    if not tycoon then 
        warn("Player has no tycoon assigned!") 
        return 
    end
    
    local slotsFolder = tycoon:FindFirstChild("TycoonSlots")
    if not slotsFolder then return end
    
    local slot = slotsFolder:FindFirstChild("Slot_" .. slotIndex)
    if not slot then return end
    
    if slot:GetAttribute("Occupied") then return end
    
    -- Auto-generate UnitId if not provided
    if not unitId then
        unitId = HttpService:GenerateGUID(false)
    end

    local modelTemplate = findUnitModel(unitName)
    
    if not modelTemplate then
        warn("[UnitManager] Model NOT FOUND for: " .. tostring(unitName))
        -- Placeholder
        local placeholder = Instance.new("Model")
        placeholder.Name = "Placeholder_" .. unitName
        local part = Instance.new("Part")
        part.Name = "Primary"
        part.Size = Vector3.new(4, 4, 4)
        part.Color = Color3.fromRGB(100, 100, 100) 
        part.Material = Enum.Material.Neon
        part.Anchored = true
        part.Parent = placeholder
        placeholder.PrimaryPart = part
        modelTemplate = placeholder
    end
    
    if modelTemplate then
        local unit = modelTemplate:Clone()
        unit.Name = "Unit_Spawned" 
        
        -- Sanitize
        for _, desc in pairs(unit:GetDescendants()) do
            if desc:IsA("Humanoid") or desc:IsA("GuiBase3d") then
                desc:Destroy()
            end
        end
        
        local tier = tierOverride
        if not tier or tier == "" then
            tier = "Common"
            if modelTemplate.Parent and EconomyLogic.RARITY_COLORS[modelTemplate.Parent.Name] then
                tier = modelTemplate.Parent.Name
            end
        end
        
        MutationManager.applyMutation(unit, tier, isShiny, true)
        
        local realLevel = level or 1
        local realValueMult = valueMultiplier
        if not realValueMult then
            realValueMult = EconomyLogic.generateValueMultiplier()
        end
        local income = EconomyLogic.calculateIncome(unitName, tier, realLevel, isShiny, realValueMult)
        
        unit:SetAttribute("Income", income)
        unit:SetAttribute("ValueMultiplier", realValueMult) 
        unit:SetAttribute("IsShiny", isShiny)
        unit:SetAttribute("Tier", tier)
        unit:SetAttribute("StoredCash", 0) 
        unit:SetAttribute("Owner", player.Name)
        unit:SetAttribute("UnitName", unitName)
        unit:SetAttribute("Level", realLevel)
        unit:SetAttribute("UnitId", unitId) 
        
        CollectionService:AddTag(unit, "BrainrotUnit")
        unit:SetAttribute("TierColor", EconomyLogic.getTierColor(tier))

        -- PIVOT
        local modelCF, modelSize = unit:GetBoundingBox()
        local bottomY = modelCF.Position.Y - (modelSize.Y / 2)
        local pivotOffset = unit:GetPivot().Position.Y - bottomY
        local targetCFrame = slot.CFrame * CFrame.new(0, slot.Size.Y/2 + pivotOffset, 0)
        
        unit:PivotTo(targetCFrame)
        unit.Parent = slot
        
        for _, v in pairs(unit:GetDescendants()) do
            if v:IsA("BasePart") then
                v.Anchored = true
                v.CanCollide = false 
            end
        end
        
        slot:SetAttribute("Occupied", true)
        slot:SetAttribute("UnitName", unitName) 
        
        local prompt = slot:FindFirstChild("ConfigurePrompt")
        if prompt then
            prompt.ActionText = "Pick Up"
        end
        
        if slot:FindFirstChild("GlowPad") then
            slot.GlowPad.Color = Color3.fromRGB(0, 255, 0)
        end
        
        -- Shiny Particles
        if isShiny then
             local sparkles = Instance.new("ParticleEmitter")
             sparkles.Name = "ShinySparkles"
             sparkles.Texture = "rbxassetid://243098098" 
             sparkles.Color = ColorSequence.new(Color3.new(1, 1, 0.4)) 
             sparkles.Size = NumberSequence.new(0.5, 0)
             sparkles.Parent = unit.PrimaryPart or unit:FindFirstChildWhichIsA("BasePart")
        end
        
        activeUnits[slot] = unit
        
        BrainrotData.setPlacedUnit(player, slotIndex, unitName, isShiny, unitId, realLevel, realValueMult, tier)
        
        -- Upgrade Prompt
        local upgradePrompt = slot:FindFirstChild("UpgradePrompt")
        if not upgradePrompt then
             upgradePrompt = Instance.new("ProximityPrompt")
             upgradePrompt.Name = "UpgradePrompt"
             upgradePrompt.KeyboardKeyCode = Enum.KeyCode.F
             upgradePrompt.RequiresLineOfSight = false
             upgradePrompt.UIOffset = Vector2.new(0, -70)
             upgradePrompt.Parent = slot
             
             upgradePrompt.Triggered:Connect(function(triggerPlayer)
                 local tycoon = typhoonOwners[triggerPlayer]
                 local slotTycoon = slot.Parent and slot.Parent.Parent
                 if not slotTycoon or tycoon ~= slotTycoon then return end
                 
                 local u = activeUnits[slot]
                 if u then
                     local uId = u:GetAttribute("UnitId")
                     local success, newLevel, msg = BrainrotData.upgradeUnitLevel(triggerPlayer, uId)
                     if success then
                          local sfx = Instance.new("Sound")
                          sfx.SoundId = "rbxassetid://2865227271" 
                          sfx.Parent = slot
                          sfx:Play()
                          Debris:AddItem(sfx, 1)
                          
                          local t = u:GetAttribute("Tier") or "Common"
                          local s = u:GetAttribute("IsShiny") or false
                          local v = u:GetAttribute("ValueMultiplier") or 1.0
                          local n = u:GetAttribute("UnitName")
                          local inc = EconomyLogic.calculateIncome(n, t, newLevel, s, v)
                          
                          u:SetAttribute("Level", newLevel)
                          u:SetAttribute("Income", inc)
                          
                          local cost = EconomyLogic.calculateUpgradeCost(t, newLevel)
                          upgradePrompt.ActionText = "Subir Nivel ($" .. EconomyLogic.Abbreviate(cost) .. ")"
                     else
                          local sfx = Instance.new("Sound")
                          sfx.SoundId = "rbxassetid://15396557879"
                          sfx.Volume = 0.5
                          sfx.Parent = slot
                          sfx:Play()
                          Debris:AddItem(sfx, 1)
                     end
                 end
             end)
        end
        
        if upgradePrompt then
            if not CollectionService:HasTag(upgradePrompt, "UpgradePrompt") then
                CollectionService:AddTag(upgradePrompt, "UpgradePrompt")
            end
            local nextCost = EconomyLogic.calculateUpgradeCost(tier, realLevel)
            upgradePrompt.ActionText = "Subir Nivel ($" .. EconomyLogic.Abbreviate(nextCost) .. ")"
            upgradePrompt.ObjectText = "Mejorar"
            upgradePrompt.Enabled = true
        end
    end
end

-- Collection Logic
function UnitManager.collectSlot(player, slot)
    local unit = activeUnits[slot]
    if not unit then return end
    
    if unit:GetAttribute("Owner") ~= player.Name then return end
    
    local stored = unit:GetAttribute("StoredCash") or 0
    if stored > 0 then
        BrainrotData.addCash(player, stored)
        unit:SetAttribute("StoredCash", 0)
        
        local info = slot:FindFirstChild("InfoDisplay")
         if info and info:FindFirstChild("SurfaceGui") and info.SurfaceGui:FindFirstChild("CashText") then
            info.SurfaceGui.CashText.Text = "$0"
        end
        
        local sfx = Instance.new("Sound")
        sfx.SoundId = "rbxasset://sounds/electronicpingshort.wav"
        sfx.Parent = slot
        sfx:Play()
        Debris:AddItem(sfx, 1)
    end
end

-- Accumulation Loop
local function startLoop()
    task.spawn(function()
        while true do
            task.wait(ACCUMULATION_RATE)
            for slot, unit in pairs(activeUnits) do
                if unit and unit.Parent then
                    local inc = unit:GetAttribute("Income") or 0
                    local current = unit:GetAttribute("StoredCash") or 0
                    
                    local effectiveIncome = inc * UnitManager.GLOBAL_MULTIPLIER
                    local newTotal = current + effectiveIncome
                    unit:SetAttribute("StoredCash", newTotal)
                    
                    local info = slot:FindFirstChild("InfoDisplay")
                    if info and info:FindFirstChild("SurfaceGui") then
                        local cashText = info.SurfaceGui:FindFirstChild("CashText")
                        if cashText then
                            cashText.Text = "$" .. EconomyLogic.Abbreviate(newTotal)
                        end
                    end
                else
                    activeUnits[slot] = nil -- Cleanup
                end
            end
        end
    end)
end

-- UNIFIED Restore Function
function UnitManager.restoreTycoon(player)
    -- 1. Assign Tycoon
    local tycoon = UnitManager.assignTycoon(player)
    if not tycoon then return end
    
    -- 2. Teleport
    local spawnLoc = tycoon:FindFirstChild("SpawnLocation")
    if spawnLoc and player.Character then
        player.Character:PivotTo(spawnLoc.CFrame + Vector3.new(0, 3, 0))
    end
    
    -- 3. Restore Slots
    local savedSlots = BrainrotData.getPlacedUnits(player)
    if not savedSlots then return end
    
    print("[UnitManager] Restoring Tycoon Units for " .. player.Name)
    local slotsFolder = tycoon:FindFirstChild("TycoonSlots")
    if not slotsFolder then return end

    for slotIdxStr, unitData in pairs(savedSlots) do
        local idx = tonumber(slotIdxStr)
        if idx then
            local slot = slotsFolder:FindFirstChild("Slot_" .. idx)
            if slot and not activeUnits[slot] then
                -- Parse
                local uName = type(unitData) == "table" and unitData.Name or unitData
                local isShiny = type(unitData) == "table" and unitData.Shiny or false
                local unitId = type(unitData) == "table" and unitData.UnitId or nil
                local level = type(unitData) == "table" and unitData.Level or 1
                local valueMult = type(unitData) == "table" and unitData.ValueMultiplier or 1.0
                local tier = type(unitData) == "table" and unitData.Tier or nil
                
                UnitManager.placeUnit(player, uName, idx, isShiny, level, unitId, valueMult, tier)
            end
        end
    end
end

-- Init
function UnitManager.Init()
    if initialized then return end
    initialized = true
    
    startLoop()
    
    -- Remote Management for Manual Placement
    local placeFunc = ReplicatedStorage:WaitForChild("PlaceUnit", 5)
    
    if placeFunc then
        placeFunc.OnServerInvoke = function(player, slotId, unitId)
              -- 1. Check if slot is occupied
              local tycoon = typhoonOwners[player]
              if tycoon then
                  local slotsFolder = tycoon:FindFirstChild("TycoonSlots")
                  local slot = slotsFolder and slotsFolder:FindFirstChild("Slot_" .. slotId)
                  if slot and slot:GetAttribute("Occupied") then
                      return false, "Slot is already occupied!"
                  end
              end
              
              -- 2. Helper to find tool
              local function findToolIn(container, uId)
                  if not container then return nil end
                  for _, child in pairs(container:GetChildren()) do
                      if child:IsA("Tool") then
                         if child:GetAttribute("UnitId") == uId then return child end
                         if child.Name == uId then return child end
                         if child.Name == "Unit_" .. uId then return child end
                      end
                  end
                  return nil
              end
              
              local character = player.Character
              local tool = findToolIn(character, unitId) or findToolIn(player.Backpack, unitId)
              
              if tool then
                  local isSecured = tool:GetAttribute("Secured")
                  local name = string.gsub(tool.Name, "Unit_", "")
                  local tier = tool:GetAttribute("Tier") or "Common"
                  local isShiny = tool:GetAttribute("IsShiny") or false
                  
                  if isSecured then
                      local unitData = BrainrotData.removeUnit(player, tool:GetAttribute("UnitId") or name)
                      if unitData then
                          UnitManager.placeUnit(player, unitData.Name, slotId, unitData.Shiny, unitData.Level, unitData.Id, unitData.ValueMultiplier, unitData.Tier)
                          tool:Destroy()
                          return true
                      end
                  else
                      -- Loot/Temp
                      local valueMult = tool:GetAttribute("ValueMultiplier") or nil
                      local lvl = tool:GetAttribute("Level") or 1
                      BrainrotData.markDiscovered(player, name, tier, isShiny)
                      UnitManager.placeUnit(player, name, slotId, isShiny, lvl, nil, valueMult, tier)
                      tool:Destroy()
                      return true
                  end
              else
                  warn("Tool not found for ID: " .. tostring(unitId))
              end
              return false, "Tool fail"
        end
    end
    
    -- Player Handling
    local function onPlayerAdded(p)
         task.wait(2) -- Wait for Map/Tycoons checks
         UnitManager.restoreTycoon(p)
         
         p.CharacterAdded:Connect(function(char)
             task.wait(0.5) 
             local tycoon = typhoonOwners[p]
             if tycoon then
                 local spawnLoc = tycoon:FindFirstChild("SpawnLocation")
                 if spawnLoc then
                     char:PivotTo(spawnLoc.CFrame + Vector3.new(0, 3, 0))
                 end
             end
         end)
    end

    Players.PlayerAdded:Connect(onPlayerAdded)
    for _, p in pairs(Players:GetPlayers()) do
         task.spawn(function() onPlayerAdded(p) end)
    end
    
    print("[UnitManager] Initialized Module")
end

function UnitManager.clearAllSlots(player)
    local tycoon = typhoonOwners[player]
    if not tycoon then return end
    
    local slotsFolder = tycoon:FindFirstChild("TycoonSlots")
    if not slotsFolder then return end
    
    local clearedCount = 0
    for _, slot in pairs(slotsFolder:GetChildren()) do
        for _, child in pairs(slot:GetChildren()) do
            if child:IsA("Model") then
                child:Destroy()
                clearedCount += 1
            end
        end
        slot:SetAttribute("Occupied", false)
        slot:SetAttribute("UnitName", nil)
        activeUnits[slot] = nil
    end
    print(string.format("[UnitManager] Cleared %d placed units for %s", clearedCount, player.Name))
end

return UnitManager
