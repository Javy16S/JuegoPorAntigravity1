-- ModelReplicator.lua
-- Skill: core-infrastructure
-- Description: Deterministic replication of models from ServerStorage to ReplicatedStorage

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModelReplicator = {}

function ModelReplicator.Init()
    print("[ModelReplicator] Initializing deterministic replication...")
    
    -- 1. Ensure target folder exists
    local clientModels = ReplicatedStorage:FindFirstChild("BrainrotModels")
    if not clientModels then
        clientModels = Instance.new("Folder")
        clientModels.Name = "BrainrotModels"
        clientModels.Parent = ReplicatedStorage
    else
        clientModels:ClearAllChildren()
    end
    
    -- 2. Fetch Source Models (Already organized by OrganizerTool)
    local serverModels = ServerStorage:FindFirstChild("BrainrotModels")
    if not serverModels then
        warn("[ModelReplicator] CRITICAL: BrainrotModels not found in ServerStorage!")
        return
    end
    
    local totalCount = 0
    
    -- 3. Clone and Optimize
    for _, tierFolder in pairs(serverModels:GetChildren()) do
        if tierFolder:IsA("Folder") and tierFolder.Name ~= "_Deprecated" then
            local clientTierFolder = Instance.new("Folder")
            clientTierFolder.Name = tierFolder.Name
            clientTierFolder.Parent = clientModels
            
            for _, model in pairs(tierFolder:GetChildren()) do
                if model:IsA("Model") then
                    local clone = model:Clone()
                    
                    -- Optimize for ViewportFrame (remove scripts, sounds, physics)
                    for _, desc in pairs(clone:GetDescendants()) do
                        if desc:IsA("Script") or desc:IsA("LocalScript") or desc:IsA("Sound") then
                            desc:Destroy()
                        end
                        if desc:IsA("BasePart") then
                            desc.Anchored = true
                            desc.CanCollide = false
                            desc.Massless = true
                            desc.CastShadow = false -- Optimization
                        end
                    end
                    
                    clone.Parent = clientTierFolder
                    totalCount += 1
                end
            end
        end
    end
    
    print("[ModelReplicator] Successfully replicated " .. totalCount .. " models to Client.")
    
    -- 4. Replicate Particles Folder (New: for Mutation VFX in Viewports)
    local particlesSource = workspace:FindFirstChild("Particles") or ServerStorage:FindFirstChild("Particles")
    if particlesSource then
        local clientParticles = ReplicatedStorage:FindFirstChild("Particles")
        if not clientParticles then
            clientParticles = Instance.new("Folder")
            clientParticles.Name = "Particles"
            clientParticles.Parent = ReplicatedStorage
        else
            clientParticles:ClearAllChildren()
        end
        
        for _, vfx in pairs(particlesSource:GetChildren()) do
            if vfx:IsA("BasePart") then
                local clone = vfx:Clone()
                clone.Anchored = true
                clone.CanCollide = false
                clone.Massless = true
                clone.Parent = clientParticles
            end
        end
        print("[ModelReplicator] Replicated " .. #clientParticles:GetChildren() .. " VFX sources to Client.")
    end

    -- 6. Replicate LuckyBlocks Folder (For Shop Viewports)
    local lbSource = ServerStorage:FindFirstChild("LuckyBlocks")
    if lbSource then
        local clientLB = ReplicatedStorage:FindFirstChild("LuckyBlocks")
        if not clientLB then
            clientLB = Instance.new("Folder")
            clientLB.Name = "LuckyBlocks"
            clientLB.Parent = ReplicatedStorage
        else
            clientLB:ClearAllChildren()
        end
        
        for _, lb in pairs(lbSource:GetChildren()) do
            local clone = lb:Clone()
            -- Optimize
            for _, desc in pairs(clone:GetDescendants()) do
                if desc:IsA("Script") or desc:IsA("LocalScript") then desc:Destroy() end
                if desc:IsA("BasePart") then
                    desc.Anchored = true
                    desc.CanCollide = false
                end
            end
            clone.Parent = clientLB
        end
        print("[ModelReplicator] Replicated " .. #clientLB:GetChildren() .. " LuckyBlocks to Client.")
    end
    
    -- 5. Setup Live Update Listener (Debounced)
    -- Only for development convenience, not critical for production flow
    local isUpdating = false
    serverModels.DescendantAdded:Connect(function()
        if isUpdating then return end
        isUpdating = true
        task.delay(5, function() -- Long debounce to batch updates
            print("[ModelReplicator] Detected changes. Re-syncing...")
            ModelReplicator.Init() -- Re-run full sync
            isUpdating = false
        end)
    end)
end

return ModelReplicator
