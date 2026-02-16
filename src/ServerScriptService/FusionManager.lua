-- FusionManager.lua
-- Skill: gacha-mechanics
-- Description: Server-side logic for the Fusion system.

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FusionData = require(ServerScriptService:WaitForChild("FusionData"))
local BrainrotData = require(ServerScriptService:WaitForChild("BrainrotData"))

local FusionManager = {}

-- Create RemoteEvent for client animation
local FusionEvent = ReplicatedStorage:FindFirstChild("FusionEvent")
if not FusionEvent then
    FusionEvent = Instance.new("RemoteEvent")
    FusionEvent.Name = "FusionEvent"
    FusionEvent.Parent = ReplicatedStorage
end

-- Get random model from a tier folder
function FusionManager.getRandomModelFromTier(tier)
    local brainrotFolder = ServerStorage:FindFirstChild("BrainrotModels")
    if not brainrotFolder then return "Unknown_Brainrot" end
    
    local tierFolder = brainrotFolder:FindFirstChild(tier)
    if not tierFolder then 
        warn("[FusionManager] Tier folder not found: " .. tier)
        return "Unknown_Brainrot" 
    end
    
    local models = {}
    for _, child in pairs(tierFolder:GetChildren()) do
        if child:IsA("Model") then
            table.insert(models, child.Name)
        end
    end
    
    if #models == 0 then
        warn("[FusionManager] No models in tier: " .. tier)
        return "Unknown_Brainrot"
    end
    
    return models[math.random(1, #models)]
end

-- Validate fusion request
function FusionManager.validateFusion(player, unitIds)
    if #unitIds ~= FusionData.FUSION_COST then
        return false, "Need exactly " .. FusionData.FUSION_COST .. " units"
    end
    
    local inventory = BrainrotData.getAdvancedInventory(player)
    local selectedUnits = {}
    local commonTier = nil
    
    for _, targetId in ipairs(unitIds) do
        local found = false
        for _, unit in ipairs(inventory) do
            if unit.Id == targetId then
                -- Check if already selected (prevent duplicates)
                if selectedUnits[targetId] then
                    return false, "Duplicate unit selected"
                end
                
                -- Check tier consistency
                if commonTier == nil then
                    commonTier = unit.Tier
                elseif commonTier ~= unit.Tier then
                    return false, "All units must be same tier"
                end
                
                selectedUnits[targetId] = unit
                found = true
                break
            end
        end
        
        if not found then
            return false, "Unit not found in inventory"
        end
    end
    
    -- Check if fusion is possible (not max tier)
    if not FusionData.canFuse(commonTier) then
        return false, "Cannot fuse max tier units"
    end
    
    return true, commonTier, selectedUnits
end

-- Main fusion function
function FusionManager.fuse(player, unitIds)
    -- 1. Validate
    local isValid, tierOrError, selectedUnits = FusionManager.validateFusion(player, unitIds)
    
    if not isValid then
        return {success = false, error = tierOrError}
    end
    
    local currentTier = tierOrError
    
    -- 2. Calculate next tier
    local nextTier = FusionData.TIER_NEXT[currentTier]
    
    -- 3. Remove the 3 units
    local removed = BrainrotData.removeUnitsById(player, unitIds)
    if not removed then
        return {success = false, error = "Failed to remove units"}
    end
    
    -- 4. Get random model from next tier
    local resultModel = FusionManager.getRandomModelFromTier(nextTier)
    
    -- 5. Roll for Shiny
    local isShiny = math.random() < FusionData.SHINY_CHANCE
    
    -- 6. Add new unit
    local newUnit = BrainrotData.addUnitAdvanced(player, resultModel, nextTier, isShiny)
    
    -- 7. Increment stats
    BrainrotData.incrementFusions(player)
    
    -- 8. Prepare result
    local result = {
        success = true,
        sacrificedUnits = selectedUnits,
        resultUnit = newUnit,
        resultName = resultModel,
        resultTier = nextTier,
        isShiny = isShiny,
        tierColor = FusionData.TIER_COLORS[nextTier]
    }
    
    -- 9. Fire client event for 3D animation
    FusionEvent:FireClient(player, result)
    
    return result
end

-- Get fusion preview (for UI)
function FusionManager.getPreview(player, unitIds)
    local isValid, tierOrError, selectedUnits = FusionManager.validateFusion(player, unitIds)
    
    if not isValid then
        return {canFuse = false, reason = tierOrError}
    end
    
    local currentTier = tierOrError
    local nextTier = FusionData.TIER_NEXT[currentTier]
    
    return {
        canFuse = true,
        currentTier = currentTier,
        nextTier = nextTier,
        shinyChance = FusionData.SHINY_CHANCE * 100,
        tierColor = FusionData.TIER_COLORS[nextTier]
    }
end

-- Initialize
function FusionManager.Init()
    print("[FusionManager] Initializing...")
    
    -- Setup remote function for fusion requests
    local fuseFunc = ReplicatedStorage:FindFirstChild("FuseUnits")
    if not fuseFunc then
        fuseFunc = Instance.new("RemoteFunction")
        fuseFunc.Name = "FuseUnits"
        fuseFunc.Parent = ReplicatedStorage
    end
    
    fuseFunc.OnServerInvoke = function(player, unitIds)
        return FusionManager.fuse(player, unitIds)
    end
    
    -- Setup preview function
    local previewFunc = ReplicatedStorage:FindFirstChild("FusionPreview")
    if not previewFunc then
        previewFunc = Instance.new("RemoteFunction")
        previewFunc.Name = "FusionPreview"
        previewFunc.Parent = ReplicatedStorage
    end
    
    previewFunc.OnServerInvoke = function(player, unitIds)
        return FusionManager.getPreview(player, unitIds)
    end
    
    -- Setup inventory sync
    local getInventoryFunc = ReplicatedStorage:FindFirstChild("GetInventory")
    if not getInventoryFunc then
        getInventoryFunc = Instance.new("RemoteFunction")
        getInventoryFunc.Name = "GetInventory"
        getInventoryFunc.Parent = ReplicatedStorage
    end
    
    getInventoryFunc.OnServerInvoke = function(player)
        return BrainrotData.getAdvancedInventory(player)
    end
    
    print("[FusionManager] Initialized.")
end

return FusionManager
