-- ModelReplicator.server.lua
-- Skill: core-infrastructure
-- Description: Copies brainrot models from ServerStorage to ReplicatedStorage for client ViewportFrames

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function replicateModels()
    print("[ModelReplicator] Syncing models to ReplicatedStorage...")
    
    -- WAIT FOR MODELS TO BE ORGANIZED (Increased timeout for Studio stability)
    local serverModels = ServerStorage:WaitForChild("BrainrotModels", 60)
    if not serverModels then
        warn("[ModelReplicator] Timeout waiting for BrainrotModels folder! Is the Organizer running?")
        return
    end
    
    -- Wait until there is at least something inside (Common folder usually first)
    if #serverModels:GetChildren() == 0 then
        serverModels.ChildAdded:Wait()
        task.wait(1) -- Extra safety for bulk move
    end
    
    -- Create or get folder in ReplicatedStorage
    local clientModels = ReplicatedStorage:FindFirstChild("BrainrotModels")
    if clientModels then
        clientModels:ClearAllChildren()
    else
        clientModels = Instance.new("Folder")
        clientModels.Name = "BrainrotModels"
        clientModels.Parent = ReplicatedStorage
    end
    
    local totalCount = 0
    
    -- Copy each tier folder and its models (SKIP _Deprecated)
    for _, tierFolder in pairs(serverModels:GetChildren()) do
        if tierFolder:IsA("Folder") and tierFolder.Name ~= "_Deprecated" then
            local clientTierFolder = Instance.new("Folder")
            clientTierFolder.Name = tierFolder.Name
            clientTierFolder.Parent = clientModels
            
            for _, model in pairs(tierFolder:GetChildren()) do
                if model:IsA("Model") then
                    local clone = model:Clone()
                    
                    -- Optimize for ViewportFrame (remove scripts, sounds, etc)
                    for _, desc in pairs(clone:GetDescendants()) do
                        if desc:IsA("Script") or desc:IsA("LocalScript") or desc:IsA("Sound") then
                            desc:Destroy()
                        end
                        -- Make parts non-collidable for viewport
                        if desc:IsA("BasePart") then
                            desc.Anchored = true
                            desc.CanCollide = false
                        end
                    end
                    
                    clone.Parent = clientTierFolder
                    totalCount += 1
                end
            end
            
            print("[ModelReplicator] Tier " .. tierFolder.Name .. ": " .. #clientTierFolder:GetChildren() .. " models")
        end
    end
    
    print("[ModelReplicator] Synced " .. totalCount .. " models to ReplicatedStorage")
end

-- Run on start
task.spawn(replicateModels) -- Run in background to not block script loading

-- Also update when new models are added (for development)
local serverModels = ServerStorage:WaitForChild("BrainrotModels", 60)
if serverModels then
    serverModels.DescendantAdded:Connect(function()
        task.wait(2) -- Debounce
        replicateModels()
    end)
end
