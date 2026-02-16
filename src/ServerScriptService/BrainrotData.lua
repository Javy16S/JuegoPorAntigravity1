-- BrainrotData.lua
-- Skill: persistence-logic
-- Description: Unified player data system. Key: BrainrotData_V2

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local PlayerDataStore = DataStoreService:GetDataStore("BrainrotData_V2")
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local MutationManager = require(ReplicatedStorage:WaitForChild("MutationManager"))

local BrainrotData = {}
local sessionData = {}
local DATA_VERSION = "V2"

-- NEW: Shared tool creation helper to ensure consistency
function BrainrotData.createUnitTool(name, tier, isShiny, id, level, valueMultiplier)
    local tool = Instance.new("Tool")
    -- USER REQUEST: CLEAN NAMES (No "Unit_" prefix)
    tool.Name = name
    tool.RequiresHandle = true
    
    -- Hidden Handle
    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(1, 1, 1)
    handle.Transparency = 1
    handle.CanCollide = false
    handle.Anchored = false 
    handle.Massless = false 
    handle.Parent = tool
    
    -- FIX: Add RightGripAttachment for proper R15 holding
    local gripAtt = Instance.new("Attachment")
    gripAtt.Name = "RightGripAttachment"
    gripAtt.Parent = handle
    
    -- Attributes (ALL preserved across pickup/place cycles)
    tool:SetAttribute("UnitId", id or HttpService:GenerateGUID(false))
    tool:SetAttribute("Tier", tier or "Common")
    tool:SetAttribute("IsShiny", isShiny or false)
    tool:SetAttribute("Level", level or 1)
    tool:SetAttribute("ValueMultiplier", valueMultiplier or 1.0) -- Persistent multiplier
    tool:SetAttribute("Secured", id ~= nil)
    
    -- Visual Model (Robust Lookup)
    local brainrotModels = ServerStorage:FindFirstChild("BrainrotModels")
    local template = nil
    if brainrotModels then
        -- Try exact match, then sanitized match (no prefix)
        template = brainrotModels:FindFirstChild(name, true)
        if not template then
            local cleanName = string.gsub(name, "Unit_", "")
            template = brainrotModels:FindFirstChild(cleanName, true)
        end
    end
    
    if template then
        local visual = template:Clone()
        visual.Name = "Visual"
        
        -- 1. AGGRESSIVE SANITIZATION
        for _, v in pairs(visual:GetDescendants()) do
            if v:IsA("LuaSourceContainer") or v:IsA("Humanoid") or v:IsA("GuiBase3d") then
                v:Destroy()
            end
        end

        -- 2. Ensure Model has PrimaryPart for positioning
        local rootPart = nil
        if visual:IsA("Model") then
            rootPart = visual.PrimaryPart or visual:FindFirstChildWhichIsA("BasePart", true)
            if rootPart then visual.PrimaryPart = rootPart else 
                -- Create invisible root if none exists to hold the model together
                rootPart = Instance.new("Part")
                rootPart.Name = "AutoRoot"
                rootPart.Transparency = 1; rootPart.CanCollide = false; rootPart.Massless = true; rootPart.Size = Vector3.one
                rootPart.Parent = visual; visual.PrimaryPart = rootPart
            end
        elseif visual:IsA("BasePart") then
            rootPart = visual
        end

        if rootPart then
            -- 3. CLEAN & PREP PHYSICS (Force everything static first)
            for _, p in pairs(visual:GetDescendants()) do
                if p:IsA("JointInstance") or p:IsA("Constraint") then
                    p:Destroy() -- Strip old welds/bones that might fight us
                elseif p:IsA("BasePart") then
                    p.Anchored = true
                    p.CanCollide = false
                    p.Massless = true
                end
            end
            if visual:IsA("BasePart") then visual.Anchored = true end

            -- 4. POSITION AT HANDLE (Perfect move because everything is anchored)
            if visual:IsA("Model") then
                visual:PivotTo(handle.CFrame)
            else
                visual.CFrame = handle.CFrame
            end

            -- 5. Weld Root to Handle FIRST (Before unanchoring anything)
            -- FIX: Use WeldConstraint for robust "freeze in place" attachment
            -- 5. Weld Root to Handle FIRST (Before unanchoring anything)
            -- 5. Weld Root to Handle FIRST (Before unanchoring anything)
            -- FIX: Use WeldConstraint for robust "freeze in place" attachment
            local mainWeld = Instance.new("WeldConstraint")
            mainWeld.Name = "HandleWeldConstraint"
            mainWeld.Part0 = handle
            mainWeld.Part1 = rootPart
            mainWeld.Parent = handle

            -- 6. APPLY INTERNAL WELDS AND UNANCHOR
            local function applyRigidWelds(modelRoot)
                for _, p in pairs(visual:GetDescendants()) do
                    if p:IsA("BasePart") and p ~= modelRoot then
                        local wc = Instance.new("WeldConstraint")
                        wc.Name = "RigidWeldConstraint"
                        wc.Part0 = modelRoot
                        wc.Part1 = p
                        wc.Parent = p
                        
                        p.Massless = true
                        p.CanCollide = false
                        p.Anchored = false 
                    end
                end
                
                -- CRITICAL: Unanchor root AFTER welding to Handle
                if modelRoot:IsA("BasePart") then
                    modelRoot.Anchored = false
                    modelRoot.CanCollide = false
                    modelRoot.Massless = true
                end
            end
            applyRigidWelds(rootPart)
            
            -- Force Position Update (Just in Case)
            if visual:IsA("Model") then
                visual:PivotTo(handle.CFrame)
            else
                visual.CFrame = handle.CFrame
            end
        end
        
    -- Apply Visual Effects (Auras, etc) (Pass nil for default)
    MutationManager.applyMutation(visual, tier, isShiny, true)
    visual.Parent = tool
    else
        -- Fallback if model missing
        handle.Transparency = 0
        handle.Color = Color3.fromRGB(255, 0, 0)
        handle.Material = Enum.Material.Neon
    end
    
    return tool
end

-- NEW: Upgrade Unit Level
function BrainrotData.upgradeUnitLevel(player, unitId)
    local data = BrainrotData.getPlayerSession(player)
    if not data or not data.AdvancedInventory then return false, "No Data" end
    
    for _, unit in ipairs(data.AdvancedInventory) do
        if unit.Id == unitId then
            if (unit.Level or 1) >= 150 then
                return false, "Max Level Reached!"
            end
            
            unit.Level = (unit.Level or 1) + 1
            print(string.format("[BrainrotData] Upgraded unit %s to Level %d", unit.Name, unit.Level))
            return true, unit.Level
        end
    end
    return false, "Unit Not Found"
end

print("[BrainrotData] Module Memory ID: " .. tostring(BrainrotData))

-- TEMPLATE
local PLAYER_TEMPLATE = {
    Cash = 1000,
    Rank = "Bronze",
    Income = 0,
    TotalCoinsEarned = 0,
    EggsOpened = 0,
    FusionsPerformed = 0,
    Discoveries = {}, -- List of brainrot names
    AdvancedInventory = {}, -- { {Id, Name, Tier, Shiny, AcquiredAt} }
    UnitInventory = {}, -- LEGACY
    PlacedUnits = {}, -- { [slotIndex] = unitName }
    LastPlaytime = 0,
    SpeedLevel = 0, -- Level of speed upgrades (0 to 5)
    BackpackLevel = 0, -- Level of backpack upgrades
    BackpackCapacity = 5, -- Default starting slots
}

-----------------------------------------------------------
-- HELPER: Generate Unique ID
-----------------------------------------------------------
function BrainrotData.generateUUID()
    return HttpService:GenerateGUID(false)
end

function BrainrotData.getSpeedBonus(level)
    return (level or 0) * 3 -- +3 WalkSpeed per level (Lvl 130 = +390)
end

-----------------------------------------------------------
-- CORE: Data Management
-----------------------------------------------------------

local function setupLeaderstats(player, data)
    local ls = Instance.new("Folder")
    ls.Name = "leaderstats"
    ls.Parent = player
    
    local cash = Instance.new("NumberValue")
    cash.Name = "Cash"
    cash.Value = data.Cash
    cash.Parent = ls
    
    local rank = Instance.new("StringValue")
    rank.Name = "Rank"
    rank.Value = data.Rank
    rank.Parent = ls
end

local function savePlayerData(player)
    local data = sessionData[player.UserId]
    if not data then return end
    
    local success, err = pcall(function()
        PlayerDataStore:SetAsync(tostring(player.UserId), data)
    end)
    
    if success then
        print("[BrainrotData] Data saved for " .. player.Name)
    else
        warn("[BrainrotData] Failed to save for " .. player.Name .. ": " .. tostring(err))
    end
end

local function onPlayerAdded(player)
    print("[BrainrotData] onPlayerAdded starting for " .. player.Name .. " (ID: " .. player.UserId .. ")")
    
    if sessionData[player.UserId] then 
        warn("[BrainrotData] sessionData already exists for " .. player.Name .. ", skipping load.")
        return 
    end
    
    -- Initialize with template values
    local data = {}
    for k, v in pairs(PLAYER_TEMPLATE) do
        if type(v) == "table" then
            data[k] = {}
        else
            data[k] = v
        end
    end
    
    -- Load from DS
    local success, saved = pcall(function()
        return PlayerDataStore:GetAsync(tostring(player.UserId))
    end)
    
    if success and saved then
        -- Reconciliation (Merge saved into data)
        for k, v in pairs(saved) do 
            data[k] = v 
        end
        print("[BrainrotData] Loaded DataStore for " .. player.Name)
        
        -- MIGRATION: UnitInventory -> AdvancedInventory
        if data.UnitInventory and #data.UnitInventory > 0 then
            print("[BrainrotData] Migrating " .. #data.UnitInventory .. " legacy units for " .. player.Name)
            if not data.AdvancedInventory then data.AdvancedInventory = {} end
            
            for _, unitId in ipairs(data.UnitInventory) do
                local name = string.gsub(unitId, "Unit_", "")
                table.insert(data.AdvancedInventory, {
                    Id = BrainrotData.generateUUID(),
                    Name = name,
                    Tier = "Common",
                    Shiny = false,
                    AcquiredAt = os.time()
                })
            end
            data.UnitInventory = {} 
            savePlayerData(player) 
        end

        -- SANITIZATION (Ensure all units have IDs)
        if data.AdvancedInventory then
            local fixes = 0
            for _, unit in ipairs(data.AdvancedInventory) do
                if not unit.Id then
                    unit.Id = BrainrotData.generateUUID()
                    fixes += 1
                end
                if not unit.Tier then unit.Tier = "Common" end
            end
            if fixes > 0 then savePlayerData(player) end
        end
    else
        print("[BrainrotData] New Player (or Load Fail): " .. player.Name)
    end
    
    sessionData[player.UserId] = data
    setupLeaderstats(player, data)
    
    player.CharacterAdded:Connect(function(char)
        print("[BrainrotData] CharacterAdded for " .. player.Name .. ". Distributing tools...")
        char:SetAttribute("Rank", data.Rank)
        char:SetAttribute("Income", data.Income)
        
        -- Apply Speed Upgrade
        local hum = char:WaitForChild("Humanoid")
        local bonus = BrainrotData.getSpeedBonus(data.SpeedLevel or 0)
        if bonus > 0 then
            task.delay(1, function() -- Small delay to ensure other scripts don't override 
                if hum and hum.Parent then
                    hum.WalkSpeed = 16 + bonus -- BASE + BONUS
                end
            end)
        end
        
        local backpack = player:FindFirstChild("Backpack")
        if data.AdvancedInventory and backpack then
            for _, unit in ipairs(data.AdvancedInventory) do
                local toolName = unit.Name
                -- Compatibility check for old tools or clean tools
                local found = backpack:FindFirstChild(toolName) or backpack:FindFirstChild("Unit_" .. toolName)
                local foundChar = char:FindFirstChild(toolName) or char:FindFirstChild("Unit_" .. toolName)
                
                if not found and not foundChar then
                    local tool = BrainrotData.createUnitTool(unit.Name, unit.Tier, unit.Shiny, unit.Id, unit.Level, unit.ValueMultiplier)
                    tool.Parent = backpack
                end
            end
        end
    end)
    
    if player.Character then
        player.Character:SetAttribute("Rank", data.Rank)
        player.Character:SetAttribute("Income", data.Income)
    end
end

-----------------------------------------------------------
-- INTER-SCRIPT API
-----------------------------------------------------------

function BrainrotData.getPlayerSession(player)
    return sessionData[player.UserId]
end

function BrainrotData.getAdvancedInventory(player)
    local data = BrainrotData.getPlayerSession(player)
    local inv = data and data.AdvancedInventory or {}
    print(string.format("[BrainrotData] getAdvancedInventory for %s -> Returning %d units.", player.Name, #inv))
    return inv
end

function BrainrotData.addUnitAdvanced(player, rawName, tier, isShiny, skipTool, level, existingId, existingValueMult)
    local data = BrainrotData.getPlayerSession(player)
    if not data then return nil end
    
    -- Sanitize Name (Trim spaces AND Replace underscores)
    local name = rawName:gsub("_", " "):match("^%s*(.-)%s*$")
    
    -- Use existing values OR generate new ones
    local EconomyLogic = require(ReplicatedStorage:WaitForChild("EconomyLogic"))
    local valueMult = existingValueMult or EconomyLogic.generateValueMultiplier()
    local unitId = existingId or BrainrotData.generateUUID()
    
    local unitData = {
        Id = unitId,
        Name = name,
        Tier = tier or "Common",
        Shiny = isShiny or false,
        Level = level or 1,
        ValueMultiplier = valueMult,
        AcquiredAt = os.time()
    }
    
    if not data.AdvancedInventory then data.AdvancedInventory = {} end
    table.insert(data.AdvancedInventory, unitData)
    print(string.format("[BrainrotData] ADDED '%s' (Lv%d, x%.1f mult) to %s. Total: %d", name, unitData.Level, valueMult, player.Name, #data.AdvancedInventory))
    
    -- Give Tool (Optional)
    if not skipTool then
        local backpack = player:FindFirstChild("Backpack")
        if backpack then
            local tool = BrainrotData.createUnitTool(name, tier, isShiny, unitData.Id, unitData.Level, unitData.ValueMultiplier)
            tool.Parent = backpack
        end
    end
    
    BrainrotData.markDiscovered(player, name, tier, isShiny)
    return unitData
end

-- Wrapper for backwards compatibility + new params
function BrainrotData.addUnit(player, unitName, tier, isShiny, level, existingId, existingValueMult)
    local name = string.gsub(unitName, "Unit_", "")
    return BrainrotData.addUnitAdvanced(player, name, tier or "Common", isShiny or false, false, level, existingId, existingValueMult) ~= nil
end

function BrainrotData.removeUnitsById(player, unitIds)
    local data = BrainrotData.getPlayerSession(player)
    if not data or not data.AdvancedInventory then return false end
    
    local idsToRemove = {}
    for _, id in ipairs(unitIds) do idsToRemove[id] = true end
    
    local newInv = {}
    local count = 0
    for _, unit in ipairs(data.AdvancedInventory) do
        if idsToRemove[unit.Id] then
            count += 1
        else
            table.insert(newInv, unit)
        end
    end
    
    data.AdvancedInventory = newInv
    
    -- PHYSICAL REMOVAL: Destroy tools in Backpack or Character
    local character = player.Character
    local backpack = player:FindFirstChild("Backpack")
    
    local function cleanupIn(container)
        if not container then return end
        for _, tool in pairs(container:GetChildren()) do
            if tool:IsA("Tool") then
                local uId = tool:GetAttribute("UnitId")
                if uId and idsToRemove[uId] then
                    tool:Destroy()
                end
            end
        end
    end
    
    cleanupIn(backpack)
    cleanupIn(character)

    print(string.format("[BrainrotData] REMOVED %d units and tools. Remaining: %d", count, #data.AdvancedInventory))
    return true
end

function BrainrotData.removeUnit(player, unitId)
    -- Legacy support for removal by name
    local data = BrainrotData.getPlayerSession(player)
    if not data or not data.AdvancedInventory then return nil end
    -- CANONICAL COMPARISON (Infalible)
    -- Remover "Unit_", espacios, guiones bajos y pasar a minúsculas
    local function toCanonical(str)
        if not str then return "" end
        local s = string.gsub(str, "Unit_", "") -- Remove Prefix first
        s = string.gsub(s, "[_ ]", "") -- Remove all separators
        return string.lower(s) -- Lowercase
    end

    local targetCanonical = toCanonical(unitId)
    -- DEBUG: Print what we are looking for
    -- print("[BrainrotData] Looking for Canonical: " .. targetCanonical) 
    
    for i = #data.AdvancedInventory, 1, -1 do
        local u = data.AdvancedInventory[i]
        
        -- 1. Check ID Match (Strong/Precision)
        if u.Id and u.Id == unitId then
             table.remove(data.AdvancedInventory, i)
             return u
        end

        -- 2. Check Name Match (Legacy/Canonical)
        local storedName = u.Name
        local storedCanonical = toCanonical(storedName)
        
        if storedCanonical == targetCanonical then
            local removedUnit = u
            table.remove(data.AdvancedInventory, i)
            return removedUnit
        end
    end
    
    -- Si llegamos aqui, imprime el inventario para ver que pasaba
    warn("[BrainrotData] FAILED TO FIND: " .. targetCanonical)
    warn("--- Current Inventory DUMP ---")
    for _, u in ipairs(data.AdvancedInventory) do
        warn(" > " .. toCanonical(u.Name) .. " (" .. u.Name .. ")")
    end
    warn("------------------------------")
    
    return nil
end

function BrainrotData.addCash(player, amount)
    local data = BrainrotData.getPlayerSession(player)
    if data then
        data.Cash += amount
        if player:FindFirstChild("leaderstats") then
             player.leaderstats.Cash.Value = data.Cash
        end
    end
end

function BrainrotData.deductCash(player, amount)
    local data = BrainrotData.getPlayerSession(player)
    if data and data.Cash >= amount then
        data.Cash -= amount
        if player:FindFirstChild("leaderstats") then
             player.leaderstats.Cash.Value = data.Cash
        end
        return true
    end
    return false
end

function BrainrotData.upgradeCapacity(player, amount)
    local data = BrainrotData.getPlayerSession(player)
    if data then
        data.BackpackLevel = (data.BackpackLevel or 0) + 1
        data.BackpackCapacity = (data.BackpackCapacity or 5) + (amount or 1)
        print(string.format("[BrainrotData] %s upgraded capacity to %d (Lvl %d)", player.Name, data.BackpackCapacity, data.BackpackLevel))
        return true
    end
    return false
end

function BrainrotData.markDiscovered(player, name, tier, isShiny)
    local data = BrainrotData.getPlayerSession(player)
    if not data then return end
    
    if not data.Discoveries then data.Discoveries = {} end
    
    -- Legacy: just name
    if not table.find(data.Discoveries, name) then
        table.insert(data.Discoveries, name)
    end
    
    -- Modern: Name_Tier
    if tier then
        local key = name .. "_" .. tier
        if not table.find(data.Discoveries, key) then
            table.insert(data.Discoveries, key)
        end
    end
    
    -- Modern: Shiny
    if isShiny and tier then
        local key = name .. "_" .. tier .. "_SHINY"
        if not table.find(data.Discoveries, key) then
            table.insert(data.Discoveries, key)
        end
    end
end

-- Helper for Client Index
function BrainrotData.getDiscoveredMap(player)
    local data = BrainrotData.getPlayerSession(player)
    local map = {}
    if data and data.Discoveries then
        for _, disc in ipairs(data.Discoveries) do
            map[disc] = true
        end
    end
    return map
end

function BrainrotData.getPlacedUnits(player)
    local data = BrainrotData.getPlayerSession(player)
    return data and data.PlacedUnits or {}
end

function BrainrotData.setPlacedUnit(player, slotIndex, unitName, isShiny, unitId, level, valueMultiplier, tier)
    local data = BrainrotData.getPlayerSession(player)
    if not data then return end
    if not data.PlacedUnits then data.PlacedUnits = {} end
    
    if unitName == nil then
        data.PlacedUnits[tostring(slotIndex)] = nil
    else
        -- NOTE (2026-02-04): Must save Tier to prevent tier mismatches on restore!
        data.PlacedUnits[tostring(slotIndex)] = {
            Name = unitName,
            Shiny = isShiny or false,
            UnitId = unitId,
            Level = level or 1,
            ValueMultiplier = valueMultiplier or 1.0,
            Tier = tier or "Common"
        }
    end
end

function BrainrotData.incrementEggsOpened(player)
    local data = BrainrotData.getPlayerSession(player)
    if data then data.EggsOpened += 1 end
end

function BrainrotData.upgradeUnitLevel(player, unitId)
    local data = BrainrotData.getPlayerSession(player)
    if not data then return false, "No Data" end
    
    -- Lazy require to prevent circular dependency issues
    local EconomyLogic = require(game:GetService("ReplicatedStorage").EconomyLogic)

    -- 1. Check Placed Units (Tycoon Slots)
    if data.PlacedUnits then
        for slotId, unitData in pairs(data.PlacedUnits) do
            if unitData.UnitId == unitId then
                 local lvl = unitData.Level or 1
                 local tier = unitData.Tier or "Common"
                 local cost = EconomyLogic.calculateUpgradeCost(tier, lvl)
                 
                 if not BrainrotData.deductCash(player, cost) then
                     return false, "Need $" .. EconomyLogic.Abbreviate(cost)
                 end
                 
                 unitData.Level = lvl + 1
                 -- unitData.ValueMultiplier is preserved
                 
                 return true, unitData.Level
            end
        end
    end
    
    -- 2. Check Inventory (Backpack/Storage)
    if data.AdvancedInventory then
        for _, unitData in ipairs(data.AdvancedInventory) do
            -- unitData handles UnitId directly
            if unitData.UnitId == unitId then
                 local lvl = unitData.Level or 1
                 local tier = unitData.Tier or "Common"
                 local cost = EconomyLogic.calculateUpgradeCost(tier, lvl)
                 
                  if not BrainrotData.deductCash(player, cost) then
                     return false, "Need $" .. EconomyLogic.Abbreviate(cost)
                 end
                 
                 unitData.Level = lvl + 1
                 return true, unitData.Level
            end
        end
    end
    
    return false, "Unit not found"
end

function BrainrotData.incrementFusions(player)
    local data = BrainrotData.getPlayerSession(player)
    if data then data.FusionsPerformed += 1 end
end

function BrainrotData.Init()
    print("[BrainrotData] Initializing...")
    
    Players.PlayerAdded:Connect(onPlayerAdded)
    for _, p in pairs(Players:GetPlayers()) do
        onPlayerAdded(p)
    end
    
    Players.PlayerRemoving:Connect(function(player)
        savePlayerData(player)
        sessionData[player.UserId] = nil
    end)
    
    -- Auto-save loop
    spawn(function()
        while true do
            task.wait(60)
            for _, player in pairs(Players:GetPlayers()) do
                savePlayerData(player)
            end
        end
    end)
    
    -- API for Client Index
    local rf = ReplicatedStorage:WaitForChild("GetDiscovered")
    rf.OnServerInvoke = function(player)
        return BrainrotData.getDiscoveredMap(player)
    end
end

return BrainrotData
