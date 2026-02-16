-- DailyRewardManager.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BrainrotData = require(ServerScriptService:WaitForChild("BrainrotData"))
local EconomyLogic = require(ReplicatedStorage.Modules:WaitForChild("EconomyLogic"))

local DailyRewardManager = {}

-- CONFIG
local BASE_REWARD = 10000 -- Base money reward
local COOLDOWN_HOURS = 24

local DONOR_LEVELS = {
    {Level = 6, MinSpent = 30000, RewardId = "lb_abuse", Name = "Abuse"},
    {Level = 5, MinSpent = 14500, RewardId = "lb_celestial", Name = "Celestial"},
    {Level = 4, MinSpent = 5000, RewardId = "lb_divine", Name = "Divine"},
    {Level = 3, MinSpent = 1500, RewardId = "lb_mythic", Name = "Mythic"},
    {Level = 2, MinSpent = 499, RewardId = "lb_legendary", Name = "Legendary"},
    {Level = 1, MinSpent = 0, RewardId = "lb_rare", Name = "Rare"}
}

function DailyRewardManager.getDonorInfo(player: Player)
    local data = BrainrotData.getPlayerSession(player)
    local spent = data and data.TotalRobuxSpent or 0
    
    for _, info in ipairs(DONOR_LEVELS) do
        if spent >= info.MinSpent then
            return info
        end
    end
    return DONOR_LEVELS[#DONOR_LEVELS] -- Default to level 1
end

function DailyRewardManager.calculateReward(player: Player)
    local data = BrainrotData.getPlayerSession(player)
    if not data then return 0 end
    
    local donorInfo = DailyRewardManager.getDonorInfo(player)
    
    -- Level scaling for cash
    local levelBonus = (data.Rebirths or 0) * 0.5 + 1.0
    local robuxBonus = 1.0 + (donorInfo.Level * 0.2) -- 20% extra cash per donor level
    
    -- Max cap? E.g. max x5 multiplier from Robux
    if robuxBonus > 5 then robuxBonus = 5 end
    
    local finalReward = math.floor(BASE_REWARD * levelBonus * robuxBonus)
    return finalReward
end

function DailyRewardManager.claim(player: Player)
    local data = BrainrotData.getPlayerSession(player)
    if not data then return false, "No Data" end
    
    local now = os.time()
    local lastClaim = data.LastDailyReward or 0
    local diff = now - lastClaim
    local cooldown = COOLDOWN_HOURS * 3600
    
    if diff < cooldown then
        local remaining = cooldown - diff
        local hours = math.floor(remaining / 3600)
        local minutes = math.floor((remaining % 3600) / 60)
        return false, string.format("Espera %dh %dm", hours, minutes)
    end
    
    local rewardCash = DailyRewardManager.calculateReward(player)
    local donorInfo = DailyRewardManager.getDonorInfo(player)
    
    -- 1. Give Cash
    BrainrotData.addCash(player, rewardCash)
    
    -- 2. Give Lucky Block (The specific request)
    local lbId = donorInfo.RewardId
    local cleanName = string.gsub(lbId, "lb_", ""):gsub("^%l", string.upper) .. " LuckyBlock"
    
    -- We use UnitManager or BrainrotData to add the item directly
    -- In this game, LuckyBlocks are typically Units/Items in inventory
    BrainrotData.addUnitAdvanced(player, cleanName, donorInfo.Name, false)
    
    data.LastDailyReward = now
    
    -- Visuals
    local vfxRemote = ReplicatedStorage:FindFirstChild("PlayStallVFX")
    if vfxRemote then
        vfxRemote:FireAllClients("LuckyBlock")
    end
    
    print(string.format("[DailyReward] %s claimed $%s and 1x %s LuckyBlock (Level %d)", 
        player.Name, EconomyLogic.Abbreviate(rewardCash), donorInfo.Name, donorInfo.Level))
        
    -- 3. PERSIST IMMEDIATELY (Critical Security)
    -- This ensures that if the server crashes 5 seconds after claiming,
    -- the player won't lose their item or be able to double-claim.
    local success_save, save_err = pcall(function()
        local BrainrotDataMod = require(ServerScriptService.BrainrotData)
        if BrainrotDataMod.savePlayerData then
            BrainrotDataMod.savePlayerData(player)
        end
    end)
    
    if not success_save then
        warn("[DailyReward] Save Error: ", save_err)
    end
    
    return true, {Cash = rewardCash, Item = donorInfo.Name .. " LuckyBlock", Level = donorInfo.Level}
end

function DailyRewardManager.Init()
    local remote = Instance.new("RemoteFunction")
    remote.Name = "ClaimDailyReward"
    remote.Parent = ReplicatedStorage
    
    remote.OnServerInvoke = function(player)
        return DailyRewardManager.claim(player)
    end
    
    local infoRemote = Instance.new("RemoteFunction")
    infoRemote.Name = "GetDailyRewardInfo"
    infoRemote.Parent = ReplicatedStorage
    infoRemote.OnServerInvoke = function(player)
        local data = BrainrotData.getPlayerSession(player)
        if not data then return nil end
        
        local spent = data.TotalRobuxSpent or 0
        local donorInfo = DailyRewardManager.getDonorInfo(player)
        
        -- Calculate next level
        local nextGoal = nil
        local nextLevelName = nil
        for i = #DONOR_LEVELS, 1, -1 do -- Check levels from bottom up
            if DONOR_LEVELS[i-1] and spent < DONOR_LEVELS[i-1].MinSpent then
                nextGoal = DONOR_LEVELS[i-1].MinSpent
                nextLevelName = DONOR_LEVELS[i-1].Name
                break
            end
        end

        return {
            LastClaim = data.LastDailyReward or 0,
            Cooldown = COOLDOWN_HOURS * 3600,
            CurrentReward = DailyRewardManager.calculateReward(player),
            RobuxSpent = spent,
            DonorLevel = donorInfo.Level,
            RewardItem = donorInfo.Name .. " LuckyBlock",
            RewardId = donorInfo.RewardId,
            NextGoal = nextGoal,
            NextLevelName = nextLevelName,
            Progress = nextGoal and (spent / nextGoal) or 1
        }
    end
end

return DailyRewardManager
