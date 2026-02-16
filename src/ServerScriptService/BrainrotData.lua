--!strict
-- BrainrotData.lua
-- Skill: persistence-logic
-- Description: Unified player data system. Key: BrainrotData_V2

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local PlayerDataStore = DataStoreService:GetDataStore("BrainrotData_V2")
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local MutationManager = require(ReplicatedStorage.Modules:WaitForChild("MutationManager"))
local EconomyLogic = require(ReplicatedStorage.Modules:WaitForChild("EconomyLogic"))

export type Unit = EconomyLogic.Unit

export type PlayerData = {
    Cash: number,
    Rank: string,
    Income: number,
    TotalCoinsEarned: number?,
    EggsOpened: number?,
    FusionsPerformed: number?,
    Discoveries: {string},
    AdvancedInventory: {Unit},
    UnitInventory: {string}, -- LEGACY
    PlacedUnits: {[string]: {
        Name: string,
        Tier: string?,
        Shiny: boolean?,
        Level: number?,
        ValueMultiplier: number?,
        StoredCash: number?,
        UnitId: string?,
        Mutation: string?
    }},
    LastPlaytime: number,
    SpeedLevel: number, -- Level of speed upgrades (0 to 5)
    BackpackLevel: number, -- Level of backpack upgrades
    BackpackCapacity: number, -- Default starting slots
    Achievements: {[string]: boolean}, -- NEW: Completed achievements { [Id] = true }
    Rebirths: number, -- NEW: Rebirth Count
    Hotbar: {[string]: string}, -- NEW: [Index] = UnitId
    Boosts: {[string]: number}, -- NEW: { [BoostId] = ExpiryTime }
    
    -- SHOP INTEGRATION
    Tokens: number, -- Premium Currency
    Cosmetics: {string}, -- List of owned cosmetic IDs
    TotalRobuxSpent: number?, -- TRACKING: Scaling for Daily Rewards
    LastDailyReward: number?, -- TRACKING: 24h cooldown
    MutationLuck: number?, -- NEW: 0-100 Luck stat
    LastLuckUpdate: number?, -- NEW: Timestamp for luck regeneration
    FloorColors: {[string]: {r: number, g: number, b: number}}?, -- NEW: [FloorName] = {r, g, b}
}

local BrainrotData = {}
BrainrotData.StatsChanged = Instance.new("BindableEvent") -- NEW: Event for AchievementManager
local sessionData: {[number]: PlayerData} = {}
local DATA_VERSION = "V2"

function BrainrotData.generateUUID(): string
    return HttpService:GenerateGUID(false)
end

-----------------------------------------------------------
-- SAFE CALL (Retry Logic)
-----------------------------------------------------------
local function safeCall(func)
    local retries = 3
    local result
    local success
    
    for i = 1, retries do
        success, result = pcall(func)
        if success then
            return true, result
        else
            warn(string.format("[BrainrotData] DataStore Error (Attempt %d/%d): %s", i, retries, tostring(result)))
            task.wait(2) -- Wait 2 seconds before retrying
        end
    end
    
    return false, result -- Failed after all retries
end

-- NEW: Shared tool creation helper to ensure consistency
function BrainrotData.createUnitTool(name: string, tier: string, isShiny: boolean, id: string?, level: number?, valueMultiplier: number?, mutationName: string?): Tool
    local tool = Instance.new("Tool")
    -- USER REQUEST: CLEAN NAMES (No "Unit_" prefix)
    tool.Name = name
    tool.RequiresHandle = true
    
    -- Hidden Handle
    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(1, 1, 1)
    handle.Transparency = 1
    handle.CanCollide = false
    handle.Anchored = false 
    handle.Massless = false 
    handle.Parent = tool
    
    -- FIX: Add RightGripAttachment for proper R15 holding
    local gripAtt = Instance.new("Attachment")
    gripAtt.Name = "RightGripAttachment"
    gripAtt.Parent = handle
    
    -- Attributes (ALL preserved across pickup/place cycles)
    tool:SetAttribute("UnitId", id or HttpService:GenerateGUID(false))
    tool:SetAttribute("Tier", tier or "Common")
    tool:SetAttribute("IsShiny", isShiny or false)
    tool:SetAttribute("Level", level or 1)
    tool:SetAttribute("ValueMultiplier", valueMultiplier or 1.0) -- Persistent multiplier
    tool:SetAttribute("Level", level or 1)
    tool:SetAttribute("ValueMultiplier", valueMultiplier or 1.0) -- Persistent multiplier
    tool:SetAttribute("Secured", id ~= nil)
    if mutationName then
        tool:SetAttribute("Mutation", mutationName)
    end
    
    -- Visual Model (Robust Lookup)
    local brainrotModels = ServerStorage:FindFirstChild("BrainrotModels")
    local template = nil
    if brainrotModels then
        -- Try exact match, then sanitized match (no prefix)
        template = brainrotModels:FindFirstChild(name, true)
        if not template then
            local cleanName = string.gsub(name, "Unit_", "")
            template = brainrotModels:FindFirstChild(cleanName, true)
        end
    end
    
    if template then
        local visual = template:Clone()
        visual.Name = "Visual"
        
        -- 1. AGGRESSIVE SANITIZATION
        for _, v in pairs(visual:GetDescendants()) do
            if v:IsA("LuaSourceContainer") or v:IsA("Humanoid") or v:IsA("GuiBase3d") then
                v:Destroy()
            end
        end

        -- 2. Ensure Model has PrimaryPart for positioning
        local rootPart = nil
        if visual:IsA("Model") then
            rootPart = visual.PrimaryPart or visual:FindFirstChildWhichIsA("BasePart", true)
            if rootPart then visual.PrimaryPart = rootPart else 
                -- Create invisible root if none exists to hold the model together
                rootPart = Instance.new("Part")
                rootPart.Name = "AutoRoot"
                rootPart.Transparency = 1; rootPart.CanCollide = false; rootPart.Massless = true; rootPart.Size = Vector3.one
                rootPart.Parent = visual; visual.PrimaryPart = rootPart
            end
        elseif visual:IsA("BasePart") then
            rootPart = visual
        end

        if rootPart then
            -- 3. PHYSICS SETUP (Preserve Original Structure)
            for _, p in pairs(visual:GetDescendants()) do
                if p:IsA("BasePart") then
                    p.Massless = true
                    p.CanCollide = false
                    p.Anchored = false
                    p.Locked = true
                    
                    -- WELD EVERYTHING to rootPart if it's not the root itself
                    if p ~= rootPart then
                        local w = p:FindFirstChild("ModelWeld") or Instance.new("WeldConstraint")
                        w.Name = "ModelWeld"
                        w.Part0 = rootPart
                        w.Part1 = p
                        w.Parent = p
                    end
                end
            end
            if visual:IsA("BasePart") then 
                visual.Anchored = false 
                visual.Massless = true
                visual.CanCollide = false
                visual.Locked = true
            end

            -- 4. POSITION AT HANDLE (Move the whole assembly)
            if visual:IsA("Model") then
                visual:PivotTo(handle.CFrame)
            else
                visual.CFrame = handle.CFrame
            end

            -- 5. SINGLE WELD (Handle <-> Root)
            local mainWeld = Instance.new("WeldConstraint")
            mainWeld.Name = "HandleRootWeld"
            mainWeld.Part0 = handle
            mainWeld.Part1 = rootPart
            mainWeld.Parent = handle
            
            -- Ensure Root is Unanchored (Critical)
            rootPart.Anchored = false
        end
        
    -- Apply Visual Effects (Auras, etc)
    MutationManager.applyTierEffects(visual, tier, isShiny, true)
    
    if mutationName then
        MutationManager.applyMutation(visual, mutationName)
    end
    
    visual.Parent = tool
    else
        -- Fallback if model missing
        handle.Transparency = 0
        handle.Color = Color3.fromRGB(255, 0, 0)
        handle.Material = Enum.Material.Neon
    end
    
    return tool
end



print("[BrainrotData] Module Memory ID: " .. tostring(BrainrotData))

-- TEMPLATE
local PLAYER_TEMPLATE = {
    Cash = 1000,
    Rank = "Bronze",
    Income = 0,
    TotalCoinsEarned = 0,
    EggsOpened = 0,
    FusionsPerformed = 0,
    Discoveries = {}, -- List of brainrot names
    AdvancedInventory = {}, -- { {Id, Name, Tier, Shiny, AcquiredAt} }
    UnitInventory = {}, -- LEGACY
    PlacedUnits = {}, -- { [slotIndex] = unitName }
    LastPlaytime = 0,
    SpeedLevel = 0, -- Level of speed upgrades (0 to 5)
    BackpackLevel = 0, -- Level of backpack upgrades
    BackpackCapacity = 5, -- Default starting slots
    Achievements = {}, -- NEW: Completed achievements { [Id] = true }
    Rebirths = 0, -- NEW: Rebirth Count
    Hotbar = {}, -- NEW: [Index] = UnitId
    Boosts = {}, -- NEW: { [BoostId] = ExpiryTime }
    BaseLevel = 1, -- PERSISTENT: Base upgrade level (1-5)
    
    -- SHOP INTEGRATION
    Tokens = 0,
    Cosmetics = {},
    TotalRobuxSpent = 0, -- TRACKING
    LastDailyReward = 0, -- TRACKING
    MutationLuck = 100, -- NEW: Default Luck
    LastLuckUpdate = 0, -- NEW: Will be set to os.time() on first join
}

-----------------------------------------------------------
-- HELPER: Generate Unique ID
-----------------------------------------------------------
function BrainrotData.generateUUID()
    return HttpService:GenerateGUID(false)
end

function BrainrotData.getSpeedBonus(level: number?): number
    return (level or 0) * 5 -- +5 WalkSpeed per level (Lvl 5 = +25, Total 41)
end

function BrainrotData.calculateIntendedSpeed(player: Player): number
    local data = sessionData[player.UserId]
    if not data then return 16 end -- Standard Roblox default fallback
    
    local baseSpeed = 32 -- Current project standard base
    local levelBonus = BrainrotData.getSpeedBonus(data.SpeedLevel or 0)
    local boostMult = BrainrotData.getMultiplier(player, "Speed")
    
    local intended = (baseSpeed + levelBonus) * boostMult
    
    -- HYBRID TRACKING: If the player currently has a HIGHER physical speed, use it.
    -- This captures mechanical boosts, gamepasses, or environment effects.
    local character = player.Character
    if character then
        local hum = character:FindFirstChild("Humanoid")
        if hum and hum:IsA("Humanoid") then
            -- Only use physical if it's SIGNIFICANTLY higher (avoid noise) or if we want exact sync.
            -- In this project, the user wants the leaderboard to show what they see (500 SPD).
            if hum.WalkSpeed > intended then
                return hum.WalkSpeed
            end
        end
    end
    
    return intended
end

-----------------------------------------------------------
-- CORE: Data Management
-----------------------------------------------------------

local function setupLeaderstats(player: Player, data: PlayerData)
    local ls = Instance.new("Folder")
    ls.Name = "leaderstats"
    ls.Parent = player
    
    local cash = Instance.new("NumberValue")
    cash.Name = "Cash"
    cash.Value = data.Cash
    cash.Parent = ls
    
    local rank = Instance.new("StringValue")
    rank.Name = "Rank"
    rank.Value = data.Rank
    rank.Parent = ls
    
    local reb = Instance.new("IntValue")
    reb.Name = "Rebirths"
    reb.Value = data.Rebirths or 0
    reb.Parent = ls

    local speed = Instance.new("IntValue")
    speed.Name = "Speed"
    speed.Value = math.floor(BrainrotData.calculateIntendedSpeed(player))
    speed.Parent = ls
end

local function countRareUnits(data: PlayerData): number
    if not data or not data.AdvancedInventory then return 0 end
    
    local count = 0
    local RARE_TIERS = {
        ["Legendary"] = true, ["Mythic"] = true, ["Divine"] = true,
        ["Celestial"] = true, ["Cosmic"] = true, ["Eternal"] = true,
        ["Transcendent"] = true, ["Infinite"] = true
    }
    
    for _, u in ipairs(data.AdvancedInventory) do
        if u.Tier and RARE_TIERS[u.Tier] then
            count += 1
        end
    end
    return count
end

local function savePlayerData(player: Player, isClosing: boolean?)
    local userId = player.UserId
    local data = sessionData[userId]
    if not data then return end
    
    -- Deep Copy to prevent mutation during save
    -- (In a real scenario w/ heavy data, maybe just save the ref, but copy is safer)
    
    local success, err = safeCall(function()
        -- SYNC STORED CASH FROM TYCOON BEFORE SAVING
        local UnitManager = require(game:GetService("ServerScriptService"):FindFirstChild("UnitManager"))
        if UnitManager then
            UnitManager.syncAllStoredCash(player)
        end
        
        data.LastPlaytime = os.time() -- Update LastPlaytime on every save
        PlayerDataStore:SetAsync(tostring(userId), data)

        -- LOCAL SYNC: Update Speed in leaderstats for visual feedback
        if player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Speed") then
            player.leaderstats.Speed.Value = math.floor(BrainrotData.calculateIntendedSpeed(player))
        end
    end)
    
    if success then
        -- print("[BrainrotData] Data saved for " .. player.Name)
        
        -- UPDATE LEADERBOARDS (Global)
        if not isClosing then -- Don't update leaderboards on server shutdown to save time
            task.spawn(function()
                local success_lb, LeaderboardManager = pcall(function() 
                    return require(game:GetService("ServerScriptService"):FindFirstChild("LeaderboardManager")) 
                end)
                if success_lb and LeaderboardManager then
                    local currentSpeed = BrainrotData.calculateIntendedSpeed(player)
                    LeaderboardManager.UpdatePlayer(player, data.Cash, currentSpeed)
                end
            end)
        end
    else
        warn("[BrainrotData] CRITICAL: Failed to save for " .. player.Name .. ": " .. tostring(err))
    end
end

local function onPlayerAdded(player: Player)
    -- print("[BrainrotData] onPlayerAdded starting for " .. player.Name .. " (ID: " .. player.UserId .. ")")
    
    if sessionData[player.UserId] then 
        warn("[BrainrotData] sessionData already exists for " .. player.Name .. ", skipping load.")
        return 
    end
    
    -- Initialize with template values
    local data = {}
    for k, v in pairs(PLAYER_TEMPLATE) do
        if type(v) == "table" then
            data[k] = {}
        else
            data[k] = v
        end
    end
    
    -- Load from DS
    local success, result = safeCall(function()
        return PlayerDataStore:GetAsync(tostring(player.UserId))
    end)
    
    if not success then
        warn("[BrainrotData] KICKING PLAYER: Could not load data for " .. player.Name .. ". Error: " .. tostring(result))
        player:Kick("Data Load Error. Please rejoin.")
        return
    end

    local saved = result
    
    if success and saved then
        -- Reconciliation (Merge saved into data)
        for k, v in pairs(saved) do 
            data[k] = v 
        end
        -- print("[BrainrotData] Loaded DataStore for " .. player.Name)
        
        -- MIGRATION: UnitInventory -> AdvancedInventory
        if data.UnitInventory and #data.UnitInventory > 0 then
            -- print("[BrainrotData] Migrating " .. #data.UnitInventory .. " legacy units for " .. player.Name)
            if not data.AdvancedInventory then data.AdvancedInventory = {} end
            
            for _, unitId in ipairs(data.UnitInventory) do
                local name = string.gsub(unitId, "Unit_", "")
                table.insert(data.AdvancedInventory, {
                    Id = BrainrotData.generateUUID(),
                    Name = name,
                    Tier = "Common",
                    Shiny = false,
                    AcquiredAt = os.time()
                })
            end
            data.UnitInventory = {} 
            savePlayerData(player) 
        end

        -- SANITIZATION (Ensure all units have IDs)
        if data.AdvancedInventory then
            local fixes = 0
            for _, unit in ipairs(data.AdvancedInventory) do
                if not unit.Id then
                    unit.Id = BrainrotData.generateUUID()
                    fixes += 1
                end
                if not unit.Tier then unit.Tier = "Common" end
                -- CLEANUP: Reset stuck mutation flags
                if unit.IsMutating then
                    unit.IsMutating = nil
                    fixes += 1
                end
            end
            if fixes > 0 then savePlayerData(player) end
        end
    else
        -- print("[BrainrotData] New Player (or Load Fail): " .. player.Name)
    end
    
    -- DATA INTEGRITY CHECK
    data.TotalRobuxSpent = data.TotalRobuxSpent or 0
    
    sessionData[player.UserId] = data
    setupLeaderstats(player, data)
    
    -- LOG DONOR STATUS (For User Verification)
    local DailyRewardManager = require(game:GetService("ServerScriptService"):WaitForChild("DailyRewardManager"))
    task.spawn(function()
        local info = DailyRewardManager.getDonorInfo(player)
        print(string.format("[BrainrotData] Player %s joined. Total Investment: %d R$ | Donor Level: %s", 
            player.Name, data.TotalRobuxSpent, info.Name))
    end)
    
    player.CharacterAdded:Connect(function(char)
        -- APPLY STATS ROBUSTLY
        BrainrotData.applyCharacterStats(player, char)
    end)
    
    if player.Character then
        BrainrotData.applyCharacterStats(player, player.Character)
    end
    player:SetAttribute("Rebirths", data.Rebirths or 0)
end

-- ROBUST CHARACTER STATS APPLICATION
function BrainrotData.applyCharacterStats(player: Player, char: Model)
    local data = sessionData[player.UserId]
    if not data then return end
    
    -- Sync Attributes
    char:SetAttribute("Rank", data.Rank)
    char:SetAttribute("Income", data.Income)
    
    local hum = char:WaitForChild("Humanoid", 10)
    if not hum then return end
    
    local finalSpeed = BrainrotData.calculateIntendedSpeed(player)
    
    -- FORCE APPLICATION (Retry if overwritten by other scripts)
    hum.WalkSpeed = finalSpeed
    
    -- Anti-Overwrite Patch: Check again after brief delay
    task.delay(0.5, function()
        if hum and hum.Parent and hum.WalkSpeed < finalSpeed then
             -- Only re-apply if it was LOWERED (e.g. by a reset). 
             -- If it's higher (e.g. valid sprint), let it be? No, enforce consistency.
             hum.WalkSpeed = finalSpeed
             -- print(string.format("[BrainrotData] Enforced WalkSpeed %.1f for %s", finalSpeed, player.Name))
        end
    end)
    
    -- SYNC TOOLS (Core Fix v4 - Bidirectional Sync)
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return end
    
    local inventory = data.AdvancedInventory or {}
    local validIds = {}
    for _, unit in ipairs(inventory) do
        if not unit.IsMutating then
            validIds[unit.Id] = true
        end
    end
    
    -- 1. CLEANUP PASS: Remove tools that shouldn't be there (Mutating or Removed)
    local function cleanupIn(container)
        if not container then return end
        for _, item in pairs(container:GetChildren()) do
            if item:IsA("Tool") then
                local uId = item:GetAttribute("UnitId")
                if uId and not validIds[uId] then
                    -- print("[BrainrotData] Removing tool (Mutating/Invalid): " .. item.Name .. " ID: " .. uId)
                    item:Destroy()
                end
            end
        end
    end
    
    cleanupIn(backpack)
    cleanupIn(char)
    
    -- 2. ADDITION PASS: Restore missing tools (Non-Mutating)
    for _, unitData in ipairs(inventory) do
        local uId = unitData.Id
        if not uId or unitData.IsMutating then continue end
        
        local exists = false
        -- Check Backpack
        for _, item in pairs(backpack:GetChildren()) do
            if item:IsA("Tool") and item:GetAttribute("UnitId") == uId then
                exists = true; break
            end
        end
        -- Check Character
        if not exists and char then
            for _, item in pairs(char:GetChildren()) do
                if item:IsA("Tool") and item:GetAttribute("UnitId") == uId then
                    exists = true; break
                end
            end
        end
        
        if not exists then
            local tool = BrainrotData.createUnitTool(unitData.Name, unitData.Tier, unitData.Shiny, unitData.Id, unitData.Level, unitData.ValueMultiplier, unitData.Mutation)
            tool.Parent = backpack
            -- print("[BrainrotData] Restored tool: " .. unitData.Name .. " ID: " .. uId)
        end
    end
    
    player:SetAttribute("Rebirths", data.Rebirths or 0)
end

-----------------------------------------------------------
-- LUCK SYSTEM (NEW)
-----------------------------------------------------------
local LUCK_REGEN_INTERVAL = 30 -- seconds per point
local MAX_LUCK = 100

function BrainrotData.getLuck(player: Player): number
    local data = sessionData[player.UserId]
    if not data then return 0 end
    
    local luck = data.MutationLuck or 100
    local lastUpdate = data.LastLuckUpdate or os.time()
    
    if luck < MAX_LUCK then
        local elapsed = os.time() - lastUpdate
        local pointsToAdd = math.floor(elapsed / LUCK_REGEN_INTERVAL)
        if pointsToAdd > 0 then
            luck = math.min(MAX_LUCK, luck + pointsToAdd)
            -- We don't update data.LastLuckUpdate here to avoid partial point loss on frequent checks
            -- Instead, we only update it when luck is consumed or manually reset.
            -- Actually, to be consistent, we should update it to "keep" the fractional progress.
            -- But for simplicity, we'll just update it during consumption or in a save loop.
        end
    end
    
    return luck
end

function BrainrotData.consumeLuck(player: Player, amount: number)
    local data = sessionData[player.UserId]
    if not data then return end
    
    local current = BrainrotData.getLuck(player)
    data.MutationLuck = math.max(0, current - amount)
    data.LastLuckUpdate = os.time() -- Reset regeneration cycle
    
    BrainrotData.StatsChanged:Fire(player, "MutationLuck", data.MutationLuck)
end

function BrainrotData.setLuck(player: Player, amount: number)
    local data = sessionData[player.UserId]
    if not data then return end
    data.MutationLuck = math.clamp(amount, 0, MAX_LUCK)
    data.LastLuckUpdate = os.time()
    BrainrotData.StatsChanged:Fire(player, "MutationLuck", data.MutationLuck)
end

function BrainrotData.addToHotbar(player: Player, unitId: string): (boolean, number?)
    local data = sessionData[player.UserId]
    if not data then return false end
    
    if not data.Hotbar then data.Hotbar = {} end
    
    -- Check if already assigned
    for slot, id in pairs(data.Hotbar) do
        if id == unitId then 
            -- SYNC TO CLIENT (v4.6)
            local updateHotbarRemote = game:GetService("ReplicatedStorage"):FindFirstChild("UpdateHotbar")
            if updateHotbarRemote then
                updateHotbarRemote:FireClient(player)
            end
            
            -- REFRESH SYNC: Even if already assigned, fire event to ensure client is in sync
            BrainrotData.StatsChanged:Fire(player, "Hotbar", data.Hotbar)
            return true, tonumber(slot) 
        end
    end
    
    -- Find first free slot (1-9)
    for i = 1, 9 do
        local key = tostring(i)
        if not data.Hotbar[key] or data.Hotbar[key] == "" then
            data.Hotbar[key] = unitId
            
            -- SYNC TO CLIENT (v4.6)
            local updateHotbarRemote = game:GetService("ReplicatedStorage"):FindFirstChild("UpdateHotbar")
            if updateHotbarRemote then
                updateHotbarRemote:FireClient(player)
            end
            
            BrainrotData.StatsChanged:Fire(player, "Hotbar", data.Hotbar)
            return true, i
        end
    end
    
    return false
end

-----------------------------------------------------------
-- CASH MANAGEMENT
-----------------------------------------------------------

function BrainrotData.getPlayerSession(player: Player): PlayerData?
    return sessionData[player.UserId]
end

function BrainrotData.getAdvancedInventory(player: Player): {Unit}
    local data = BrainrotData.getPlayerSession(player)
    local inv = data and data.AdvancedInventory or {}
    -- print(string.format("[BrainrotData] getAdvancedInventory for %s -> Returning %d units.", player.Name, #inv))
    return inv
end

function BrainrotData.addUnitAdvanced(player: Player, rawName: string, tier: string?, isShiny: boolean?, skipTool: boolean?, level: number?, existingId: string?, existingValueMult: number?, mutationName: string?): Unit?
    local data = BrainrotData.getPlayerSession(player)
    if not data then return nil end
    
    -- Sanitize Name (Trim spaces AND Replace underscores)
    local name = rawName:gsub("_", " "):match("^%s*(.-)%s*$")
    
    -- Use existing values OR generate new ones
    local EconomyLogic = require(ReplicatedStorage.Modules:WaitForChild("EconomyLogic"))
    local luckMult = BrainrotData.getMultiplier(player, "Luck", data.Boosts)
    local valueMult = existingValueMult or EconomyLogic.generateValueMultiplier(luckMult)
    local unitId = existingId or BrainrotData.generateUUID()
    
    -- Quality & Mutation (New Unit Logic)
    local quality = nil
    if not existingId then -- Only generate for new units
        quality = EconomyLogic.generateQuality()
        
        
        -- ROLL MUTATION (Global Hook)
        if not mutationName then
             mutationName = MutationManager.rollMutation()
             if mutationName then
                -- print("[BrainrotData] ROLLED MUTATION: " .. mutationName .. " for " .. name)
             end
        end
    end
    
    local unitData = {
        Id = unitId,
        Name = name,
        Tier = tier or "Common",
        Shiny = isShiny or false,
        Level = level or 1,
        ValueMultiplier = valueMult,
        Quality = quality or 50, -- Default Normal
        Mutation = mutationName, -- NEW: Persistent Mutation
        AcquiredAt = os.time()
    }
    
    if not data.AdvancedInventory then data.AdvancedInventory = {} end
    table.insert(data.AdvancedInventory, unitData)
    
    -- Notify Systems of Inventory Change
    BrainrotData.StatsChanged:Fire(player, "AdvancedInventory", data.AdvancedInventory)
    
    -- Give Tool (Physical Instance)
    if not skipTool then
        local backpack = player:FindFirstChild("Backpack")
        if backpack then
            local tool = BrainrotData.createUnitTool(name, tier, isShiny, unitData.Id, unitData.Level, unitData.ValueMultiplier, mutationName)
            tool.Parent = backpack
        end
    end
    
    -- PRIORITY: AUTO-FILL HOTBAR
    BrainrotData.addToHotbar(player, unitId)
    
    BrainrotData.markDiscovered(player, name, tier, isShiny)
    return unitData
end

-- Wrapper for backwards compatibility + new params
function BrainrotData.addUnit(player: Player, unitName: string, tier: string?, isShiny: boolean?, level: number?, existingId: string?, existingValueMult: number?): boolean
    local name = string.gsub(unitName, "Unit_", "")
    return BrainrotData.addUnitAdvanced(player, name, tier or "Common", isShiny or false, false, level, existingId, existingValueMult) ~= nil
end

function BrainrotData.removeUnitsById(player: Player, unitIds: {string}): boolean
    local data = BrainrotData.getPlayerSession(player)
    if not data or not data.AdvancedInventory then return false end
    
    local idsToRemove = {}
    for _, id in ipairs(unitIds) do idsToRemove[id] = true end
    
    local newInv = {}
    local count = 0
    for _, unit in ipairs(data.AdvancedInventory) do
        if idsToRemove[unit.Id] then
            count += 1
        else
            table.insert(newInv, unit)
        end
    end
    
    data.AdvancedInventory = newInv
    
    -- Also remove from Hotbar if present
    if data.Hotbar then
        for slot, id in pairs(data.Hotbar) do
            if idsToRemove[id] then
                data.Hotbar[slot] = nil
            end
        end
    end

    -- PHYSICAL REMOVAL: Destroy tools in Backpack or Character
    local character = player.Character
    local backpack = player:FindFirstChild("Backpack")
    
    local function cleanupIn(container)
        if not container then return end
        for _, tool in pairs(container:GetChildren()) do
            if tool:IsA("Tool") then
                local uId = tool:GetAttribute("UnitId")
                if uId and idsToRemove[uId] then
                    tool:Destroy()
                end
            end
        end
    end
    
    cleanupIn(backpack)
    cleanupIn(character)

    -- print(string.format("[BrainrotData] REMOVED %d units and tools. Remaining: %d", count, #data.AdvancedInventory))
    BrainrotData.StatsChanged:Fire(player, "Inventory", #data.AdvancedInventory)
    return true
end

function BrainrotData.removeUnit(player: Player, unitId: string): Unit?
    -- Legacy support for removal by name
    local data = BrainrotData.getPlayerSession(player)
    if not data or not data.AdvancedInventory then return nil end
    -- CANONICAL COMPARISON (Infalible)
    -- Remover "Unit_", espacios, guiones bajos y pasar a minúsculas
    local function toCanonical(str)
        if not str then return "" end
        local s = string.gsub(str, "Unit_", "") -- Remove Prefix first
        s = string.gsub(s, "[_ ]", "") -- Remove all separators
        return string.lower(s) -- Lowercase
    end

    local targetCanonical = toCanonical(unitId)
    -- DEBUG: Print what we are looking for
    -- print("[BrainrotData] Looking for Canonical: " .. targetCanonical) 
    
    for i = #data.AdvancedInventory, 1, -1 do
        local u = data.AdvancedInventory[i]
        
        -- 1. Check ID Match (Strong/Precision)
        if u.Id and u.Id == unitId then
             local removedUnit = table.remove(data.AdvancedInventory, i)
             
             -- HOTBAR CLEANUP
             if data.Hotbar then
                 for slot, id in pairs(data.Hotbar) do
                     if id == unitId then
                         data.Hotbar[slot] = "" -- Clear Slot
                         
                         -- SYNC TO CLIENT (v4.6)
                         local updateHotbarRemote = game:GetService("ReplicatedStorage"):FindFirstChild("UpdateHotbar")
                         if updateHotbarRemote then
                             updateHotbarRemote:FireClient(player)
                         end
                         
                         BrainrotData.StatsChanged:Fire(player, "Hotbar", data.Hotbar)
                         break
                     end
                 end
             end
             
             BrainrotData.StatsChanged:Fire(player, "AdvancedInventory", data.AdvancedInventory)
             return removedUnit
        end

        -- 2. Check Name Match (Legacy/Canonical)
        local storedName = u.Name
        local storedCanonical = toCanonical(storedName)
        
        if storedCanonical == targetCanonical then
            local uId = u.Id
            local removedUnit = table.remove(data.AdvancedInventory, i)
            
            -- HOTBAR CLEANUP (by Canonical Match ID)
            if data.Hotbar and uId then
                for slot, id in pairs(data.Hotbar) do
                    if id == uId then
                        data.Hotbar[slot] = ""
                        BrainrotData.StatsChanged:Fire(player, "Hotbar", data.Hotbar)
                        break
                    end
                end
            end
            
            BrainrotData.StatsChanged:Fire(player, "AdvancedInventory", data.AdvancedInventory)
            return removedUnit
        end
    end
    
    -- Si llegamos aqui, imprime el inventario para ver que pasaba
    warn("[BrainrotData] FAILED TO FIND: " .. targetCanonical)
    warn("--- Current Inventory DUMP ---")
    for _, u in ipairs(data.AdvancedInventory) do
        warn(" > " .. toCanonical(u.Name) .. " (" .. u.Name .. ")")
    end
    warn("------------------------------")
    
    return nil
end

function BrainrotData.addCash(player: Player, amount: number)
    local data = BrainrotData.getPlayerSession(player)
    if data then
        data.Cash += amount
        if player:FindFirstChild("leaderstats") then
             player.leaderstats.Cash.Value = data.Cash
        end
        
        -- Track Lifetime Earnings
        data.TotalCoinsEarned = (data.TotalCoinsEarned or 0) + amount

        -- Fire Event for Achievements
        BrainrotData.StatsChanged:Fire(player, "Cash", data.Cash)
        BrainrotData.StatsChanged:Fire(player, "TotalEarnings", data.TotalCoinsEarned)
    end
end

function BrainrotData.deductCash(player: Player, amount: number): boolean
    local data = BrainrotData.getPlayerSession(player)
    if data and data.Cash >= amount then
        data.Cash -= amount
        if player:FindFirstChild("leaderstats") then
             player.leaderstats.Cash.Value = data.Cash
        end
        return true
    end
    return false
end

function BrainrotData.upgradeCapacity(player: Player, amount: number?): boolean
    local data = BrainrotData.getPlayerSession(player)
    if data then
        data.BackpackLevel = (data.BackpackLevel or 0) + 1
        data.BackpackCapacity = (data.BackpackCapacity or 5) + (amount or 1)
        -- print(string.format("[BrainrotData] %s upgraded capacity to %d (Lvl %d)", player.Name, data.BackpackCapacity, data.BackpackLevel))
        return true
    end
    return false
end

function BrainrotData.doRebirth(player: Player): (boolean, any)
    local data = BrainrotData.getPlayerSession(player)
    if not data then return false, "No Data" end
    
    local EconomyLogic = require(ReplicatedStorage.Modules.EconomyLogic)
    local rebirths = data.Rebirths or 0
    local cost = EconomyLogic.calculateRebirthCost(rebirths)
    
    if data.Cash < cost then
        return false, "Necesitas $" .. EconomyLogic.Abbreviate(cost)
    end
    
    -- 1. Deduct Cash
    data.Cash -= cost
    
    -- 2. Return Placed Units to Inventory (CRITICAL FIX)
    if data.PlacedUnits then
        -- print("[BrainrotData] Rebirth: Returning placed units to inventory.")
        for slotIdx, unitData in pairs(data.PlacedUnits) do
            if type(unitData) == "table" then
                table.insert(data.AdvancedInventory, {
                    Id = unitData.UnitId or BrainrotData.generateUUID(),
                    Name = unitData.Name,
                    Tier = unitData.Tier or "Common",
                    Shiny = unitData.Shiny or false,
                    Level = unitData.Level or 1,
                    ValueMultiplier = unitData.ValueMultiplier or 1.0,
                    Mutation = unitData.Mutation,
                    AcquiredAt = os.time()
                })
            end
        end
    end

    -- 3. Trigger Physical Reset
    local UnitManager = require(game:GetService("ServerScriptService"):FindFirstChild("UnitManager"))
    if UnitManager then
        UnitManager.resetTycoonPhysical(player)
    end

    -- 4. Update Stats
    data.Rebirths = rebirths + 1
    data.Cash = 1000 -- Starting bonus
    data.PlacedUnits = {} 
    data.SpeedLevel = 0 -- Reset speed upgrades
    data.Boosts = {} -- Reset active boosts (prevents persistent 32 SPD)
    
    -- Sync Attributes & Leaderstats
    player:SetAttribute("Rebirths", data.Rebirths)
    if player:FindFirstChild("leaderstats") then
        player.leaderstats.Cash.Value = data.Cash
        if player.leaderstats:FindFirstChild("Rebirths") then
            player.leaderstats.Rebirths.Value = data.Rebirths
        end
    end
    
    -- Update Character
    if player.Character then
        player.Character:SetAttribute("Income", 0)
        -- Reset speed? 
        -- If Rebirth resets Upgrade Levels (including SpeedLevel), then logic dictates speed resets to 16.
        -- BUT, if we want to ensure it calculates correctly:
        BrainrotData.applyCharacterStats(player, player.Character)
    end
    
    savePlayerData(player)
    print(string.format("[BrainrotData] Rebirth SUCCESS for %s. New Count: %d", player.Name, data.Rebirths))
    
    return true, data.Rebirths
end

-- Helper for counting
function table_count(t: {[any]: any}): number
    local c = 0
    for _ in pairs(t) do c += 1 end
    return c
end


function BrainrotData.markDiscovered(player: Player, name: string, tier: string?, isShiny: boolean?)
    local data = BrainrotData.getPlayerSession(player)
    if not data then return end
    
    if not data.Discoveries then data.Discoveries = {} end
    
    local changed = false

    -- Legacy: just name
    if not table.find(data.Discoveries, name) then
        table.insert(data.Discoveries, name)
        changed = true
    end
    
    -- Modern: Name_Tier
    if tier then
        local key = name .. "_" .. tier
        if not table.find(data.Discoveries, key) then
            table.insert(data.Discoveries, key)
            changed = true
        end
    end
    
    -- Modern: Shiny
    if isShiny and tier then
        local key = name .. "_" .. tier .. "_SHINY"
        if not table.find(data.Discoveries, key) then
            table.insert(data.Discoveries, key)
            changed = true
        end
    end

    if changed then
        BrainrotData.StatsChanged:Fire(player, "Discoveries", #data.Discoveries, tier, isShiny)
    end
end

-- Helper for Client Index
function BrainrotData.getDiscoveredMap(player: Player): {[string]: boolean}
    local data = BrainrotData.getPlayerSession(player)
    local map = {}
    if data and data.Discoveries then
        for _, disc in ipairs(data.Discoveries) do
            map[disc] = true
        end
    end
    return map
end

function BrainrotData.getPlacedUnits(player: Player): {[string]: any}
    local data = BrainrotData.getPlayerSession(player)
    return data and data.PlacedUnits or {}
end

function BrainrotData.setPlacedUnit(player: Player, slotIndex: number, unitName: string?, isShiny: boolean?, unitId: string?, level: number?, valueMultiplier: number?, tier: string?, mutationName: string?, storedCash: number?)
    local data = BrainrotData.getPlayerSession(player)
    if not data then return end
    if not data.PlacedUnits then data.PlacedUnits = {} end
    
    if unitName == nil then
        data.PlacedUnits[tostring(slotIndex)] = nil
    else
        data.PlacedUnits[tostring(slotIndex)] = {
            Name = unitName,
            Shiny = isShiny or false,
            UnitId = unitId,
            Level = level or 1,
            ValueMultiplier = valueMultiplier or 1.0,
            Tier = tier or "Common",
            Mutation = mutationName,
            StoredCash = storedCash or 0
        }
    end
end

function BrainrotData.incrementEggsOpened(player: Player)
    local data = BrainrotData.getPlayerSession(player)
    if data then data.EggsOpened += 1 end
end

function BrainrotData.upgradeUnitLevel(player: Player, unitId: string): (boolean, any)
    local data = BrainrotData.getPlayerSession(player)
    if not data then return false, "No Data" end
    
    -- Lazy require to prevent circular dependency issues
    local EconomyLogic = require(game:GetService("ReplicatedStorage").Modules.EconomyLogic)

    -- 1. Check Placed Units (Tycoon Slots)
    if data.PlacedUnits then
        for slotId, unitData in pairs(data.PlacedUnits) do
            if unitData.UnitId == unitId then
                 local lvl = unitData.Level or 1
                 local tier = unitData.Tier or "Common"
                 local cost = EconomyLogic.calculateUpgradeCost(tier, lvl)
                 
                 if not BrainrotData.deductCash(player, cost) then
                     return false, "Need $" .. EconomyLogic.Abbreviate(cost)
                 end
                 
                 unitData.Level = lvl + 1
                 -- unitData.ValueMultiplier is preserved
                 
                 return true, unitData.Level
            end
        end
    end
    
    -- 2. Check Inventory (Backpack/Storage)
    if data.AdvancedInventory then
        for _, unitData in ipairs(data.AdvancedInventory) do
            -- unitData handles UnitId directly
            if unitData.UnitId == unitId then
                 local lvl = unitData.Level or 1
                 local tier = unitData.Tier or "Common"
                 local cost = EconomyLogic.calculateUpgradeCost(tier, lvl)
                 
                  if not BrainrotData.deductCash(player, cost) then
                     return false, "Need $" .. EconomyLogic.Abbreviate(cost)
                 end
                 
                 unitData.Level = lvl + 1
                 return true, unitData.Level
            end
        end
    end
    
    return false, "Unit not found"
end

function BrainrotData.incrementFusions(player: Player)
    local data = BrainrotData.getPlayerSession(player)
    if data then data.FusionsPerformed += 1 end
end

function BrainrotData.Init()
    print("[BrainrotData] Initializing...")
    
    Players.PlayerAdded:Connect(onPlayerAdded)
    for _, p in pairs(Players:GetPlayers()) do
        onPlayerAdded(p)
    end
    
    Players.PlayerRemoving:Connect(function(player)
        savePlayerData(player)
        sessionData[player.UserId] = nil
    end)

    -- Initialize Shared Events
    local levelUpRemote = ReplicatedStorage:FindFirstChild("DonorLevelUp")
    if not levelUpRemote then
        levelUpRemote = Instance.new("RemoteEvent")
        levelUpRemote.Name = "DonorLevelUp"
        levelUpRemote.Parent = ReplicatedStorage
    end

    -- BindToClose (Server Shutdown)
    game:BindToClose(function()
        print("[BrainrotData] Server shutting down. Saving all data...")
        
        -- Use a counter to track pending saves if needed, or just iterate (which is blocking in BindToClose)
        -- In BindToClose, we have ~30 seconds.
        
        -- Parallel saving is risky with limits, but sequential is safer for data integrity
        for _, player in pairs(Players:GetPlayers()) do
            task.spawn(function()
                savePlayerData(player, true) -- true = isClosing
            end)
        end
        
        task.wait(3) -- Give time for async saves to fire off
        print("[BrainrotData] BindToClose complete.")
    end)
    
    -- Auto-save loop (Modern)
    task.spawn(function()
        while true do
            task.wait(120) -- 2 minute auto-save
            for _, player in pairs(Players:GetPlayers()) do
                savePlayerData(player)
                task.wait(0.5) -- Stagger saves
            end
        end
    end)
    
    -- API for Client Index
    local rf = ReplicatedStorage:WaitForChild("GetDiscovered")
    rf.OnServerInvoke = function(player)
        return BrainrotData.getDiscoveredMap(player)
    end
    
    -- REBIRTH API
    local rbFunc = ReplicatedStorage:WaitForChild("DoRebirth")
    rbFunc.OnServerInvoke = function(player)
        local data = BrainrotData.getPlayerSession(player)
        if not data then return false, "No Data" end
        
        local EconomyLogic = require(ReplicatedStorage.Modules.EconomyLogic)
        local cost = EconomyLogic.calculateRebirthCost(data.Rebirths or 0)
        
        if data.Cash >= cost then
             local success, count = BrainrotData.doRebirth(player)
             
             -- Update Multiplier on Tycoon immediately if success
             if success then
                 local UnitManager = require(game:GetService("ServerScriptService"):FindFirstChild("UnitManager"))
             end
             
             return success, count
        else
             return false, "Need $" .. EconomyLogic.Abbreviate(cost)
        end
    end
    
    -- BOOST SHOP API
    local buyBoostFunc = Instance.new("RemoteFunction")
    buyBoostFunc.Name = "BuyBoost"
    buyBoostFunc.Parent = ReplicatedStorage
    
    buyBoostFunc.OnServerInvoke = function(player, boostId)
        local cost = 5000 -- Placeholder: Move to config later
        local data = BrainrotData.getPlayerSession(player)
        if not data then return false, "No Data" end
        
        -- Check if boost exists
        local BoostManager = require(ReplicatedStorage.Modules:WaitForChild("BoostManager"))
        local info = BoostManager.getBoostInfo(boostId)
        if not info then return false, "Invalid Boost" end
        
        -- Deduct Cash
        if data.Cash >= cost then
            BrainrotData.deductCash(player, cost)
            BrainrotData.addBoost(player, boostId)
            return true
        else
            return false, "Need $" .. cost
        end
    end
    
    -- INVENTORY API (Integrated with Hotbar & Settings)
    local getInvFunc = ReplicatedStorage:FindFirstChild("GetInventory") or Instance.new("RemoteFunction")
    getInvFunc.Name = "GetInventory"
    getInvFunc.Parent = ReplicatedStorage
    getInvFunc.OnServerInvoke = function(player)
        return BrainrotData.getInventorySyncData(player)
    end
    
    -- HOTBAR SYNC API
    local updateHotbarRemote = ReplicatedStorage:WaitForChild("UpdateHotbar")
    updateHotbarRemote.OnServerEvent:Connect(function(player, hotbarMap)
        local data = BrainrotData.getPlayerSession(player)
        if data and type(hotbarMap) == "table" then
            data.Hotbar = hotbarMap
            print("[BrainrotData] Updated Hotbar for " .. player.Name .. ". Saving immediately.")
            savePlayerData(player) -- PERSIST IMMEDIATELY
        end
    end)

    -- SYNC SPEED FROM CLIENT (Fix for 32 vs 500 SPD discrepancy)
    local syncSpeedRemote = ReplicatedStorage:WaitForChild("SyncSpeed")
    syncSpeedRemote.OnServerEvent:Connect(function(player, clientSpeed)
        if typeof(clientSpeed) ~= "number" then return end
        
        -- Update leaderstats immediately for visual consistency
        if player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Speed") then
            player.leaderstats.Speed.Value = math.floor(clientSpeed)
        end
        
        -- Update Global Leaderboard (Only if higher - handled by UpdateAsync in LeaderboardManager)
        local LeaderboardManager = require(game:GetService("ServerScriptService"):FindFirstChild("LeaderboardManager"))
        if LeaderboardManager then
            local data = sessionData[player.UserId]
            local cash = data and data.Cash or 0
            LeaderboardManager.UpdatePlayer(player, cash, clientSpeed)
        end
    end)
    
    
end

function BrainrotData.unlockAchievement(player: Player, achievementId: string): boolean
    local data = BrainrotData.getPlayerSession(player)
    if not data then return false end
    
    if not data.Achievements then data.Achievements = {} end
    
    if not data.Achievements[achievementId] then
        data.Achievements[achievementId] = true
        savePlayerData(player) -- Save immediately on achievement
        return true
    end
    return false
end

-- BOOST API
function BrainrotData.addBoost(player: Player, boostId: string): boolean
    local data = BrainrotData.getPlayerSession(player)
    if not data then return false end
    
    local BoostManager = require(ReplicatedStorage.Modules:WaitForChild("BoostManager"))
    local info = BoostManager.getBoostInfo(boostId)
    if not info then return false end
    
    if not data.Boosts then data.Boosts = {} end
    
    -- Add duration to current time (or extend if already active)
    local now = os.time()
    local currentExpiry = data.Boosts[boostId] or now
    if currentExpiry < now then currentExpiry = now end
    
    data.Boosts[boostId] = currentExpiry + info.Duration
    
    print(string.format("[BrainrotData] Added Boost %s to %s. Expires in %ds", boostId, player.Name, (data.Boosts[boostId] - now)))
    savePlayerData(player) -- Save immediately for safety
    
    -- Handle Speed Boost immediately if applicable
    if info.Type == "Speed" then
        local char = player.Character
        if char then
             local hum = char:FindFirstChild("Humanoid")
              local finalSpeed = BrainrotData.calculateIntendedSpeed(player)
              if hum then hum.WalkSpeed = finalSpeed end
        end
    end
    
    return true
end

function BrainrotData.getMultiplier(player: Player, boostType: string, dataBoosts: {[string]: number}?): number
    local mult = 1.0
    
    if not dataBoosts then
        local data = BrainrotData.getPlayerSession(player)
        dataBoosts = data and data.Boosts or {}
    end
    
    if not dataBoosts then return mult end
    local now = os.time()
    
    local BoostManager = require(ReplicatedStorage.Modules:WaitForChild("BoostManager"))
    for bId, expiry in pairs(dataBoosts) do
        if expiry > now then
            local def = BoostManager.getBoostInfo(bId)
            if def and def.Type == boostType then
                mult = mult * def.Multiplier
            end
        end
    end
    
    return mult
end



function BrainrotData.getInventorySyncData(player: Player): {Inventory: {Unit}, Hotbar: {[string]: string}}
    local data = BrainrotData.getPlayerSession(player)
    if not data then return { Inventory = {}, Hotbar = {} } end
    
    local filteredInv = {}
    if data.AdvancedInventory then
        for _, u in ipairs(data.AdvancedInventory) do
            if not u.IsMutating then
                table.insert(filteredInv, u)
            end
        end
    end
    
    return {
        Inventory = filteredInv,
        Hotbar = data.Hotbar or {}
    }
end

-----------------------------------------------------------
-- SHOP API (Tokens & Cosmetics)
-----------------------------------------------------------

function BrainrotData.addTokens(player: Player, amount: number)
    local data = BrainrotData.getPlayerSession(player)
    if data then
         data.Tokens = (data.Tokens or 0) + amount
         savePlayerData(player) -- Save high value transactions immediately
         print(string.format("[BrainrotData] Added %d Tokens to %s. Total: %d", amount, player.Name, data.Tokens))
    end
end

function BrainrotData.trackRobuxSpent(player: Player, amount: number)
    local data = BrainrotData.getPlayerSession(player)
    if data and amount > 0 then
        local DailyRewardManager = require(game:GetService("ServerScriptService"):FindFirstChild("DailyRewardManager"))
        local oldLevel = DailyRewardManager.getDonorInfo(player).Level
        
        data.TotalRobuxSpent = (data.TotalRobuxSpent or 0) + amount
        
        local newInfo = DailyRewardManager.getDonorInfo(player)
        local newLevel = newInfo.Level
        
        -- LEVEL UP LOGIC
        if newLevel > oldLevel then
            print(string.format("[INVESTMENT] %s LEVELED UP! %d -> %d", player.Name, oldLevel, newLevel))
            
            -- Reward: Instant Reset of Daily Cooldown so they can claim their new tier immediately
            data.LastDailyReward = 0 
            
            -- Trigger Client VFX
            local levelUpRemote = ReplicatedStorage:FindFirstChild("DonorLevelUp")
            if not levelUpRemote then
                levelUpRemote = Instance.new("RemoteEvent")
                levelUpRemote.Name = "DonorLevelUp"
                levelUpRemote.Parent = ReplicatedStorage
            end
            levelUpRemote:FireClient(player, newInfo.RewardId)
        end
        
        print(string.format("[SECURITY] Tracked %d Robux investment for %s. Lifetime Total: %d", amount, player.Name, data.TotalRobuxSpent))
        savePlayerData(player)
    end
end

function BrainrotData.getTokens(player: Player): number
    local data = BrainrotData.getPlayerSession(player)
    return data and (data.Tokens or 0) or 0
end

function BrainrotData.addCosmetic(player: Player, cosmeticId: string): (boolean, string)
    local data = BrainrotData.getPlayerSession(player)
    if not data then return false, "No Data" end
    
    if not data.Cosmetics then data.Cosmetics = {} end
    
    -- check if owned
    for _, id in ipairs(data.Cosmetics) do
        if id == cosmeticId then return false, "Already Owned" end
    end
    
    table.insert(data.Cosmetics, cosmeticId)
    savePlayerData(player) -- Save purchase immediately
    return true, "Unlock Success"
end

function BrainrotData.hasCosmetic(player: Player, cosmeticId: string): boolean
    local data = BrainrotData.getPlayerSession(player)
    if not data or not data.Cosmetics then return false end
    
    for _, id in ipairs(data.Cosmetics) do
        if id == cosmeticId then return true end
    end
    return false
end

-----------------------------------------------------------
-- TYCOON CUSTOMIZATION API
-----------------------------------------------------------

function BrainrotData.saveFloorColor(player: Player, floorName: string, color: Color3)
    local data = BrainrotData.getPlayerSession(player)
    if not data then return end
    
    if not data.FloorColors then data.FloorColors = {} end
    data.FloorColors[floorName] = { r = color.R, g = color.G, b = color.B }
    
    -- Save periodically (every 5-10 mins) or use savePlayerData for immediate
    -- For color, we can just let it save on leave, but let's do one save for safety if it's the first time
    -- actually, standard tycoon practice is to save on leave or auto-save loop.
end

function BrainrotData.getFloorColors(player: Player): {[string]: Color3}
    local data = BrainrotData.getPlayerSession(player)
    if not data or not data.FloorColors then return {} end
    
    local colors = {}
    for floorName, rgb in pairs(data.FloorColors) do
        colors[floorName] = Color3.new(rgb.r, rgb.g, rgb.b)
    end
    return colors
end

return BrainrotData
