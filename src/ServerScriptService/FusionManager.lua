--!strict
-- FusionManager.lua
-- Skill: gacha-mechanics
-- Description: Server-side logic for the Fusion system.

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FusionData = require(ServerScriptService:WaitForChild("FusionData"))
local BrainrotData = require(ServerScriptService:WaitForChild("BrainrotData"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MutationManager = require(ReplicatedStorage.Modules:WaitForChild("MutationManager"))
local EconomyLogic = require(ReplicatedStorage.Modules:WaitForChild("EconomyLogic"))

export type Unit = EconomyLogic.Unit

export type FusionResult = {
    success: boolean,
    error: string?,
    sacrificedUnits: { [string]: Unit }?,
    resultUnit: Unit?,
    resultName: string?,
    resultTier: string?,
    isShiny: boolean?,
    tierColor: Color3?
}

local FusionManager = {}

-- Create RemoteEvent for client animation
local FusionEvent = ReplicatedStorage:FindFirstChild("FusionEvent") or Instance.new("RemoteEvent")
FusionEvent.Name = "FusionEvent"
FusionEvent.Parent = ReplicatedStorage

-- Get random model from a tier folder
function FusionManager.getRandomModelFromTier(tier: string): string
    local brainrotFolder = ServerStorage:FindFirstChild("BrainrotModels")
    if not brainrotFolder then return "Unknown_Brainrot" end
    
    local tierFolder = brainrotFolder:FindFirstChild(tier)
    if not tierFolder then 
        warn("[FusionManager] Tier folder not found: " .. tier)
        return "Unknown_Brainrot" 
    end
    
    local models: {string} = {}
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
function FusionManager.validateFusion(player: Player, unitIds: {string}): (boolean, string, { [string]: Unit }?)
    if #unitIds ~= FusionData.FUSION_COST then
        return false, "Need exactly " .. FusionData.FUSION_COST .. " units", nil
    end
    
    local inventory = BrainrotData.getAdvancedInventory(player) :: {Unit}
    local selectedUnits: { [string]: Unit } = {}
    local commonTier: string? = nil
    
    for _, targetId in ipairs(unitIds) do
        local found = false
        for _, unit in ipairs(inventory) do
            if unit.Id == targetId then
                -- Check if already selected (prevent duplicates)
                if selectedUnits[targetId] then
                    return false, "Duplicate unit selected", nil
                end
                
                -- Check tier consistency
                if commonTier == nil then
                    commonTier = unit.Tier
                elseif commonTier ~= unit.Tier then
                    return false, "All units must be same tier", nil
                end
                
                selectedUnits[targetId] = unit
                found = true
                break
            end
        end
        
        if not found then
            return false, "Unit not found in inventory", nil
        end
    end
    
    if not commonTier then
         return false, "No units selected", nil
    end

    -- Check if fusion is possible (not max tier)
    if not FusionData.canFuse(commonTier) then
        return false, "Cannot fuse max tier units", nil
    end
    
    return true, commonTier, selectedUnits
end

-- Main fusion function
function FusionManager.fuse(player: Player, unitIds: {string}): FusionResult
    -- 1. Validate
    local isValid, tierOrError, selectedUnits = FusionManager.validateFusion(player, unitIds)
    
    if not isValid or not tierOrError then
        return {success = false, error = tierOrError or "Unknown error"}
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
    
    -- 6. Roll for Shiny & Mutation
    local isShiny = math.random() < FusionData.SHINY_CHANCE
    
    local mutation = nil
    if math.random() < 0.1 then -- 10% Chance to mutate on fusion
         mutation = MutationManager.rollMutation()
    end

    -- 7. Add new unit
    local newUnit = BrainrotData.addUnitAdvanced(player, resultModel, nextTier, isShiny, false, 1, nil, nil, mutation)
    
    -- 7. Increment stats
    BrainrotData.incrementFusions(player)
    
    -- 8. Prepare result
    local result: FusionResult = {
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
function FusionManager.getPreview(player: Player, unitIds: {string})
    local isValid, tierOrError, selectedUnits = FusionManager.validateFusion(player, unitIds)
    
    if not isValid or not tierOrError then
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
    local fuseFunc = ReplicatedStorage:FindFirstChild("FuseUnits") or Instance.new("RemoteFunction")
    fuseFunc.Name = "FuseUnits"
    fuseFunc.Parent = ReplicatedStorage
    
    fuseFunc.OnServerInvoke = function(player, unitIds)
        if typeof(unitIds) ~= "table" then return {success=false, error="Invalid Input"} end
        return FusionManager.fuse(player, unitIds)
    end
    
    -- Setup preview function
    local previewFunc = ReplicatedStorage:FindFirstChild("FusionPreview") or Instance.new("RemoteFunction")
    previewFunc.Name = "FusionPreview"
    previewFunc.Parent = ReplicatedStorage
    
    previewFunc.OnServerInvoke = function(player, unitIds)
         if typeof(unitIds) ~= "table" then return {canFuse=false} end
        return FusionManager.getPreview(player, unitIds)
    end
    
    -- Setup inventory sync
    -- GetInventory is handled by BrainrotData.lua

    
    print("[FusionManager] Initialized.")
end

return FusionManager

