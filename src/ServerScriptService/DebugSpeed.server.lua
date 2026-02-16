-- DebugSpeed.server.lua
-- Use this to see what the server thinks of your speed
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local BrainrotData = require(ServerScriptService:WaitForChild("BrainrotData"))

task.spawn(function()
    while true do
        for _, p in pairs(Players:GetPlayers()) do
            local data = BrainrotData.getPlayerSession(p)
            if data then
                local intended = BrainrotData.calculateIntendedSpeed(p)
                local physical = 0
                if p.Character and p.Character:FindFirstChild("Humanoid") then
                    physical = p.Character.Humanoid.WalkSpeed
                end
                
                print(string.format("👤 [DEBUG SPD] %s | Physical: %.1f | Intended: %.1f | Lvl: %d | Mult: %.1f", 
                    p.Name, physical, intended, data.SpeedLevel or 0, BrainrotData.getMultiplier(p, "Speed")))
            end
        end
        task.wait(5)
    end
end)
