-- ShopLogic.lua
-- Skill: modular-architecture
-- Description: Core logic for the Shop, refactored for BrainrotData.

local ShopLogic = {}
local ServerScriptService = game:GetService("ServerScriptService")
local BrainrotData = require(ServerScriptService:WaitForChild("BrainrotData"))
local UnitManager = require(ServerScriptService:WaitForChild("UnitManager"))

local PRICES = {
    -- Upgrades
    ["DoubleJump"] = 1000, 
    ["BackpackUpgrade"] = 7500,
}

function ShopLogic.getSpeedPrice(level)
    -- Formula: 2500 * (1.5 ^ Level) -> Reaches Sextillions around Level 120+
    return math.floor(2500 * math.pow(1.5, level or 0))
end

function ShopLogic.processPurchase(player, itemId)
    local data = BrainrotData.getPlayerSession(player)
    if not data then return false, "Error loading data" end
    
    -- 1. Determine Price
    local price = PRICES[itemId]
    if itemId == "SpeedUpgrade" then
        price = ShopLogic.getSpeedPrice(data.SpeedLevel or 0)
    end
    
    if not price then
        return false, "Invalid Item"
    end

    -- 2. Check Ownership (for persistent items)
    if itemId == "DoubleJump" then
        local inventory = player:FindFirstChild("Inventory")
        if inventory and inventory:FindFirstChild("DoubleJump") then
            return false, "Already Owned!"
        end
    end
    
    -- 3. Check Funds & Deduct
    local success = BrainrotData.deductCash(player, price)
    if not success then
        return false, "Need $" .. price
    end
    
    -- 4. Apply Effect
    if string.find(itemId, "Unit_") then
        local unitName = string.sub(itemId, 6)
        local slotFound = UnitManager.placeUnitInFirstEmpty(player, unitName)
        if slotFound then
            return true, "Deployed " .. unitName
        else
            BrainrotData.addCash(player, price)
            return false, "No Slots Free!"
        end
        
    elseif itemId == "BackpackUpgrade" then
        BrainrotData.upgradeCapacity(player, 1)
        return true, "Backpack Upgraded!"
        
    elseif itemId == "SpeedUpgrade" then
        local newLevel = (data.SpeedLevel or 0) + 1
        data.SpeedLevel = newLevel
        
        -- Apply immediately
        local char = player.Character
        local hum = char and char:FindFirstChild("Humanoid")
        if hum then
            hum.WalkSpeed = 16 + BrainrotData.getSpeedBonus(newLevel)
            
            -- VFX
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                local sfx = Instance.new("Sound")
                sfx.SoundId = "rbxassetid://154812393"
                sfx.Pitch = 1 + (newLevel * 0.05)
                sfx.Volume = 0.5
                sfx.Parent = root
                sfx:Play()
                game:GetService("Debris"):AddItem(sfx, 2)
            end
        end
        return true, "Speed Lvl " .. newLevel
        
    elseif itemId == "DoubleJump" then
        -- Add to legacy inventory to ensure PersistenceManager picks it up
        local inventory = player:FindFirstChild("Inventory")
        if inventory then
            local val = Instance.new("StringValue")
            val.Name = "DoubleJump"
            val.Parent = inventory
        end
        
        -- Apply immediately
        local hum = player.Character and player.Character:FindFirstChild("Humanoid")
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower = 100
        end
        return true, "Jump Enabled!"
    end
    
    print(player.Name .. " bought unknown item: " .. itemId)
    return true, "Success!"
end
return ShopLogic
