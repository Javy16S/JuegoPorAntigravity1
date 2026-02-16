-- UnitHUD.client.lua
-- Skill: interactive-ui
-- Description: Manages the overhead UI for units LOCALLY to ensure smooth buttons and instant updates.
-- Replaces server-side UI.

print("[UnitHUD] Script starting...")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Require EconomyLogic with error handling
local EconomyLogic
local success, err = pcall(function()
    EconomyLogic = require(ReplicatedStorage:WaitForChild("EconomyLogic", 10))
end)
if not success then
    warn("[UnitHUD] Failed to load EconomyLogic: " .. tostring(err))
    return -- Exit script if module fails
end
print("[UnitHUD] EconomyLogic loaded.")

-- Remote for Upgrading (optional, don't block if missing)
local upgradeRemote = ReplicatedStorage:FindFirstChild("UpgradeUnit")
if not upgradeRemote then
    print("[UnitHUD] UpgradeUnit remote not found, waiting...")
    upgradeRemote = ReplicatedStorage:WaitForChild("UpgradeUnit", 10)
end
print("[UnitHUD] Upgrade remote: " .. tostring(upgradeRemote))

-- UI CONSTANTS
local UI_OFFSET = Vector3.new(0, 4.5, 0)
local UI_SIZE = UDim2.new(5, 0, 3, 0) -- Scaled size

local function createUnitUI(model)
    if not model then 
        warn("[UnitHUD] createUnitUI called with nil model")
        return 
    end
    
    -- Find the best part to attach the UI to
    local adornee = model.PrimaryPart or model:FindFirstChild("Head") or model:FindFirstChildWhichIsA("BasePart")
    if not adornee then
        warn("[UnitHUD] No valid BasePart found in model: " .. model.Name)
        return
    end
    
    print("[UnitHUD] Creating UI for: " .. model.Name .. " (Adornee: " .. adornee.Name .. ")")
    
    -- Cleanup existing
    local hudName = "HUD_" .. model:GetFullName():gsub("[^%w]", "_")
    if PlayerGui:FindFirstChild(hudName) then
        PlayerGui[hudName]:Destroy()
    end
    
    -- Create Billboard in PlayerGui (Adornee pattern for reliable clicks)
    local bb = Instance.new("BillboardGui")
    bb.Name = hudName
    bb.Adornee = adornee
    bb.Size = UI_SIZE
    bb.StudsOffset = UI_OFFSET
    bb.AlwaysOnTop = false -- Keep depth
    bb.MaxDistance = 40
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
    local nameStr = model:GetAttribute("UnitName") or model.Name
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
    
    -- INCOME
    local incVal = model:GetAttribute("Income") or 0
    local incLbl = addText("+$" .. EconomyLogic.Abbreviate(incVal) .. "/s", Color3.fromRGB(100, 255, 100), 4, 0.25)
    
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
    
    -- Destroy handler
    model.AncestryChanged:Connect(function(_, parent)
        if not parent then
            bb:Destroy()
        end
    end)
end

local function onUnitAdded(model)
    task.wait(0.5) -- Wait for attributes
    createUnitUI(model)
end

CollectionService:GetInstanceAddedSignal("BrainrotUnit"):Connect(onUnitAdded)

local existingUnits = CollectionService:GetTagged("BrainrotUnit")
print("[UnitHUD] Found " .. #existingUnits .. " existing BrainrotUnit(s)")

for _, unit in pairs(existingUnits) do
    print("[UnitHUD] Processing existing unit: " .. tostring(unit.Name))
    onUnitAdded(unit)
end

print("[UnitHUD] Client UI System Ready.")
