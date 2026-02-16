-- InventoryManager.server.lua
-- Skill: persistence-logic
-- Description: Re-applies owned effects (Speed, Jump) when the player respawns.

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local function applyInventoryEffects(player, character)
    local inventory = player:FindFirstChild("Inventory")
    if not inventory then return end
    
    local humanoid = character:WaitForChild("Humanoid", 10)
    local root = character:WaitForChild("HumanoidRootPart", 10)
    
    if not humanoid or not root then return end
    
    -- Check for Double Jump
    if inventory:FindFirstChild("DoubleJump") then
        humanoid.UseJumpPower = true
        humanoid.JumpPower = 100
        print("[InventoryManager] Applied DoubleJump to " .. player.Name)
    end
    
    -- Check for Absurd Speed
    if inventory:FindFirstChild("AbsurdSpeed") then
        humanoid.WalkSpeed = 60
        
        -- Apply Trail VFX
        local att0 = Instance.new("Attachment", root)
        att0.Position = Vector3.new(0, -1, 0)
        local att1 = Instance.new("Attachment", root)
        att1.Position = Vector3.new(0, 1, 0)
        
        local trail = Instance.new("Trail")
        trail.Attachment0 = att0
        trail.Attachment1 = att1
        trail.Lifetime = 0.5
        trail.Color = ColorSequence.new(Color3.fromRGB(255, 170, 0), Color3.fromRGB(255, 0, 0))
        trail.Transparency = NumberSequence.new(0.2, 1)
        trail.Parent = root
        
        print("[InventoryManager] Applied AbsurdSpeed to " .. player.Name)
    end
end

local function onPlayerAdded(player)
    player.CharacterAdded:Connect(function(character)
        -- Wait a frame to ensure character is ready
        task.wait(0.1)
        applyInventoryEffects(player, character)
    end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
-- Handle existing players
for _, p in pairs(Players:GetPlayers()) do
    onPlayerAdded(p)
end
