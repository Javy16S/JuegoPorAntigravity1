-- AchievementManager.server.lua
-- Skill: gamification-logic
-- Description: Listens to player stats and awards achievements.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local BrainrotData = require(ServerScriptService:WaitForChild("BrainrotData"))
local Achievements = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("AchievementDefinitions"))
local AchievementUnlocked = ReplicatedStorage:WaitForChild("AchievementUnlocked")

-- SOUND CONFIG
local UNLOCK_SOUND = "rbxassetid://12221966" -- Default spark sound

-- HELPER: Award Achievement
local function awardAchievement(player, achievement)
    -- Try to unlock in Data (returns true if first time)
    if BrainrotData.unlockAchievement(player, achievement.Id) then
        print(string.format("[AchievementManager] %s unlocked '%s'", player.Name, achievement.Id))
        
        -- Give Reward
        if achievement.Reward and achievement.Reward > 0 then
            BrainrotData.addCash(player, achievement.Reward)
        end
        
        -- Notify Client
        AchievementUnlocked:FireClient(player, achievement.Id, achievement.Title, achievement.ImageId)
    end
end

-- LISTEN TO STATS
BrainrotData.StatsChanged.Event:Connect(function(player, statName, value, extra1, extra2)
    -- statName: "Cash", "TotalEarnings", "Discoveries"
    -- value: The numeric value
    -- extra1: (Optional) Tier name for discoveries
    
    for _, ach in ipairs(Achievements.LIST) do
        local completed = false
        
        if ach.Type == "Cash" and statName == "Cash" then
            if value >= ach.Target then completed = true end
            
        elseif ach.Type == "TotalEarnings" and statName == "TotalEarnings" then
            if value >= ach.Target then completed = true end
            
        elseif ach.Type == "Discoveries" and statName == "Discoveries" then
            if value >= ach.Target then completed = true end
            
        elseif ach.Type == "Rarity" and statName == "Discoveries" then
            -- Value is count, extra1 is Tier Name (e.g. "Legendary")
            if extra1 and extra1 == ach.Target then completed = true end
            
        elseif ach.Type == "RarityGroup" and statName == "Discoveries" then
             -- extra1 is Tier Name
             if extra1 and table.find(ach.Target, extra1) then completed = true end
        end
        
        if completed then
            awardAchievement(player, ach)
        end
    end
end)

print("[AchievementManager] Initialized and listening for stats.")
