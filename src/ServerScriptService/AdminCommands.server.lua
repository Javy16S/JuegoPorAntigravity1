-- AdminCommands.server.lua
-- Skill: admin-tools
-- Description: Debugging comands for development (Clear Inventory, Reset Data, Add Money)

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

-- COMMANDS
local COMMANDS = {
    ["/clearinventory"] = function(player)
        print("[AdminCommands] Clearing inventory for " .. player.Name)
        local BrainrotData = require(ServerScriptService.BrainrotData)
        local data = BrainrotData.getPlayerSession(player)
        if data then
            data.AdvancedInventory = {}
            data.UnitInventory = {}
            -- Clear physical tools (Correctly handle clean names)
            local function cleanTools(container)
                for _, tool in pairs(container:GetChildren()) do
                    if tool:IsA("Tool") and (tool:GetAttribute("Tier") or string.sub(tool.Name, 1, 5) == "Unit_") then
                        tool:Destroy()
                    end
                end
            end
            cleanTools(player.Backpack)
            if player.Character then cleanTools(player.Character) end
            print("[AdminCommands] Inventory wiped for " .. player.Name)
        end
    end,

    ["/resetdata"] = function(player)
        print("[AdminCommands] FULL DATA RESET for " .. player.Name)
        
        -- 1. Clear all physical tools first
        local function cleanTools(container)
            if not container then return end
            for _, tool in pairs(container:GetChildren()) do
                if tool:IsA("Tool") and (tool:GetAttribute("Tier") or string.sub(tool.Name, 1, 5) == "Unit_") then
                    tool:Destroy()
                end
            end
        end
        cleanTools(player.Backpack)
        if player.Character then cleanTools(player.Character) end
        
        -- 2. Clear session data
        local BrainrotData = require(ServerScriptService.BrainrotData)
        local data = BrainrotData.getPlayerSession(player)
        if data then
            data.AdvancedInventory = {}
            data.UnitInventory = {}
            data.Cash = 0
            data.SpeedLevel = 0
            data.BackpackLevel = 0
            data.BackpackCapacity = 3
            data.Discovered = {}
        end
        
        -- 3. Clear placed units from slots
        local UnitManager = require(ServerScriptService.UnitManager)
        if UnitManager.clearAllSlots then
            UnitManager.clearAllSlots(player)
        end
        
        -- 4. Delete from DataStore
        local PlayerDataStore = DataStoreService:GetDataStore("BrainrotData_V2")
        local success, err = pcall(function()
            PlayerDataStore:RemoveAsync(tostring(player.UserId))
        end)
        
        if success then
            player:Kick("✅ RESET COMPLETO. ¡Vuelve a entrar para empezar de cero!")
        else
            warn("[AdminCommands] Reset failed: " .. tostring(err))
            player:Kick("Reset parcial - Vuelve a entrar")
        end
    end,

    ["/addmoney"] = function(player)
        local BrainrotData = require(ServerScriptService.BrainrotData)
        BrainrotData.addCash(player, 1000000) -- Give 1M
        print("[AdminCommands] Added 1M money to " .. player.Name)
    end,

    ["/spawnmutation"] = function(player, args) -- /spawnmutation UnitName MutationName
        if not args or #args < 2 then 
            warn("Usage: /spawnmutation [Name] [Mutation]")
            return 
        end
        local unitName = args[1]
        local mutationName = args[2]
        
        local BrainrotData = require(ServerScriptService.BrainrotData)
        -- Give unit to player directly
        BrainrotData.addUnitAdvanced(player, unitName, "Common", false, false, mutationName)
        print("[AdminCommands] Gave " .. unitName .. " with mutation " .. mutationName .. " to " .. player.Name)
    end,

    ["/triggerevent"] = function(player, args) -- /triggerevent 1 (Minor) or 2 (Major)
        local evtType = args and args[1] or "Minor"
        local EventManager = require(ServerScriptService.EventManager)
        
        if evtType == "Minor" then
            EventManager.triggerMinorEvent()
        elseif evtType == "Major" then
            EventManager.triggerMajorEvent()
        else
            warn("Usage: /triggerevent [Minor/Major]")
        end
    end
}

-- Alias (must be defined after COMMANDS table is complete)
COMMANDS["/fullreset"] = COMMANDS["/resetdata"]

Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(message)
        -- message = "/cmd arg1 arg2"
        local parts = message:split(" ")
        local cmd = parts[1]
        local args = {}
        if #parts > 1 then
            for i = 2, #parts do
                table.insert(args, parts[i])
            end
        end
        
        if COMMANDS[cmd] then
            COMMANDS[cmd](player, args)
        end
    end)
end)

print("[AdminCommands] Commands loaded: /clearinventory, /resetdata, /fullreset, /addmoney")
