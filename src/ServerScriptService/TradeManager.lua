-- TradeManager.server.lua
-- Skill: secure-trading
-- Description: Manages secure trading sessions between players. 

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local BrainrotData = require(ServerScriptService.BrainrotData)

local TradeManager = {}

--------------------------------------------------------
-- REMOTES
--------------------------------------------------------
local Remotes = ReplicatedStorage:FindFirstChild("TradeRemotes")

--------------------------------------------------------
-- STATE
--------------------------------------------------------
local Sessions = {} -- [SessionId] = { P1, P2, Offer1={}, Offer2={}, Locked1=false, Locked2=false, Confirmed1=false, Confirmed2=false, Status="Active" }
local PlayerSession = {} -- [Player] = SessionId
local pendingRequests = {} -- [Target] = Requester

--------------------------------------------------------
-- HELPER
--------------------------------------------------------
local function getItemDetails(player, idList)
    local inv = BrainrotData.getAdvancedInventory(player)
    local map = {}; for _, u in pairs(inv) do map[u.Id] = u end
    
    local details = {}
    for _, id in pairs(idList) do
        local d = map[id]
        if d then
            table.insert(details, {
                Id = d.Id,
                Name = d.Name,
                Tier = d.Tier,
                Shiny = d.Shiny or false
            })
        end
    end
    return details
end

local function notifyUpdate(session)
    local state = {
        P1 = session.P1.Name,
        P2 = session.P2.Name,
        Offer1 = session.Offer1,
        Offer2 = session.Offer2,
        Offer1Details = getItemDetails(session.P1, session.Offer1),
        Offer2Details = getItemDetails(session.P2, session.Offer2),
        Locked1 = session.Locked1,
        Locked2 = session.Locked2,
        Confirmed1 = session.Confirmed1,
        Confirmed2 = session.Confirmed2,
        Status = session.Status
    }
    
    Remotes.UpdateTradeState:FireClient(session.P1, state)
    Remotes.UpdateTradeState:FireClient(session.P2, state)
end

local function endSession(sessionId, reason)
    local s = sessionId and Sessions[sessionId]
    if not s then return end
    
    PlayerSession[s.P1] = nil
    PlayerSession[s.P2] = nil
    Sessions[sessionId] = nil
    
    Remotes.TradeClosed:FireClient(s.P1, reason)
    Remotes.TradeClosed:FireClient(s.P2, reason)
    print("[TradeManager] Session Ended: " .. reason)
end

local function performSwap(sId)
    local session = Sessions[sId]
    if not session then return end
    
    session.Status = "Completed"
    notifyUpdate(session)
    
    local p1 = session.P1
    local p2 = session.P2
    
    -- 1. Validate ownership ONE LAST TIME (Atomic Check)
    local inv1 = BrainrotData.getAdvancedInventory(p1)
    local inv2 = BrainrotData.getAdvancedInventory(p2)
    
    local map1 = {}; for _, u in pairs(inv1) do map1[u.Id] = u end
    local map2 = {}; for _, u in pairs(inv2) do map2[u.Id] = u end
    
    local offer1Data = {}
    local offer2Data = {}
    
    for _, uId in pairs(session.Offer1) do
        if not map1[uId] then
            endSession(sId, "Trade Failed: Items modified during trade.")
            return
        end
        table.insert(offer1Data, map1[uId])
    end
    
    for _, uId in pairs(session.Offer2) do
        if not map2[uId] then
            endSession(sId, "Trade Failed: Items modified during trade.")
            return
        end
        table.insert(offer2Data, map2[uId])
    end
    
    -- 2. REMOVE
    BrainrotData.removeUnitsById(p1, session.Offer1)
    BrainrotData.removeUnitsById(p2, session.Offer2)
    
    -- 3. ADD (Swap)
    for _, u in pairs(offer1Data) do
        BrainrotData.addUnitAdvanced(p2, u.Name, u.Tier, u.Shiny, false, u.Level, u.Id, u.ValueMultiplier, u.Mutation)
    end
    
    for _, u in pairs(offer2Data) do
        BrainrotData.addUnitAdvanced(p1, u.Name, u.Tier, u.Shiny, false, u.Level, u.Id, u.ValueMultiplier, u.Mutation)
    end
    
    task.wait(2)
    endSession(sId, "Trade Successful!")
end

--------------------------------------------------------
-- API
--------------------------------------------------------

function TradeManager.Init()
    print("[TradeManager] Initializing...")
    
    if not Remotes then
        Remotes = Instance.new("Folder")
        Remotes.Name = "TradeRemotes"
        Remotes.Parent = ReplicatedStorage
        
        Instance.new("RemoteFunction", Remotes).Name = "RequestTrade"
        Instance.new("RemoteEvent", Remotes).Name = "TradeInvite"
        Instance.new("RemoteFunction", Remotes).Name = "AcceptTrade"
        Instance.new("RemoteEvent", Remotes).Name = "UpdateTradeState"
        Instance.new("RemoteFunction", Remotes).Name = "ModifyOffer"
        Instance.new("RemoteFunction", Remotes).Name = "SetLock"
        Instance.new("RemoteFunction", Remotes).Name = "ConfirmTrade"
        Instance.new("RemoteEvent", Remotes).Name = "TradeClosed"
    end

    Remotes.RequestTrade.OnServerInvoke = function(player, targetPlayer)
        if player == targetPlayer then return false, "Cannot trade yourself" end
        if PlayerSession[player] then return false, "You are busy" end
        if not targetPlayer or not targetPlayer:IsA("Player") then return false, "Invalid player" end
        if PlayerSession[targetPlayer] then return false, "Player is busy" end
        
        local targetChar = targetPlayer.Character
        local targetPrimary = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
        if targetPrimary then
            if player:DistanceFromCharacter(targetPrimary.Position) > 50 then
                return false, "Too far away"
            end
        end
        
        pendingRequests[targetPlayer] = player
        Remotes.TradeInvite:FireClient(targetPlayer, player)
        
        task.delay(10, function()
            if pendingRequests[targetPlayer] == player then
                pendingRequests[targetPlayer] = nil
            end
        end)
        
        return true, "Sent request"
    end

    Remotes.AcceptTrade.OnServerInvoke = function(player, fromPlayer)
        if pendingRequests[player] == fromPlayer then
            pendingRequests[player] = nil
            
            local session = {
                P1 = fromPlayer,
                P2 = player,
                Offer1 = {},
                Offer2 = {},
                Locked1 = false,
                Locked2 = false,
                Confirmed1 = false,
                Confirmed2 = false,
                Status = "Active"
            }
            
            local sId = HttpService:GenerateGUID(false)
            Sessions[sId] = session
            PlayerSession[fromPlayer] = sId
            PlayerSession[player] = sId
            
            notifyUpdate(session)
            return true
        end
        return false
    end

    Remotes.ModifyOffer.OnServerInvoke = function(player, action, itemId)
        local sId = PlayerSession[player]
        if not sId then return false end
        local s = Sessions[sId]
        
        if s.Status ~= "Active" then return false end
        if (s.P1 == player and s.Locked1) or (s.P2 == player and s.Locked2) then return false, "Locked" end
        
        local isP1 = (s.P1 == player)
        local offer = isP1 and s.Offer1 or s.Offer2
        
        if action == "Add" then
            if #offer >= 4 then return false, "Max 4 items" end
            local inv = BrainrotData.getAdvancedInventory(player)
            local found = false
            for _, u in pairs(inv) do if u.Id == itemId then found = true break end end
            if not found then return false, "Item not owned" end
            
            for _, oid in pairs(offer) do if oid == itemId then return false end end
            table.insert(offer, itemId)
            
        elseif action == "Remove" then
            for i, oid in ipairs(offer) do
                if oid == itemId then
                    table.remove(offer, i)
                    break
                end
            end
        end
        
        s.Locked1 = false; s.Locked2 = false
        s.Confirmed1 = false; s.Confirmed2 = false
        
        notifyUpdate(s)
        return true
    end

    Remotes.SetLock.OnServerInvoke = function(player, locked)
        local sId = PlayerSession[player]
        if not sId then return false end
        local s = Sessions[sId]
        
        if s.P1 == player then s.Locked1 = locked else s.Locked2 = locked end
        if not locked then
            s.Confirmed1 = false; s.Confirmed2 = false
        end
        
        notifyUpdate(s)
        return true
    end

    Remotes.ConfirmTrade.OnServerInvoke = function(player)
        local sId = PlayerSession[player]
        if not sId then return false end
        local s = Sessions[sId]
        
        if not s.Locked1 or not s.Locked2 then return false, "Not locked" end
        if s.P1 == player then s.Confirmed1 = true else s.Confirmed2 = true end
        
        notifyUpdate(s)
        
        if s.Confirmed1 and s.Confirmed2 then
            s.Status = "Processing"
            notifyUpdate(s)
            task.delay(1, function() performSwap(sId) end)
        end
        
        return true
    end
    
    Remotes.TradeClosed.OnServerEvent:Connect(function(player, reason)
        local sId = PlayerSession[player]
        if sId then
            endSession(sId, "Closed by " .. player.Name)
        end
    end)
end

Players.PlayerRemoving:Connect(function(player)
    local sId = PlayerSession[player]
    if sId then
        endSession(sId, "Player left")
    end
end)

return TradeManager
