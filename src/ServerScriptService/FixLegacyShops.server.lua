-- FixLegacyShops.server.lua
-- Skill: cleanup-legacy
-- Description: Removes broken scripts inside imported Shop models to prevent console errors.

local Workspace = game:GetService("Workspace")

local function cleanShops()
    -- Immediate cleanup attempt
    local shopsFolder = Workspace:FindFirstChild("Shops")
    if not shopsFolder then 
        -- If not found yet, wait for it briefly but check periodically
        task.spawn(function()
             shopsFolder = Workspace:WaitForChild("Shops", 5)
             if shopsFolder then
                 for _, shop in pairs(shopsFolder:GetChildren()) do
                    for _, descendant in pairs(shop:GetDescendants()) do
                        if descendant:IsA("Script") and (descendant.Name == "Shop" or descendant.Name == "RobuxShop") then
                            descendant:Destroy()
                            -- print("Deleted legacy script")
                        end
                    end
                 end
             end
        end)
        return 
    end
    
    -- If exists, nuke immediately
    local count = 0
    for _, shop in pairs(shopsFolder:GetChildren()) do
        for _, descendant in pairs(shop:GetDescendants()) do
            if descendant:IsA("Script") and (descendant.Name == "Shop" or descendant.Name == "RobuxShop") then
                -- Disable first then destroy
                descendant.Disabled = true 
                descendant:Destroy()
                count += 1
            end
        end
    end
    
    if count > 0 then
        print(string.format("[FixLegacyShops] IMMINENTLY Cleaned %d legacy scripts.", count))
    end
end

cleanShops()
