-- print("[PlacementClient] STARTING SCRIPT INITIALIZATION (in StarterGui)")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- print("[PlacementClient] Waiting for Remotes...")
local placeUnitRemote = ReplicatedStorage:WaitForChild("PlaceUnit", 5)
local interactSlotRemote = ReplicatedStorage:WaitForChild("InteractSlot", 5)

if not placeUnitRemote then
    warn("[PlacementClient] CRITICAL: PlaceUnit remote not found after 5s!")
end
if not interactSlotRemote then
    warn("[PlacementClient] CRITICAL: InteractSlot remote not found after 5s!")
end

-- print("[PlacementClient] Logic Loaded. (PlaceUnit=" .. tostring(placeUnitRemote) .. ", InteractSlot=" .. tostring(interactSlotRemote) .. ")")

-- We will listen for ANY tool equip that looks like a Unit
local function setupTool(tool)
    if tool:GetAttribute("UnitId") then
        -- print("[PlacementClient] Setting up unit tool:", tool.Name)
    end
end

-- Listener for InteractSlot (TRIGGERED BY PROXIMITY PROMPT)
if interactSlotRemote then
    interactSlotRemote.OnClientEvent:Connect(function(slotModel, slotId)
        -- print("[PlacementClient] Interaction Signal Received for Slot:", slotId)
        
        local char = player.Character
        local tool = char and char:FindFirstChildWhichIsA("Tool")
        
        if tool then
            -- print("[PlacementClient] Tool equipped:", tool.Name)
            local unitId = tool:GetAttribute("UnitId") or tool.Name
            
            if unitId then
                -- DEPLOY HELD UNIT (Invoke PlaceUnit)
                -- print("[PlacementClient] Invoking PlaceUnit for UnitID:", unitId, "on Slot:", slotId)
                local result, errorMsg = placeUnitRemote:InvokeServer(slotId, unitId)
                
                if result then
                     -- print("[PlacementClient] Deployment SUCCESSFUL")
                else
                     warn("[PlacementClient] Deployment FAILED:", errorMsg or "Unknown server error")
                end
            else
                warn("[PlacementClient] Tool equipped but has NO name or UnitId?!")
            end
        else
            -- print("[PlacementClient] No tool equipped. Opening Backpack UI.")
            -- NO UNIT HELD -> Open Backpack
            local toggleInv = ReplicatedStorage:FindFirstChild("ToggleInventory")
            if toggleInv then
                toggleInv:Fire(true) -- Force open
            end
        end
    end)
end

-- Monitor Character ChildAdded (Equip)
local function onCharacterAdded(char)
    char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            setupTool(child)
        end
    end)
    
    -- Check current
    for _, child in pairs(char:GetChildren()) do
         if child:IsA("Tool") then
            setupTool(child)
        end
    end
end

if player.Character then
    onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)
