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
        ["Eternal"] = 30.0,
        ["Cosmic"] = 60.0,
        ["Infinite"] = 120.0,
        ["Transcendent"] = 250.0,
        ["God"] = 25.0,
        ["Void"] = 20.0,
        ["Ascended"] = 18.0,
    }
}

-- MANUAL OVERRIDES (User requested specific classifications)
local MANUAL_OVERRIDES = {
    -- Mythic
    ["Graipuss Medussi"] = "Mythic",
    ["Blackhole Goat"] = "Mythic",
    ["Frigo Camelo"] = "Mythic",

    -- Divine
    ["Strawberry Flamingelli"] = "Divine",
    ["To To To Sahur"] = "Divine",
    ["TungTungSahur"] = "Divine",

    -- Celestial
    ["La Spooky Grande"] = "Celestial",
    ["Spaghetti Tualetti"] = "Celestial",
    ["Glorbo Fruttodrillo"] = "Celestial",
    ["Turtoginni Dragonfrutini"] = "Celestial",
    ["Torrtuginni Dragonfrutini"] = "Celestial",
    ["Pot Hotspot"] = "Celestial",

    -- Eternal
    ["Eviledon"] = "Eternal",
    ["Piccione Macchina"] = "Eternal",
    ["Los Crocodillitos"] = "Eternal",
    ["La Vacca Saturno Saturnita"] = "Eternal",
    ["La Vacca Jacko Linterino"] = "Eternal",
    ["Los Hotspotsitos"] = "Eternal",
    ["67"] = "Eternal",
    ["Esok Sekolah"] = "Eternal",

    -- Cosmic
    ["Zombie Tralala"] = "Cosmic",
    ["Strawberry Elephant"] = "Cosmic",
    ["Frankentteo"] = "Cosmic",
    ["Strawberrelli Flamingelli"] = "Cosmic",
    ["Cavallo Virtuoso"] = "Cosmic",
    ["Las Vaquitas Saturnitas"] = "Cosmic",
    ["Los Tacoritas"] = "Cosmic",

    -- Infinite
    ["La Grande Combinasion"] = "Infinite",
    ["Mariachi Corazoni"] = "Infinite",
    ["Los Combinasionas"] = "Infinite",
    ["Trenostuzzo Turbo 3000"] = "Infinite",

    -- Transcendent
    ["La Cucaracha"] = "Transcendent",
    ["La Secret Combinacon"] = "Transcendent",
    ["La Secret Combinasion"] = "Transcendent",
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
    {Name = "Eternal",      MinScore = 1200},
    {Name = "Cosmic",       MinScore = 2000},
    {Name = "Infinite",     MinScore = 4000},
    {Name = "Transcendent", MinScore = 7000},
}

-- HELPER: Extraer nombre base normalizado (para agrupar variantes)
local function extractBaseName(name)
    local base = name
    -- Eliminar sufijos comunes de variantes (solo si no es el nombre entero)
    local temp = string.gsub(base, "%s*[vV]?%d+$", "")
    if temp ~= "" then base = temp end
    
    base = string.gsub(base, "%s*[Ss]hiny%s*", "")
    base = string.gsub(base, "%s*[Vv]ariant%s*", "")
    base = string.gsub(base, "%s*[Cc]opy%s*", "")
    base = string.gsub(base, "%s*%(%d+%)$", "")
    base = string.gsub(base, "[_%s]+", "")
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
    -- 0. MIGRATE PERSISTENT ASSETS (LuckyBlocks, Particles)
    -- This prevents other cleanup scripts from deleting them from Workspace.
    local persistentAssets = {"LuckyBlocks", "Particles"}
    for _, assetName in ipairs(persistentAssets) do
        local asset = Workspace:FindFirstChild(assetName)
        if asset then
            -- Move to ServerStorage if not already there
            asset.Parent = ServerStorage
            print("[Organizer] Safely migrated '" .. assetName .. "' to ServerStorage.")
        end
    end

    -- 1. MIGRATE BASE PREFABS (Simple move as requested)
    local basePrefabs = Workspace:FindFirstChild("BaseBrainrots")
    if basePrefabs then
        basePrefabs.Parent = ServerStorage
        print("[Organizer] Migrated 'BaseBrainrots' to ServerStorage.")
    end

    local sourceFolder = Workspace:FindFirstChild("Brainrots models")
    local storageSource = ServerStorage:FindFirstChild("Brainrot") -- Old name if Rojo hasn't updated
    
    -- Cleanup legacy folder
    local legacyFolder = ServerStorage:FindFirstChild("Brainrot")
    if legacyFolder and destFolder and legacyFolder ~= destFolder then
        -- If we have models inside, move them to sourceFolder for re-processing
        for _, child in pairs(legacyFolder:GetDescendants()) do
            if child:IsA("Model") then
                child.Parent = sourceFolder or Workspace
            end
        end
        legacyFolder:Destroy()
        print("[Organizer] Cleaned up legacy 'Brainrot' folder.")
    end

    if not sourceFolder and not storageSource then
        warn("[Organizer] No model sources found! Skipping unit organization.")
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
                -- VALIDATION: Ignore generic names and models without parts
                local rawName = child.Name
                local trimmedName = rawName:match("^%s*(.-)%s*$") or ""
                local lowerName = string.lower(trimmedName)
                local isInvalid = false
                
                -- Catch broader generic names and whitespace
                if lowerName == "model" or lowerName == "part" or lowerName == "basepart" or lowerName == "meshpart" or 
                   lowerName == "" or lowerName == "folder" or #trimmedName < 2 then
                    isInvalid = true
                end
                
                if not isInvalid then
                    local hasParts = false
                    for _, p in pairs(child:GetDescendants()) do
                        if p:IsA("BasePart") then
                            hasParts = true
                            break
                        end
                    end
                    if not hasParts then isInvalid = true end
                end

                -- PURGE: If it's already in an organized tier folder but invalid, move to _Deprecated
                if isInvalid then
                    if container.Parent == destFolder then
                        local deprecatedFolder = destFolder:FindFirstChild("_Deprecated")
                        if not deprecatedFolder then
                            deprecatedFolder = Instance.new("Folder")
                            deprecatedFolder.Name = "_Deprecated"
                            deprecatedFolder.Parent = destFolder
                        end
                        if child.Parent ~= deprecatedFolder then
                            print("[Organizer] PURGING invalid model from storage: '" .. rawName .. "'")
                            child.Parent = deprecatedFolder
                        end
                    end
                    continue
                end

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
            elseif child:IsA("Folder") and child.Name ~= "_Deprecated" then
                collectModels(child) -- Recurse into folders
            end
        end
    end
    
    collectModels(sourceFolder)
    
    -- Also collect from STORAGE (Crucial for Rojo models)
    if destFolder then
        collectModels(destFolder)
    end
    
    -- print("[Organizer] Found " .. #allModels .. " models to analyze.")
    
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
    
    -- print("------------------------------------------------")
    -- print("[Organizer] PROCESSING VARIANT GROUPS...")
    -- print("------------------------------------------------")
    
    for groupKey, entries in pairs(groups) do
        -- Sort by score (highest first)
        table.sort(entries, function(a, b) return a.score > b.score end)
        
        local primaryEntry = entries[1] -- Highest score = becomes the "definitive" version
        local model = primaryEntry.model
        
        -- 1. Derive CLEAN NAME (Consistently used for renaming and overrides)
        local displayBase = primaryEntry.originalName
        local tempName = string.gsub(displayBase, "%s*[vV]?%d+$", "") -- remove "v2"
        if tempName ~= "" then displayBase = tempName end
        
        displayBase = string.gsub(displayBase, "%s*[Ss]hiny%s*", "")
        displayBase = string.gsub(displayBase, "%s*[Vv]ariant%s*", "")
        displayBase = string.gsub(displayBase, "%s*[Cc]opy%s*", "")
        displayBase = string.gsub(displayBase, "%s*%(%d+%)$", "")
        displayBase = string.gsub(displayBase, "_+", " ") -- Underscores to spaces
        
        -- Capitalize Each Word
        local cleanName = displayBase:gsub("(%w)(%w*)", function(first, rest)
            return string.upper(first) .. rest
        end)
        cleanName = string.match(cleanName, "^%s*(.-)%s*$") or cleanName
        
        -- 2. Determine Tier (Check Override First, then Score)
        local chosenTierName = MANUAL_OVERRIDES[cleanName]
        if not chosenTierName then
            local tier = TIERS[1]
            for i = #TIERS, 1, -1 do
                if primaryEntry.score >= TIERS[i].MinScore then
                    tier = TIERS[i]
                    break
                end
            end
            chosenTierName = tier.Name
        end
        
        -- 3. SANITIZE model
        for _, desc in pairs(model:GetDescendants()) do
            if desc:IsA("BasePart") then
                desc.CanCollide = false
                desc.Anchored = true
            elseif desc:IsA("LuaSourceContainer") or desc:IsA("GuiBase3d") then
                desc:Destroy()
            end
        end
        
        -- Rename model to Clean Name
        model.Name = cleanName
        
        -- 3.5 CLEANUP: Remove existing versions in other tiers to prevent duplicates
        for _, folder in pairs(folders) do
            local existing = folder:FindFirstChild(cleanName)
            if existing and existing ~= model then
                existing:Destroy()
            end
        end

        -- 4. If there are variants (more than 1 entry), the highest is Shiny
        if #entries > 1 then
            model:SetAttribute("IsShiny", true)
            shinyCount = shinyCount + 1
            
            -- print(string.format("✨ SHINY: '%s' (Tier: %s, score: %d) from %d variants", cleanName, chosenTierName, primaryEntry.score, #entries))
            
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
            end
        else
            -- Single model, no Shiny designation
            model:SetAttribute("IsShiny", false)
            -- print(string.format("📦 NORMAL: '%s' (Tier: %s, score: %d)", cleanName, chosenTierName, primaryEntry.score))
        end
        
        -- Move to Storage
        local targetFolder = folders[chosenTierName]
        if targetFolder then
            model.Parent = targetFolder
        else
            warn("[Organizer] Missing folder for tier: " .. chosenTierName .. " (Model: " .. cleanName .. ")")
            model.Parent = folders["Common"]
        end
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
