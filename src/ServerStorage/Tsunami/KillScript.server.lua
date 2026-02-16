-- KillScript.server.lua
-- Skill: viral-mechanics-analyst
-- Attached to the Tsunami Part via Rojo logic or Tags

local part = script.Parent

local VINE_BOOM_ID = "rbxassetid://6342615263" -- Placeholder ID

local function playSound(position)
    local sound = Instance.new("Sound")
    sound.SoundId = VINE_BOOM_ID
    sound.Volume = 10
    sound.Parent = workspace
    sound.PlayOnRemove = true
    sound:Destroy()
end

part.Touched:Connect(function(hit)
    local humanoid = hit.Parent:FindFirstChild("Humanoid")
    if humanoid and humanoid.Health > 0 then
        humanoid.Health = 0
        playSound(part.Position)
        
        -- Brainrot Physics
        local rootPart = hit.Parent:FindFirstChild("HumanoidRootPart")
        if rootPart then
            rootPart:ApplyImpulse(Vector3.new(0, 1000, 0))
        end
    end
end)
