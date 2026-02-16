-- TycoonVisuals.server.lua
-- Skill: tycoon-mechanics
-- Description: Manages visual elements of the tycoon base (Owner Sign, Upgrade Button).

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local UnitManager = require(ServerScriptService.UnitManager)
local BrainrotData = require(ServerScriptService.BrainrotData)
local EconomyLogic = require(ReplicatedStorage.Modules.EconomyLogic)

-- CONFIG
local MAX_CAPACITY_TIERS = 5 -- Example max upgrades

-- Ensure Remotes
local OpenBaseUpgradeEvent = ReplicatedStorage:FindFirstChild("OpenBaseUpgradeUI") or Instance.new("RemoteEvent")
OpenBaseUpgradeEvent.Name = "OpenBaseUpgradeUI"
OpenBaseUpgradeEvent.Parent = ReplicatedStorage

--------------------------------------------------------
-- 1. BASE OWNER DISPLAY
--------------------------------------------------------
local function updateOwnerSign(tycoon, player)
    local ownerPart = tycoon:FindFirstChild("BaseOwner")
    if not ownerPart then return end
    
    -- Reference Part: Invisible but keeps collision for "Touch to Claim"
    ownerPart.Transparency = 1
    ownerPart.CanCollide = true -- Essential for claiming
    
    -- Clear old GUi
    for _, child in pairs(ownerPart:GetChildren()) do
        if child:IsA("SurfaceGui") or child:IsA("BillboardGui") then child:Destroy() end
    end
    
    -- Billboard Setup
    local bb = Instance.new("BillboardGui")
    bb.Name = "OwnerGui"
    bb.Size = UDim2.new(10, 0, 3.5, 0) -- Smaller
    bb.StudsOffset = Vector3.new(0, 4.5, 0) -- Lower
    bb.AlwaysOnTop = false 
    bb.MaxDistance = 150
    bb.Parent = ownerPart

    if not player then 
        if ownerPart:FindFirstChild("OwnerGui") then ownerPart.OwnerGui:Destroy() end
        return 
    end

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(1, 0, 1, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    mainFrame.BackgroundTransparency = 0.4
    mainFrame.Parent = bb
    
    local uiCorner = Instance.new("UICorner", mainFrame)
    uiCorner.CornerRadius = UDim.new(0.2, 0)
    
    local uiStroke = Instance.new("UIStroke", mainFrame)
    uiStroke.Thickness = 2
    uiStroke.Transparency = 0.5
    uiStroke.Color = Color3.new(1, 1, 1)
    -- Avatar Circular
    local avatarFrame = Instance.new("Frame")
    avatarFrame.Size = UDim2.new(0.3, 0, 0.8, 0)
    avatarFrame.Position = UDim2.new(0.05, 0, 0.1, 0)
    avatarFrame.BackgroundTransparency = 1
    avatarFrame.Parent = mainFrame
    
    local avatar = Instance.new("ImageLabel")
    avatar.Size = UDim2.new(1, 0, 1, 0)
    avatar.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=420&h=420"
    avatar.Parent = avatarFrame
    Instance.new("UICorner", avatar).CornerRadius = UDim.new(1, 0)
    
    local avatarStroke = Instance.new("UIStroke", avatar)
    avatarStroke.Thickness = 2
    avatarStroke.Color = Color3.new(1, 1, 1)

    -- Name and Title
    local textContainer = Instance.new("Frame")
    textContainer.Size = UDim2.new(0.55, 0, 0.8, 0)
    textContainer.Position = UDim2.new(0.4, 0, 0.1, 0)
    textContainer.BackgroundTransparency = 1
    textContainer.Parent = mainFrame
    
    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, 0, 0.3, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = "TYCOON OWNER"
    titleLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextScaled = true
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = textContainer
    
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, 0, 0.6, 0)
    nameLbl.Position = UDim2.new(0, 0, 0.3, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = player.DisplayName
    nameLbl.TextColor3 = Color3.new(1, 1, 1)
    nameLbl.Font = Enum.Font.GothamBlack
    nameLbl.TextScaled = true
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.Parent = textContainer
end

-- Hook into Tycoon Assignment (We need a signal or polling, polling for now since UnitManager doesn't expose an event yet)
-- Better approach: Hook into UnitManager.assignTycoon if we modify it, or use Attribute changes if UnitManager sets them.
-- UnitManager creates a 'TycoonOwner' attribute on the base or similar? Let's check UnitManager.

-- We'll accept that UnitManager tracks owners in 'tycoonOwners' table but doesn't expose it easily.
-- However, UnitManager assigns the base to the player.
-- Let's poll for attribute changes if possible, or just hook into PlayerAdded/Removing and check UnitManager.

-- Wait, map generates "TycoonBase_X". UnitManager assigns it.
-- Let's look for an attribute on the Base Model. If not there, we should add it in UnitManager.
--------------------------------------------------------

--------------------------------------------------------
-- 2. BASE UPGRADE LOGIC
--------------------------------------------------------
local function setupUpgradeButton(tycoon)
    local upgrader = tycoon:FindFirstChild("BaseUpgrader")
    if not upgrader then return end
    
    local btnPart = upgrader:FindFirstChild("UpgradeButton") or upgrader:FindFirstChildWhichIsA("BasePart")
    if not btnPart then return end

    -- HITBOX SOLUTION: Create a volume that captures clics from ANY side (360 degrees)
    local hitbox = upgrader:FindFirstChild("InteractionHitbox")
    if not hitbox then
        hitbox = Instance.new("Part")
        hitbox.Name = "InteractionHitbox"
        hitbox.Transparency = 1
        hitbox.CanCollide = false
        hitbox.CastShadow = false
        hitbox.Anchored = true
        -- Make it a bit bigger than the part to catch clics easily
        hitbox.Size = (btnPart:IsA("Model") and btnPart:GetExtentsSize() or btnPart.Size) + Vector3.new(0.5, 0.5, 0.5)
        hitbox.CFrame = (btnPart:IsA("Model") and btnPart:GetPivot() or btnPart.CFrame)
        hitbox.Parent = upgrader
    end

    local function onTriggered(player)
        local ownerId = tycoon:GetAttribute("OwnerUserId")
        print(string.format("[TycoonVisuals] Click detected by %s. OwnerId: %s", player.Name, tostring(ownerId)))
        
        if not ownerId then return end
        if player.UserId ~= ownerId then 
            print("[TycoonVisuals] Access Denied: Player is not owner.")
            return 
        end
        
        local remote = ReplicatedStorage:FindFirstChild("OpenBaseUpgradeUI")
        if remote then
            print("[TycoonVisuals] Firing OpenBaseUpgradeUI to " .. player.Name)
            remote:FireClient(player, tycoon)
        else
            warn("[TycoonVisuals] ERROR: OpenBaseUpgradeUI remote not found!")
        end
    end

    -- 1. CLICK DETECTOR (Infallible 360 degree clicking)
    local cd = hitbox:FindFirstChildOfClass("ClickDetector") or Instance.new("ClickDetector")
    cd.MaxActivationDistance = 32
    cd.Parent = hitbox
    
    -- Disconnect old if any (though unlikely here)
    cd.MouseClick:Connect(onTriggered)
    
    -- 2. PROXIMITY PROMPT (Optional but good)
    local prompt = upgrader:FindFirstChildOfClass("ProximityPrompt", true) or hitbox:FindFirstChildOfClass("ProximityPrompt")
    if not prompt then
        prompt = Instance.new("ProximityPrompt")
        prompt.ActionText = "Upgrade"
        prompt.HoldDuration = 0
        prompt.Parent = hitbox
    end
    prompt.Triggered:Connect(onTriggered)
end

--------------------------------------------------------
-- INIT
--------------------------------------------------------
-- We need to listen for Map Generation
local function onTycoonAdded(tycoon)
    if not tycoon.Name:match("TycoonBase_") then return end
    
    print("[TycoonVisuals] Detected tycoon: " .. tycoon.Name .. ". Waiting for components...")
    
    -- WAIT FOR COMPONENTS (Race condition fix)
    local upgrader = nil
    local owner = nil
    local start = os.clock()
    
    while os.clock() - start < 5 do
        upgrader = tycoon:FindFirstChild("BaseUpgrader")
        owner = tycoon:FindFirstChild("BaseOwner")
        if upgrader and owner then break end
        task.wait(0.5)
    end
    
    if upgrader then
        setupUpgradeButton(tycoon)
        
        -- HIDE AT MAX LEVEL
        local function checkMaxLevel()
            local level = tycoon:GetAttribute("BaseLevel") or 1
            for _, part in pairs(upgrader:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Transparency = (level >= 5) and 1 or part:GetAttribute("OriginalTransparency") or 0
                end
                if part:IsA("ProximityPrompt") then part.Enabled = (level < 5) end
                if part:IsA("ClickDetector") then part.MaxActivationDistance = (level < 5) and 32 or 0 end
                if part:IsA("SurfaceGui") then part.Enabled = (level < 5) end
            end
        end
        
        -- Save original transparencies
        for _, part in pairs(upgrader:GetDescendants()) do
            if part:IsA("BasePart") then
                part:SetAttribute("OriginalTransparency", part.Transparency)
            end
        end
        
        checkMaxLevel()
        tycoon:GetAttributeChangedSignal("BaseLevel"):Connect(checkMaxLevel)
    else
        warn("[TycoonVisuals] TIMEOUT: BaseUpgrader not found in " .. tycoon.Name)
    end
    
    -- INITIALIZE SIGN
    if owner then
        local currentOwnerName = tycoon:GetAttribute("Owner")
        local p = currentOwnerName and Players:FindFirstChild(currentOwnerName)
        updateOwnerSign(tycoon, p)
    end
    
    -- CLAIM LOGIC (BaseOwner Touched)
    if owner then
        owner.Touched:Connect(function(hit)
            local char = hit.Parent
            local player = Players:GetPlayerFromCharacter(char)
            if player and not tycoon:GetAttribute("Owner") then
                -- Verify if player already has a tycoon
                local hasTycoon = false
                for _, t in pairs(Workspace:GetDescendants()) do
                    if t:IsA("Model") and t.Name:match("TycoonBase_") and t:GetAttribute("Owner") == player.Name then
                        hasTycoon = true
                        break
                    end
                end
                
                if not hasTycoon then
                    UnitManager.assignTycoon(player)
                end
            end
        end)
    else
        warn("[TycoonVisuals] TIMEOUT: BaseOwner not found in " .. tycoon.Name)
    end

    -- 2. APPLY SAVED COLORS
    local function applySavedColors(p)
        local savedColors = BrainrotData.getFloorColors(p)
        for floorName, color in pairs(savedColors) do
            local slotsFolder = tycoon:FindFirstChild("TycoonSlots")
            local floorModel = (floorName == "Floor_0") and tycoon or (slotsFolder and slotsFolder:FindFirstChild(floorName))
            if not floorModel then floorModel = tycoon:FindFirstChild(floorName, true) end
            
            if floorModel then
                local suelo = floorModel:FindFirstChild("Suelo")
                if suelo and suelo:IsA("BasePart") then suelo.Color = color end
            end
        end
    end

    -- Listen for Owner Change
    tycoon:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
        local uid = tycoon:GetAttribute("OwnerUserId")
        if uid then
            local p = Players:GetPlayerByUserId(uid)
            updateOwnerSign(tycoon, p)
            if p then applySavedColors(p) end
        else
            updateOwnerSign(tycoon, nil)
        end
    end)
    
    -- Listen for new floors being built
    local slots = tycoon:FindFirstChild("TycoonSlots")
    if slots then
        slots.ChildAdded:Connect(function(child)
            local uid = tycoon:GetAttribute("OwnerUserId")
            if uid then
                local p = Players:GetPlayerByUserId(uid)
                if p then applySavedColors(p) end
            end
        end)
    end
end

Workspace.ChildAdded:Connect(function(child)
    if child.Name == "SimulatorMap" then
        child.ChildAdded:Connect(onTycoonAdded)
        for _, g in pairs(child:GetChildren()) do onTycoonAdded(g) end
    elseif child.Name:match("TycoonBase_") then
        onTycoonAdded(child)
    end
end)

-- Check existing
local sm = Workspace:FindFirstChild("SimulatorMap")
if sm then
    sm.ChildAdded:Connect(onTycoonAdded)
    for _, child in pairs(sm:GetChildren()) do
        onTycoonAdded(child)
    end
end

for _, child in pairs(Workspace:GetChildren()) do
    if child.Name:match("TycoonBase_") then
        onTycoonAdded(child)
    end
end

-- 3. FLOOR CUSTOMIZATION
local UpdateFloorColorEvent = ReplicatedStorage:FindFirstChild("UpdateFloorColor") or Instance.new("RemoteEvent")
UpdateFloorColorEvent.Name = "UpdateFloorColor"
UpdateFloorColorEvent.Parent = ReplicatedStorage

UpdateFloorColorEvent.OnServerEvent:Connect(function(player, tycoon, floorName, color)
    if not tycoon or not floorName or not color then return end
    
    -- Security: Check ownership
    local ownerId = tycoon:GetAttribute("OwnerUserId")
    if ownerId ~= player.UserId then 
        warn(string.format("[TycoonVisuals] %s tried to change color of a tycoon they don't own!", player.Name))
        return 
    end
    
    -- Find the floor
    local slotsFolder = tycoon:FindFirstChild("TycoonSlots")
    local floorModel = (floorName == "Floor_0") and tycoon or (slotsFolder and slotsFolder:FindFirstChild(floorName))
    
    if not floorModel then
        -- Search descendant if not in slots
        floorModel = tycoon:FindFirstChild(floorName, true)
    end
    
    if floorModel then
        local suelo = floorModel:FindFirstChild("Suelo")
        if suelo and suelo:IsA("BasePart") then
            suelo.Color = color
            -- PERSISTENCE
            BrainrotData.saveFloorColor(player, floorName, color)
            print(string.format("[TycoonVisuals] %s updated %s color to %s (Persisted)", player.Name, floorName, tostring(color)))
        else
            warn(string.format("[TycoonVisuals] Suelo part not found in %s", floorName))
        end
    else
        warn(string.format("[TycoonVisuals] Floor model %s not found in %s", floorName, tycoon.Name))
    end
end)

return {}
