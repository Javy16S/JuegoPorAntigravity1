local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local placeUnitRemote = ReplicatedStorage:WaitForChild("PlaceUnit", 10)
local interactSlotRemote = ReplicatedStorage:WaitForChild("InteractSlot", 10)

if not placeUnitRemote then
    warn("[PlacementClient] CRITICAL: PlaceUnit remote not found!")
    return
end

print("[PlacementClient] Logic Loaded.")

-- We will listen for ANY tool equip that looks like a Unit
local function setupTool(tool)
    if tool:GetAttribute("UnitId") then
        print("[PlacementClient] Setting up unit tool:", tool.Name)
        
        tool.Activated:Connect(function()
            if not tool.Parent or tool.Parent ~= player.Character then return end
            
            local target = mouse.Target
            if target then
                -- Check if target is a Slot or near a Slot
                -- The server expects 'slot' instance
                
                -- Usually slots are named "Slot_X" or have a specific tag/folder
                local model = target:FindFirstAncestorOfClass("Model")
                local slotCandidate = target
                
                -- Traverse up to find the actual Slot part if we hit a decoration
                while slotCandidate and slotCandidate.Name ~= "TycoonSlots" and slotCandidate ~= game.Workspace do
                    if slotCandidate.Name:match("Slot_%d+") then
                        break
                    end
                    slotCandidate = slotCandidate.Parent
                end
                
                if slotCandidate and slotCandidate.Name:match("Slot_%d+") then
                    print("[PlacementClient] Requesting placement on:", slotCandidate.Name)
                    local result = placeUnitRemote:InvokeServer(slotCandidate)
                    if result then
                         -- Success handled by server (removing tool etc)
                         print("[PlacementClient] Placement Success")
                    else
                         print("[PlacementClient] Placement Failed")
                    end
                else
                    print("[PlacementClient] Invalid Target:", target.Name)
                end
            end
        end)
    end
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
