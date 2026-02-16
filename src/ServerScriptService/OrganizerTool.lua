local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Organizer = {}

-- CONFIGURATION
local CRITERIA = {
    PARTICLE_SCORE = 15,
    LIGHT_SCORE = 10,
    BEAM_SCORE = 10,
    TRAIL_SCORE = 10,
    NEON_SCORE = 5,
    MESH_SCORE = 1,
    
    -- Name Multipliers (Keywords that affect rarity)
    NAME_WEIGHTS = {
        -- Common Keywords
        ["Skibidi"] = 0.8,    
        ["Gattatino"] = 0.8,  
        ["Toilet"] = 0.8,
        ["Baby"] = 0.9,
        
        -- Rare/Epic Keywords
        ["Grimace"] = 1.5,    
        ["Chef"] = 1.3,
        ["Sigma"] = 1.5,
        
        -- Legendary Keywords
        ["Salchicha"] = 2.0,  
        ["Bombardiro"] = 2.0,
        ["King"] = 2.5,
        
        -- Mythic Keywords
        ["Omega"] = 3.0,
        ["Ultra"] = 3.5,
        ["Supreme"] = 4.0,
        
        -- SUPREME TIER KEYWORDS
        ["Divine"] = 10.0,
        ["Celestial"] = 15.0,
        ["Cosmic"] = 20.0,
        ["Eternal"] = 30.0,
        ["Transcendent"] = 50.0,
        ["Infinite"] = 100.0,
        ["God"] = 25.0,
        ["Void"] = 20.0,
        ["Ascended"] = 18.0,
    }
}

-- TIER THRESHOLDS (Score needed for each tier)
local TIERS = {
    -- Standard Tiers
    {Name = "Common",       MinScore = 0},
    {Name = "Rare",         MinScore = 20},
    {Name = "Epic",         MinScore = 50},
    {Name = "Legendary",    MinScore = 100},
    {Name = "Mythic",       MinScore = 200},
    
    -- SUPREME TIERS (Very high scores required)
    {Name = "Divine",       MinScore = 400},
    {Name = "Celestial",    MinScore = 700},
    {Name = "Cosmic",       MinScore = 1000},
    {Name = "Eternal",      MinScore = 1500},
    {Name = "Transcendent", MinScore = 2500},
    {Name = "Infinite",     MinScore = 5000},
}

-- HELPER: Extraer nombre base normalizado (para agrupar variantes)
local function extractBaseName(name)
    local base = name
    -- Eliminar sufijos comunes de variantes
    base = string.gsub(base, "%s*[vV]?%d+$", "") -- "v2", "2", " 2"
    base = string.gsub(base, "%s*[Ss]hiny%s*", "") -- "Shiny", "shiny"
    base = string.gsub(base, "%s*[Vv]ariant%s*", "")
    base = string.gsub(base, "%s*[Cc]opy%s*", "")
    base = string.gsub(base, "%s*%(%d+%)$", "") -- "(1)", "(2)"
    base = string.gsub(base, "_+", " ") -- Guiones bajos a espacios
    base = string.gsub(base, "%s+", " ") -- Espacios múltiples a uno
    base = string.match(base, "^%s*(.-)%s*$") or base -- Trim
    return string.lower(base)
end

-- HELPER: Generar "fingerprint" estructural (para detectar modelos realmente diferentes)
local function getModelFingerprint(model)
    local partCount = 0
    local totalSize = Vector3.new(0, 0, 0)
    
    for _, desc in pairs(model:GetDescendants()) do
        if desc:IsA("BasePart") then
            partCount = partCount + 1
            totalSize = totalSize + desc.Size
        end
    end
    
    -- Fingerprint = partCount + tamaño aproximado (redondeado a 10s)
    local sizeHash = math.floor((totalSize.X + totalSize.Y + totalSize.Z) / 10)
    return partCount .. "_" .. sizeHash
end

function Organizer.AnalyzeModel(model)
    local score = 0
    local debugInfo = {}
    
    -- 1. Visual Inspection
    for _, desc in pairs(model:GetDescendants()) do
        if desc:IsA("ParticleEmitter") then 
            score += CRITERIA.PARTICLE_SCORE 
            table.insert(debugInfo, "+Particle")
        elseif desc:IsA("PointLight") or desc:IsA("SurfaceLight") or desc:IsA("SpotLight") then
            score += CRITERIA.LIGHT_SCORE
            table.insert(debugInfo, "+Light")
        elseif desc:IsA("Beam") then
            score += CRITERIA.BEAM_SCORE
            table.insert(debugInfo, "+Beam")
        elseif desc:IsA("Trail") then
            score += CRITERIA.TRAIL_SCORE
            table.insert(debugInfo, "+Trail")
        elseif desc:IsA("BasePart") then
            if desc.Material == Enum.Material.Neon then
                score += CRITERIA.NEON_SCORE
                table.insert(debugInfo, "+Neon")
            end
            if desc:IsA("MeshPart") then
                score += CRITERIA.MESH_SCORE
            end
        end
    end
    
    -- 2. Name Weighting
    local multiplier = 1
    for keyword, weight in pairs(CRITERIA.NAME_WEIGHTS) do
        if string.find(model.Name, keyword) then
            multiplier = weight
            table.insert(debugInfo, "x" .. weight .. " (" .. keyword .. ")")
            break -- Only apply one multiplier
        end
    end
    
    local finalScore = score * multiplier
    return finalScore, table.concat(debugInfo, ", ")
end

function Organizer.Run()
    local sourceFolder = Workspace:FindFirstChild("Brainrots models")
    if not sourceFolder then
        warn("[Organizer] 'Brainrots models' folder not found in Workspace!")
        return
    end
    
    -- PRE-CLEAN: Destroy every script in workspace models immediately
    print("[Organizer] Pre-cleaning scripts from Workspace models...")
    for _, desc in pairs(sourceFolder:GetDescendants()) do
        if desc:IsA("LuaSourceContainer") then
            desc:Destroy()
        end
    end
    
    local destFolder = ServerStorage:FindFirstChild("BrainrotModels")
    if not destFolder then
        destFolder = Instance.new("Folder")
        destFolder.Name = "BrainrotModels"
        destFolder.Parent = ServerStorage
    end
    
    -- Create _Deprecated folder for duplicates
    local deprecatedFolder = destFolder:FindFirstChild("_Deprecated")
    if not deprecatedFolder then
        deprecatedFolder = Instance.new("Folder")
        deprecatedFolder.Name = "_Deprecated"
        deprecatedFolder.Parent = destFolder
    end
    
    print("------------------------------------------------")
    print("[Organizer] MIGRATING TO SERVER STORAGE...")
    print("------------------------------------------------")
    
    -- 1. Create Tier Folders in ServerStorage
    local folders = {}
    for _, tier in ipairs(TIERS) do
        local f = destFolder:FindFirstChild(tier.Name)
        if not f then
            f = Instance.new("Folder")
            f.Name = tier.Name
            f.Parent = destFolder
        end
        folders[tier.Name] = f
    end
    
    -- 2. Collect ALL models with their analysis
    local allModels = {}
    
    local function collectModels(container)
        for _, child in pairs(container:GetChildren()) do
            if child:IsA("Model") then
                local score, notes = Organizer.AnalyzeModel(child)
                local baseName = extractBaseName(child.Name)
                local fingerprint = getModelFingerprint(child)
                
                table.insert(allModels, {
                    model = child,
                    originalName = child.Name,
                    baseName = baseName,
                    fingerprint = fingerprint,
                    score = score,
                    notes = notes
                })
            elseif child:IsA("Folder") then
                collectModels(child) -- Recurse into folders
            end
        end
    end
    
    collectModels(sourceFolder)
    print("[Organizer] Found " .. #allModels .. " models to analyze.")
    
    -- 3. Group by baseName ONLY (if same name = same brainrot, regardless of structure)
    local groups = {} -- { "baseName" = { entries... } }
    
    for _, entry in ipairs(allModels) do
        local groupKey = entry.baseName -- ONLY baseName, not fingerprint
        if not groups[groupKey] then
            groups[groupKey] = {}
        end
        table.insert(groups[groupKey], entry)
    end
    
    -- 4. Process Groups: Select Shiny, mark duplicates
    local movedCount = 0
    local shinyCount = 0
    local deprecatedCount = 0
    
    print("------------------------------------------------")
    print("[Organizer] PROCESSING VARIANT GROUPS...")
    print("------------------------------------------------")
    
    for groupKey, entries in pairs(groups) do
        -- Sort by score (highest first)
        table.sort(entries, function(a, b) return a.score > b.score end)
        
        local primaryEntry = entries[1] -- Highest score = becomes the "definitive" version
        local model = primaryEntry.model
        
        -- SANITIZE model
        for _, desc in pairs(model:GetDescendants()) do
            if desc:IsA("BasePart") then
                desc.CanCollide = false
                desc.Anchored = true
            elseif desc:IsA("LuaSourceContainer") or desc:IsA("GuiBase3d") then
                desc:Destroy()
            end
        end
        
        -- Determine Tier
        local chosenTier = TIERS[1]
        for i = #TIERS, 1, -1 do
            if primaryEntry.score >= TIERS[i].MinScore then
                chosenTier = TIERS[i]
                break
            end
        end
        
        -- If there are variants (more than 1 entry), the highest is Shiny
        if #entries > 1 then
            model:SetAttribute("IsShiny", true)
            shinyCount = shinyCount + 1
            
            -- Use a clean name (capitalize first letter of each word)
            local cleanName = primaryEntry.baseName:gsub("(%a)([%w]*)", function(first, rest)
                return string.upper(first) .. rest
            end)
            model.Name = cleanName
            
            print(string.format("✨ SHINY: '%s' (score: %d) from %d variants", cleanName, primaryEntry.score, #entries))
            
            -- Move duplicates to _Deprecated
            for i = 2, #entries do
                local dupModel = entries[i].model
                -- Sanitize
                for _, desc in pairs(dupModel:GetDescendants()) do
                    if desc:IsA("LuaSourceContainer") or desc:IsA("GuiBase3d") then
                        desc:Destroy()
                    end
                end
                dupModel.Parent = deprecatedFolder
                deprecatedCount = deprecatedCount + 1
                print(string.format("   ❌ Deprecated: '%s' (score: %d)", entries[i].originalName, entries[i].score))
            end
        else
            -- Single model, no Shiny designation
            model:SetAttribute("IsShiny", false)
        end
        
        -- Move to Storage
        model.Parent = folders[chosenTier.Name]
        movedCount = movedCount + 1
    end
    
    -- 5. Deep Clean ServerStorage models (existing ones)
    print("[Organizer] Cleaning existing models in ServerStorage...")
    local cleanedCount = 0
    for _, desc in pairs(destFolder:GetDescendants()) do
        if desc:IsA("LuaSourceContainer") or desc:IsA("Humanoid") or desc:IsA("GuiBase3d") then
            desc:Destroy()
            cleanedCount = cleanedCount + 1
        end
    end
    if cleanedCount > 0 then print("[Organizer] Cleaned " .. cleanedCount .. " rogue scripts from storage.") end
    
    print("------------------------------------------------")
    print(string.format("[Organizer] Migration Complete!"))
    print(string.format("  ✅ Moved: %d unique models", movedCount))
    print(string.format("  ✨ Shiny: %d models marked", shinyCount))
    print(string.format("  ❌ Deprecated: %d duplicates", deprecatedCount))
    print("------------------------------------------------")
end

-- Managed by SystemLoader
-- Organizer.Run()

return Organizer
