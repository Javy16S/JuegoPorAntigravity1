-- CameraManager.lua
-- Skill: camera-cinematics
-- Description: Centralized manager for cinematic camera sessions. 
-- Ensures the camera always returns to the player even after errors or resets.

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CameraManager = {}
local activeSession = nil
local camera = workspace.CurrentCamera

-- Restore default camera settings
local function restoreDefaultCamera()
    camera.CameraType = Enum.CameraType.Custom
    local player = Players.LocalPlayer
    if player and player.Character then
        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            camera.CameraSubject = humanoid
        end
    end
end

-- Force reset if something goes wrong
function CameraManager.forceReset()
    activeSession = nil
    restoreDefaultCamera()
    print("[CameraManager] Emergency Reset Triggered.")
end

-- Lock camera for a cinematic session
function CameraManager.lock(sessionID, targetCFrame, duration)
    -- If there's an active session of a different ID, override it
    activeSession = sessionID
    
    camera.CameraType = Enum.CameraType.Scriptable
    
    if targetCFrame then
        if duration and duration > 0 then
            TweenService:Create(camera, TweenInfo.new(duration, Enum.EasingStyle.Quart), {CFrame = targetCFrame}):Play()
        else
            camera.CFrame = targetCFrame
        end
    end
    
    return true
end

-- Unlock camera and return to player
function CameraManager.unlock(sessionID)
    if activeSession ~= sessionID and sessionID ~= "FORCE" then 
        return -- Don't unlock someone else's session
    end
    
    activeSession = nil
    restoreDefaultCamera()
end

-- Smooth transition back to player
function CameraManager.smoothUnlock(sessionID, duration)
    if activeSession ~= sessionID and sessionID ~= "FORCE" then return end
    
    local player = Players.LocalPlayer
    if not player or not player.Character or not player.Character:FindFirstChild("Head") then
        CameraManager.unlock(sessionID)
        return
    end
    
    local head = player.Character.Head
    local returnCFrame = CFrame.new(head.Position + Vector3.new(0, 5, 10), head.Position)
    
    local tween = TweenService:Create(camera, TweenInfo.new(duration or 0.5, Enum.EasingStyle.Quad), {CFrame = returnCFrame})
    tween:Play()
    tween.Completed:Connect(function()
        CameraManager.unlock(sessionID)
    end)
end

-- Handle character resets automatically
Players.LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.1)
    if not activeSession then
        restoreDefaultCamera()
    end
end)

return CameraManager
