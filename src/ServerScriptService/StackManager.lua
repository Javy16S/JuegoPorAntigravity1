-- StackManager.server.lua
-- Skill: physics-attachment
-- Description: Manages carrying Brainrot items in a visual stack.

local StackManager = {}
local Players = game:GetService("Players")

-- Visual Config
local STACK_OFFSET = Vector3.new(0, 2, 1) -- Behind and above

function StackManager.addItemToStack(player, part)
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local root = char.HumanoidRootPart
    
    -- Create inventory folder if needed
    local inventory = player:FindFirstChild("CarriedItems")
    if not inventory then
        inventory = Instance.new("Folder")
        inventory.Name = "CarriedItems"
        inventory.Parent = player
    end
    
    -- CHECK CAPACITY
    local leaderstats = player:FindFirstChild("leaderstats")
    local maxCap = leaderstats and leaderstats:FindFirstChild("MaxCapacity") and leaderstats.MaxCapacity.Value or 3
    
    if #inventory:GetChildren() >= maxCap then
        -- Inventory Full Feedback
        local sfx = Instance.new("Sound")
        sfx.SoundId = "rbxasset://sounds/uuhhh.mp3" -- Roblox 'Oof' or similar error sound
        sfx.Parent = root
        sfx:Play()
        game:GetService("Debris"):AddItem(sfx, 1)
        return false -- Reject pickup
    end
    
    if part:IsA("Model") then
        local prim = part.PrimaryPart or part:FindFirstChildWhichIsA("BasePart")
        if not prim then
            warn("StackManager: Model " .. part.Name .. " has no PrimaryPart!")
            part:Destroy()
            return
        end
        part.PrimaryPart = prim
        for _, p in pairs(part:GetDescendants()) do 
            if p:IsA("BasePart") then 
                p.CanCollide = false 
                p.Anchored = false 
                p.CastShadow = false
            end 
        end
    else
        part.CanCollide = false
        part.Anchored = false
        part.CastShadow = false
    end

    part.Parent = char
    
    -- Destroy original world pickup (part is now the visual)
    -- Note: Caller should handle cleanup if needed
    
    -- Count current depth
    local count = #inventory:GetChildren()
    
    -- Weld to Player (Snake style or Backpack style)
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = root
    
    local targetPart = part:IsA("Model") and part.PrimaryPart or part
    weld.Part1 = targetPart
    weld.Parent = targetPart
    
    -- Stack up: Each item is higher/further back
    local offsetCF = CFrame.new(0, 1 + (count * 1.5), 1.5 + (count * 0.5))
    local targetCF = root.CFrame * offsetCF
    
    if part:IsA("Model") then
        part:PivotTo(targetCF)
    else
        part.CFrame = targetCF
    end
    
    -- Store Data reference
    local val = Instance.new("IntValue")
    val.Name = part.Name -- "Common", "Rare"
    val.Value = part:GetAttribute("Value") or 1
    val.Parent = inventory
    
    -- Link visual to data
    part:SetAttribute("InventoryId", val.Name)
    
    -- print("STACK: Added " .. val.Name .. " to " .. player.Name .. " Inventory.")
    return true
end

function StackManager.depositStack(player, stationModel)
    local inventory = player:FindFirstChild("CarriedItems")
    if not inventory then return end
    
    local placedCount = 0
    
    for _, itemVal in pairs(inventory:GetChildren()) do
        -- Visual Transfer to Station
        -- Find an empty slot? Or just pile them up?
        -- For now: Pile them visually in the station
        
        local stationItems = stationModel:FindFirstChild("StoredItems")
        if stationItems then
             -- Logic handled by LootTycoonManager mainly, but we clear player here
        end
        itemVal:Destroy()
        placedCount += 1
    end
    
    -- Clear Visuals on Character
    if player.Character then
        for _, child in pairs(player.Character:GetChildren()) do
            if child:GetAttribute("InventoryId") then
                child:Destroy()
            end
        end
    end
    
    return placedCount
end

return StackManager
