-- GameManager.server.lua
-- Skill: game-loop-management
-- Description: Manages the Speed Corridor Loop. Spawns enemies locally based on player Zones.
-- UPDATED: Removed Skibidi functionality (Legacy)

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local BrainrotData = require(game:GetService("ServerScriptService").BrainrotData)
local EconomyLogic = require(game:GetService("ReplicatedStorage").Modules:WaitForChild("EconomyLogic"))
local MutationManager = require(game:GetService("ReplicatedStorage").Modules:WaitForChild("MutationManager"))

-- CONFIG (Updated for Short Zones)
local ZONE_1_END = 180
local ZONE_2_END = 360
local ZONE_3_START = 390

local SPAWN_RATE = 0.5 
local MAX_UNITS = 20 -- Maximum brainrots in world at once
local activeUnits = 0 -- Current count

-- INCOME CONFIG (Mirrored from UnitManager for separate calculation)
local TIER_CONFIG = {
    -- Standard Tiers (10x progression)
    ["Common"] = {Base = 5, Var = 5},                    -- $5 - $10/s
    ["Rare"] = {Base = 50, Var = 25},                    -- $50 - $75/s
    ["Epic"] = {Base = 500, Var = 250},                  -- $500 - $750/s
    ["Legendary"] = {Base = 5000, Var = 2500},           -- $5k - $7.5k/s
    ["Mythic"] = {Base = 50000, Var = 25000},            -- $50k - $75k/s
    
    -- SUPREME TIERS (100x progression each!) 
    ["Divine"] = {Base = 5000000, Var = 2500000},        -- $5M - $7.5M/s
    ["Celestial"] = {Base = 500000000, Var = 250000000}, -- $500M - $750M/s
    ["Cosmic"] = {Base = 50000000000, Var = 25000000000}, -- $50B - $75B/s
    ["Eternal"] = {Base = 5000000000000, Var = 2500000000000}, -- $5T - $7.5T/s
    ["Transcendent"] = {Base = 500000000000000, Var = 250000000000000}, -- $500T - $750T/s
    ["Infinite"] = {Base = 50000000000000000, Var = 25000000000000000}, -- $50Qd - $75Qd/s
}

-- Color Palette
local RARITY_COLORS = {
    -- Standard
    ["Common"] = Color3.fromRGB(200, 200, 200),      -- Gray
    ["Rare"] = Color3.fromRGB(0, 170, 255),          -- Blue
    ["Epic"] = Color3.fromRGB(170, 0, 255),          -- Purple
    ["Legendary"] = Color3.fromRGB(255, 170, 0),     -- Orange
    ["Mythic"] = Color3.fromRGB(255, 0, 85),         -- Red/Pink
    
    -- SUPREME (Special vibrant colors)
    ["Divine"] = Color3.fromRGB(255, 255, 100),      -- Golden Yellow (Holy)
    ["Celestial"] = Color3.fromRGB(100, 255, 255),   -- Cyan (Sky)
    ["Cosmic"] = Color3.fromRGB(200, 100, 255),      -- Violet (Space)
    ["Eternal"] = Color3.fromRGB(255, 255, 255),     -- Pure White (Timeless)
    ["Transcendent"] = Color3.fromRGB(255, 100, 200),-- Pink/Magenta (Beyond)
    ["Infinite"] = Color3.fromRGB(50, 255, 150),     -- Bright Green (Unlimited)
}

-- HELPERS
-- HELPERS
local function Abbreviate(n)
    -- Full suffix list for simulator games
    local suffixes = {
        "K",   -- Thousand (10^3)
        "M",   -- Million (10^6)
        "B",   -- Billion (10^9)
        "T",   -- Trillion (10^12)
        "Qd",  -- Quadrillion (10^15)
        "Qn",  -- Quintillion (10^18)
        "Sx",  -- Sextillion (10^21)
        "Sp",  -- Septillion (10^24)
        "Oc",  -- Octillion (10^27)
        "No",  -- Nonillion (10^30)
        "Dc",  -- Decillion (10^33)
        "Ud",  -- Undecillion (10^36)
        "Dd",  -- Duodecillion (10^39)
        "Td",  -- Tredecillion (10^42)
        "Qtd", -- Quattuordecillion (10^45)
        "Qnd", -- Quindecillion (10^48)
        "Sxd", -- Sexdecillion (10^51)
        "Spd", -- Septendecillion (10^54)
        "Ocd", -- Octodecillion (10^57)
        "Nod", -- Novemdecillion (10^60)
        "Vg",  -- Vigintillion (10^63)
    }
    for i = #suffixes, 1, -1 do
        local v = math.pow(10, i * 3)
        if n >= v then
            return string.format("%.1f%s", n / v, suffixes[i])
        end
    end
    return tostring(math.floor(n))
end

local function calculateDeterministicIncome(name, tier, level)
    -- Unified with UnitManager/EconomyLogic
    return EconomyLogic.calculateIncome(name, tier, level or 1, false) -- Assuming pickup is not shiny for calc or handled elsewhere
end

-- Update Status UI
local statusVal = ReplicatedStorage:FindFirstChild("Status") or Instance.new("StringValue", ReplicatedStorage)
statusVal.Name = "Status"

local function setStatus(text)
    statusVal.Value = text
end

-- SPAWN LOGIC
local function spawnCoinAt(pos)
    local coin = Instance.new("Part")
    coin.Name = "RiskCoin"
    coin.Size = Vector3.new(3, 3, 0.5)
    coin.Shape = Enum.PartType.Cylinder
    coin.Color = Color3.fromRGB(255, 215, 0) -- Gold
    coin.Material = Enum.Material.Neon
    coin.Position = pos + Vector3.new(0, 3, 0)
    coin.Orientation = Vector3.new(0, 0, 90)
    coin.Anchored = false
    coin.CanCollide = false
    coin.Parent = workspace
    
    -- Visual Spin
    local at = Instance.new("Attachment", coin)
    local torque = Instance.new("Torque", coin)
    torque.Torque = Vector3.new(0, 500, 0)
    torque.Attachment0 = at
    
    local collected = false
    coin.Touched:Connect(function(hit)
        if collected then return end
        local player = Players:GetPlayerFromCharacter(hit.Parent)
        if player then
            collected = true
            coin:Destroy()
            
            BrainrotData.addCash(player, 500) -- Updated Reward
            
            local sfx = Instance.new("Sound")
            sfx.SoundId = "rbxasset://sounds/electronicpingshort.wav"
            sfx.Parent = hit.Parent:FindFirstChild("Head") or hit.Parent
            sfx:Play()
            Debris:AddItem(sfx, 1)
        end
    end)
    Debris:AddItem(coin, 10)
end

local function spawnRockAt(pos)
    -- Try to find the template in ServerStorage first, then Workspace
    local rockTemplate = ServerStorage:FindFirstChild("RockTemplate")
    
    if not rockTemplate then
        local wsRock = workspace:FindFirstChild("Rock")
        if wsRock then
            wsRock.Name = "RockTemplate"
            wsRock.Parent = ServerStorage
            rockTemplate = wsRock
            print("[GameManager] Found 'Rock' in Workspace, moved to ServerStorage as template.")
        end
    end
    
    local rock = nil
    if rockTemplate then
        rock = rockTemplate:Clone()
        rock.Name = "FallingRock"
        
        -- Setup physics for model
        for _, p in pairs(rock:GetDescendants()) do
            if p:IsA("BasePart") then
                p.Anchored = false
                p.CanCollide = true
                -- Add some chaotic initial rotation and velocity to avoid perfect rolling
                p.AssemblyLinearVelocity = Vector3.new(math.random(-10, 10), -60, math.random(-10, 10))
                p.AssemblyAngularVelocity = Vector3.new(math.random(-5, 5), math.random(-5, 5), math.random(-5, 5))
                
                -- Irregular Physical Properties (High friction, low elasticity for "rock" feel)
                p.CustomPhysicalProperties = PhysicalProperties.new(1.5, 0.7, 0.1, 1, 1) -- Density, Friction, Elasticity, etc.
            end
        end
        
        local initialPos = pos + Vector3.new(0, 100, math.random(-10, 10))
        if rock.PrimaryPart then
            rock:SetPrimaryPartCFrame(CFrame.new(initialPos) * CFrame.Angles(math.rad(math.random(360)), math.rad(math.random(360)), math.rad(math.random(360))))
        else
            local p = rock:FindFirstChildWhichIsA("BasePart", true)
            if p then 
                p.CFrame = CFrame.new(initialPos) * CFrame.Angles(math.rad(math.random(360)), math.rad(math.random(360)), math.rad(math.random(360)))
            end
        end
    else
        -- Fallback Part if model not found
        rock = Instance.new("Part")
        rock.Name = "FallingRock"
        rock.Size = Vector3.new(6, 6, 6)
        rock.Shape = Enum.PartType.Ball
        rock.Color = Color3.fromRGB(50, 50, 50)
        rock.Material = Enum.Material.Slate
        rock.Position = pos + Vector3.new(0, 100, 0)
        rock.Anchored = false
        rock.CustomPhysicalProperties = PhysicalProperties.new(2, 0.8, 0.1)
    end
    
    rock.Parent = workspace
    
    -- Damage Logic
    local function applyDamage(hit)
        if not hit or not hit.Parent then return end
        local hum = hit.Parent:FindFirstChild("Humanoid")
        if hum then
            local velocity = 0
            if rock:IsA("Model") and rock.PrimaryPart then
                velocity = rock.PrimaryPart.AssemblyLinearVelocity.Magnitude
            elseif rock:IsA("BasePart") then
                velocity = rock.AssemblyLinearVelocity.Magnitude
            end
            
            if velocity > 20 then
                 hum:TakeDamage(40)
                 -- Play hit sound
                 local sfx = Instance.new("Sound")
                 sfx.SoundId = "rbxassetid://566593606"
                 sfx.Parent = hit.Parent:FindFirstChild("Head") or hit.Parent
                 sfx:Play()
                 Debris:AddItem(sfx, 1)
            end
        end
    end

    if rock:IsA("Model") then
        for _, p in pairs(rock:GetDescendants()) do
            if p:IsA("BasePart") then p.Touched:Connect(applyDamage) end
        end
    else
        rock.Touched:Connect(applyDamage)
    end
    
    Debris:AddItem(rock, 12) -- Longer life to see it tumble down
end

local function getUnitsFromTiers(tierNames)
    local root = ServerStorage:FindFirstChild("BrainrotModels")
    if not root then return {} end
    
    local pool = {}
    for _, tName in ipairs(tierNames) do
        local f = root:FindFirstChild(tName)
        if f then
            for _, child in pairs(f:GetChildren()) do
                if child:IsA("Model") then table.insert(pool, child) end
            end
        end
    end
    return pool
end

local function spawnUnitCapsule(pos, tier)
    activeUnits += 1
    
    local targetTiers = {tier}
    local unitPool = getUnitsFromTiers(targetTiers)
    
    -- Fallback if specific tier folder is empty
    if #unitPool == 0 then 
        unitPool = getUnitsFromTiers({"Common", "Rare"}) 
    end
    
    if #unitPool == 0 then
        -- Last resort fallback to first found unit if possible
        local root = ServerStorage:FindFirstChild("BrainrotModels")
        if root then unitPool = getUnitsFromTiers({"Common", "Rare", "Epic", "Legendary", "Mythic"}) end
    end

    if #unitPool == 0 then return end -- Give up
    
    local modelTemplate = unitPool[math.random(1, #unitPool)]
    local chosen = modelTemplate.Name
    local realTier = modelTemplate.Parent and modelTemplate.Parent.Name or tier
    local isSpecial = (realTier ~= "Common")
    
    -- GENERATE VALUE MULTIPLIER AT SPAWN
    local valueMult = EconomyLogic.generateValueMultiplier()
    local level = math.random(1, 150)
    local mutationName = MutationManager.rollMutation()

    local spawnedItem = modelTemplate:Clone()
    
    -- Setup PrimaryPart for positioning
    if not spawnedItem.PrimaryPart then
        local p = spawnedItem:FindFirstChildWhichIsA("BasePart")
        if p then spawnedItem.PrimaryPart = p end
    end
    
    local hitbox = nil
    if spawnedItem.PrimaryPart then
        -- Fix Floor Clipping: Get Height
        local size = spawnedItem:GetExtentsSize()
        local heightOffset = size.Y / 2
        spawnedItem:SetPrimaryPartCFrame(CFrame.new(pos.X, pos.Y + 0.5 + heightOffset, pos.Z))
    else
        spawnedItem:Destroy()
        return -- Abort if bad model
    end
        
        -- HITBOX (For easier collection)
        hitbox = Instance.new("Part")
        hitbox.Name = "Hitbox"
        hitbox.Size = Vector3.new(4, 4, 4)
        hitbox.Transparency = 1
        hitbox.CanCollide = false
        hitbox.Anchored = true
        hitbox.CFrame = spawnedItem.PrimaryPart.CFrame
        hitbox.Parent = spawnedItem
        
        -- Anchor Visuals
        for _, v in pairs(spawnedItem:GetDescendants()) do
            if v:IsA("BasePart") then 
                v.Anchored = true 
                v.CanCollide = false 
            end
        end
    
    spawnedItem.Parent = workspace
    
    -- Apply Mutation Visuals (if any)
    if mutationName then
        MutationManager.applyMutation(spawnedItem, mutationName)
    end
    
    -- Visual Label Premium Design
    local realTier = "Common" 
    if modelTemplate and modelTemplate.Parent and RARITY_COLORS[modelTemplate.Parent.Name] then
        realTier = modelTemplate.Parent.Name
    else
        realTier = tier
    end
    
    local tierColor = RARITY_COLORS[realTier] or RARITY_COLORS["Common"]
    -- Calculate income WITH the generated valueMultiplier
    local baseIncome = calculateDeterministicIncome(chosen, realTier, level)
    local estIncome = math.floor(baseIncome * valueMult)
    
    -- Store valueMult in hitbox so tool creation can read it
    hitbox:SetAttribute("ValueMultiplier", valueMult)
    hitbox:SetAttribute("Tier", realTier)
    -- Store valueMult in hitbox so tool creation can read it
    hitbox:SetAttribute("ValueMultiplier", valueMult)
    hitbox:SetAttribute("Tier", realTier)
    hitbox:SetAttribute("Level", level)
    if mutationName then
        hitbox:SetAttribute("Mutation", mutationName)
    end
    
    -- SUPREME TIER VISUAL EFFECTS
    local SUPREME_TIERS = {
        ["Divine"] = true, ["Celestial"] = true, ["Cosmic"] = true,
        ["Eternal"] = true, ["Transcendent"] = true, ["Infinite"] = true
    }
    
    if SUPREME_TIERS[realTier] and hitbox then
        -- Glowing Light Effect
        local light = Instance.new("PointLight")
        light.Color = tierColor
        light.Brightness = 3
        light.Range = 20
        light.Parent = hitbox
        
        -- Particle Emitter (Sparkles)
        local particles = Instance.new("ParticleEmitter")
        particles.Color = ColorSequence.new(tierColor)
        particles.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.5),
            NumberSequenceKeypoint.new(0.5, 1),
            NumberSequenceKeypoint.new(1, 0)
        })
        particles.Lifetime = NumberRange.new(0.5, 1.5)
        particles.Rate = 30
        particles.Speed = NumberRange.new(2, 5)
        particles.SpreadAngle = Vector2.new(180, 180)
        particles.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.3),
            NumberSequenceKeypoint.new(1, 1)
        })
        particles.LightEmission = 1
        particles.Parent = hitbox
        
        -- Special effects per tier
        if realTier == "Divine" then
            particles.Texture = "rbxassetid://243098098" -- Star sparkle
            particles.Rate = 50
        elseif realTier == "Celestial" then
            particles.Texture = "rbxassetid://243098098"
            light.Brightness = 5
        elseif realTier == "Cosmic" then
            particles.Texture = "rbxassetid://243098098"
            particles.RotSpeed = NumberRange.new(100, 200)
            particles.Rate = 60
        elseif realTier == "Eternal" then
            light.Brightness = 8
            particles.Rate = 80
            particles.Speed = NumberRange.new(0.5, 2)
        elseif realTier == "Transcendent" then
            particles.Rate = 100
            light.Range = 30
            
            -- Second particle layer
            local p2 = particles:Clone()
            p2.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
            p2.Size = NumberSequence.new(0.2, 0.5)
            p2.Parent = hitbox
        elseif realTier == "Infinite" then
            light.Brightness = 15
            light.Range = 40
            particles.Rate = 150
            particles.Speed = NumberRange.new(5, 10)
            
            -- Rainbow effect
            local colors = {
                Color3.fromRGB(255, 0, 0), Color3.fromRGB(255, 165, 0),
                Color3.fromRGB(255, 255, 0), Color3.fromRGB(0, 255, 0),
                Color3.fromRGB(0, 255, 255), Color3.fromRGB(255, 0, 255)
            }
            task.spawn(function()
                local i = 1
                while hitbox and hitbox.Parent do
                    light.Color = colors[i]
                    i = (i % #colors) + 1
                    task.wait(0.2)
                end
            end)
        end
    end
    
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(8, 0, 4.5, 0) -- Generous canvas
    bb.StudsOffset = Vector3.new(0, 5.5, 0) -- High clearance
    bb.AlwaysOnTop = true
    bb.MaxDistance = 60
    bb.Parent = hitbox
    
    -- Main Card
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1,0,1,0)
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20) 
    frame.BackgroundTransparency = 1 -- Invisible Background (User Request)
    frame.BorderSizePixel = 0
    frame.Parent = bb
    
    -- No Corner/Stroke on Frame anymore
    -- local corner = Instance.new("UICorner") ...
    -- local stroke = Instance.new("UIStroke") ...
    
    local list = Instance.new("UIListLayout")
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, 0)
    list.HorizontalAlignment = Enum.HorizontalAlignment.Center
    list.VerticalAlignment = Enum.VerticalAlignment.Center
    list.Parent = frame
    
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0.05, 0)
    padding.PaddingBottom = UDim.new(0.05, 0)
    padding.Parent = frame
    
    -- 1. NAME (Top, White, Big)
    local lblName = Instance.new("TextLabel")
    lblName.LayoutOrder = 1
    lblName.Size = UDim2.new(1, 0, 0.4, 0)
    lblName.BackgroundTransparency = 1
    -- Update Name logic: Show Level clearly. GameManager pickup is temporary tool.
    -- User wants separate label for level in UnitManager (Placed).
    -- For Pickup Prompt (GameManager), "Unit (Lvl X)" is fine or add label?
    -- Snippet is creating "Frame" with ListLayout.
    -- I'll keep the (Lvl X) here for simplicity or separate it?
    -- User said "Type name (Lvl X) -> Separate Label".
    lblName.Text = chosen -- Just Name
    lblName.TextColor3 = Color3.new(1,1,1)
    
    -- Insert Level Label for Pickup UI too?
    -- The user explicitly complained about UnitManager (Placed Units).
    -- But consistency is key.
    -- I'll modify the text to "Unit" and color.
    -- Current snippet EndLine 472 matches Text setting.
    -- I will leave it simple.
    lblName.Text = chosen .. " (Lvl " .. level .. ")" -- Keeping it but maybe user wants it separate everywhere.
    -- I'll leave it combined here to avoid UI overflow in prompt, this is a ephemeral popup.
    lblName.TextColor3 = Color3.new(1,1,1)
    lblName.Font = Enum.Font.GothamBlack
    lblName.TextScaled = true
    lblName.Parent = frame
    
    -- Add Mutation Label if needed
    if mutationName then
        local lblMut = Instance.new("TextLabel")
        lblMut.LayoutOrder = 1 -- Insert above Name? Or below? Let's put at bottom (order 4)
        lblMut.Name = "MutationLabel"
        lblMut.Size = UDim2.new(1, 0, 0.2, 0)
        lblMut.BackgroundTransparency = 1
        lblMut.Text = "☢ " .. mutationName .. " ☢"
        -- Get mutation color
        local mData = require(ReplicatedStorage.Modules.MutationDefinitions)[mutationName]
        lblMut.TextColor3 = mData and mData.Color or Color3.new(1,1,1)
        lblMut.Font = Enum.Font.GothamBlack
        lblMut.TextScaled = true
        lblMut.Parent = frame
        
        local sm = Instance.new("UIStroke")
        sm.Thickness = 1.5
        sm.Color = Color3.new(0,0,0)
        sm.Parent = lblMut
    end
    
    local s1 = Instance.new("UIStroke")
    s1.Thickness = 1.5
    s1.Color = Color3.new(0,0,0)
    s1.Parent = lblName
    
    -- 2. RARITY (Middle, Colored)
    local lblTier = Instance.new("TextLabel")
    lblTier.LayoutOrder = 2
    lblTier.Size = UDim2.new(1, 0, 0.25, 0)
    lblTier.BackgroundTransparency = 1
    lblTier.Text = string.upper(realTier)
    lblTier.TextColor3 = EconomyLogic.getTierColor(realTier)
    lblTier.Font = Enum.Font.GothamBold
    lblTier.TextScaled = true
    lblTier.Parent = frame
    
    local s2 = Instance.new("UIStroke")
    s2.Thickness = 1.5
    s2.Color = Color3.new(0,0,0)
    s2.Parent = lblTier
    
    -- 3. INCOME (Bottom, Green)
    local lblInc = Instance.new("TextLabel")
    lblInc.LayoutOrder = 3
    lblInc.Size = UDim2.new(1, 0, 0.25, 0)
    lblInc.BackgroundTransparency = 1
    lblInc.Text = "+$" .. Abbreviate(estIncome) .. "/s"
    lblInc.TextColor3 = Color3.fromRGB(100, 255, 120) -- Vibrant Green
    lblInc.Font = Enum.Font.GothamBlack -- Thicker Font (User Request)
    lblInc.TextScaled = true
    lblInc.Parent = frame
    
    local s3 = Instance.new("UIStroke")
    s3.Thickness = 1.5
    s3.Color = Color3.new(0,0,0)
    s3.Parent = lblInc
    
    -- Manual Pickup (ProximityPrompt)
    local prompt = Instance.new("ProximityPrompt")
    prompt.ObjectText = chosen
    prompt.ActionText = "Recoger Brainrot"
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.HoldDuration = 0.3
    prompt.RequiresLineOfSight = false
    prompt.MaxActivationDistance = 10
    prompt.Parent = hitbox
    
    local collected = false
    prompt.Triggered:Connect(function(player)
        if collected then return end
        
        -- CHECK SINGLE CARRY LIMIT (Only blocks if holding UNSECURED loot)
        local character = player.Character
        if character then
            local hasUnsecured = false
            local function checkContainer(container)
                for _, t in pairs(container:GetChildren()) do
                    -- Check for Tier attribute (modern) OR legacy Unit_ prefix
                    if t:IsA("Tool") and (t:GetAttribute("Tier") or string.sub(t.Name, 1, 5) == "Unit_") then
                        if not t:GetAttribute("Secured") then
                            hasUnsecured = true
                            break
                        end
                    end
                end
            end
            
            checkContainer(character)
            if not hasUnsecured then checkContainer(player.Backpack) end
            
            if hasUnsecured then
                -- Inform player (Error Sound)
                local sfx = Instance.new("Sound")
                sfx.SoundId = "rbxassetid://6820551381"
                sfx.Parent = character
                sfx:Play()
                Debris:AddItem(sfx, 1)
                return 
            end
        end
        
        collected = true
        activeUnits -= 1 -- Decrement counter
        
        -- Discovery: Mark as seen in the index, but DON'T add to permanent inventory yet
        BrainrotData.markDiscovered(player, chosen, realTier, false)
        
        -- Create Tool (Temporary Loot) - READ ValueMultiplier from hitbox (generated at spawn)
        local spawnedValueMult = hitbox:GetAttribute("ValueMultiplier") or 1.0
        local spawnedLevel = hitbox:GetAttribute("Level") or level
        -- Create Tool (Temporary Loot) - READ ValueMultiplier from hitbox (generated at spawn)
        local spawnedValueMult = hitbox:GetAttribute("ValueMultiplier") or 1.0
        local spawnedLevel = hitbox:GetAttribute("Level") or level
        local spawnedMutation = hitbox:GetAttribute("Mutation") -- Retrieve mutation
        
        local tool = BrainrotData.createUnitTool(chosen, realTier, false, nil, spawnedLevel, spawnedValueMult, spawnedMutation)
        tool.Parent = player.Backpack
        if character and character:FindFirstChild("Humanoid") then
            character.Humanoid:EquipTool(tool)
        end
        
        -- Feedback
        local sfx = Instance.new("Sound")
        sfx.SoundId = "rbxassetid://134012322" -- Item pickup
        sfx.Parent = player.Character:FindFirstChild("Head") or player.Character:FindFirstChild("HumanoidRootPart")
        sfx:Play()
        Debris:AddItem(sfx, 1)
        
        -- Destroy World Model
        spawnedItem:Destroy()
    end)
    
    -- COUNTDOWN TIMER (60 seconds)
    local DESPAWN_TIME = 60
    
    -- Add countdown label
    local countdownLabel = Instance.new("TextLabel")
    countdownLabel.Name = "Countdown"
    countdownLabel.LayoutOrder = 4
    countdownLabel.Size = UDim2.new(1, 0, 0.2, 0)
    countdownLabel.BackgroundTransparency = 1
    countdownLabel.Text = "⏱ " .. DESPAWN_TIME .. "s"
    countdownLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
    countdownLabel.Font = Enum.Font.GothamBold
    countdownLabel.TextScaled = true
    countdownLabel.Parent = frame
    
    local sc = Instance.new("UIStroke")
    sc.Thickness = 1.5
    sc.Color = Color3.new(0,0,0)
    sc.Parent = countdownLabel
    
    -- Countdown coroutine
    task.spawn(function()
        local remaining = DESPAWN_TIME
        while remaining > 0 and spawnedItem.Parent do
            if collected then return end
            countdownLabel.Text = "⏱ " .. remaining .. "s"
            
            -- Color warning when low
            if remaining <= 10 then
                countdownLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
            elseif remaining <= 30 then
                countdownLabel.TextColor3 = Color3.fromRGB(255, 180, 80)
            end
            
            task.wait(1)
            remaining -= 1
        end
        
        -- Despawn if not collected
        if not collected and spawnedItem.Parent then
            activeUnits -= 1
            spawnedItem:Destroy()
        end
    end)
end

-- MAIN LOOP
task.spawn(function()
    setStatus("SURVIVE & LOOT!")
    
    -- SLOPE CONFIG FOR SPAWN CALCULATIONS
    local SLOPE_START_Z = 75 -- SYNCED: Matches MapManager
    local SLOPE_LENGTH = 1500 
    local EVENT_SLOPE_LENGTH = 400 -- Must match MapManager
    local SLOPE_MAX_Z = SLOPE_START_Z + SLOPE_LENGTH
    
    local SLOPE_WIDTH = 200 -- SYNCED: Was 120
    local SLOPE_ANGLE_RAD = math.rad(25) 
    
    local MAX_ACTIVE_UNITS = _G.DoubleWaveActive and 160 or 80 -- Double cap during event
    
    while true do
        local iterations = _G.DoubleWaveActive and 2 or 1
        
        for i = 1, iterations do
            -- 1. BRAINROT SPAWN
            if activeUnits < MAX_ACTIVE_UNITS then
                local z, x, y
                local tier = "Common"
                
                if _G.DoubleWaveActive then
                    -- EVENT SPAWN (In Special Zone only)
                    z = math.random(SLOPE_MAX_Z + 10, SLOPE_MAX_Z + EVENT_SLOPE_LENGTH - 50)
                    x = math.random(-SLOPE_WIDTH/2 + 20, SLOPE_WIDTH/2 - 20)
                    -- Calculate Y for Event Slope (Same angle continued)
                    y = (math.tan(SLOPE_ANGLE_RAD) * (z - SLOPE_START_Z)) + 2
                    
                    -- EVENT TIERS (Mythic+)
                    local rng = math.random()
                    tier = (rng > 0.9) and "Cosmic" or ((rng > 0.6) and "Celestial" or ((rng > 0.3) and "Divine" or "Mythic"))
                else
                    -- NORMAL SPAWN (Ramp Only)
                    z = math.random(SLOPE_START_Z + 10, SLOPE_MAX_Z - 50)
                    x = math.random(-SLOPE_WIDTH/2 + 20, SLOPE_WIDTH/2 - 20)
                    y = (math.tan(SLOPE_ANGLE_RAD) * (z - SLOPE_START_Z)) + 2
                    
                    -- DEPTH-BASED RARITY
                    local distFactor = (z - SLOPE_START_Z) / SLOPE_LENGTH
                    if distFactor > 0.85 then
                         tier = (math.random() > 0.4) and "Mythic" or "Legendary"
                    elseif distFactor > 0.6 then
                         local rng = math.random()
                         tier = (rng > 0.7) and "Legendary" or ((rng > 0.3) and "Epic" or "Rare")
                    elseif distFactor > 0.3 then
                         local rng = math.random()
                         tier = (rng > 0.6) and "Epic" or ((rng > 0.2) and "Rare" or "Common") -- Reduced Common to 20%
                    elseif distFactor > 0.05 then
                         tier = (math.random() > 0.4) and "Rare" or "Common" -- Rare 60%
                    else
                         tier = (math.random() > 0.8) and "Rare" or "Common" -- Very Start: Chance for Rare
                    end
                end

                spawnUnitCapsule(Vector3.new(x, y, z), tier)
            end
            
            -- 2. DISASTER SPAWN
            if math.random() > 0.75 then
                local rZ = _G.DoubleWaveActive and math.random(SLOPE_MAX_Z, SLOPE_MAX_Z + EVENT_SLOPE_LENGTH) or math.random(SLOPE_START_Z, SLOPE_MAX_Z)
                local rX = math.random(-SLOPE_WIDTH/2, SLOPE_WIDTH/2)
                local rY = (math.tan(SLOPE_ANGLE_RAD) * (rZ - SLOPE_START_Z)) + 120
                spawnRockAt(Vector3.new(rX, rY, rZ))
            end
        end
        
        task.wait(0.8) 
    end
end)

-- DISTANCE INCOME: DISABLED (Replaced by Tycoon)
-- COIN SPAWNING: DISABLED (Replaced by Loot Spawner)
-- Keeping Enemy Spawners below
