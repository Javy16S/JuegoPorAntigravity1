-- LightingManager.server.lua
-- Skill: atmosphere-control
-- Description: Enforces a "Volcanic/Cyber" atmosphere. Dark, foggy, and dramatic.

local Lighting = game:GetService("Lighting")

local Lighting = game:GetService("Lighting")

local function setupLighting()
    -- Lighting logic REMOVED per User Request ("ya me he encargado yo, quita lo que tenías creado")
    -- The script is now passive and will not override manual Studio settings.
    
    print("[LightingManager] Passive Mode. Manual settings active.")
end

setupLighting()

-- No Heartbeat enforcement either
game:GetService("RunService").Heartbeat:Connect(function()
    if Lighting.ClockTime ~= 20 then
       -- Lighting.ClockTime = 20 -- Optional: enforcement
    end
end)
