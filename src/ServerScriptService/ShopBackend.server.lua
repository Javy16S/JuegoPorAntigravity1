-- ShopBackend.server.lua
-- Skill: secure-remote-handling
-- Description: Handles server-side validation for shop purchases and selling.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Require Module
local ShopLogic = require(ServerScriptService:WaitForChild("ShopLogic"))
local EconomyLogic = require(ReplicatedStorage:WaitForChild("EconomyLogic"))
local BrainrotData = require(ServerScriptService:WaitForChild("BrainrotData"))

-- Create RemoteFunctions
local function ensureRemote(name)
    if not ReplicatedStorage:FindFirstChild(name) then
        local r = Instance.new("RemoteFunction")
        r.Name = name
        r.Parent = ReplicatedStorage
    end
    return ReplicatedStorage[name]
end

local purchaseFunc = ensureRemote("PurchaseSkill")
local sellFunc = ensureRemote("SellUnits") -- Legacy support (list of IDs)
local sellAllFunc = ensureRemote("SellAllUnits")
local sellHandFunc = ensureRemote("SellHandUnit")
local getValuesFunc = ensureRemote("GetSellValues")
local getUpgradeFunc = ensureRemote("GetUpgradeData")
local inventoryFunc = ensureRemote("GetInventory")

-----------------------------------------------------------
-- HANDLERS
-----------------------------------------------------------

-- 1. Get Sell Values (For UI Labels)
local function handleGetValues(player)
    
    local session = BrainrotData.getPlayerSession(player)
    if not session then return {total = 0, hand = 0} end
    
    local inv = session.AdvancedInventory or {}
    
    -- Calculate Total
    local totalVal = 0
    for _, unit in ipairs(inv) do
        totalVal += EconomyLogic.calculateSellPrice(unit)
    end
    
    -- Calculate Hand Unit Value
    local handVal = 0
    local char = player.Character
    if char then
        local tool = char:FindFirstChildWhichIsA("Tool")
        -- Modern: Check for Tier attribute
        if tool and tool:GetAttribute("Tier") then
            local toolId = tool:GetAttribute("UnitId")
            for _, u in ipairs(inv) do
                if u.Id == toolId then
                    handVal = EconomyLogic.calculateSellPrice(u)
                    break
                end
            end
        end
    end
    
    return {total = totalVal, hand = handVal, count = #inv}
end

-- 2. Sell All
local function handleSellAll(player)
    
    local session = BrainrotData.getPlayerSession(player)
    if not session then return {success = false} end
    
    local inv = session.AdvancedInventory or {}
    if #inv == 0 then return {success = false, msg = "Nothing to sell!"} end
    
    local totalValue = 0
    for _, unit in ipairs(inv) do
        totalValue += EconomyLogic.calculateSellPrice(unit)
    end
    
    -- Clear Inventory Data
    session.AdvancedInventory = {}
    
    -- Give Cash
    BrainrotData.addCash(player, totalValue)
    
    -- Clear Physical Tools
    local backpack = player:FindFirstChild("Backpack")
    if backpack then backpack:ClearAllChildren() end
    
    local char = player.Character
    if char then
        for _, t in pairs(char:GetChildren()) do
            -- Modern: Check for Tier attribute (indicates it's a unit tool)
            if t:IsA("Tool") and t:GetAttribute("Tier") then
                t:Destroy()
            end
        end
    end
    
    print(string.format("[Shop] %s SOLD ALL (%d units) for $%d", player.Name, #inv, totalValue))
    return {success = true, earned = totalValue}
end

-- 3. Sell Hand
local function handleSellHand(player)
    print("[Shop] handleSellHand called for " .. player.Name)
    
    local char = player.Character
    if not char then return {success = false} end
    
    local tool = char:FindFirstChildWhichIsA("Tool")
    -- Modern: Check for Tier attribute
    if not tool or not tool:GetAttribute("Tier") then
        return {success = false, msg = "Hold a unit!"}
    end
    
    local unitId = tool:GetAttribute("UnitId")
    local unitName = tool.Name
    local session = BrainrotData.getPlayerSession(player)
    local inv = session and session.AdvancedInventory or {}
    
    print("[Shop] Looking for unitId: " .. tostring(unitId) .. " in " .. #inv .. " inventory items")
    
    -- Find unit by ID
    local soldUnit = nil
    local soldIndex = -1
    
    for i, u in ipairs(inv) do
        if u.Id == unitId then
            soldUnit = u
            soldIndex = i
            break
        end
    end
    
    if soldUnit then
        local val = EconomyLogic.calculateSellPrice(soldUnit)
        
        -- Remove Data
        table.remove(inv, soldIndex)
        
        -- Give Cash
        BrainrotData.addCash(player, val)
        
        -- Remove Tool
        tool:Destroy()
        
        print(string.format("[Shop] %s sold HAND (%s) for $%s (x%.1f mult)", player.Name, unitName, EconomyLogic.Abbreviate(val), soldUnit.ValueMultiplier or 1.0))
        return {success = true, earned = val}
    else
        -- Unit tool exists but not in data? Calculate from attributes
        local tier = tool:GetAttribute("Tier") or "Common"
        local isShiny = tool:GetAttribute("IsShiny") or false
        local level = tool:GetAttribute("Level") or 1
        local valueMult = tool:GetAttribute("ValueMultiplier") or 1.0
        
        local val = EconomyLogic.calculateSellPrice({
            Name = unitName, 
            Tier = tier, 
            Shiny = isShiny, 
            Level = level,
            ValueMultiplier = valueMult
        })
        
        BrainrotData.addCash(player, val)
        tool:Destroy()
        
        print(string.format("[Shop] %s sold UNSECURED HAND (%s) for $%s", player.Name, unitName, EconomyLogic.Abbreviate(val)))
        return {success = true, earned = val}
    end
end

-- 4. Legacy Sell (IDs) - Keeping for compatibility if needed
local function handleSellLegacy(player, unitIds)
    return {success = false, msg = "Use Sell All"}
end

local function handleGetInventory(player)
    return BrainrotData.getAdvancedInventory(player)
end

-- BIND
purchaseFunc.OnServerInvoke = function(p, id) return ShopLogic.processPurchase(p, id) end
sellFunc.OnServerInvoke = handleSellLegacy
sellAllFunc.OnServerInvoke = handleSellAll
sellHandFunc.OnServerInvoke = handleSellHand
getValuesFunc.OnServerInvoke = handleGetValues
getUpgradeFunc.OnServerInvoke = function(player)
    local session = BrainrotData.getPlayerSession(player)
    local level = session and session.SpeedLevel or 0
    return {
        Level = level,
        Price = ShopLogic.getSpeedPrice(level)
    }
end
inventoryFunc.OnServerInvoke = handleGetInventory

-- 5. UPGRADE UNIT (Brainrot Leveling)
local upgradeUnitFunc = ensureRemote("UpgradeUnit")

local function handleUpgradeUnit(player, unitId)
    print("[ShopBackend] Upgrade request for UnitId: " .. tostring(unitId))
    
    local session = BrainrotData.getPlayerSession(player)
    if not session then 
        warn("[ShopBackend] No session for player!")
        return {success = false} 
    end
    
    local inv = session.AdvancedInventory or {}
    print("[ShopBackend] Inventory has " .. #inv .. " units. Searching...")
    
    local targetUnit = nil
    for i, u in ipairs(inv) do
        print("[ShopBackend] Unit " .. i .. ": Id=" .. tostring(u.Id) .. " Name=" .. tostring(u.Name))
        if u.Id == unitId then 
            targetUnit = u
            print("[ShopBackend] MATCH FOUND at index " .. i)
            break 
        end
    end
    
    if not targetUnit then 
        warn("[ShopBackend] Unit not found in inventory! UnitId: " .. tostring(unitId))
        return {success = false, msg = "Unit not found"} 
    end
    
    local level = targetUnit.Level or 1
    if level >= 150 then return {success = false, msg = "Max Level!"} end
    
    -- Cost Formula: BaseSellValue * (1.15 ^ Level)
    -- This ensures upgrading a Celestial (Base $250T) costs Trillions, but Common costs hundreds.
    local baseValue = EconomyLogic.calculateSellPrice({Tier = targetUnit.Tier, Shiny = false, Level = 1})
    if baseValue < 100 then baseValue = 100 end -- Min floor
    
    local price = math.floor(baseValue * math.pow(1.15, level))
    
    if not BrainrotData.deductCash(player, price) then
        return {success = false, msg = "Need $" .. EconomyLogic.Abbreviate(price)} 
    end
    
    local success, newLevel = BrainrotData.upgradeUnitLevel(player, unitId)
    if success then
        -- UPDATE WORLD ATTRIBUTES (Replicates to Client Logic & Accumulation Loop)
        local CollectionService = game:GetService("CollectionService")
        for _, part in pairs(CollectionService:GetTagged("BrainrotUnit")) do
            if part:GetAttribute("UnitId") == unitId then
                -- 1. Update LeveL
                part:SetAttribute("Level", newLevel)
                
                -- 2. Update Income (Crucial for Return and UI)
                local name = part:GetAttribute("UnitName")
                local tier = part:GetAttribute("Tier")
                local isShiny = part:GetAttribute("IsShiny")
                local valueMult = part:GetAttribute("ValueMultiplier") or 1.0
                
                local newIncome = EconomyLogic.calculateIncome(name, tier, newLevel, isShiny, valueMult)
                part:SetAttribute("Income", newIncome)
                
                break -- Found the unit
            end
        end
        return {success = true, level = newLevel}
    else
        BrainrotData.addCash(player, price) -- Refund
        return {success = false, msg = "Error upgrading"}
    end
end

upgradeUnitFunc.OnServerInvoke = handleUpgradeUnit
