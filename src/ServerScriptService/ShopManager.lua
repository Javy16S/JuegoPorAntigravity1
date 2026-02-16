-- ShopManager.server.lua
-- Skill: shop-interaction
-- Description: Manages the physical shop interaction via ProximityPrompt.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local ShopManager = {}

function ShopManager.Init()
    print("[ShopManager] Initializing ProximityPrompt Shop System...")
    
    local function setupZone(zone, isUpgrade)
        zone.Transparency = 0.8
        zone.CanCollide = false
        zone.Anchored = true
        
        -- Cleanup legacy prompts if map was re-simulated
        for _, p in pairs(zone:GetChildren()) do
            if p:IsA("ProximityPrompt") then p:Destroy() end
        end

        if not isUpgrade then
            -- ONLY add prompt to Sell Shop as requested (Manual Interaction)
            local prompt = Instance.new("ProximityPrompt")
            prompt.ObjectText = "Mercado Negro"
            prompt.ActionText = "💰 VENDER"
            prompt.KeyboardKeyCode = Enum.KeyCode.E
            prompt.RequiresLineOfSight = false
            prompt.MaxActivationDistance = 12
            prompt.Parent = zone
            
            prompt:SetAttribute("ShopType", "Sell")
            
            -- FIX (2026-02-04): DECOUPLED SELL FROM INTERACTION
            -- "E" now only serves as a hook for the Client to open the UI.
            -- Server does nothing on trigger except maybe log it.
            prompt.Triggered:Connect(function(player)
                -- Logic moved to UI (SimpleShopUI / ShopClient)
                -- Do NOT sell here.
                print("[ShopManager] Player interacted with shop prompt.")
            end)
        end
    end

    -- Setup Sell Zones
    for _, zone in pairs(CollectionService:GetTagged("SellZone")) do
        setupZone(zone, false)
    end
    CollectionService:GetInstanceAddedSignal("SellZone"):Connect(function(zone)
        setupZone(zone, false)
    end)
    
    -- Setup Upgrade Zones
    for _, zone in pairs(CollectionService:GetTagged("UpgradeZone")) do
        setupZone(zone, true)
    end
    CollectionService:GetInstanceAddedSignal("UpgradeZone"):Connect(function(zone)
        setupZone(zone, true)
    end)
    
    print("[ShopManager] Shop Prompts Active & Listening for new Zones.")
end

-- Use SystemLoader to Init, but if running standalone (dev mode):
-- ShopManager.Init() 

return ShopManager
