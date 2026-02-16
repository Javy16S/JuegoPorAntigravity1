--!strict
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

local MutationManager = require(ReplicatedStorage.Modules:WaitForChild("MutationManager"))
local Maid = require(ReplicatedStorage.Modules:WaitForChild("Maid"))
local elModule = ReplicatedStorage.Modules:WaitForChild("EconomyLogic", 10)
if not elModule then
    warn("CRITICAL: [UnitManager] EconomyLogic not found in ReplicatedStorage.Modules after 10s!")
    error("EconomyLogic missing")
end
local EconomyLogic = require(elModule)

export type Unit = EconomyLogic.Unit

-- STATE (Module Level)
local activeUnits: {[Instance]: Model} = {} -- [slotInstance] = unitModel
local typhoonOwners: {[Player]: Model} = {} -- [player] = tycoonModel
local tycoons: {Model} = {} -- List of all tycoon models
local playerMaids: {[Player]: any} = {} -- [player] = Maid object
local activeOwnerSlots: {[Player]: {[number]: Model}} = {} -- NEW: [player] = { [slotId] = unitModel }
local initialized = false

local UnitManager = {}
UnitManager.GLOBAL_MULTIPLIER = 1 :: number -- Global Event Multiplier

-- CONFIG
local ACCUMULATION_RATE = 1
local FLOOR_COUNT = 2 -- Vertical Expansion
local ROTATION_OFFSET = math.rad(-90) -- Adjusting to face inward
local SLOTS_PER_FLOOR = 8
local TOTAL_SLOTS = SLOTS_PER_FLOOR * FLOOR_COUNT

local SLOT_SPACING_Z = 8 
local SLOT_SPACING_X = 14 -- Wider spacing
local FLOOR_HEIGHT = 16 -- Taller (User request)
local FLOOR_SIZE_X = 38 -- Wider (User request)
local FLOOR_SIZE_Z = 40 -- Longer
local PILLAR_SIZE = 2 -- Thicker pillars for bigger base

-- Helper to find unit models
-- Helper to find unit models (ROBUST SEARCH)
local function findUnitModel(targetName: string): Model?
    if not targetName or targetName == "" then return nil end
    local brainrotFolder = ServerStorage:FindFirstChild("BrainrotModels")
    if not brainrotFolder then return nil end

    -- Direct search with normalization
    local cleanTarget = string.lower(string.gsub(targetName, "[%s_]+", ""))
    
    for _, item in ipairs(brainrotFolder:GetDescendants()) do
        if item:IsA("Model") then
            local itemName = string.lower(string.gsub(item.Name, "[%s_]+", ""))
            if itemName == cleanTarget or itemName == "unit_" .. cleanTarget then
                return item
            end
        end
    end

    return nil
end

-- FX: Upgrade Animation
local function playUpgradeFX(unitModel: Model)
    if not unitModel then return end
    local primary = unitModel.PrimaryPart or unitModel:FindFirstChildWhichIsA("BasePart")
    if not primary then return end
    
    -- 1. Highlight Flash
    local hl = Instance.new("Highlight")
    hl.FillColor = Color3.fromRGB(255, 255, 255)
    hl.OutlineColor = Color3.fromRGB(255, 215, 0)
    hl.FillTransparency = 0
    hl.OutlineTransparency = 0
    hl.Parent = unitModel
    
    game:GetService("TweenService"):Create(hl, TweenInfo.new(0.5), {FillTransparency = 1, OutlineTransparency = 1}):Play()
    Debris:AddItem(hl, 1)
    
    -- 2. Particles (Burst)
    local burst = Instance.new("ParticleEmitter")
    burst.Texture = "rbxassetid://243098098" -- Star
    burst.Color = ColorSequence.new(Color3.fromRGB(255, 255, 0))
    burst.Size = NumberSequence.new(0.5, 0)
    burst.Speed = NumberRange.new(5, 10)
    burst.SpreadAngle = Vector2.new(360, 360)
    burst.Acceleration = Vector3.new(0, 10, 0)
    burst.Drag = 2
    burst.Rate = 100
    burst.Lifetime = NumberRange.new(0.5, 1)
    burst.Parent = primary
    
    burst:Emit(20)
    Debris:AddItem(burst, 2)
    
    -- 3. Floating Text
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(4,0,2,0)
    bb.StudsOffset = Vector3.new(0, 4, 0)
    bb.AlwaysOnTop = true
    bb.Parent = primary
    
    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1,0,1,0)
    txt.BackgroundTransparency = 1
    txt.Text = "LEVEL UP!"
    txt.TextColor3 = Color3.fromRGB(255, 255, 0)
    txt.Font = Enum.Font.FredokaOne
    txt.TextScaled = true
    txt.Parent = bb
    
    game:GetService("TweenService"):Create(bb, TweenInfo.new(1, Enum.EasingStyle.Back), {StudsOffset = Vector3.new(0, 8, 0)}):Play()
    game:GetService("TweenService"):Create(txt, TweenInfo.new(1), {TextTransparency = 1}):Play()
    Debris:AddItem(bb, 1.2)
end

-- Generator Function (Called by MapManager)
-- HELPER: SETUP FLOOR MODEL (New Global Method)
function UnitManager.setupFloorModel(baseModel, template, floorIndex, yOffset) 
    local rawClone = template:Clone()
    local floorModel = rawClone
    
    -- Fix: If Prefab is a Folder, we must wrap it in a Model to use PivotTo
    if not floorModel:IsA("Model") and not floorModel:IsA("BasePart") then
        local newModel = Instance.new("Model")
        newModel.Name = rawClone.Name
        
        for _, child in ipairs(rawClone:GetChildren()) do
            child.Parent = newModel
        end
        
        rawClone:Destroy() -- Destroy empty folder
        floorModel = newModel
    end
    
    -- ANCHOR ALL PARTS (Physics Fix)
    for _, desc in ipairs(floorModel:GetDescendants()) do
        if desc:IsA("BasePart") then
            desc.Anchored = true
        end
    end
    
    floorModel.Name = "Floor_" .. floorIndex
    floorModel.Parent = baseModel:FindFirstChild("TycoonSlots") or baseModel
    
    -- ALIGNMENT FIX: Use "Suelo" as the anchor point
    local suelo = floorModel:FindFirstChild("Suelo")
    if suelo and suelo:IsA("BasePart") then
        floorModel.PrimaryPart = suelo
    else
        if not floorModel.PrimaryPart then
            warn("Warning: Prefab " .. floorModel.Name .. " missing 'Suelo' part for alignment!")
        end
    end

    -- Position
    local targetCFrame = baseModel.PrimaryPart.CFrame * CFrame.new(0, yOffset, 0)
    
    -- ALTERNATING ROTATION: Flip floors so stairs are on opposite sides
    -- User requested to reverse the sequence (likely starting at 180 instead of 0)
    if floorIndex % 2 == 0 then
        targetCFrame = targetCFrame * CFrame.Angles(0, math.pi, 0)
    end
    
    floorModel:PivotTo(targetCFrame)
    
    return floorModel
end

function UnitManager.createTycoonSlots(baseModel: Model)
    if not baseModel or not baseModel.PrimaryPart then return end
    
    table.insert(tycoons, baseModel)

    local slotsFolder = Instance.new("Folder")
    slotsFolder.Name = "TycoonSlots"
    slotsFolder.Parent = baseModel


    task.wait()    
    -- PREFAB LOGIC
    local prefabs = ServerStorage:FindFirstChild("BaseBrainrots")
    if not prefabs then
        local inWorkspace = Workspace:FindFirstChild("BaseBrainrots")
        if inWorkspace then
            -- print("[UnitManager] Migrating 'BaseBrainrots' from Workspace to ServerStorage...")
            inWorkspace.Parent = ServerStorage
            prefabs = inWorkspace
        else
            warn("CRITICAL: 'BaseBrainrots' folder missing in ServerStorage and Workspace!")
            return 
        end
    end
    
    local baseTemplate = prefabs:FindFirstChild("BaseBasica") or prefabs
    local extraTemplate = prefabs:FindFirstChild("PisoExtra") or prefabs
    
    if not baseTemplate or baseTemplate == prefabs then
        -- Fallback: If BaseBasica is missing, try to find ANY model that looks like a base
        baseTemplate = prefabs:FindFirstChildWhichIsA("Model") or prefabs
    end
    
    if not baseTemplate then
        warn("CRITICAL: Missing 'BaseBrainrots' template!")
        return
    end
    
    -- CACHE TEMPLATES GLOBALLY for Upgrader
    UnitManager.BaseTemplate = baseTemplate
    UnitManager.ExtraTemplate = extraTemplate

    local FLOOR_HEIGHT = 18 -- User defined fixed height

    -- HELPER: SETUP SLOTS (Local Helper for createTycoonSlots)
    local function setupSlotsInternal(floorModel, floorIndex, baseModel)
         local Players = game:GetService("Players")
         for _, child in ipairs(floorModel:GetChildren()) do
            local slotNum = child.Name:match("^Slot_?(%d+)")
            if slotNum then
                local localIndex = tonumber(slotNum)
                local globalID = localIndex
                if floorIndex > 0 then
                    globalID = (floorIndex * 10) + localIndex
                end
                
                child.Name = "Slot_" .. globalID
                child.Parent = slotsFolder
                
                -- FIND PARTS
                local posPart = child:FindFirstChild("BrainrotSlotPosition")
                local infoPart = child:FindFirstChild("infodisplay")
                
                if not posPart then
                    posPart = child:IsA("BasePart") and child or child:FindFirstChildWhichIsA("BasePart")
                end
                
                -- SETUP INTERACTION (PROMPT)
                if posPart then
                    local prompt = posPart:FindFirstChild("ConfigurePrompt") or Instance.new("ProximityPrompt")
                    prompt.Name = "ConfigurePrompt"
                    prompt.ActionText = "Deploy Unit"
                    prompt.ObjectText = "Slot " .. globalID
                    prompt.RequiresLineOfSight = false
                    prompt.KeyboardKeyCode = Enum.KeyCode.E
                    prompt.Parent = posPart
                    
                    prompt.Triggered:Connect(function(player)
                        if baseModel:GetAttribute("Owner") ~= player.Name then return end
                        
                        local isOccupied = child:GetAttribute("Occupied")
                        if isOccupied then
                            UnitManager.removeUnit(player, globalID)
                        else
                            game.ReplicatedStorage:WaitForChild("InteractSlot"):FireClient(player, child, globalID)
                        end
                    end)
                end
                
                -- SETUP UI
                if infoPart then
                    local cd = infoPart:FindFirstChildOfClass("ClickDetector") or Instance.new("ClickDetector", infoPart)
                    local function triggerCollection(player)
                        if baseModel:GetAttribute("Owner") == player.Name then
                             UnitManager.collectSlot(player, child)
                        end
                    end
        
                    cd.MouseClick:Connect(triggerCollection)
                    infoPart.Touched:Connect(function(hit)
                         local p = Players:GetPlayerFromCharacter(hit.Parent)
                         if p then triggerCollection(p) end
                    end)
                end
                
                -- STATE VISUALS
                local function updateState()
                    local prompt = posPart and posPart:FindFirstChild("ConfigurePrompt")
                    if prompt then
                        if child:GetAttribute("Occupied") then
                             prompt.ActionText = "Remove Unit"
                        else
                             prompt.ActionText = "Deploy Unit"
                        end
                    end
                end
                child:GetAttributeChangedSignal("Occupied"):Connect(updateState)
                updateState()
            end
        end
    end

    -- WRAPPER: Bridge Global Helper + Local Slot Logic
    local function setupFloorModel(template, floorIndex, yOffset)
         local fm = UnitManager.setupFloorModel(baseModel, template, floorIndex, yOffset) 
         if fm then setupSlotsInternal(fm, floorIndex, baseModel) end
    end
    
    -- 2. BUILD FLOORS (Dynamic based on Attribute or Default 1)
    local currentLevel = baseModel:GetAttribute("BaseLevel") or 1
    baseModel:SetAttribute("BaseLevel", currentLevel)
    
    -- Check if baseModel already has slots (to avoid duplication when MapManager clones BaseBasica directly)
    local hasExistingSlots = false
    for _, child in ipairs(baseModel:GetChildren()) do
        if child.Name:match("^Slot_?%d+") then
            hasExistingSlots = true
            break
        end
    end

    -- Floor 0 Handling
    if hasExistingSlots then
        -- Use the baseModel itself as the container for Floor 0 slots
        -- (Ensures interaction logic is applied to existing parts)
        setupSlotsInternal(baseModel, 0, baseModel)
        print("[UnitManager] Applied interaction logic to existing slots in " .. baseModel.Name)
    else
        -- Traditional flow: Clone BaseBasica template
        setupFloorModel(baseTemplate, 0, 0)
    end
    
    -- Build extra floors if level > 1
    if currentLevel > 1 then
        for i = 1, currentLevel - 1 do
            setupFloorModel(extraTemplate, i, i * FLOOR_HEIGHT)
        end
    end
    
    -- Additional Floors if Level > 1
    -- e.g. Level 2 -> Add Floor 1. Level 3 -> Add Floor 2.
    -- Assuming Level 1 = Ground Floor (0).
    for f = 1, currentLevel - 1 do
        local y = f * FLOOR_HEIGHT
        setupFloorModel(extraTemplate, f, y)
    end
    
    -- Store Template References for Upgrade System
    if not UnitManager.ExtraTemplate then UnitManager.ExtraTemplate = extraTemplate:Clone() end
    
    -- DEAD CODE (Old Procedural Generation)
    if false then -- Disabled Loop

        local slot = Instance.new("Part")
        slot.Name = "Slot_" .. i
        
        -- Vertical Logic
        local floor = math.ceil(i / SLOTS_PER_FLOOR)
        local iInFloor = (i - 1) % SLOTS_PER_FLOOR + 1
        
        -- Build Structure for this floor (Always, including Floor 1)
        if iInFloor == 1 then
            createStructure(floor)
        end
        
        -- GRID LOGIC (Per Floor)
        local row = math.ceil(iInFloor / 2) 
        local col = (iInFloor - 1) % 2 
        
        local xPos = startX + (col * SLOT_SPACING_X)
        local zPos = startZ + ((row - 1) * SLOT_SPACING_Z)
        
        -- Fix Height Logic:
        -- Floor Plate Center Y relative to Base = (floor-1) * FLOOR_HEIGHT
        -- Plate Size Y = 1. Top Surface = Center + 0.5.
        local floorCenterY = ((floor - 1) * FLOOR_HEIGHT)
        local floorTopY = floorCenterY + 0.5
        
        -- Slot Target: Sit ON TOP of floor.
        -- Slot Size Y = 0.2. Center = Bottom + 0.1 = FloorTop + 0.1.
        local slotCenterY = floorTopY + 0.1
        
        -- PEDESTAL DESIGN (Fixed Assembly)
        -- Use User's requested Rim Y (16.625 relative to base? No, assuming base starts at 0).
        -- Floor Top Y is 'floorTopY' (calculated above).
        -- If User example was 16.625 and Floor 2 is at 16.0. 
        -- Floor Top is 16.5. 
        -- 16.625 - 16.5 = +0.125.
        -- This means Rim IS centered at +0.125 above Floor Top.
        -- Since Rim Height is 0.25, Half Height is 0.125.
        -- Bottom of Rim = 0.125 - 0.125 = 0.0. (Flush with Floor Top).
        -- MATH CONFIRMED.
        
        -- Let's target Slot Center to be exactly this 'pos' (FloorTop + 0.125).
        local pos = baseModel.PrimaryPart.Position + Vector3.new(xPos, floorTopY + 0.125, zPos)
        
        local angle = 0
        if iInFloor % 2 == 0 then angle = 90 else angle = -90 end
        
        slot.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(angle), 0)
        slot.Size = Vector3.new(5, 0.2, 5) 
        slot.Material = Enum.Material.DiamondPlate
        slot.Color = Color3.fromRGB(50, 50, 50) 
        slot.Anchored = true
        slot.CanCollide = true
        slot.CastShadow = true
        slot.Parent = slotsFolder
        
        -- RIM (User Specifics)
        -- Size: 5.4, 0.25, 5.4. 
        -- Pos: 16.625. (Implies sitting on floor 16.5).
        -- Our 'pos' variable is calculated as EXACTLY this height (FloorTop + 0.125).
        -- So we use 'pos' directly for the Rim.
        -- We rename 'slot' to 'rim' effectively?
        -- Actually, 'slot' is the interaction part. Let's make 'slot' the Rim.
        
        -- REFACTOR: 'slot' becomes the Rim geometry, since that's the main visual anchor.
        slot.Size = Vector3.new(5.4, 0.25, 5.4)
        -- slot.CFrame already set to 'pos' (Floor + 0.125). Perfect.
        
        -- But wait, slot needs to be clicked?
        -- Yes, keeping slot as the main part is fine.
        
        -- What about the inner part?
        -- If 'slot' is the Rim, it's solid.
        -- User didn't ask for a hole.
        -- We'll keep 'slot' as the Rim.
        -- And we remove the extra 'rim' part since 'slot' IS the rim now.
        
        slot.Name = "Slot_" .. i -- Preserve Name Logic
        -- No separate rim part needed if we resize slot to be the rim.
        -- Unless we need two different colors?
        -- User: "pedestral rim size... position...".
        -- Previous code had 'slot' (Grey) and 'rim' (Neon Green).
        -- If I make 'slot' the Rim (Neon Green), where is the Grey part?
        -- User didn't specify Grey part Size.
        -- Okay, I will make 'slot' the inner Grey part (Size 5?), and 'PedestalRim' the outer Green part.
        
        local rim = Instance.new("Part")
        rim.Name = "PedestalRim"
        rim.Size = Vector3.new(5.4, 0.25, 5.4)
        rim.Size = Vector3.new(5.4, 0.25, 5.4)
        rim.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(angle), 0) -- EXACTLY at 16.625 (Floor + 0.125)
        rim.Color = Color3.fromRGB(236, 236, 236) -- Lily White
        rim.Material = Enum.Material.SmoothPlastic -- Cleaner for White
        rim.Anchored = true
        rim.CanCollide = true -- Walkable
        rim.CastShadow = false
        rim.Parent = slotsFolder -- Parent to folder, or slot?
        -- Typically 'slot' is the logic root.
        -- Let's make 'slot' invisible sensor? Or just the inner part?
        -- Let's keep 'slot' as the inner DiamondPlate part.
        -- Inner Part Height? If Rim is 0.25 (Height), Inner should be 0.2 or 0.25?
        -- Let's make Slot 0.25 too to be flush.
        
        slot.Size = Vector3.new(5, 0.25, 5) -- Inner Part
        slot.CFrame = rim.CFrame -- Same pos/rot
        slot.Parent = slotsFolder
        
        rim.Parent = slot -- Parenting for hierarchy
        
        -- Wait, 'slot' is the prompt holder. Parent rim to slot.
        -- But Slot is smaller than Rim? z-fighting?
        -- Ideally Rim is a Hollow Union.
        -- But with Parts, if Rim is 5.4 and Slot is 5.0, and both are same Pos/SizeY...
        -- The Slot is INSIDE the Rim.
        -- You will see Z-Fighting on Top/Bottom faces where they overlap.
        -- Fix: Scale Slot Y slightly smaller (0.24) or Shift it?
        -- Or just assume User wants Rim to be the container.
        -- Let's stick to: Slot (Inner, Grey), Rim (Outer Ring, Green).
        -- To make 'Outer Ring' with a Part, it must be larger.
        -- If I put a small block inside a large block, the large block HIDES the small block (unless transparent).
        -- So 'PedestalRim' will hide 'Slot'.
        -- Unless 'PedestalRim' is a MESH? Or Union?
        -- User calls it "Pedestal Rim".
        -- I'll assume for now they stack or Rim is meant to be below?
        -- User Y Position: 16.625 for Rim.
        -- If Slot is visible, it must be ABOVE Rim?
        -- Or maybe Rim is just the "Trim".
        -- Let's make Rim slighty larger but LOWER?
        -- User Pos: 16.625. Height 0.25. (Floor 16.5 to 16.75).
        -- If I put Rim at Y=16.625. Top is 16.75.
        -- If I put Slot at Y=16.75 (On top of Rim). Slot Top is 17.0.
        -- This creates a stepped look.
        -- User said "no desmontado" (not dismantled). This implies FLUSH.
        -- I will put Slot (Size 5) centered.
        -- I will put 4 "Trim" parts around it to form the Rim? No, too many parts.
        -- I will use a **SpecialMesh** in the Rim part to make it a hollow box? Or FileMesh?
        -- Simpler: User gave coordinates. 16.625.
        -- If I assume 16.625 is the Center of the Rim.
        -- I'll place the Slot also at 16.625.
        -- And I'll set Slot.ZIndex? No, parts don't have ZIndex.
        -- I'll just scale Slot to be `5.4, 0.25, 5.4` (The full size) and Grey.
        -- And add a `SelectionBox` or `Texture` for the green rim?
        -- No, User asked for a PART named "Pedestal Rim".
        -- I'll just place them both. The Z-fighting is inevitable with blocks unless I offset Y.
        -- I will shift Slot Y up by 0.01 to ensure Grey Top is visible?
        -- Or shift Rim Y up by 0.01 to ensure Green Top is visible?
        -- "Rim" usually frames the object.
        -- I will make Rim dimensions `5.4` x `0.25` x `5.4`.
        -- I will make Slot dimensions `5.0` x `0.3` x `5.0` (Slightly taller, sticks out).
        -- Slot Center Y = `16.625 + 0.025` = `16.65`.
        -- This way Slot protrudes from the Rim.
        
        slot.Size = Vector3.new(5, 0.3, 5) -- Taller inner block
        slot.CFrame = CFrame.new(pos) * CFrame.new(0, 0.025, 0)
        
        rim.Parent = slot
        
        -- TOP GLOW (User Specifics)
        local glow = Instance.new("Part")
        glow.Name = "GlowPad"
        glow.Size = Vector3.new(4.544, 0.1, 4.656) 
        -- Position: User said 16.8 (Glow) vs 16.625 (Rim). Delta = +0.175.
        -- Rim Center Y (relative locally to floor) = 0.125.
        -- Glow Center Y should be 0.125 + 0.175 = 0.3.
        -- So Glow sits 0.3 studs above FLOOR.
        -- Current slot.CFrame is at Floor + 0.125 (Rim Height Center).
        -- We want Glow at Floor + 0.3. 
        -- Offset = 0.3 - 0.125 = 0.175.
        glow.CFrame = slot.CFrame * CFrame.new(0, 0.175, 0)
        glow.Color = Color3.fromRGB(0, 50, 0)
        glow.Material = Enum.Material.Neon
        glow.Anchored = true
        glow.CanCollide = false
        glow.CastShadow = false
        glow.Parent = slot

        -- INFO DISPLAY
        local infoParams = Instance.new("Part")
        infoParams.Name = "InfoDisplay"
        infoParams.Size = Vector3.new(3, 3, 0.2) -- Upright Board? Or Flat?
        -- User: "position: ... rotation: 0, -90, 0".
        -- If Rotation is -90 Y, it faces sideways relative to Slot?
        -- And Y = 0.65?
        -- Let's try to infer form factor. Usually InfoDisplay is a "Sign".
        -- Let's stick to the previous Part Size but rotate it? 
        -- Previous Size was 3, 0.1, 3 (Flat pad).
        -- If Rotated -90 on Y, it's still flat.
        -- If Rotated -90 on X? "rotation: 0, -90, 0". That's Y.
        -- Let's respect the Offset.
        
        infoParams.Size = Vector3.new(3, 3, 0.2) -- Making it a vertical board? 
        -- Wait, if it's "0, -90, 0", it's a vertical rotation.
        -- But previously it was a flat pad on the ground.
        -- "Text larger... Gradient".
        -- Let's assume it's a FLOATING SIGN designated by User's requested coords.
        -- Position relative to Slot:
        -- Slot is at `pos`.
        -- We'll use CFrame.new(..., 0.65, ...) relative to slot.
        -- And Rotation -90.
        
        infoParams.CFrame = slot.CFrame * CFrame.new(-3.5, 2.5, 0) * CFrame.Angles(0, math.rad(-90), 0)
        -- Wait, I'm guessing the offset. 
        -- Slot might be at -255.5? 
        -- Delta X: -265.3 - (-255.5) = -9.8.
        -- Delta Z: -104.5 - (-96) = -8.5.
        -- This implies it's "Far" from the slot.
        -- Actually, the user might be placing the sign "Next to" the slot.
        -- I'll stick to a sensible offset: Next to the slot, facing the player?
        -- If user said "rotation 0, -90, 0", let's lock that.
        
        infoParams.CFrame = slot.CFrame * CFrame.new(-4, 2, 0) * CFrame.Angles(0, math.rad(-90), 0) -- Side sign?
        
        -- Override: User's intent for "Infodisplay on the slot".
        -- Let's restore previous "Flat Pad" logic but with NEW color/rotation.
        -- If rotation is -90 Y, and it's flat... it just spins.
        -- Maybe 0.65 Y implies it's slightly higher floating?
        
        -- Let's adhere to "Parsley Green" and Text styles first.
        -- SIDE POSITION: Symmetrical Logic.
        -- We want them on the 'North' side (Global -Z) for visual consistency? 
        -- Or 'Left' of the unit?
        -- If we want them facing the Aisle.
        -- Slot 1 (Left, Faces Right/+X). Left Side is Global -Z.
        -- Slot 2 (Right, Faces Left/-X). Right Side is Global -Z.
        -- So we want them on Local Left (Odd) and Local Right (Even).
        
        local sideX = -3.5
        if col == 1 then sideX = 3.5 end
        
        infoParams.Size = Vector3.new(3, 3, 0.2) -- Vertical Board
        -- Position: Side offset, Higher Y (Center of 3 height = 1.5 + Floor).
        -- Rotation: Inherit Slot Rotation (Faces Aisle).
        infoParams.CFrame = slot.CFrame * CFrame.new(sideX, 2, 0) 
        -- Note: No extra rotation needed if Slot already faces Aisle.
        -- Slot 1 (-90) -> Faces +X. Info faces +X.
        -- Slot 2 (90) -> Faces -X. Info faces -X.
        -- Perfect.
        
        infoParams.Color = Color3.fromRGB(34, 52, 34) -- Parsley Green
        infoParams.Anchored = true
        infoParams.CanCollide = false 
        infoParams.Transparency = 0
        infoParams.Transparency = 0
        infoParams.Material = Enum.Material.Plastic -- User requested Plastic
        infoParams.CastShadow = false
        infoParams.Parent = slot
        
        local cd = Instance.new("ClickDetector")
        cd.Parent = infoParams
        
        local sg = Instance.new("SurfaceGui")
        sg.Face = Enum.NormalId.Front -- Vertical Face
        sg.LightInfluence = 0
        sg.Parent = infoParams
        
        local txn = Instance.new("TextLabel")
        txn.Size = UDim2.new(1,0,1,0)
        txn.Text = "$0"
        txn.TextColor3 = Color3.new(1,1,1) -- White Text base for Gradient
        txn.TextScaled = true
        txn.BackgroundTransparency = 1
        txn.Font = Enum.Font.FredokaOne
        txn.Name = "CashText"
        txn.Parent = sg
        
        -- STYLING
        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 3
        stroke.Color = Color3.fromRGB(0, 0, 0)
        stroke.Parent = txn
        
        local grad = Instance.new("UIGradient")
        grad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 100)), -- Yellow
            ColorSequenceKeypoint.new(1, Color3.fromRGB(85, 255, 85))  -- Green
        })
        grad.Rotation = 90
        grad.Parent = txn
        
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
        
        cd.MouseClick:Connect(triggerCollection)
        
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
                       
                       -- READ MUTATION FROM TOOL ATTRIBUTE (Critical fix for Ramp Units)
                       local toolMutation = tool:GetAttribute("Mutation")
                       
                       if removedUnit then
                             -- Prefer mutation from DataStore (removedUnit), fallback to Tool (fresh ramp unit)
                             local finalMutation = removedUnit.Mutation or toolMutation
                             
                             UnitManager.placeUnit(player, removedUnit.Name, i, removedUnit.Shiny, removedUnit.Level, removedUnit.Id, removedUnit.ValueMultiplier, removedUnit.Tier, removedUnit.Quality, finalMutation)
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
function UnitManager.assignTycoon(player: Player): Model?
    if typhoonOwners[player] then return typhoonOwners[player] end
    
    -- Find empty tycoon
    for _, tycoon in pairs(tycoons) do
        local ownerAttr = tycoon:GetAttribute("Owner")
        if not ownerAttr then
            -- Claim
            tycoon:SetAttribute("Owner", player.Name)
            tycoon:SetAttribute("OwnerUserId", player.UserId)
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
            
            -- Set Rebirth Multiplier
            UnitManager.updateRebirthMultiplier(player)
            
            -- RESTORE SAVED BASE LEVEL + BUILD FLOORS
            local BrainrotData = require(game:GetService("ServerScriptService").BrainrotData)
            local data = BrainrotData.getPlayerSession(player)
            if data and data.BaseLevel and data.BaseLevel > 1 then
                local savedLevel = data.BaseLevel
                tycoon:SetAttribute("BaseLevel", savedLevel)
                print("[UnitManager] Restored BaseLevel " .. savedLevel .. " for " .. player.Name)
                
                -- BUILD MISSING FLOORS
                local FLOOR_HEIGHT = 18
                local slotsFolder = tycoon:FindFirstChild("TycoonSlots")
                local template = UnitManager.ExtraTemplate
                
                if template and slotsFolder then
                    -- Build floors 1 through (savedLevel - 1)
                    for floorIdx = 1, savedLevel - 1 do
                        -- Check if this floor already exists
                        local alreadyBuilt = false
                        for _, child in pairs(slotsFolder:GetChildren()) do
                            if child.Name == "Floor_" .. floorIdx then
                                alreadyBuilt = true
                                break
                            end
                        end
                        
                        if not alreadyBuilt then
                            local yOffset = floorIdx * FLOOR_HEIGHT
                            local fm = UnitManager.setupFloorModel(tycoon, template, floorIdx, yOffset)
                            if fm then
                                -- Setup slots on the new floor
                                for _, child in ipairs(fm:GetChildren()) do
                                    local slotNum = child.Name:match("^Slot_?(%d+)")
                                    if slotNum then
                                        local localIndex = tonumber(slotNum)
                                        local globalID = (floorIdx * 10) + localIndex
                                        child.Name = "Slot_" .. globalID
                                        if slotsFolder then child.Parent = slotsFolder end
                                        
                                        local posPart = child:FindFirstChild("BrainrotSlotPosition")
                                        local infoPart = child:FindFirstChild("infodisplay")
                                        if not posPart then
                                            posPart = child:IsA("BasePart") and child or child:FindFirstChildWhichIsA("BasePart")
                                        end
                                        
                                        if posPart then
                                            local prompt = Instance.new("ProximityPrompt")
                                            prompt.Name = "ConfigurePrompt"
                                            prompt.ActionText = "Deploy Unit"
                                            prompt.ObjectText = "Slot " .. globalID
                                            prompt.RequiresLineOfSight = false
                                            prompt.Parent = posPart
                                            
                                            prompt.Triggered:Connect(function(triggeredPlayer)
                                                if tycoon:GetAttribute("Owner") ~= triggeredPlayer.Name then return end
                                                local isOccupied = child:GetAttribute("Occupied")
                                                if isOccupied then
                                                    UnitManager.removeUnit(triggeredPlayer, globalID)
                                                else
                                                    ReplicatedStorage:WaitForChild("InteractSlot"):FireClient(triggeredPlayer, child, globalID)
                                                end
                                            end)
                                        end
                                        
                                        if infoPart then
                                            local cd = infoPart:FindFirstChildOfClass("ClickDetector") or Instance.new("ClickDetector", infoPart)
                                            local function triggerCollection(colPlayer)
                                                if tycoon:GetAttribute("Owner") == colPlayer.Name then
                                                    UnitManager.collectSlot(colPlayer, child)
                                                end
                                            end
                                            cd.MouseClick:Connect(triggerCollection)
                                            infoPart.Touched:Connect(function(hit)
                                                local p = Players:GetPlayerFromCharacter(hit.Parent)
                                                if p then triggerCollection(p) end
                                            end)
                                        end
                                    end
                                end
                            end
                            print("[UnitManager] Built Floor_" .. floorIdx .. " for restored level")
                        end
                    end
                else
                    warn("[UnitManager] Cannot restore floors - missing template or slotsFolder")
                end
            end
            
            return tycoon
        end
    end
    
    warn("[UnitManager] No Tycoons Available for " .. player.Name)
    return nil
end

function UnitManager.updateRebirthMultiplier(player: Player)
    local tycoon = typhoonOwners[player]
    if not tycoon then return end
    
    local BrainrotData = require(game:GetService("ServerScriptService"):WaitForChild("BrainrotData"))
    local data = BrainrotData.getPlayerSession(player)
    local mult = 1.0
    if data then
         mult = EconomyLogic.calculateRebirthMultiplier(data.Rebirths)
    end
    tycoon:SetAttribute("RebirthMultiplier", mult)
end

function UnitManager.clearTycoon(player: Player)
    local tycoon = typhoonOwners[player]
    if not tycoon then return end
    
    local slotsFolder = tycoon:FindFirstChild("TycoonSlots")
    if not slotsFolder then return end
    
    for _, slot in pairs(slotsFolder:GetChildren()) do
        if slot.Name:find("Slot_") then
            -- Clean Visuals
            local unit = activeUnits[slot]
            if unit then unit:Destroy() end
            activeUnits[slot] = nil
            
            -- Deep Clean
            for _, child in pairs(slot:GetChildren()) do
                 if child.Name == "Unit_Spawned" or child.Name == "UnitModel" or child.Name:find("Placeholder") then
                     child:Destroy()
                 end
            end
            
            -- Reset Attributes
            slot:SetAttribute("Occupied", nil)
            slot:SetAttribute("UnitName", nil)
            slot:SetAttribute("Income", nil)
            
             -- Reset Prompts
            local p = slot:FindFirstChild("ConfigurePrompt")
            if p then p.ActionText = "Deploy Unit" end
             
            local up = slot:FindFirstChild("UpgradePrompt")
            if up then up.Enabled = false end
            
            -- Reset Glow
            if slot:FindFirstChild("GlowPad") then
                 slot.GlowPad.Color = Color3.fromRGB(0, 50, 0)
            end
        end
    end
end

-- 3. UPGRADE BASE FUNCTION
function UnitManager.upgradeBase(player, baseModel)
    if not baseModel then return false, "No Base" end
    
    -- Verify Owner
    if baseModel:GetAttribute("Owner") ~= player.Name then 
        return false, "Not Owner" 
    end
    
    local level = baseModel:GetAttribute("BaseLevel") or 1
    local nextLevel = level + 1
    if nextLevel > 5 then return false, "Max Level" end -- Cap
    
    -- Cost calc (EXTREME TIER)
    local COSTS = {
        [1] = 1e9,    -- 1 Billion (to go to Lvl 2)
        [2] = 1e15,   -- 1 Quadrillion (to go to Lvl 3)
        [3] = 1e21,   -- 1 Sextillion (to go to Lvl 4)
        [4] = 1e27    -- 1 Octillion (to go to Lvl 5)
    }
    local cost = COSTS[level] or 1e33 -- Fallback extreme
    
    -- Check Money
    local BrainrotData = require(game:GetService("ServerScriptService").BrainrotData)
    local profile = BrainrotData.getPlayerSession(player)
    if not profile or profile.Cash < cost then
        return false, "Insufficient Funds"
    end
    
    -- Deduct
    BrainrotData.addCash(player, -cost)
    
    -- Apply Upgrade
    baseModel:SetAttribute("BaseLevel", nextLevel)
    
    -- PERSIST to DataStore
    profile.BaseLevel = nextLevel
    
    -- Add Floor
    local prefabs = ServerStorage:FindFirstChild("BaseBrainrots") or Workspace:FindFirstChild("BaseBrainrots")
    local baseTemplate = prefabs and prefabs:FindFirstChild("BaseBasica")
    local extraTemplate = prefabs and prefabs:FindFirstChild("PisoExtra")
    
    if not baseTemplate or not extraTemplate then
        -- Fallback to cached if available
        baseTemplate = baseTemplate or UnitManager.BaseTemplate
        extraTemplate = extraTemplate or UnitManager.ExtraTemplate
    end
    
    if not baseTemplate or not extraTemplate then
        warn("CRITICAL: Missing 'BaseBasica' or 'PisoExtra' models!")
        return
    end
    
    -- CACHE TEMPLATES GLOBALLY for Upgrader
    UnitManager.BaseTemplate = baseTemplate
    UnitManager.ExtraTemplate = extraTemplate

    local FLOOR_HEIGHT = 18 -- User defined fixed height
    
    -- HELPER: SETUP SLOTS (Local Helper for upgradeBase)
    -- DUPLICATED SLOT LOGIC (Ideally should be shared, but scope issue with local setupSlotsInternal above)
    local function setupSlotsInternal(floorModel, floorIndex, baseModel)
         local Players = game:GetService("Players")
         local slotsFolder = baseModel:FindFirstChild("TycoonSlots")
         for _, child in ipairs(floorModel:GetChildren()) do
            local slotNum = child.Name:match("^Slot_?(%d+)")
            if slotNum then
                local localIndex = tonumber(slotNum)
                local globalID = localIndex
                if floorIndex > 0 then
                    globalID = (floorIndex * 10) + localIndex
                end
                child.Name = "Slot_" .. globalID
                if slotsFolder then child.Parent = slotsFolder end
                
                -- RESTORE STORED CASH VISUALS
                if unitData and unitData.StoredCash and unitData.StoredCash > 0 then
                    local info = child:FindFirstChild("infodisplay")
                    if info and info:FindFirstChild("SurfaceGui") then
                        local cashText = info.SurfaceGui:FindFirstChild("Price") or info.SurfaceGui:FindFirstChildOfClass("TextLabel")
                        if cashText then
                            cashText.Text = "$" .. EconomyLogic.Abbreviate(unitData.StoredCash)
                        end
                    end
                end
                
                -- FIND PARTS
                local posPart = child:FindFirstChild("BrainrotSlotPosition")
                local infoPart = child:FindFirstChild("infodisplay")
                
                if not posPart then
                    posPart = child:IsA("BasePart") and child or child:FindFirstChildWhichIsA("BasePart")
                end
                
                -- SETUP INTERACTION (PROMPT)
                if posPart then
                    local prompt = posPart:FindFirstChild("ConfigurePrompt") or Instance.new("ProximityPrompt")
                    prompt.Name = "ConfigurePrompt"
                    prompt.ActionText = "Deploy Unit"
                    prompt.ObjectText = "Slot " .. globalID
                    prompt.RequiresLineOfSight = false
                    prompt.KeyboardKeyCode = Enum.KeyCode.E
                    prompt.Parent = posPart
                    
                    prompt.Triggered:Connect(function(player)
                        if baseModel:GetAttribute("Owner") ~= player.Name then return end
                        
                        local isOccupied = child:GetAttribute("Occupied")
                        if isOccupied then
                            UnitManager.removeUnit(player, globalID)
                        else
                            game.ReplicatedStorage:WaitForChild("InteractSlot"):FireClient(player, child, globalID)
                        end
                    end)
                end
                
                -- SETUP UI
                if infoPart then
                    local cd = infoPart:FindFirstChildOfClass("ClickDetector") or Instance.new("ClickDetector", infoPart)
                    local function triggerCollection(player)
                        if baseModel:GetAttribute("Owner") == player.Name then
                             UnitManager.collectSlot(player, child)
                        end
                    end
        
                    cd.MouseClick:Connect(triggerCollection)
                    infoPart.Touched:Connect(function(hit)
                         local p = Players:GetPlayerFromCharacter(hit.Parent)
                         if p then triggerCollection(p) end
                    end)
                end
                
                -- STATE VISUALS
                local function updateState()
                    local prompt = posPart and posPart:FindFirstChild("ConfigurePrompt")
                    if prompt then
                        if child:GetAttribute("Occupied") then
                             prompt.ActionText = "Remove Unit"
                        else
                             prompt.ActionText = "Deploy Unit"
                        end
                    end
                end
                child:GetAttributeChangedSignal("Occupied"):Connect(updateState)
                updateState()
            end
        end
    end
    
    local floorIndex = nextLevel - 1
    
    if UnitManager.ExtraTemplate then
        local template = UnitManager.ExtraTemplate
        local yOffset = floorIndex * FLOOR_HEIGHT
        
        -- CALL GLOBAL HELPER
        local fm = UnitManager.setupFloorModel(baseModel, template, floorIndex, yOffset) 
        if fm then setupSlotsInternal(fm, floorIndex, baseModel) end
        end
    

    -- HELPER: SETUP SLOTS (Local Helper for createTycoonSlots)
    local function setupSlotsInternal(floorModel, floorIndex, baseModel)
         local Players = game:GetService("Players")
         for _, child in ipairs(floorModel:GetChildren()) do
            local slotNum = child.Name:match("^Slot_?(%d+)")
            if slotNum then
                local localIndex = tonumber(slotNum)
                local globalID = localIndex
                if floorIndex > 0 then
                    globalID = (floorIndex * 10) + localIndex
                end
                
                child.Name = "Slot_" .. globalID
                
                -- FIND PARTS
                local posPart = child:FindFirstChild("BrainrotSlotPosition")
                local infoPart = child:FindFirstChild("infodisplay")
                
                if not posPart then
                    posPart = child:IsA("BasePart") and child or child:FindFirstChildWhichIsA("BasePart")
                end
                
                -- SETUP INTERACTION (PROMPT)
                if posPart then
                    local prompt = posPart:FindFirstChild("ConfigurePrompt") or Instance.new("ProximityPrompt")
                    prompt.Name = "ConfigurePrompt"
                    prompt.ActionText = "Deploy Unit"
                    prompt.ObjectText = "Slot " .. globalID
                    prompt.RequiresLineOfSight = false
                    prompt.KeyboardKeyCode = Enum.KeyCode.E
                    prompt.Parent = posPart
                    
                    prompt.Triggered:Connect(function(player)
                        if baseModel:GetAttribute("Owner") ~= player.Name then return end
                        
                        local isOccupied = child:GetAttribute("Occupied")
                        if isOccupied then
                            UnitManager.removeUnit(player, globalID)
                        else
                            game.ReplicatedStorage:WaitForChild("InteractSlot"):FireClient(player, child, globalID)
                        end
                    end)
                end
                
                -- SETUP UI
                if infoPart then
                    local cd = infoPart:FindFirstChildOfClass("ClickDetector") or Instance.new("ClickDetector", infoPart)
                    local function triggerCollection(player)
                        if baseModel:GetAttribute("Owner") == player.Name then
                             UnitManager.collectSlot(player, child)
                        end
                    end
        
                    cd.MouseClick:Connect(triggerCollection)
                    infoPart.Touched:Connect(function(hit)
                         local p = Players:GetPlayerFromCharacter(hit.Parent)
                         if p then triggerCollection(p) end
                    end)
                end
                
                -- STATE VISUALS
                local function updateState()
                    local prompt = posPart and posPart:FindFirstChild("ConfigurePrompt")
                    if prompt then
                        if child:GetAttribute("Occupied") then
                             prompt.ActionText = "Remove Unit"
                        else
                             prompt.ActionText = "Deploy Unit"
                        end
                    end
                end
                child:GetAttributeChangedSignal("Occupied"):Connect(updateState)
                updateState()
            end
        end
    end

    -- OLD LOCAL HELPER REPLACED BY NEW GLOBAL METHOD + INTERNAL SLOT SETUP
    local function setupFloorModel(template, floorIndex, yOffset)
         local fm = UnitManager.setupFloorModel(baseModel, template, floorIndex, yOffset) 
         if fm then setupSlotsInternal(fm, floorIndex, baseModel) end
    end
    
    local floorIndex = nextLevel - 1
    
    if UnitManager.ExtraTemplate then
        -- REPLICATION OF SETUP FLOOR LOGIC (Since local function is out of scope)
        -- In a full refactor, 'setupFloorModel' should be a Module function.
        local template = UnitManager.ExtraTemplate
        local yOffset = floorIndex * FLOOR_HEIGHT
        setupFloorModel(template, floorIndex, yOffset)
        
    else
        warn("CRITICAL: Template missing for upgrade")
    end
    
    -- FX
    local upgrader = baseModel:FindFirstChild("BaseUpgrader")
    if upgrader then playUpgradeFX(upgrader) end
    
    return true, "Upgraded to Level " .. nextLevel
end

-- INIT REMOTE
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then 
    remotes = Instance.new("Folder", ReplicatedStorage)
    remotes.Name = "Remotes"
end

local upFunc = remotes:FindFirstChild("UpgradeBaseFunc")
if not upFunc then
    upFunc = Instance.new("RemoteFunction", remotes)
    upFunc.Name = "UpgradeBaseFunc"
end

upFunc.OnServerInvoke = function(player, base)
    return UnitManager.upgradeBase(player, base)
end

-- 3. Remove Unit Logic (Pick Up)
function UnitManager.removeUnit(player: Player, slotIndex: number)
    local BrainrotData = require(game:GetService("ServerScriptService").BrainrotData)
    local tycoon = typhoonOwners[player]
    if not tycoon then return end
    
    local slot = tycoon.TycoonSlots:FindFirstChild("Slot_" .. slotIndex, true)
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
    local mutation = nil
    
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
        mutation = model:GetAttribute("Mutation")
    end
    
    -- Give back to player
    BrainrotData.addUnitAdvanced(player, cleanName, tier, isShiny, false, level, unitId, valueMult, mutation)
    
    -- COLLECT PENDING CASH BEFORE REMOVAL
    local stored = 0
    if model then
        stored = model:GetAttribute("StoredCash") or 0
    end
    if stored > 0 then
        BrainrotData.addCash(player, stored)
        -- print("[UnitManager] Collected $" .. stored .. " from slot " .. slotIndex .. " during removal.")
    end
    
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
    
    -- Reset Prompt
    BrainrotData.setPlacedUnit(player, slotIndex, nil)
    
    -- Reset Prompt
    local prompt = slot:FindFirstChild("ConfigurePrompt")
    if prompt then
        prompt.ActionText = "Deploy Unit"
    end
    
    local upgradePrompt = slot:FindFirstChild("UpgradePrompt", true)
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

-- NEW: Physical Reset for Rebirth
function UnitManager.resetTycoonPhysical(player: Player)
    local tycoon = typhoonOwners[player]
    if not tycoon then return end
    
    local slotsFolder = tycoon:FindFirstChild("TycoonSlots")
    if not slotsFolder then return end
    
    -- 1. Locate all slots
    for _, slot in pairs(slotsFolder:GetDescendants()) do
        if slot:IsA("BasePart") and slot:GetAttribute("Occupied") then
            slot:SetAttribute("Occupied", false)
            slot:SetAttribute("UnitName", nil)
            slot:SetAttribute("Tier", nil)
        end
    end
    
    -- 2. Cleanup activeUnits for this tycoon's slots
    for slot, unit in pairs(activeUnits) do
        if slot:IsDescendantOf(tycoon) then
            if unit then unit:Destroy() end
            activeUnits[slot] = nil
        end
    end
    
    print("[UnitManager] Tycoon physically reset for " .. player.Name)
end

-- 4. Place Unit Logic
function UnitManager.placeUnit(player: Player, unitName: string, slotIndex: number, isShiny: boolean, level: number?, unitId: string?, valueMultiplier: number?, tierOverride: string?, quality: number?, mutationName: string?): boolean
    local tycoon = typhoonOwners[player]
    if not tycoon then 
        warn("Player has no tycoon assigned!") 
        return 
    end
    
    local slotsFolder = tycoon:FindFirstChild("TycoonSlots")
    if not slotsFolder then return end
    
    local slot = slotsFolder:FindFirstChild("Slot_" .. slotIndex, true)
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
        
        MutationManager.applyTierEffects(unit, tier, isShiny, true)
        
        -- ROLL MUTATION (NEW or PERSISTENT)
        local mutation = mutationName
        if not mutation and not unitId then -- Only roll if new unit (no existing ID)
             mutation = MutationManager.rollMutation()
        end
        
        if mutation then
             MutationManager.applyMutation(unit, mutation)
             unit:SetAttribute("Mutation", mutation)
        end
        
        local realLevel = level or 1
        local realValueMultiplier = valueMultiplier or EconomyLogic.generateValueMultiplier()
        local realQuality = quality or 50
        
        -- CALC INCOME
        local qMult = EconomyLogic.getQualityMultiplier(realQuality)
        local rebirths = player:GetAttribute("Rebirths") or 0
        -- Base Income + Boosts
        local baseIncome = EconomyLogic.calculateIncome(unitName, tier, realLevel, isShiny, realValueMultiplier, rebirths, mutation)
        local income = math.floor(baseIncome * qMult)
        
        unit:SetAttribute("Income", income)
        unit:SetAttribute("ValueMultiplier", realValueMult) 
        unit:SetAttribute("Quality", realQuality) 
        unit:SetAttribute("IsShiny", isShiny)
        unit:SetAttribute("Tier", tier)
        unit:SetAttribute("StoredCash", 0) 
        unit:SetAttribute("Owner", player.Name)
        unit:SetAttribute("UnitName", unitName)
        unit:SetAttribute("Level", realLevel)
        unit:SetAttribute("UnitId", unitId) 
        
        CollectionService:AddTag(unit, "BrainrotUnit")
        unit:SetAttribute("TierColor", EconomyLogic.getTierColor(tier))

        -- PIVOT logic for Pre-fab
        local posPart = slot:FindFirstChild("BrainrotSlotPosition")
        local finalTarget = slot:GetPivot() 
        
        local modelCF, modelSize = unit:GetBoundingBox()
        local bottomY = modelCF.Position.Y - (modelSize.Y / 2)
        local pivotOffset = unit:GetPivot().Position.Y - bottomY

        if posPart and posPart:IsA("BasePart") then
            -- SANITIZE ROTATION: Extract only Y-axis rotation to keep unit upright
            local pos = posPart.Position + Vector3.new(0, posPart.Size.Y/2 + pivotOffset, 0)
            local _, yRot, _ = posPart.CFrame:ToEulerAnglesYXZ()
            finalTarget = CFrame.new(pos) * CFrame.Angles(0, yRot + ROTATION_OFFSET, 0)
        else
            -- Legacy fallback
            local slotCF, slotSize = slot:GetPivot(), Vector3.new(5, 1, 5) 
            if slot:IsA("BasePart") then
                slotCF, slotSize = slot.CFrame, slot.Size
            else
                local sCF, sSize = slot:GetBoundingBox()
                slotCF, slotSize = sCF, sSize
            end
            
            -- SANITIZE ROTATION
            local pos = slotCF.Position + Vector3.new(0, slotSize.Y/2 + pivotOffset, 0)
            local _, yRot, _ = slotCF:ToEulerAnglesYXZ()
            finalTarget = CFrame.new(pos) * CFrame.Angles(0, yRot + ROTATION_OFFSET, 0)
        end
        
        unit:PivotTo(finalTarget)
        unit.Parent = slot
        
        for _, v in pairs(unit:GetDescendants()) do
            if v:IsA("BasePart") then
                v.Anchored = true
                v.CanCollide = false 
            end
        end
        
        slot:SetAttribute("Occupied", true)
        slot:SetAttribute("UnitName", unitName) 
        
        local prompt = (posPart and posPart:FindFirstChild("ConfigurePrompt")) or slot:FindFirstChild("ConfigurePrompt")
        if prompt then
            prompt.ActionText = "Pick Up"
        end
        
        -- Shiny Particles (POLISHED)
        -- ... (no changes to particles)
        if isShiny then
             local sparkles = Instance.new("ParticleEmitter")
             sparkles.Name = "ShinySparkles"
             sparkles.Texture = "rbxassetid://243098098" 
             sparkles.Color = ColorSequence.new({
                 ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 200)),
                 ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 0)), -- Gold center
                 ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))
             }) 
             sparkles.Size = NumberSequence.new(0.4, 0)
             sparkles.Lifetime = NumberRange.new(0.5, 1.0)
             sparkles.Rate = 10
             sparkles.Speed = NumberRange.new(2, 4)
             sparkles.SpreadAngle = Vector2.new(360, 360)
             sparkles.Acceleration = Vector3.new(0, 2, 0) -- Float up
             sparkles.LightEmission = 0.8 -- Glowing effect
             sparkles.Parent = unit.PrimaryPart or unit:FindFirstChildWhichIsA("BasePart")
             
             -- Add subtle light
             local sl = Instance.new("PointLight")
             sl.Color = Color3.fromRGB(255, 255, 200)
             sl.Range = 8
             sl.Brightness = 1
             sl.Parent = sparkles.Parent
        end
        
        activeUnits[slot] = unit
        
        local BrainrotData = require(game:GetService("ServerScriptService"):WaitForChild("BrainrotData"))
        BrainrotData.setPlacedUnit(player, slotIndex, unitName, isShiny, unitId, realLevel, realValueMultiplier, tier, mutation, unit:GetAttribute("StoredCash"))
        
        -- Upgrade Prompt
        local upgradePrompt = slot:FindFirstChild("UpgradePrompt") or (posPart and posPart:FindFirstChild("UpgradePrompt"))
        if not upgradePrompt then
             upgradePrompt = Instance.new("ProximityPrompt")
             upgradePrompt.Name = "UpgradePrompt"
             upgradePrompt.KeyboardKeyCode = Enum.KeyCode.F
             upgradePrompt.RequiresLineOfSight = false
             upgradePrompt.UIOffset = Vector2.new(0, -70)
             upgradePrompt.Parent = posPart or slot
             
                 upgradePrompt.Triggered:Connect(function(triggerPlayer)
                 local tycoon = typhoonOwners[triggerPlayer]
                 -- FIX: Robust check (IsDescendantOf) instead of fragile .Parent.Parent
                 if not tycoon or not slot:IsDescendantOf(tycoon) then
                      return 
                 end
                 
                 local u = activeUnits[slot]
                 if u then
                      local BrainrotData = require(game:GetService("ServerScriptService").BrainrotData)
                      local uId = u:GetAttribute("UnitId")
                      local success, newLevel, msg = BrainrotData.upgradeUnitLevel(triggerPlayer, uId)
                      if success then
                           -- playUpgradeFX(u) -- This line is NOT in the provided snippet, so I will NOT add it.
                           
                           local sfx = Instance.new("Sound")
                           sfx.SoundId = "rbxassetid://2865227271" 
                           sfx.Parent = slot
                           sfx:Play()
                           Debris:AddItem(sfx, 1)
                          
                          local t = u:GetAttribute("Tier") or "Common"
                          local s = u:GetAttribute("IsShiny") or false
                          local v = u:GetAttribute("ValueMultiplier") or 1.0
                          local n = u:GetAttribute("UnitName")
                          local rebirths = triggerPlayer:GetAttribute("Rebirths") or 0
                          local mutation = u:GetAttribute("Mutation")
                          local inc = EconomyLogic.calculateIncome(n, t, newLevel, s, v, rebirths, mutation)
                          
                          u:SetAttribute("Level", newLevel)
                          u:SetAttribute("Income", inc)
                          
                          local cost = EconomyLogic.calculateUpgradeCost(t, newLevel)
                          upgradePrompt.ActionText = "Subir Nivel ($" .. EconomyLogic.Abbreviate(cost) .. ")"
                     else
                          local sfx = Instance.new("Sound")
                          sfx.SoundId = "rbxassetid://4590662766" -- Valid error buzz
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
        return true
    end
end

-- Collection Logic
function UnitManager.collectSlot(player: Player, slot: Instance)
    local unit = activeUnits[slot]
    if not unit then return end
    
    if unit:GetAttribute("Owner") ~= player.Name then return end
    
    local stored = unit:GetAttribute("StoredCash") or 0
    if stored > 0 then
        local BrainrotData = require(game:GetService("ServerScriptService").BrainrotData)
        BrainrotData.addCash(player, stored)
        unit:SetAttribute("StoredCash", 0)
        
        -- Update Data Session
        local slotIndex = tonumber(slot.Name:match("%d+"))
        if slotIndex then
            local pUnits = BrainrotData.getPlacedUnits(player)
            local unitData = pUnits[tostring(slotIndex)]
            if unitData then
                unitData.StoredCash = 0
            end
        end
        
        local info = slot:FindFirstChild("infodisplay")
         if info and info:FindFirstChild("SurfaceGui") then
            local priceLabel = info.SurfaceGui:FindFirstChild("Price") or info.SurfaceGui:FindFirstChildOfClass("TextLabel")
            if priceLabel then
                priceLabel.Text = "$0"
            end
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
                    
                    -- Rebirth Multiplier Lookup (Tycoon -> TycoonSlots -> Slot -> Unit)
                    -- Unit.Parent = Slot. Slot.Parent = TycoonSlots. TycoonSlots.Parent = Tycoon
                    local function getTy()
                         if unit.Parent and unit.Parent.Parent and unit.Parent.Parent.Parent then
                             return unit.Parent.Parent.Parent
                         end
                         return nil
                    end
                    local ty = getTy()
                    local rMult = ty and ty:GetAttribute("RebirthMultiplier") or 1.0
                    
                    -- BOOSTS (New)
                    local ownerName = unit:GetAttribute("Owner")
                    local rebirths = 0
                    local boostMult = 1.0
                    if ownerName then
                         local p = Players:FindFirstChild(ownerName)
                         if p then
                             local BrainrotData = require(game:GetService("ServerScriptService").BrainrotData)
                             rebirths = p:GetAttribute("Rebirths") or 0
                             boostMult = BrainrotData.getMultiplier(p, "Cash")
                         end
                    end
                    
                    local effectiveIncome = inc * UnitManager.GLOBAL_MULTIPLIER * boostMult
                    -- Note: Rebirth multiplier is ALREADY baked into 'inc' in placeUnit and upgradeUnitLevel.
                    -- But if old units were placed before a rebirth, they might need refreshing.
                    -- Actually, Rebirth RESETS tycoon, so all units are fresh after rebirth.
                    
                    local newTotal = current + effectiveIncome
                    unit:SetAttribute("StoredCash", newTotal)
                    
                    local info = slot:FindFirstChild("infodisplay")
                    if info and info:FindFirstChild("SurfaceGui") then
                        local cashText = info.SurfaceGui:FindFirstChild("Price") or info.SurfaceGui:FindFirstChildOfClass("TextLabel")
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
function UnitManager.restoreTycoon(player: Player)
    local BrainrotData = require(game:GetService("ServerScriptService").BrainrotData)
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
    
    -- Count slots
    local count = 0
    for _ in pairs(savedSlots) do count += 1 end
    -- print("[UnitManager] Restoring " .. count .. " Tycoon Units for " .. player.Name)
    local slotsFolder = tycoon:FindFirstChild("TycoonSlots")
    if not slotsFolder then return end

    for slotIdxStr, unitData in pairs(savedSlots) do
        local idx = tonumber(slotIdxStr)
        if idx then
            -- Note: placeUnit will use unitData.StoredCash if we pass it
            UnitManager.placeUnit(player, unitData.Name, idx, unitData.Shiny or false, unitData.Level, unitData.UnitId, unitData.ValueMultiplier, unitData.Tier, nil, unitData.Mutation)
            
            -- Set the restored StoredCash attribute
            local slot = slotsFolder:FindFirstChild("Slot_" .. idx, true)
            if slot then
                local unitModel = activeUnits[slot]
                if unitModel then
                    unitModel:SetAttribute("StoredCash", unitData.StoredCash or 0)
                end
            end
        end
    end
    
    -- 4. Calculate Offline Earnings
    UnitManager.calculateOfflineEarnings(player)
end

function UnitManager.syncAllStoredCash(player: Player)
    local tycoon = typhoonOwners[player]
    if not tycoon then return end
    
    local BrainrotData = require(game:GetService("ServerScriptService").BrainrotData)
    local savedSlots = BrainrotData.getPlacedUnits(player)
    
    for slot, unitModel in pairs(activeUnits) do
        if unitModel and unitModel.Parent and slot:IsDescendantOf(tycoon) then
            local slotIdx = tonumber(slot.Name:match("%d+"))
            if slotIdx then
                local unitData = savedSlots[tostring(slotIdx)]
                if unitData then
                    unitData.StoredCash = unitModel:GetAttribute("StoredCash") or 0
                end
            end
        end
    end
end

function UnitManager.calculateOfflineEarnings(player: Player)
    local BrainrotData = require(game:GetService("ServerScriptService").BrainrotData)
    local data = BrainrotData.getPlayerSession(player)
    if not data or not data.PlacedUnits or not data.LastPlaytime or data.LastPlaytime == 0 then return end
    
    local now = os.time()
    local awayTime = now - data.LastPlaytime
    
    print("[UnitManager:Offline] Checking for " .. player.Name .. ": Needs > 30s. Actual: " .. awayTime .. "s. LastPlaytime: " .. data.LastPlaytime)
    
    if awayTime < 30 then 
        -- print("[UnitManager:Offline] Not away long enough.")
        return 
    end -- Minimum 30s away for offline earnings (Testing Mode)
    
    -- Limit offline earnings to e.g. 24 hours to prevent extreme inflation
    local MAX_AWAY = 24 * 3600
    if awayTime > MAX_AWAY then awayTime = MAX_AWAY end
    
    local totalIncome = 0
    for _, unitData in pairs(data.PlacedUnits) do
        local income = EconomyLogic.calculateIncome(
            unitData.Name, 
            unitData.Tier or "Common", 
            unitData.Level or 1, 
            unitData.Shiny or false, 
            unitData.ValueMultiplier or 1.0,
            data.Rebirths or 0,
            unitData.Mutation
        )
        totalIncome += income
    end
    
    local earnings = math.floor(totalIncome * awayTime)
    
    print("[UnitManager:Offline] Earnings Calc: TotalIncome=" .. totalIncome .. ", Earnings=" .. earnings)
    
    if totalIncome <= 0 then return end
    
    -- Store pending earnings in a temporary cache (server-side security)
    if not UnitManager.PendingEarnings then UnitManager.PendingEarnings = {} end
    UnitManager.PendingEarnings[player] = {Amount = earnings, Time = awayTime}
    
    -- Notification Logic (Prompt Client)
    task.spawn(function()
        local remote = ReplicatedStorage:FindFirstChild("NotifyOfflineEarnings")
        if not remote then
            remote = Instance.new("RemoteEvent", ReplicatedStorage)
            remote.Name = "NotifyOfflineEarnings"
        end
        remote:FireClient(player, earnings, awayTime)
        
        
        -- Debug: Print confirm
        print("[UnitManager] Sent offline earnings prompt to", player.Name)
    end)
    
    print(string.format("[UnitManager] %s has $%s pending offline earnings (%d sec). Prompting...", player.Name, EconomyLogic.Abbreviate(earnings), awayTime))
end


-- Init
function UnitManager.Init()
    if initialized then return end
    initialized = true
    
    startLoop()
    
    -- Remote Management for Manual Placement
    local placeFunc = ReplicatedStorage:WaitForChild("PlaceUnit", 5)
    
    -- Ensure Offline Earnings Remotes exist EARLY
    if not ReplicatedStorage:FindFirstChild("NotifyOfflineEarnings") then
        local re = Instance.new("RemoteEvent", ReplicatedStorage)
        re.Name = "NotifyOfflineEarnings"
    end
    -- ResolveOfflineEarnings Handler
    local resolveFunc = ReplicatedStorage:FindFirstChild("ResolveOfflineEarnings")
    if not resolveFunc then
        resolveFunc = Instance.new("RemoteFunction", ReplicatedStorage)
        resolveFunc.Name = "ResolveOfflineEarnings"
    end
    
    resolveFunc.OnServerInvoke = function(plr, choice)
        local BrainrotData = require(game:GetService("ServerScriptService").BrainrotData)
        print("[UnitManager] ResolveOfflineEarnings Invoked by", plr.Name, "Choice:", choice)
        local pending = UnitManager.PendingEarnings and UnitManager.PendingEarnings[plr]
        
        if not pending then 
            print("[UnitManager] ERROR: No pending earnings found for", plr.Name)
             if UnitManager.PendingEarnings then
                for k,v in pairs(UnitManager.PendingEarnings) do
                     print(" - Pending for:", k.Name, v)
                end
            else
                print(" - PendingEarnings table is nil")
            end
            return false 
        end
        
        UnitManager.PendingEarnings[plr] = nil -- Consume
        print("[UnitManager] Processing pending amount:", pending.Amount)
        
        if choice == "Collect" then
            BrainrotData.addCash(plr, pending.Amount)
            return true
        elseif choice == "ToSlots" then
            -- Distribute to slots
            local tycoon = typhoonOwners[plr]
            if tycoon then
                local slotsFolder = tycoon:FindFirstChild("TycoonSlots")
                if slotsFolder then
                     -- Simple strategy: Split evenly among active slots
                     local activeCount = 0
                     local targets = {}
                     for slot, unit in pairs(activeUnits) do
                         if unit.Parent and slot:IsDescendantOf(tycoon) then
                             activeCount += 1
                             table.insert(targets, unit)
                         end
                     end
                     
                     if activeCount > 0 then
                         local perSlot = math.floor(pending.Amount / activeCount)
                         for _, u in ipairs(targets) do
                             local cur = u:GetAttribute("StoredCash") or 0
                             u:SetAttribute("StoredCash", cur + perSlot)
                         end
                     else
                         -- Fallback if no slots active? Give to wallet.
                         BrainrotData.addCash(plr, pending.Amount)
                     end
                end
            end
            return true
        end
        return false
    end
    
    if placeFunc then
        placeFunc.OnServerInvoke = function(player, slotId, unitId)
              -- print("[UnitManager] OnServerInvoke PlaceUnit: Player=" .. player.Name .. ", Slot=" .. tostring(slotId) .. ", Unit=" .. tostring(unitId))
              -- 1. Check if slot is occupied
              local tycoon = typhoonOwners[player]
              if tycoon then
                  local slotsFolder = tycoon:FindFirstChild("TycoonSlots")
                  local slot = slotsFolder and (slotsFolder:FindFirstChild("Slot_" .. slotId, true) or slotsFolder:FindFirstChild("Slot" .. slotId, true))
                  if slot and slot:GetAttribute("Occupied") then
                      print("[UnitManager] Placement FAILED: Slot " .. tostring(slotId) .. " occupied.")
                      return false, "Slot is already occupied!"
                  end
                  if not slot then
                      print("[UnitManager] Placement FAILED: Slot_" .. tostring(slotId) .. " NOT FOUND in " .. tycoon.Name)
                  end
              else
                  print("[UnitManager] Placement FAILED: No tycoon for player " .. player.Name)
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
                  local name = tool.Name
                  local tier = tool:GetAttribute("Tier") or "Common"
                  local isShiny = tool:GetAttribute("IsShiny") or false
                  local mutation = tool:GetAttribute("Mutation") -- READ MUTATION
                  
                  local BrainrotData = require(game:GetService("ServerScriptService").BrainrotData)
                  if isSecured then
                      local unitData = BrainrotData.removeUnit(player, tool:GetAttribute("UnitId") or name)
                      if unitData then
                          -- Prefer mutation from DataStore, fallback to tool
                          local finalMutation = unitData.Mutation or mutation
                          UnitManager.placeUnit(player, unitData.Name, slotId, unitData.Shiny, unitData.Level, unitData.Id, unitData.ValueMultiplier, unitData.Tier, unitData.Quality, finalMutation)
                          tool:Destroy()
                          return true
                      end
                  else
                      -- Loot/Temp
                      local valueMult = tool:GetAttribute("ValueMultiplier") or nil
                      local lvl = tool:GetAttribute("Level") or 1
                      BrainrotData.markDiscovered(player, name, tier, isShiny)
                      UnitManager.placeUnit(player, name, slotId, isShiny, lvl, nil, valueMult, tier, nil, mutation)
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
    local function onPlayerAdded(p: Player)
         if not playerMaids[p] then
             playerMaids[p] = Maid.new()
         end
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

    Players.PlayerRemoving:Connect(function(p: Player)
        if playerMaids[p] then
            playerMaids[p]:Destroy()
            playerMaids[p] = nil
        end
    end)
    
    Players.PlayerAdded:Connect(onPlayerAdded)
    for _, p in pairs(Players:GetPlayers()) do
         task.spawn(function() onPlayerAdded(p) end)
    end
    
    print("[UnitManager] Initialized Module")
end

function UnitManager.clearAllSlots(player: Player)
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
    -- print(string.format("[UnitManager] Cleared %d placed units for %s", clearedCount, player.Name))
end

return UnitManager
