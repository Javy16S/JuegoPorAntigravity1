-- UnitHUD.client.lua
-- Skill: interactive-ui
-- Description: Manages the overhead UI for units LOCALLY to ensure smooth buttons and instant updates.
-- Replaces server-side UI.

-- print("[UnitHUD] Script starting...")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Require EconomyLogic with error handling
local EconomyLogic
local success, err = pcall(function()
    EconomyLogic = require(ReplicatedStorage.Modules:WaitForChild("EconomyLogic", 10))
end)
if not success then
    warn("[UnitHUD] Failed to load EconomyLogic: " .. tostring(err))
    return -- Exit script if module fails
end
-- print("[UnitHUD] EconomyLogic loaded.")

-- Remote for Upgrading (optional, don't block if missing)
local upgradeRemote = ReplicatedStorage:FindFirstChild("UpgradeUnit")
if not upgradeRemote then
    print("[UnitHUD] UpgradeUnit remote not found, waiting...")
    upgradeRemote = ReplicatedStorage:WaitForChild("UpgradeUnit", 10)
end
-- print("[UnitHUD] Upgrade remote: " .. tostring(upgradeRemote))

-- Load MutationDefinitions for color lookup
local MutationDefinitions
pcall(function()
    MutationDefinitions = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MutationDefinitions", 5))
end)
if MutationDefinitions then
    -- print("[UnitHUD] MutationDefinitions loaded.")
else
    print("[UnitHUD] MutationDefinitions not found, using fallback colors.")
end

-- UI CONSTANTS
local UI_OFFSET = Vector3.new(0, 4.5, 0)
local UI_SIZE = UDim2.new(5, 0, 3, 0) -- Scaled size

local function createUnitUI(model)
    if not model then return end
    
    -- Check if HUD already exists to avoid work
    local hudName = "HUD_" .. model:GetFullName():gsub("[^%w]", "_")
    if PlayerGui:FindFirstChild(hudName) then return end

    -- Find Adornee efficiently
    -- PrimaryPart is fastest. Fallback to child search only if needed.
    local adornee = model.PrimaryPart
    
    if not adornee then
        adornee = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart", true)
    end

    if not adornee then
        -- Quick retry (max 1s) for streaming
        local retries = 0
        while retries < 2 and not adornee do
            task.wait(0.5)
            adornee = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
            retries += 1
        end
    end

    if not adornee then
        -- Silent fail for now, polling will catch it later if it streams in
        return
    end

    -- Cleanup existing (just in case)
    if PlayerGui:FindFirstChild(hudName) then
        PlayerGui[hudName]:Destroy()
    end    
    -- Creates Billboard in PlayerGui

    
    -- Creates Billboard in PlayerGui (Adornee pattern for reliable clicks)
    local bb = Instance.new("BillboardGui")
    bb.Name = hudName
    bb.Adornee = adornee
    bb.Size = UI_SIZE
    
    -- DYNAMIC HEIGHT OFFSET
    local height = 4.5
    if model:IsA("Model") then
        local cf, size = model:GetBoundingBox()
        if size.Y > 0 then
            height = (size.Y / 2) + 3 -- Top of model + 3 studs
        end
    elseif model:IsA("BasePart") then
        height = (model.Size.Y / 2) + 3
    end
    
    bb.StudsOffset = Vector3.new(0, height, 0)
    bb.AlwaysOnTop = false -- Keep depth
    bb.MaxDistance = 60 -- Increased distance for big units
    bb.Parent = PlayerGui
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1,0,1,0)
    frame.BackgroundTransparency = 1
    frame.Parent = bb
    
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Padding = UDim.new(0, 2)
    layout.Parent = frame
    
    -- Helper
    local function addText(text, color, order, sizeY, font)
        local lbl = Instance.new("TextLabel")
        lbl.Text = text
        lbl.TextColor3 = color
        lbl.BackgroundTransparency = 1
        lbl.TextStrokeTransparency = 0
        lbl.Font = font or Enum.Font.GothamBold
        lbl.TextScaled = true
        lbl.Size = UDim2.new(1, 0, sizeY or 0.2, 0)
        lbl.LayoutOrder = order
        lbl.Parent = frame
        return lbl
    end
    
    -- 1. HEADER (Level + Name)
    -- User wants separated labels.
    -- Row for Name/Level? Or Stacked?
    -- User said: "separar el nivel del nombre" (Label propio de otro color).
    
    -- LEVEL Display (Cyan)
    local lvlLbl = addText("Lv " .. (model:GetAttribute("Level") or 1), Color3.fromRGB(0, 255, 255), 1, 0.15, Enum.Font.FredokaOne)
    
    -- NAME Display
    local rawName = model:GetAttribute("UnitName") or model.Name
    local nameStr = rawName:gsub("_", " ") -- Force spaces for display
    local isShiny = model:GetAttribute("IsShiny")
    local nameColor = Color3.new(1,1,1)
    if isShiny then 
        nameStr = "✨ " .. nameStr .. " ✨"
        nameColor = Color3.fromRGB(255, 255, 100)
    end
    addText(nameStr, nameColor, 2, 0.25, Enum.Font.GothamBlack)
    
    -- RARITY
    local tier = model:GetAttribute("Tier") or "Common"
    local tColor = EconomyLogic.RARITY_COLORS[tier] or Color3.new(1,1,1)
    addText(string.upper(tier), tColor, 3, 0.2)
    
    -- MUTATION (NEW)
    local mutationLbl = nil
    local mutationName = model:GetAttribute("Mutation")
    if mutationName and mutationName ~= "" then
        local mutColor = Color3.fromRGB(255, 100, 255) -- Fallback purple
        if MutationDefinitions and MutationDefinitions[mutationName] then
            mutColor = MutationDefinitions[mutationName].Color or mutColor
        end
        mutationLbl = addText("☢ " .. mutationName .. " ☢", mutColor, 4, 0.15, Enum.Font.GothamBold)
    end
    
    -- INCOME
    local incVal = model:GetAttribute("Income") or 0
    local incLbl = addText("+$" .. EconomyLogic.Abbreviate(incVal) .. "/s", Color3.fromRGB(100, 255, 100), 5, 0.25)
    
    -- UPGRADE BUTTON REMOVED (User Request)
    -- Using 'F' ProximityPrompt instead.
    
    -- LOGIC: Update visuals on Attribute Change
    local function update()
        local l = model:GetAttribute("Level") or 1
        local i = model:GetAttribute("Income") or 0
        local tier = model:GetAttribute("Tier") or "Common"
        
        lvlLbl.Text = "Lv " .. l
        incLbl.Text = "+$" .. EconomyLogic.Abbreviate(i) .. "/s"
    end
    
    -- Initial Update
    update()
    
    -- Listeners
    model:GetAttributeChangedSignal("Level"):Connect(update)
    model:GetAttributeChangedSignal("Income"):Connect(update)
    
    -- Mutation listener (if mutation appears later)
    model:GetAttributeChangedSignal("Mutation"):Connect(function()
        local newMut = model:GetAttribute("Mutation")
        if newMut and newMut ~= "" and not mutationLbl then
            local mutColor = Color3.fromRGB(255, 100, 255)
            if MutationDefinitions and MutationDefinitions[newMut] then
                mutColor = MutationDefinitions[newMut].Color or mutColor
            end
            mutationLbl = addText("☢ " .. newMut .. " ☢", mutColor, 4, 0.15, Enum.Font.GothamBold)
        elseif mutationLbl and newMut and MutationDefinitions then
            local mutColor = MutationDefinitions[newMut] and MutationDefinitions[newMut].Color or Color3.fromRGB(255, 100, 255)
            mutationLbl.Text = "☢ " .. newMut .. " ☢"
            mutationLbl.TextColor3 = mutColor
        end
    end)
    
    -- Destroy handler
    model.AncestryChanged:Connect(function(_, parent)
        if not parent then
            bb:Destroy()
        end
    end)
end

local function onUnitAdded(model)
    -- print("[UnitHUD] Signal Received for: " .. model.Name)
    -- task.wait(0.1) -- Minimal yield to allow properties to replicate
    createUnitUI(model)
end

CollectionService:GetInstanceAddedSignal("BrainrotUnit"):Connect(onUnitAdded)

local existingUnits = CollectionService:GetTagged("BrainrotUnit")
-- print("[UnitHUD] Found " .. #existingUnits .. " existing BrainrotUnit(s)")

for _, unit in pairs(existingUnits) do
--    print("[UnitHUD] Processing existing unit: " .. tostring(unit.Name))
    onUnitAdded(unit)
end

-- FALLBACK POLLING (Fixes replication timing issues)
task.spawn(function()
    while true do
        task.wait(5)
        local units = CollectionService:GetTagged("BrainrotUnit")
        for _, u in pairs(units) do
             local hudName = "HUD_" .. u:GetFullName():gsub("[^%w]", "_")
             if not PlayerGui:FindFirstChild(hudName) then
--                 print("[UnitHUD] Polling found missed unit: " .. u.Name)
                 onUnitAdded(u)
             end
        end
    end
end)

-- DEBUG: Monitor Workspace for ANY unit spawning
workspace.DescendantAdded:Connect(function(desc)
    if desc.Name == "Unit_Spawned" then
--        print("[UnitHUD] DEBUG: Unit_Spawned appeared in Workspace at " .. desc:GetFullName())
--        -- Check if it has tag
--        if CollectionService:HasTag(desc, "BrainrotUnit") then
--            print("[UnitHUD] DEBUG: ...and it has the Tag.")
--        else
--            warn("[UnitHUD] DEBUG: ...but it MISSES the BrainrotUnit tag!")
--        end
    end
end)

-- print("[UnitHUD] Client UI System Ready.")
