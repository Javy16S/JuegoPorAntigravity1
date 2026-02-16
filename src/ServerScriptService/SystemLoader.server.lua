-- SystemLoader.server.lua
-- PROPER INITIALIZATION ORDER
-- 1. Create Remotes
-- 2. Run Organizer
-- 3. Require Modules (to init data loops)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- 0. MutationManager is now shared via Rojo in ReplicatedStorage

print("[SystemLoader] Initializing Brainrot Simulator...")

-- 1. Ensure RemoteEvents Exist
local function ensureRemote(name, class)
    if not ReplicatedStorage:FindFirstChild(name) then
        local r = Instance.new(class)
        r.Name = name
        r.Parent = ReplicatedStorage
        print("  Created Remote: " .. name)
    end
end

ensureRemote("PurchaseSkill", "RemoteFunction")
ensureRemote("PlaceUnit", "RemoteFunction")
ensureRemote("InteractSlot", "RemoteEvent") 
ensureRemote("OnIncomeTick", "RemoteEvent")
ensureRemote("EggOpenEvent", "RemoteEvent")
ensureRemote("FusionEvent", "RemoteEvent")
ensureRemote("PurchaseEgg", "RemoteFunction")
ensureRemote("FuseUnits", "RemoteFunction")
ensureRemote("FusionPreview", "RemoteFunction")
ensureRemote("GetInventory", "RemoteFunction")
ensureRemote("SellUnits", "RemoteFunction")
ensureRemote("SellAllUnits", "RemoteFunction")
ensureRemote("SellHandUnit", "RemoteFunction")
ensureRemote("GetSellValues", "RemoteFunction")
ensureRemote("GetDiscovered", "RemoteFunction") -- New for Index
ensureRemote("GetUpgradeData", "RemoteFunction") -- For Shop UI

-- 2. RUN ORGANIZER FIRST (Move models to ServerStorage)
local Organizer = require(ServerScriptService:WaitForChild("OrganizerTool"))
if Organizer.Run then
    Organizer.Run()
end

-- 3. INITIALIZE DATA
local BrainrotData = require(ServerScriptService.BrainrotData)
if BrainrotData.Init then
    BrainrotData.Init()
end

-- 4. INITIALIZE MANAGERS
local UnitManager = require(ServerScriptService.UnitManager)
if UnitManager.Init then
    UnitManager.Init()
end

local EggManager = require(ServerScriptService.EggManager)
if EggManager.Init then
    EggManager.Init()
end

local FusionManager = require(ServerScriptService.FusionManager)
if FusionManager.Init then
    FusionManager.Init()
end

local ShopManager = require(ServerScriptService:WaitForChild("ShopManager"))
if ShopManager.Init then
    ShopManager.Init()
end

print("[SystemLoader] Initialization Complete. All systems synchronized.")
