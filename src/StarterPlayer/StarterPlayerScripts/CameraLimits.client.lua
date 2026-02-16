-- CameraLimits.client.lua
-- Skill: camera-control
-- Description: Enforces maximum zoom distance for better immersion.

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local MAX_ZOOM = 60 -- Reduced from default 128/400

local function applyLimits()
    player.CameraMaxZoomDistance = MAX_ZOOM
    
    -- Optional: If current distance is greater, clamp it
    local camera = workspace.CurrentCamera
    if camera and (camera.Focus.Position - camera.CFrame.Position).Magnitude > MAX_ZOOM then
        player.CameraMaxZoomDistance = MAX_ZOOM -- Force update
    end
end

-- Apply on spawn and periodically ensure it sticks
player.CharacterAdded:Connect(applyLimits)
if player.Character then applyLimits() end

-- Keep it enforced
task.spawn(function()
    while true do
        if player.CameraMaxZoomDistance ~= MAX_ZOOM then
            player.CameraMaxZoomDistance = MAX_ZOOM
        end
        task.wait(1)
    end
end)
