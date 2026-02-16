print("[Interactions] SCRIPT STARTING...")
-- EnvironmentInteractions.client.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local function waitFor(parent, name)
    local obj = parent:WaitForChild(name, 5)
    if not obj then
        warn("[Interactions] STILL WAITING FOR: " .. name .. " in " .. parent:GetFullName())
        return parent:WaitForChild(name)
    end
    return obj
end

local Modules = waitFor(ReplicatedStorage, "Modules")
local UIManager = require(Modules:WaitForChild("UIManager"))
local MutationManager = require(Modules:WaitForChild("MutationManager"))
local claimRemote = waitFor(ReplicatedStorage, "ClaimDailyReward")
local rerollRemote = waitFor(ReplicatedStorage, "RerollMutation")
local eventStarted = waitFor(ReplicatedStorage, "EventStarted")
local vfxRemote = waitFor(ReplicatedStorage, "PlayStallVFX")
local showVfx = waitFor(ReplicatedStorage, "ShowMutationVFX")
local brainrotModels = waitFor(ReplicatedStorage, "BrainrotModels")
local infoRemote = waitFor(ReplicatedStorage, "GetDailyRewardInfo")
local levelUpRemote = waitFor(ReplicatedStorage, "DonorLevelUp")

-- UTILS
local function playSound(id, vol, duration) -- v5.3 POLISH
    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://" .. tostring(id)
    s.Volume = vol or 0.5
    s.Parent = game:GetService("SoundService")
    s:Play()
    if duration then
        task.delay(duration, function()
            if s and s.Parent then
                s:Stop()
                s:Destroy()
            end
        end)
    else
        s.Ended:Connect(function() s:Destroy() end)
    end
end

-- 0. VISUAL POLISH (Continuous)
local function animateStall(obj, isMutation)
    task.spawn(function()
        -- 1. POSICIÓN (Ajuste vertical para que no flote)
        local verticalOffset = -3.2 -- Bajado más para que encaje bien
        local startPos = obj.Position
        local floatAmp = isMutation and 0.2 or 0.6
        local floatFreq = isMutation and 1 or 2
        
        -- 2. ORIENTACIÓN FIJA (Sin multiplicadores para evitar ángulos extraños)
        -- Si estamos a la izquierda (X < 0), el centro está a la derecha (+X).
        -- Invertimos la lógica anterior porque el usuario dice que estaba "al revés".
        local angle = (obj.Position.X < 0) and math.rad(-90) or math.rad(90)
        local baseOrientation = CFrame.Angles(0, angle, 0)
        
        while obj and obj.Parent do
            local t = tick()
            local hover = Vector3.new(0, math.sin(t * floatFreq) * floatAmp, 0)
            
            -- Construcción limpia: Altura -> Orientación Fija -> Bobbing (sin giro)
            local targetBaseCF = CFrame.new(startPos) * CFrame.new(0, verticalOffset, 0) * baseOrientation * CFrame.new(hover)
            
            for _, child in pairs(obj:GetChildren()) do
                if child:IsA("Model") or child:IsA("BasePart") then
                    if child.Name == "FloatingLabel" or child.Name == "FloatingLabelSub" then continue end
                    
                    if child:IsA("Model") then
                        -- Aplicar rotación extra del modelo (ej: Celestial)
                        local tierRotation = child:GetAttribute("BaseRotation") or CFrame.new()
                        child:PivotTo(targetBaseCF * tierRotation)
                    else
                        child.CFrame = targetBaseCF
                    end
                end
            end
            
            task.wait()
        end
    end)
end

-- 0b. PILLAR ANIMATION (Circular)
local function animatePillars(altarPart)
    local group = altarPart:WaitForChild("MutationPillars", 10)
    if not group then return end
    
    local pillars = {}
    for _, p in pairs(group:GetChildren()) do
        if p:IsA("Model") then
            table.insert(pillars, p)
        end
    end

    task.spawn(function()
        local radius = 7 -- Slightly wider
        local orbitSpeed = 0.8
        local selfSpinSpeed = 1.5
        
        while altarPart and altarPart.Parent do
            local t = tick()
            for i, p in ipairs(pillars) do
                local angle = (t * orbitSpeed) + (i * (math.pi/2))
                local offset = Vector3.new(math.cos(angle) * radius, 5, math.sin(angle) * radius)
                local targetPos = altarPart.Position + offset
                
                p:PivotTo(CFrame.new(targetPos) * CFrame.Angles(0, t * selfSpinSpeed, 0))
            end
            task.wait()
        end
    end)
end

-- 1. LUCKY BLOCK INTERACTION
local isEvolving = {}

local function updateStallVisuals(part)
    if isEvolving[part] then return end -- Don't interrupt animation
    task.spawn(function()
        local info = infoRemote:InvokeServer()
        if not info or not info.RewardId then return end
        
        part.Transparency = 1
        part.CanCollide = false
        
        local luckyBlocks = ReplicatedStorage:WaitForChild("LuckyBlocks", 10)
        local template = luckyBlocks:FindFirstChild(info.RewardId) or luckyBlocks:FindFirstChild(info.RewardItem)
        
        if template then
            local partCount = #template:GetDescendants()
            print(string.format("[Interactions] Found template: %s (Class: %s, Parts: %d)", 
                info.RewardId, template.ClassName, partCount))
            
            for _, c in pairs(part:GetChildren()) do
                if c:IsA("Model") or (c:IsA("BasePart") and c.Name ~= "FloatingLabel" and c.Name ~= "FloatingLabelSub") then
                    c:Destroy()
                end
            end
            
            local visual = template:Clone()
            local rootPart = nil
            
            if visual:IsA("Model") then
                -- 1. ANCHOR & HIDE VFX
                rootPart = visual.PrimaryPart or visual:FindFirstChildWhichIsA("BasePart", true)
                for _, p in pairs(visual:GetDescendants()) do
                    if p:IsA("BasePart") then 
                        p.Anchored = true 
                        p.CanCollide = false 
                        -- Only override if specifically known to be a VFX part that should be hidden
                        if p.Name == "VfxInstance" then
                            p.Transparency = 1
                        end
                    end
                end
                
                -- 2. POSITION (Reference only)
                local rotation = (info.RewardId == "lb_celestial") and CFrame.Angles(0, math.rad(-90), 0) or CFrame.new()
                visual:PivotTo(part.CFrame * rotation)
                visual:SetAttribute("BaseRotation", rotation)
                
                -- 3. SCALE (Direct factor of 1.5)
                visual:ScaleTo(1.5)
                
                -- 4. GLOW 
                if rootPart then
                    local light = Instance.new("PointLight")
                    light.Color = Color3.fromRGB(255, 255, 200)
                    light.Range = 8
                    light.Brightness = 1.2
                    light.Parent = rootPart
                end
            elseif visual:IsA("BasePart") then
                visual.Anchored = true
                visual.CanCollide = false
                visual.Transparency = 0
                visual.Size = Vector3.new(1.5, 1.5, 1.5)
                visual.CFrame = part.CFrame
                rootPart = visual
                
                local light = Instance.new("PointLight")
                light.Color = Color3.fromRGB(255, 255, 200)
                light.Range = 8
                light.Brightness = 1.2
                light.Parent = visual
            end
            
            visual.Parent = part
            print("[Interactions] Visual anchored & positioned as reference. Parts:", #visual:GetDescendants())
        else
            warn("[Interactions] Template NOT FOUND in LuckyBlocks folder for:", info.RewardId or "nil")
            local items = {}
            for _, child in pairs(luckyBlocks:GetChildren()) do table.insert(items, child.Name) end
            print("[Interactions] LuckyBlocks available:", table.concat(items, ", "))
        end
    end)
end

-- NEW: EVOLUTION ANIMATION
levelUpRemote.OnClientEvent:Connect(function(newRewardId)
    local stallVisuals = CollectionService:GetTagged("LuckyBlockClaim")
    for _, part in ipairs(stallVisuals) do
        if isEvolving[part] then continue end
        isEvolving[part] = true
        
        task.spawn(function()
            -- 1. Accelerate Spin
            local startTime = tick()
            local duration = 2.5
            
            -- Add Particles for Hype
            local attachment = Instance.new("Attachment", part)
            local particles = Instance.new("ParticleEmitter", attachment)
            particles.Rate = 0
            particles.Speed = NumberRange.new(5, 10)
            particles.Acceleration = Vector3.new(0, 10, 0)
            particles.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 215, 0))
            particles.Transparency = NumberSequence.new(0, 1)
            particles.Enabled = true
            
            -- High Speed Sound
            playSound(402982861, 1, 3) 

            while tick() - startTime < duration do
                local progress = (tick() - startTime) / duration
                particles.Rate = progress * 100
                -- Apply extra rotation on top of the base animation
                part.CFrame = part.CFrame * CFrame.Angles(0, math.rad(progress * 45), 0)
                task.wait()
            end
            
            -- 2. Flash & Swap
            particles.Rate = 500
            task.wait(0.2)
            
            -- Update model and reset cooldown state
            isEvolving[part] = nil -- Allow updateStallVisuals to work
            updateStallVisuals(part)
            
            -- 3. Final Burst
            local explosion = Instance.new("Explosion")
            explosion.Position = part.Position
            explosion.BlastRadius = 0
            explosion.Visible = true
            explosion.Parent = part
            
            playSound(138090511, 1.2, 1)
            
            task.wait(1)
            attachment:Destroy()
        end)
    end
end)

local function setupLuckyBlock(part)
    animateStall(part, false)
    updateStallVisuals(part)
    
    -- DYNAMIC PROMPT + LABEL TEXT (Smooth Countdown)
    task.spawn(function()
        local lastServerSync = 0
        local cachedInfo = nil
        
        -- Find the ProximityPrompt directly on the part (lbVisual)
        local prompt = part:FindFirstChildOfClass("ProximityPrompt")
        
        -- Find the Countdown Label (FloatingLabelSub)
        local subLabel = part:FindFirstChild("FloatingLabelSub") or part:FindFirstChild("FloatingLabelSub", true)
        local labelTxt = subLabel and subLabel:FindFirstChildWhichIsA("TextLabel", true)

        while part and part.Parent do
            if os.time() - lastServerSync > 30 or not cachedInfo then
                local success, info = pcall(function() return infoRemote:InvokeServer() end)
                if success and info then
                    cachedInfo = info
                    lastServerSync = os.time()
                end
            end
            
            if cachedInfo then
                local now = os.time()
                local last = cachedInfo.LastClaim or 0
                local diff = now - last
                local cooldown = cachedInfo.Cooldown or (24 * 3600)
                
                if diff < cooldown then
                    local rem = cooldown - diff
                    local h = math.floor(rem / 3600)
                    local m = math.floor((rem % 3600) / 60)
                    local s = rem % 60
                    local timeStr = string.format("%02d:%02d:%02d", h, m, s)
                    
                    if labelTxt then labelTxt.Text = timeStr end
                    if prompt then prompt.ActionText = "READY IN " .. timeStr end
                else
                    if labelTxt then 
                        labelTxt.Text = "READY TO CLAIM!" 
                        labelTxt.TextColor3 = Color3.fromRGB(0, 255, 0)
                    end
                    if prompt then 
                        prompt.ActionText = "CLAIM NOW!" 
                    end
                end
                if prompt then prompt.Enabled = true end
            end
            task.wait(1) 
        end
    end)
    
    -- Local prompt handler
    local localPrompt = part:FindFirstChildOfClass("ProximityPrompt")
    if localPrompt then
        localPrompt.Triggered:Connect(function()
            UIManager.Open("DailyRewardUI")
        end)
    end
    print("[Interactions] Setup LuckyBlock prompt for:", part:GetFullName())
end

-- 2. MUTATION ALTAR INTERACTION
local function setupMutationAltar(part)
    -- Group Animation
    animatePillars(part)

    -- Handle remaining visual crystals if any (fallback)
    for _, child in pairs(part.Parent:GetDescendants()) do
        if (child.Name == "AltarCrystal" and not child:FindFirstAncestor("MutationPillars")) or child.Name == "LuckyBlockVisual" then
            animateStall(child, child.Name == "AltarCrystal")
        end
    end

    local prompt = part:FindFirstChildOfClass("ProximityPrompt")
    if not prompt then return end
    
    prompt.Triggered:Connect(function()
        print("[Interactions] MutationAltar Triggered!")
        UIManager.Open("MutationAltarUI")
    end)
    print("[Interactions] Setup MutationAltar prompt for:", part:GetFullName())
end

-- 3. GLOBAL VFX LISTENER
vfxRemote.OnClientEvent:Connect(function(stallType)
    if stallType == "LuckyBlock" then
        for _, obj in pairs(CollectionService:GetTagged("LuckyBlockClaim")) do
            -- Spin animation
            local startCF = obj.CFrame
            TweenService:Create(obj, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                CFrame = startCF * CFrame.Angles(0, math.rad(360), 0)
            }):Play()
            
            local sparkles = Instance.new("Sparkles")
            sparkles.SparkleColor = Color3.fromRGB(255, 255, 0)
            sparkles.Parent = obj
            task.delay(2, function() sparkles:Destroy() end)
        end
    elseif stallType == "MutationAltar" then
        for _, obj in pairs(CollectionService:GetTagged("MutationAltar")) do
            local light = Instance.new("PointLight")
            light.Color = Color3.fromRGB(200, 0, 255)
            light.Brightness = 10
            light.Range = 30
            light.Parent = obj
            
            TweenService:Create(light, TweenInfo.new(1.5), {Brightness = 0}):Play()
            game:GetService("Debris"):AddItem(light, 1.6)
        end
    end
end)

-- 4. PHYSICAL MUTATION ANIMATION
showVfx.OnClientEvent:Connect(function(info)
    -- info: {UnitName, Tier, Mutation, IsSuccess, UnitId}
    
    -- Find nearby altar
    local altarPart = nil
    local shortestDist = 25
    for _, obj in pairs(CollectionService:GetTagged("MutationAltar")) do
        local dist = (obj.Position - player.Character.PrimaryPart.Position).Magnitude
        if dist < shortestDist then
            shortestDist = dist
            altarPart = obj
        end
    end
    
    if not altarPart then return end
    
    -- Spawn Visual Model
    local tierFolder = brainrotModels:FindFirstChild(info.Tier)
    if not tierFolder then return end
    local source = tierFolder:FindFirstChild(info.UnitName)
    if not source then return end
    
    local clone = source:Clone()
    clone:ScaleTo(1.5)
    clone.Parent = workspace
    
    -- Position above altar
    local startPos = altarPart.Position + Vector3.new(0, 5, 0)
    clone:PivotTo(CFrame.new(startPos))
    
    -- Animation: Spin and Rise
    local spinInfo = TweenInfo.new(5.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    local spinValue = Instance.new("NumberValue")
    spinValue.Value = 0
    
    local conn = game:GetService("RunService").Heartbeat:Connect(function()
        if clone and clone.Parent then
            -- Hover + Orbit offset (small) + rotation
            local t = tick()
            local hover = Vector3.new(0, math.sin(t * 4) * 0.5, 0)
            clone:PivotTo(CFrame.new(startPos + hover) * CFrame.Angles(0, math.rad(spinValue.Value), 0))
        end
    end)
    
    TweenService:Create(spinValue, spinInfo, {Value = 3240}):Play() -- 9 full spins
    
    task.wait(2.5) -- THE MOMENT OF TRUTH
    
    -- TRANSFORMATION PULSE
    local pulseColor = info.IsSuccess and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    if info.Mutation then
        -- If successful, try to get the mutation's specific color
        local Modules = ReplicatedStorage:FindFirstChild("Modules")
        if Modules then
            local Definitions = Modules:FindFirstChild("MutationDefinitions")
            if Definitions then
                local defs = require(Definitions)
                if defs[info.Mutation] and defs[info.Mutation].Color then
                    pulseColor = defs[info.Mutation].Color
                end
            end
        end
    end

    local light = Instance.new("PointLight")
    light.Color = pulseColor
    light.Brightness = 40
    light.Range = 40
    light.Parent = clone.PrimaryPart or altarPart
    
    TweenService:Create(light, TweenInfo.new(1, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, true), {Brightness = 0, Range = 60}):Play()
    
    if info.IsSuccess then
        playSound(9126213759, 1.2) -- Magic Sparkle / Success
        -- APPLY MUTATION LIVE
        if info.Mutation then
            MutationManager.applyMutation(clone, info.Mutation)
            print("[MutationVFX] Success! Applied: " .. info.Mutation)
        end
    else
        playSound(9112765376, 0.8) -- Error / Fail
        -- Clear any existing mutation visuals to show "reset" or "fail"
        for _, d in pairs(clone:GetDescendants()) do
            if d:IsA("ParticleEmitter") and d.Name == "MutationParticles" then
                d:Destroy()
            end
        end
        print("[MutationVFX] Failed mutation.")
    end
    
    -- RESULT TEXT (Floating above clone)
    task.spawn(function()
        local resultPart = clone.PrimaryPart or altarPart
        local bg = Instance.new("BillboardGui")
        bg.Size = UDim2.new(10, 0, 2, 0)
        bg.StudsOffset = Vector3.new(0, 6, 0)
        bg.AlwaysOnTop = true
        bg.Parent = resultPart
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBlack
        label.TextScaled = true
        label.TextColor3 = pulseColor
        label.TextStrokeTransparency = 0
        label.Parent = bg
        
        if info.IsSuccess then
            label.Text = "¡ÉXITO: " .. (info.Mutation or "???"):upper() .. "!"
        else
            label.Text = "FALLO..."
        end
        
        -- Animation: Rise and Fade
        local fadeTarget = bg.StudsOffset + Vector3.new(0, 4, 0)
        TweenService:Create(bg, TweenInfo.new(2.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {StudsOffset = fadeTarget}):Play()
        task.wait(1.5)
        TweenService:Create(label, TweenInfo.new(1.0), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
        task.delay(1.1, function() bg:Destroy() end)
    end)
    
    -- Show results for a bit
    task.wait(2.5)
    
    -- Fade out & Float away
    for _, d in pairs(clone:GetDescendants()) do
        if d:IsA("BasePart") then
            TweenService:Create(d, TweenInfo.new(1.0), {Transparency = 1}):Play()
        end
    end
    
    task.wait(1.0)
    conn:Disconnect()
    clone:Destroy()
    light:Destroy()
end)

for _, obj in pairs(CollectionService:GetTagged("LuckyBlockClaim")) do
    setupLuckyBlock(obj)
end
for _, obj in pairs(CollectionService:GetTagged("MutationAltar")) do
    setupMutationAltar(obj)
end

CollectionService:GetInstanceAddedSignal("LuckyBlockClaim"):Connect(setupLuckyBlock)
CollectionService:GetInstanceAddedSignal("MutationAltar"):Connect(setupMutationAltar)

print("[Interactions] Altar V3 Mechanics Loaded.")
