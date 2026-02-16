-- DevCommands.server.lua
-- Description: Chat commands for testing.
-- Usage: /addcash 1000

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local BrainrotData = require(ServerScriptService:WaitForChild("BrainrotData"))

local ADKINS = {
    [game.CreatorId] = true,
    -- Add user IDs here or just allow everyone in Studio
}

local function isAllowed(player)
    return game["Run Service"]:IsStudio() or ADKINS[player.UserId] or player.Name == "BuhoArrollador" -- Specific override
end

Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(msg)
        if not isAllowed(player) then return end
        
        local args = string.split(msg, " ")
        local cmd = string.lower(args[1])
        
        if cmd == "/addcash" then
            local amount = tonumber(args[2]) or 1000000
            BrainrotData.addCash(player, amount)
            print("[Dev] Gave $"..amount.." to "..player.Name)
            
        elseif cmd == "/reset" then
            -- Reset Data logic if needed
            print("[Dev] Reset requested (Not fully implemented)")
        end
    end)
end)
