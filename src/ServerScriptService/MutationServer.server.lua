-- MutationServer.server.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local BrainrotData = require(ServerScriptService:WaitForChild("BrainrotData"))
local MutationManager = require(ReplicatedStorage.Modules:WaitForChild("MutationManager"))
local EconomyLogic = require(ReplicatedStorage.Modules:WaitForChild("EconomyLogic"))

-- VFX EVENT
local showVfx = ReplicatedStorage:FindFirstChild("ShowMutationVFX")
if not showVfx then
    showVfx = Instance.new("RemoteEvent")
    showVfx.Name = "ShowMutationVFX"
    showVfx.Parent = ReplicatedStorage
end

local REROLL_COST_CASH = 500000 -- Hardcoded for now

local remote = Instance.new("RemoteFunction")
remote.Name = "RerollMutation"
remote.Parent = ReplicatedStorage

remote.OnServerInvoke = function(player, unitId, mode)
    local data = BrainrotData.getPlayerSession(player)
    if not data then return false, "No Data" end
    
    -- LUCK SYSTEM QUICK QUERY
    if mode == "QueryLuck" then
        return true, {
            Luck = BrainrotData.getLuck(player)
        }
    end
    
    -- Find unit
    local unitData = nil
    if data.AdvancedInventory then
        for _, u in ipairs(data.AdvancedInventory) do
            if u.Id == unitId then unitData = u; break end
        end
    end
    if not unitData and data.PlacedUnits then
        for _, u in pairs(data.PlacedUnits) do
            if u.UnitId == unitId then unitData = u; break end
        end
    end
    
    if not unitData then return false, "Unidad no encontrada" end
    
    -- CALCULATE DYNAMIC PRICE (v4.1 - 5 Minutes of Income)
    local income = EconomyLogic.calculateIncome(
        unitData.Name,
        unitData.Tier or "Common",
        unitData.Level or 1,
        unitData.Shiny or unitData.IsShiny or false,
        unitData.ValueMultiplier or 1.0,
        data.Rebirths or 0,
        unitData.Mutation
    )
    
    local finalPrice = math.max(50000, math.floor(income * 300))
    
    -- LUCK SYSTEM
    local currentLuck = BrainrotData.getLuck(player)
    local luckMultiplier = currentLuck / 100 -- 0.0 to 1.0
    
    if mode == "Query" then
        return true, {
            Price = finalPrice,
            Luck = currentLuck,
            SuccessChance = luckMultiplier -- Simplified indicator
        }
    end
    
    -- REROLL LOGIC
    if data.Cash < finalPrice then
        return false, "Dinero insuficiente"
    end
    
    -- 1. LOCK UNIT & PREPARE REROLL (IMMEDIATE)
    local oldSlot = nil
    if data.Hotbar then
        for slot, id in pairs(data.Hotbar) do
            if id == unitId then
                oldSlot = slot
                data.Hotbar[slot] = "" -- Empty temporarily
                break
            end
        end
    end
    
    -- FORCE UNEQUIP (Visual and Internal Sync)
    local char = player.Character
    if char then
        local human = char:FindFirstChildOfClass("Humanoid")
        if human then
            human:UnequipTools()
        end
    end
    
    unitData.IsMutating = true
    
    -- Deduct Cost & Luck Immediately
    BrainrotData.deductCash(player, finalPrice)
    BrainrotData.consumeLuck(player, 25)
    
    -- Sync Tools (Remove from Backpack/Character immediately)
    BrainrotData.applyCharacterStats(player, player.Character)
    
    -- Fire Stats Changes to hide unit from all UIs
    BrainrotData.StatsChanged:Fire(player, "Hotbar", data.Hotbar)
    BrainrotData.StatsChanged:Fire(player, "AdvancedInventory", data.AdvancedInventory)
    
    -- 2. TRIGGER WORLD & CLIENT VFX
    local vfxRemote = ReplicatedStorage:FindFirstChild("PlayStallVFX")
    if vfxRemote then
        vfxRemote:FireAllClients("MutationAltar")
    end
    
    -- 3. CALCULATE LUCK & ROLL MUTATION
    -- NEW: 100% luck = 100% mutation chance.
    local isSuccess = math.random(1, 100) <= currentLuck 
    
    local rolledMutation = nil
    if isSuccess then
        rolledMutation = MutationManager.pickMutation(luckMultiplier)
    end

    showVfx:FireClient(player, {
        UnitName = unitData.Name,
        Tier = unitData.Tier,
        Mutation = rolledMutation, -- The target mutation (nil if failed)
        IsSuccess = isSuccess,
        UnitId = unitId
    })
    
    -- 4. DELAYED MUTATION & UNLOCK (5.5s Animation)
    task.delay(5.5, function()
        -- Update the unit data
        unitData.Mutation = rolledMutation -- Will be nil if failed (Removing old mutation)
        unitData.IsMutating = nil
        
        -- Restore to Hotbar
        if oldSlot and (not data.Hotbar[oldSlot] or data.Hotbar[oldSlot] == "") then
            data.Hotbar[oldSlot] = unitId
        else
            -- Find first free if old slot taken
            BrainrotData.addToHotbar(player, unitId)
        end
        
        -- Final Sync
        local hotbarSync = game:GetService("ReplicatedStorage"):FindFirstChild("UpdateHotbar")
        if hotbarSync then
            hotbarSync:FireClient(player)
        end
        
        BrainrotData.StatsChanged:Fire(player, "Hotbar", data.Hotbar)
        BrainrotData.StatsChanged:Fire(player, "AdvancedInventory", data.AdvancedInventory)
        
        -- Re-add tool to player
        BrainrotData.applyCharacterStats(player, player.Character)
        
        print(string.format("[MutationAltar] Process complete for %s. New: %s", player.Name, tostring(newMutation)))
    end)
    
    print(string.format("[MutationAltar] %s started mutating %s. Lock active.", player.Name, unitData.Name))
    
    return true, {
        NewMutation = "MUTATING...", -- Feedback for UI
        Price = finalPrice,
        Luck = BrainrotData.getLuck(player)
    }
end
