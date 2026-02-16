--!strict
-- LeaderboardManager.server.lua
-- Skill: roblox-scripting-expert
-- Description: Manages Global Leaderboards for Money and Rare Units using OrderedDataStore.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Configuration
local UPDATE_INTERVAL = 5 -- REDUCED FOR TESTING
local MAX_ITEMS = 50

-- DataStores
-- DataStores
local MoneyStore = DataStoreService:GetOrderedDataStore("GlobalLeaderboard_Money_v4")
local SpeedStore = DataStoreService:GetOrderedDataStore("GlobalLeaderboard_MaxSpeed_v1")

local VERSION = "LB_4.1_COMPRESSED"
print("🚀 [" .. VERSION .. "] Loading Leaderboard System...")

local LeaderboardManager = {}

-- ============================================================================
-- HELPER: FORMAT NUMBERS
-- ============================================================================
local function formatNumber(n: number): string
    if n >= 1e24 then return string.format("%.2fSp", n / 1e24) end -- Septillion
    if n >= 1e21 then return string.format("%.2fSx", n / 1e21) end -- Sextillion
    if n >= 1e18 then return string.format("%.2fQi", n / 1e18) end -- Quintillion
    if n >= 1e15 then return string.format("%.2fQa", n / 1e15) end -- Quadrillion
    if n >= 1e12 then return string.format("%.2fT", n / 1e12) end
    if n >= 1e9 then return string.format("%.2fB", n / 1e9) end
    if n >= 1e6 then return string.format("%.2fM", n / 1e6) end
    if n >= 1e3 then return string.format("%.2fK", n / 1e3) end
    return tostring(math.floor(n))
end

-- Large Number Compression for OrderedDataStore (Limit ~9e18)
-- Stored as: (Exponent * 1e14) + (Mantissa * 1e13)
-- Example: 1.5e21 -> Exp=21, Mant=1.5 -> (21 * 1e14) + (1.5 * 1e13) = 2.115e15 (Safe)
local function compressScore(n: number): number
    if n <= 0 then return 0 end
    local exp = math.floor(math.log10(n))
    local mant = n / (10 ^ exp)
    return math.floor((exp * 1e14) + (mant * 1e13))
end

local function decompressScore(s: number): number
    if s <= 0 then return 0 end
    local exp = math.floor(s / 1e14)
    local mant = (s - (exp * 1e14)) / 1e13
    return mant * (10 ^ exp)
end

-- ============================================================================
-- UPDATE SPECIFIC BOARD
-- ============================================================================
local function updateBoardVisuals(boardName: string, data: { {key: string, value: number} }, labelSuffix: string?)
    local boardModel = workspace:FindFirstChild(boardName)
    if not boardModel then return end
    
    local screen = boardModel:FindFirstChild("Screen")
    if not screen then 
        warn("❌ Part 'Screen' missing in " .. boardName)
        return 
    end
    
    local uis = {}
    for _, child in pairs(screen:GetChildren()) do
        if child.Name == "LeaderboardUI" then
            table.insert(uis, child)
        end
    end
    
    if #uis == 0 then return end
    
    for _, surfaceGui in ipairs(uis) do
        local frame = surfaceGui:FindFirstChild("Frame")
        local list = frame and frame:FindFirstChild("List")
        
        if not list then 
            warn("❌ List or Frame missing in " .. boardName)
            continue 
        end
        
        -- Safe template
        local template = script:FindFirstChild("RowTemplate")
        if not template then continue end
        
        -- Clear old items (BUT KEEP THE TEMPLATE if it's there, although it's in script)
        for _, child in pairs(list:GetChildren()) do
            if (child:IsA("Frame") and child.Name ~= "RowTemplate") or child:IsA("UIListLayout") then
                child:Destroy()
            end
        end
        
        -- New Layout
        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 8)
        layout.Parent = list
        
        print(string.format("🎨 [LeaderboardManager] Rendering %d entries on %s (%s)", #data, boardName, surfaceGui.Face.Name))
        
        if #data == 0 then
            print("⚠️ [LeaderboardManager] No data to render for " .. boardName)
        end

        for rank, entry in ipairs(data) do
            local userId = tonumber(entry.key)
            if not userId then continue end
            
            local row = template:Clone()
            row.Name = "Entry_" .. rank
            row.LayoutOrder = rank
            row.ZIndex = 11
            row.Visible = true
            
            -- Top 3 Colors
            local rankBox = row:FindFirstChild("RankBox", true) or row:FindFirstChild("Frame", true)
            if rankBox then
                if rank == 1 then
                    rankBox.BackgroundColor3 = Color3.fromRGB(255, 215, 0) -- Gold
                    rankBox.BackgroundTransparency = 0.2
                elseif rank == 2 then
                    rankBox.BackgroundColor3 = Color3.fromRGB(192, 192, 192) -- Silver
                    rankBox.BackgroundTransparency = 0.2
                elseif rank == 3 then
                    rankBox.BackgroundColor3 = Color3.fromRGB(205, 127, 50) -- Bronze
                    rankBox.BackgroundTransparency = 0.2
                end
            end
            
            -- Labels
            local rankLbl = row:FindFirstChild("RankLabel", true)
            local nameLbl = row:FindFirstChild("NameLabel", true)
            local valLbl = row:FindFirstChild("ValueLabel", true)
            local icon = row:FindFirstChild("AvatarIcon", true)
            
            if rankLbl then rankLbl.Text = "#" .. rank end
            if valLbl then 
                local displayValue = entry.value
                if labelSuffix ~= "SPD" then
                    displayValue = decompressScore(entry.value)
                end
                valLbl.Text = (labelSuffix == "SPD" and formatNumber(displayValue) .. " SPD") or "$" .. formatNumber(displayValue)
            end
            
            task.spawn(function()
                local success, name = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
                if success and nameLbl then 
                    nameLbl.Text = name 
                    if rank <= 3 then nameLbl.Font = Enum.Font.GothamBlack end
                end
                if icon then
                    local content, isReady = Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
                    if isReady then icon.Image = content end
                end
            end)
            
            row.Parent = list
        end
    end
end

-- ============================================================================
-- CORE LOGIC
-- ============================================================================

function LeaderboardManager.ForceUpdate()
    print("🔄 [LeaderboardManager] Starting ForceUpdate...")
    local success, err = pcall(function()
        -- 1. Get Sorted Data
        print("📥 [" .. VERSION .. "] Fetching from DataStore...")
        local moneyPages = MoneyStore:GetSortedAsync(false, MAX_ITEMS)
        local speedPages = SpeedStore:GetSortedAsync(false, MAX_ITEMS)
        
        local topMoney = moneyPages:GetCurrentPage()
        local topSpeed = speedPages:GetCurrentPage()
        
        print(string.format("📊 [LeaderboardManager] Data received! Money: %d entries, Speed: %d entries", #topMoney, #topSpeed))
        
        -- DEBUG: Print first money entry raw value
        if #topMoney > 0 then
            print(string.format("🔍 [DEBUG] First Money Entry: Key=%s, RawValue=%s", tostring(topMoney[1].key), tostring(topMoney[1].value)))
        end
        
        -- 2. Update Visuals
        updateBoardVisuals("Leaderboard_Money", topMoney, nil)
        updateBoardVisuals("Leaderboard_Rare", topSpeed, "SPD")
    end)
    
    if not success then
        warn("❌ [LeaderboardManager] Update failed: " .. tostring(err))
    end
end

local function updateLeaderboards()
    LeaderboardManager.ForceUpdate()
end

-- ============================================================================
-- MAIN API (Called by BrainrotData)
-- ============================================================================

function LeaderboardManager.UpdatePlayer(player: Player, money: number, maxSpeed: number)
    if not player then return end
    
    task.spawn(function()
        local success, err = pcall(function()
            if money then 
                local compressedMoney = compressScore(money)
                print(string.format("💾 [DEBUG] Saving Money for %s: Original=%s, Compressed=%s", player.Name, tostring(money), tostring(compressedMoney)))
                MoneyStore:SetAsync(tostring(player.UserId), compressedMoney) 
            end
            if maxSpeed then 
                SpeedStore:UpdateAsync(tostring(player.UserId), function(oldValue)
                    local currentMax = oldValue or 0
                    if maxSpeed > currentMax then
                        return math.floor(maxSpeed)
                    end
                    return currentMax
                end)
            end
        end)
        if success then
            print("[Leaderboard] Updated scores for " .. player.Name)
        else
            warn("[Leaderboard] Failed to update " .. player.Name .. ": " .. tostring(err))
        end
    end)
end

-- Loop
task.spawn(function()
    while true do
        task.wait(UPDATE_INTERVAL)
        updateLeaderboards()
    end
end)

-- Initial Wait and Load
task.delay(5, updateLeaderboards)

return LeaderboardManager
