-- EggManager.lua
-- Skill: gacha-mechanics
-- Description: Server-side logic for Egg opening with 3D world animation.

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local EggData = require(ServerScriptService:WaitForChild("EggData"))
local BrainrotData = require(ServerScriptService:WaitForChild("BrainrotData"))

local EggManager = {}

-- Create RemoteEvent for client animation
local EggOpenEvent = ReplicatedStorage:FindFirstChild("EggOpenEvent")
if not EggOpenEvent then
    EggOpenEvent = Instance.new("RemoteEvent")
    EggOpenEvent.Name = "EggOpenEvent"
    EggOpenEvent.Parent = ReplicatedStorage
end

-- Get all available brainrots from a tier folder
function EggManager.getModelsFromTier(tier)
    local brainrotFolder = ServerStorage:FindFirstChild("BrainrotModels")
    if not brainrotFolder then return {} end
    
    local tierFolder = brainrotFolder:FindFirstChild(tier)
    if not tierFolder then return {} end
    
    local models = {}
    for _, child in pairs(tierFolder:GetChildren()) do
        if child:IsA("Model") then
            table.insert(models, child.Name)
        end
    end
    
    return models
end

-- Get random model from a tier
function EggManager.getRandomModelFromTier(tier)
    local models = EggManager.getModelsFromTier(tier)
    if #models == 0 then
        warn("[EggManager] No models found in tier: " .. tier)
        return "Unknown_Brainrot"
    end
    return models[math.random(1, #models)]
end

-- Get pool of possible results for animation
function EggManager.getPossibilities(eggId)
    local egg = EggData.EGGS[eggId]
    if not egg then return {} end
    
    local possibilities = {}
    
    -- Gather models from each possible tier
    for tier, chance in pairs(egg.Chances) do
        local models = EggManager.getModelsFromTier(tier)
        for _, modelName in ipairs(models) do
            table.insert(possibilities, {
                Name = modelName,
                Tier = tier,
                Chance = chance
            })
        end
    end
    
    -- Shuffle for randomness in animation
    for i = #possibilities, 2, -1 do
        local j = math.random(1, i)
        possibilities[i], possibilities[j] = possibilities[j], possibilities[i]
    end
    
    return possibilities
end

-- Main egg opening function
function EggManager.openEgg(player, eggId, amount)
    amount = math.clamp(amount or 1, 1, 8) -- Limit to 8 for performance/UX
    
    -- 1. Validate egg exists
    local egg = EggData.EGGS[eggId]
    if not egg then
        return {success = false, error = "Invalid egg type"}
    end
    
    -- 2. Check and deduct cost
    local totalCost = egg.Price * amount
    local hasFunds = BrainrotData.deductCash(player, totalCost)
    if not hasFunds then
        return {success = false, error = "Not enough cash"}
    end
    
    local results = {}
    
    for i = 1, amount do
        -- 3. Roll for tier
        local wonTier = EggData.rollTier(eggId)
        
        -- 4. Get random model from that tier
        local wonModel = EggManager.getRandomModelFromTier(wonTier)
        
        -- 5. Roll for Shiny
        local isShiny = math.random() < EggData.SHINY_CHANCE
        
        -- 6. Add to advanced inventory
        local unitData = BrainrotData.addUnitAdvanced(player, wonModel, wonTier, isShiny)
        
        -- 7. Increment stats
        BrainrotData.incrementEggsOpened(player)
        
        table.insert(results, {
            unitData = unitData,
            resultName = wonModel,
            resultTier = wonTier,
            isShiny = isShiny,
            vfx = EggData.TIER_VFX[wonTier]
        })
    end
    
    -- 8. Get possibilities for animation (one pool is enough for all)
    local possibilities = EggManager.getPossibilities(eggId)
    
    -- 9. Fire client event for 3D animation
    local multiResult = {
        success = true,
        eggId = eggId,
        results = results,
        possibilities = possibilities,
        amount = amount
    }
    
    EggOpenEvent:FireClient(player, multiResult)
    
    return multiResult
end

-- Initialize egg pedestals in the world
function EggManager.setupEggPedestal(pedestal, eggId)
    if not pedestal then return end
    
    local egg = EggData.EGGS[eggId]
    if not egg then return end
    
    -- Store egg type
    pedestal:SetAttribute("EggType", eggId)
    pedestal:SetAttribute("EggPrice", egg.Price)
    
    -- Setup ProximityPrompt
    local prompt = pedestal:FindFirstChild("OpenPrompt")
    if not prompt then
        prompt = Instance.new("ProximityPrompt")
        prompt.Name = "OpenPrompt"
        prompt.Parent = pedestal.PrimaryPart or pedestal:FindFirstChildWhichIsA("BasePart")
    end
    
    prompt.ActionText = "Open"
    prompt.ObjectText = egg.DisplayName .. " ($" .. egg.Price .. ")"
    prompt.HoldDuration = 0.3
    prompt.RequiresLineOfSight = false
    
    -- Handle interaction
    prompt.Triggered:Connect(function(player)
        -- Disable prompt during animation
        prompt.Enabled = false
        
        local result = EggManager.openEgg(player, eggId)
        
        if not result.success then
            -- Show error feedback
            warn("[EggManager] " .. player.Name .. " failed: " .. result.error)
        end
        
        -- Re-enable after animation
        task.delay(EggData.ANIMATION.SpinDuration + 2, function()
            prompt.Enabled = true
        end)
    end)
end

-- Find and setup all egg pedestals in workspace
function EggManager.Init()
    print("[EggManager] Initializing...")
    
    -- Look for egg pedestals tagged or named appropriately
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and string.find(obj.Name, "EggPedestal") then
            -- Extract egg type from name (e.g., "EggPedestal_Basic" -> "BasicEgg")
            local eggType = obj:GetAttribute("EggType")
            if not eggType then
                -- Try to parse from name
                local parts = string.split(obj.Name, "_")
                if parts[2] then
                    eggType = parts[2] .. "Egg"
                else
                    eggType = "BasicEgg"
                end
            end
            
            EggManager.setupEggPedestal(obj, eggType)
            print("[EggManager] Setup pedestal: " .. obj.Name .. " -> " .. eggType)
        end
    end
    
    -- Setup remote function for manual purchase (from UI)
    local purchaseEggFunc = ReplicatedStorage:FindFirstChild("PurchaseEgg")
    if not purchaseEggFunc then
        purchaseEggFunc = Instance.new("RemoteFunction")
        purchaseEggFunc.Name = "PurchaseEgg"
        purchaseEggFunc.Parent = ReplicatedStorage
    end
    
    purchaseEggFunc.OnServerInvoke = function(player, eggId, amount)
        return EggManager.openEgg(player, eggId, amount)
    end
    
    local count = 0
    for _ in pairs(EggData.EGGS) do count += 1 end
    print("[EggManager] Initialized. Egg types available: " .. count)
end

return EggManager
