-- ShopData.lua
-- Configuration data for VIP Shop items
-- Place this in shared/Data/

local ShopData = {}

-- CONFIG: Special Bundles (Displayed in Large Frames)
ShopData.VIP_PACKAGES = {
	{
		ID = "starter_bundle",
		Name = "Starter Pack",
		Price = 499, -- Example Price
		ProductId = 0, -- REPLACE
		Type = "DevProduct",
		Description = "2x Common, 2x Rare, 1x Legendary",
        Content = {
  
			{ID = "lb_common", Amount = 2},
            {ID = "lb_rare", Amount = 2},
            {ID = "lb_legendary", Amount = 1}
        },
		ColorGradient = {
			Start = Color3.fromRGB(100, 255, 100),
			Middle = Color3.fromRGB(50, 200, 50),
			End = Color3.fromRGB(0, 150, 0)
		},
		Icon = "📦",
		SortOrder = 1
	},
	{
		ID = "lb_abuse",
		Name = "Lucky Block ABUSE",
		Price = 9999, -- High Price
		ProductId = 0, -- REPLACE
		Type = "DevProduct",
        Description = "Posibilidad de items INFINITOS",
        Content = {
             {ID = "lb_abuse", Amount = 1}
        },
		ColorGradient = {
			Start = Color3.fromRGB(255, 0, 0),
			Middle = Color3.fromRGB(100, 0, 0),
			End = Color3.fromRGB(0, 0, 0)
		},
		Icon = "☠️",
		Popular = true,
		SortOrder = 2
	}
}

-- CONFIG: Cosmetic Items
ShopData.COSMETIC_ITEMS = {
	-- Keeping existing cosmetics for now...
	{
		ID = "aura_rainbow",
		Name = "Aura Arcoíris",
		Price = 1500,
		Rarity = "Legendario",
		DropChance = 0.675,
		ColorGradient = {
			Start = Color3.fromRGB(255, 100, 200),
			Middle = Color3.fromRGB(200, 100, 255),
			End = Color3.fromRGB(100, 200, 255)
		},
		Icon = "🌈",
		SortOrder = 1
	}
}

-- CONFIG: Lucky Blocks (Displayed in Small Frames)
ShopData.LUCKY_BLOCKS = {
	{
		ID = "lb_legendary",
		Name = "LB Legendario",
		Price = 1000,
		ProductId = 0, 
		ProductIdPack = 0, 
		Type = "DevProduct",
		Rarity = "Legendario",
		Icon = "🟨", 
		SortOrder = 1
	},
	{
		ID = "lb_divine",
		Name = "LB Divino", -- Assuming Divine replaces Mythic based on user list
		Price = 2500,
		ProductId = 0, 
		ProductIdPack = 0,
		Type = "DevProduct",
		Rarity = "Divino",
		Icon = "🟦", 
		SortOrder = 2
	},
	{
		ID = "lb_celestial",
		Name = "LB Celestial",
		Price = 5000,
		ProductId = 0,
		ProductIdPack = 0,
		Type = "DevProduct",
		Rarity = "Celestial",
		Icon = "🟪", 
		SortOrder = 3
	}
}

-- CONFIG: Rarity Colors for visual feedback
ShopData.RARITY_COLORS = {
	Legendario = Color3.fromRGB(255, 100, 200),
	["Épico"] = Color3.fromRGB(150, 100, 255),
	Raro = Color3.fromRGB(100, 150, 255),
	["Común"] = Color3.fromRGB(150, 150, 150)
}

-- FUNCTIONS
function ShopData.getVIPPackageByID(id)
	for _, package in ipairs(ShopData.VIP_PACKAGES) do
		if package.ID == id then
			return package
		end
	end
	return nil
end

function ShopData.getCosmeticByID(id)
	for _, item in ipairs(ShopData.COSMETIC_ITEMS) do
		if item.ID == id then
			return item
		end
	end
	return nil
end

function ShopData.getLuckyBlockByID(id)
	for _, item in ipairs(ShopData.LUCKY_BLOCKS) do
		if item.ID == id then
			return item
		end
	end
	return nil
end

function ShopData.formatPrice(price)
	if price >= 1000 then
		return string.format("%.1fk", price / 1000)
	end
	return tostring(price)
end

return ShopData
