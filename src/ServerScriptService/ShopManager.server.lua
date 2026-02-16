-- ShopManager.server.lua
-- Server-side shop logic and purchase handling
-- Place this in ServerScriptService/

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- Wait for modules
local Modules = ReplicatedStorage:WaitForChild("Modules", 10) or ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules") -- Fallback if structure varies
local ShopData = require(Modules:WaitForChild("ShopData"))
local BrainrotData = require(game:GetService("ServerScriptService").BrainrotData)

-- Initialize Events (Requires ShopEvents to create them if they don't exist)
local ShopEvents = require(Modules:WaitForChild("ShopEvents"))

-- Wait for RemoteEvents (They should be created by ShopEvents require above)
local Events = ReplicatedStorage:WaitForChild("Events")
local PurchaseItemEvent = Events:WaitForChild("PurchaseItem")
local OpenShopEvent = Events:WaitForChild("OpenShop")

-- CONFIG
local ROBUX_TO_TOKENS_RATIO = 1 -- 1 Robux = 1 Token (adjust as needed)


-- FUNCTIONS: Inventory Management (Bridge to BrainrotData)
local function getPlayerInventory(player)
    -- Bridge to new system for compatibility with existing code structure
    local tokens = BrainrotData.getTokens(player)
    local cosmetics = BrainrotData.getPlayerSession(player).Cosmetics or {}
    
    return {
        Tokens = tokens,
        Cosmetics = cosmetics,
        VIPPackages = {} -- Deprecated/Not Stored in Session yet? Or just track by purchase
    }
end

local function hasEnoughRobux(player, price)
    -- In production, check actual Robux balance via MarketplaceService
    -- For now, return true for testing
    return true
end

local function deductRobux(player, amount)
    -- In production, use PromptProductPurchase
    -- This is a placeholder
    print("Deducted " .. amount .. " Robux from " .. player.Name)
    return true
end

-- FUNCTIONS: Purchase Handlers
local function purchaseVIPPackage(player, packageID)
    local packageData = ShopData.getVIPPackageByID(packageID)
    
    if not packageData then
        warn("Invalid VIP package ID: " .. packageID)
        return false, "Paquete no encontrado"
    end
    
    -- Check if player can afford it
    if not hasEnoughRobux(player, packageData.Price) then
        return false, "Robux insuficientes"
    end
    
    -- Deduct Robux
    local success = deductRobux(player, packageData.Price)
    if not success then
        return false, "Error al procesar pago"
    end
    
    -- Add tokens to inventory (PERSISTENT)
    BrainrotData.addTokens(player, packageData.TotalTokens)
    
    -- Record purchase (Logging/Analytics)
    print(string.format("[ShopManager] %s bought VIP Package %s (+%d Tokens)", player.Name, packageID, packageData.TotalTokens))
    
    return true, "Paquete VIP comprado: +" .. packageData.TotalTokens .. " tokens"
end

local function purchaseCosmetic(player, cosmeticID)
    local itemData = ShopData.getCosmeticByID(cosmeticID)
    
    if not itemData then
        warn("Invalid cosmetic ID: " .. cosmeticID)
        return false, "Cosmético no encontrado"
    end
    
    -- Check if player can afford it
    if not hasEnoughRobux(player, itemData.Price) then
        return false, "Robux insuficientes"
    end
    
    -- Deduct Robux
    local success = deductRobux(player, itemData.Price)
    if not success then
        return false, "Error al procesar pago"
    end
    
    -- Add to inventory (PERSISTENT)
    local unlocked, message = BrainrotData.addCosmetic(player, cosmeticID)
    
    if unlocked then
        -- TODO: Apply cosmetic effect to player character
        print(string.format("[ShopManager] %s unlocked cosmetic: %s", player.Name, cosmeticID))
        return true, message
    else
        return false, message
    end
end

-- EVENTS: Purchase Handler
PurchaseItemEvent.OnServerEvent:Connect(function(player, itemType, itemID)
	if not player or not itemType or not itemID then
		warn("Invalid purchase request")
		return
	end
	
	local success, message
	
	if itemType == "VIP" then
		success, message = purchaseVIPPackage(player, itemID)
	elseif itemType == "Cosmetic" then
		success, message = purchaseCosmetic(player, itemID)
	else
		warn("Unknown item type: " .. tostring(itemType))
		return
	end
	
	-- Send feedback to player
	if success then
		print("✓ Purchase successful: " .. player.Name .. " bought " .. itemID)
		-- TODO: Show success notification on client
	else
		warn("✗ Purchase failed: " .. message)
		-- TODO: Show error notification on client
	end
end)

-- EVENTS: Player Join
Players.PlayerAdded:Connect(function(player)
    -- Logic is now handled by BrainrotData initialization
    
    -- Wait for character
    player.CharacterAdded:Connect(function(character)
        -- Apply owned cosmetics to character (Delayed to ensure data load)
        task.delay(2, function()
             if BrainrotData.hasCosmetic(player, "GhostWalker") then
                  -- Example Application
                  print("Applying GhostWalker to " .. player.Name)
             end
        end)
    end)
end)

-- EVENTS: Player Leave (save data)
-- EVENTS: Player Leave (save data)
-- Handled by BrainrotData.BindToClose and PlayerRemoving automatically.
-- No action needed here.

-- FUNCTIONS: Admin Commands (for testing)
local function giveTokens(player, amount)
    BrainrotData.addTokens(player, amount)
end

local function openShopForPlayer(player)
	OpenShopEvent:FireClient(player)
end

-- MARKETPLACE HANDLING
local MarketplaceService = game:GetService("MarketplaceService")

function MarketplaceService.ProcessReceipt(receiptInfo)
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    
    local productId = receiptInfo.ProductId
    
    -- 1. Check Bundles / Big Items (VIP_PACKAGES)
    for _, bundle in ipairs(ShopData.VIP_PACKAGES) do
        if bundle.ProductId == productId then
            print("Processing Bundle: " .. bundle.Name)
            
            if bundle.Content then
                for _, item in ipairs(bundle.Content) do
                    -- Give each item in the bundle
                    -- (For now we give tokens as placeholder, but ideally we call BrainrotData.addItem)
                    print(" > Awarding: " .. item.ID .. " x" .. item.Amount)
                    
                    -- TODO: Connect to explicit Item Giving logic
                    -- BrainrotData.giveItem(player, item.ID, item.Amount)
                    BrainrotData.addTokens(player, 100 * item.Amount) -- Placeholder
                end
            end
            
            -- TRACK ROBUX SPENT
            BrainrotData.trackRobuxSpent(player, bundle.Price or 0)
            
            return Enum.ProductPurchaseDecision.PurchaseGranted
        end
    end
    
    -- 2. Check Lucky Blocks (Single & Packs)
    local luckyBlockFound = nil
    for _, lb in ipairs(ShopData.LUCKY_BLOCKS) do
        if lb.ProductId == productId then
            luckyBlockFound = {Data = lb, Amount = 1}
            break
        elseif lb.ProductIdPack == productId then
            luckyBlockFound = {Data = lb, Amount = 3}
            break
        end
    end
    
    if luckyBlockFound then
        local msg = "Lucky Block Purchased: " .. luckyBlockFound.Data.Name .. " x" .. luckyBlockFound.Amount
        print(msg)
        
        -- GIVE REWARD
        BrainrotData.addTokens(player, 500 * luckyBlockFound.Amount) -- Placeholder Reward
        
        -- TRACK ROBUX SPENT
        BrainrotData.trackRobuxSpent(player, luckyBlockFound.Data.Price * luckyBlockFound.Amount)
        
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end
    
    warn("ProductId not found in ShopData: " .. productId)
    return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Export for testing
_G.ShopManagerAPI = {
	GiveTokens = giveTokens,
	OpenShop = openShopForPlayer,
	GetInventory = getPlayerInventory
}

print("ShopManager initialized successfully with Marketplace support")
