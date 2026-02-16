---
name: roblox-rojo-autonomous
description: Autonomous development workflow for Roblox games using Rojo with headless validation. Use this skill when the user provides a roadmap, feature list, or multi-step development plan for a Roblox project. Triggers include mentions of "roadmap", "autonomous development", "punto por punto", "headless", "validation", requests to implement multiple features sequentially, or when creating game systems like events, mutations, shops, managers, data persistence, or UI for Roblox. This skill enables Claude to work through tasks systematically with automated syntax validation, linting, and build checks - all without opening Roblox Studio.
---

# Roblox/Rojo Autonomous Development v3.0 (Headless Validation)

This skill enables autonomous, sequential development of Roblox game features using Rojo sync with **automated headless validation**. It provides structure, templates, and best practices for creating production-ready Luau code that is validated before being written to files.

## What's New in v3.0

✨ **Headless Validation Pipeline**: Every file is automatically validated using:
- `luau-analyze` for syntax and type checking
- `selene` for linting and best practices  
- `stylua` for auto-formatting
- `rojo build` for project integrity

✨ **100% Console Workflow**: Develop entirely from terminal without opening Roblox Studio

✨ **Auto-Correction**: Detected errors are fixed immediately before proceeding

✨ **Zero Accumulated Errors**: Each file is validated before moving to the next task

## When to Use This Skill

Activate when:
- User provides a roadmap or multi-step development plan
- User requests autonomous/sequential work ("punto por punto", "work through this list")
- User mentions Roblox game systems: events, mutations, shops, managers, inventory, data persistence
- User wants complete features implemented without constant back-and-forth

## Project Context

**Project Type:** Escape Tsunami / Idle Incremental  
**Sync Method:** Rojo (changes auto-sync to Roblox Studio via Antigravity)

**Project Structure:**
```
src/
├── ServerScriptService/     # Server-side managers and logic
├── ServerStorage/
│   └── Banami/
│       ├── Brainrots/       # Brainrot models
│       ├── BaseBrainrot.rbxm
│       └── Shops.rbxm
├── StarterGui/              # UI screens and menus
├── StarterPlayer/
│   └── StarterPlayerScripts/ # Client-side scripts
└── shared/                  # ReplicatedStorage (events, modules, data)
    ├── Events/              # RemoteEvents and RemoteFunctions
    ├── Modules/             # Shared utility modules
    └── Data/                # Configuration tables
```

**Code Conventions:**
- Files: `PascalCase.server.lua` (server scripts), `PascalCase.lua` (ModuleScripts)
- Functions: `camelCase` → `function spawnBrainrot()`
- Variables: `PascalCase` → `local BrainrotData = {}`
- Constants: `UPPER_SNAKE_CASE` → `local MAX_UNITS = 20`
- Services: Declare at top → `local Players = game:GetService("Players")`
- Comments: Use `-- CONFIG`, `-- FUNCTIONS`, `-- EVENTS` section headers
- Type annotations: Use when beneficial → `local function calculateIncome(tier: string): number`

**No Frameworks:** This project uses vanilla Luau with ModuleScript patterns. Do NOT use Knit, Fusion, or other frameworks.

## Autonomous Workflow

When user provides a roadmap, follow this process:

### 1. Parse Roadmap Structure
```markdown
Example roadmap format:
1. Sistema de Eventos
   1.1 Rotación temporal de eventos
   1.2 Scripts para meteoritos
   1.3 SuperEventos de progresión
2. Sistema de Mutaciones
   2.1 Alteración de meshes
   2.2 Incrementos por tipo
   ...
```

Identify:
- Main features (1, 2, 3...)
- Sub-tasks (1.1, 1.2, 1.3...)
- Dependencies between tasks
- Which tasks can be done in parallel vs. sequentially

### 2. Execute Each Task Sequentially

For EACH task in the roadmap:

**A. Generate Complete Code**
- NO pseudocode or `-- TODO: implement this` comments
- Full implementation with all logic
- Include error handling where appropriate
- Add configuration constants at the top

**B. Mental Syntax Validation (Pre-Flight Check)**
BEFORE writing the file, perform mental validation:
```
[Pre-Flight Syntax Check]
✓ Function blocks: X opens, X closes
✓ If statements: X opens, X closes
✓ For loops: X opens, X closes
✓ String literals: X opens, X closes
✓ Mental validation PASSED - Writing file...
```

**C. Create File**
Write the file to the appropriate location:
- Server scripts in `ServerScriptService/`
- Shared modules in `shared/Modules/`
- RemoteEvents in `shared/Events/`
- Configuration data in `shared/Data/`

**D. CRITICAL: Headless Validation**
IMMEDIATELY after creating the file, execute validation:

```bash
python3 scripts/validate_and_continue.py <filepath>
```

**Example:**
```bash
python3 scripts/validate_and_continue.py src/ServerScriptService/EventManager.server.lua
```

**E. Interpret Validation Results**

**If PASS (exit code 0):**
```
✅ VALIDACIÓN EXITOSA - ARCHIVO APROBADO
```
→ Mark task as complete and continue to next task

**If FAIL (exit code 1):**
```
❌ ERROR DE SINTAXIS DETECTADO
```
→ STOP immediately
→ Read the error message carefully
→ Use references/syntax-debugging.md if needed
→ Fix the file
→ Re-run validation
→ Only continue when validation passes

**F. Mark Completion (Only After Validation Passes)**
```
✓ [X.Y] TASK_NAME COMPLETED & VALIDATED
Files created & validated:
- src/ServerScriptService/NewManager.server.lua ✓
```

Then **immediately continue** to the next task WITHOUT waiting for user confirmation.

**CRITICAL RULE:** NEVER mark a task as complete or move to the next task until headless validation passes with exit code 0.

### 3. Handle Dependencies Intelligently

If task 2.3 requires something from 1.2:
- Note the dependency
- Ensure 1.2 is complete first
- Reference the created modules/events correctly

Example:
```lua
-- Task 2.3 depends on EventManager from 1.1
local EventManager = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("EventManager"))
```

## Headless Validation Pipeline

This skill uses a **4-step automated validation pipeline** to ensure code quality without opening Roblox Studio.

### Pipeline Overview

```
Code Generation → Mental Check → Write File → Headless Validation
                                                     ↓
                                    ┌────────────────┴────────────────┐
                                    │                                 │
                              PASS (0) ✓                        FAIL (1) ✗
                                    │                                 │
                          Continue Next Task              Fix → Re-validate
```

### Validation Script: `validate_and_continue.py`

**Location:** `scripts/validate_and_continue.py`

**Usage:**
```bash
python3 scripts/validate_and_continue.py <filepath>
```

**What It Does:**

**Step 1: Syntax Validation (luau-analyze)** ⭐ CRITICAL
- Validates Luau syntax without Roblox Studio
- Detects missing/extra `end`, unclosed strings, type errors
- Exit immediately if fails

**Step 2: Linting (selene)** ⚠️ NON-BLOCKING
- Checks for unused variables, undefined references
- Detects bad practices and potential bugs
- Warnings don't block, but should be addressed

**Step 3: Format Check (stylua)** 🔧 AUTO-FIX
- Verifies code formatting consistency
- Auto-corrects if format is wrong
- Ensures consistent style across project

**Step 4: Rojo Build (rojo build)** ⭐ CRITICAL (for .server.lua)
- Attempts headless build to verify project integrity
- Only runs for server scripts to save time
- Catches structural issues before sync

### Output Interpretation

**Success Output:**
```
🔍 VALIDACIÓN HEADLESS: GameManager.server.lua
📄 Archivo: src/ServerScriptService/GameManager.server.lua
📊 Líneas: 145 total, 120 de código

[1/4] Validando sintaxis Luau: GameManager.server.lua...
   ✓ Sintaxis válida - Sin errores

[2/4] Ejecutando linter (selene): GameManager.server.lua...
   ✓ Linting limpio - Sin warnings

[3/4] Verificando formato (stylua): GameManager.server.lua...
   ✓ Formato correcto

[4/4] Intentando Rojo build headless...
   ✓ Rojo build exitoso

✅ VALIDACIÓN EXITOSA - ARCHIVO APROBADO
Todos los pasos completados: 4/4
El archivo está listo para sincronizar con Roblox
```

**Failure Output (Syntax Error):**
```
🔍 VALIDACIÓN HEADLESS: BrokenFile.lua

[1/4] Validando sintaxis Luau: BrokenFile.lua...

❌ ERROR DE SINTAXIS DETECTADO
──────────────────────────────────────────────────────────────────
BrokenFile.lua:15:1: Expected 'end' (to close 'function' at line 10), got <eof>
──────────────────────────────────────────────────────────────────

💡 Sugerencia: Lee references/syntax-debugging.md para ayuda

❌ VALIDACIÓN FALLIDA - ERROR DE SINTAXIS
Pasos completados: 0/4
Acción requerida: Corregir errores de sintaxis y volver a validar
```

### Batch Validation

For tasks that create multiple files, use batch validation:

```bash
python3 scripts/batch_validate.py src/ServerScriptService/*.lua
python3 scripts/batch_validate.py --all  # Validate entire project
```

**Output:**
```
VALIDACIÓN BATCH - 5 archivos

[1/5] Validando: EventManager.server.lua
✓ Pasó

[2/5] Validando: MutationManager.lua
✓ Pasó

[3/5] Validando: SafeZoneManager.server.lua
✗ Falló
  ❌ Error de sintaxis: expected 'end' at line 45

[4/5] Validando: AchievementManager.server.lua
✓ Pasó

[5/5] Validando: QuestManager.server.lua
✓ Pasó

RESUMEN:
Total: 5
Pasaron: 4 (80%)
Fallaron: 1 (20%)

Archivos con errores:
  • src/ServerScriptService/SafeZoneManager.server.lua
```

### When Validation Fails

**NEVER proceed to the next task when validation fails.**

1. **Read Error Message**: Understand what went wrong
2. **Consult Debugging Guide**: Use `references/syntax-debugging.md`
3. **Fix the Code**: Correct the error in the file
4. **Re-Validate**: Run `validate_and_continue.py` again
5. **Verify Success**: Only continue when you see ✅ VALIDACIÓN EXITOSA

### Integration with Autonomous Workflow

**Correct flow:**
```
1.1 Parse task → Generate code → Mental check → Write file
    → Run validate_and_continue.py
    → ✅ PASS → Mark [1.1] COMPLETED ✓ → Continue to 1.2

1.2 Parse task → Generate code → Mental check → Write file
    → Run validate_and_continue.py
    → ❌ FAIL → Fix error → Re-validate
    → ✅ PASS → Mark [1.2] COMPLETED ✓ → Continue to 1.3
```

**Incorrect flow (DO NOT DO THIS):**
```
❌ 1.1 Generate → Write → Mark COMPLETED → Continue to 1.2 (skipped validation!)
❌ 1.2 Generate → Write → Mark COMPLETED → Continue to 1.3 (skipped validation!)
❌ 1.3 Generate → Write → Validation fails → Now 1.1 and 1.2 might have errors too!
```

### Tools Required

**Critical (must have):**
- `luau-analyze` - Syntax validation
- `python3` - Run validation scripts

**Recommended:**
- `rojo` - Build verification (you already have this)

**Optional (improves quality):**
- `selene` - Advanced linting
- `stylua` - Auto-formatting

See `references/installation-guide.md` for installation instructions.

### Workflow Summary

```markdown
For each task in roadmap:
    1. Generate complete code
    2. Mental pre-flight check
    3. Write file to disk
    4. Execute: python3 scripts/validate_and_continue.py <file>
    5. IF validation passes:
         Mark task COMPLETED ✓
         Continue to next task
       ELSE:
         Fix error
         Re-validate
         Only continue when PASS
```

**Key Principle:** One task, one validation, one approval. Never accumulate errors.

## CRITICAL: Syntax Validation Before Writing Code

**ALWAYS perform mental syntax validation BEFORE generating any Luau code.** This prevents syntax errors like `expected eof, got end`.

### Pre-Generation Checklist

Before writing ANY function or code block, mentally verify:

1. **Count Control Structures**
   ```
   Each needs exactly ONE `end`:
   - if ... then → end
   - for ... do → end  
   - while ... do → end
   - repeat → until (no end needed)
   - function ... → end
   ```

2. **Verify Block Pairing**
   ```
   Opening → Closing
   if condition then → end
   for i = 1, 10 do → end
   function name() → end
   { → }
   ( → )
   [ → ]
   " → " or ' → '
   ```

3. **Check Common Errors**
   - ❌ `if x then` without `end`
   - ❌ Nested functions without all `end`s
   - ❌ `function() end end` (double end)
   - ❌ Unclosed strings: `"text`
   - ❌ Unclosed tables: `{value, value`
   - ❌ Using Lua 5.1 syntax (use Luau instead)

### Validation Process

**Step 1: Draft the code mentally**

**Step 2: Count blocks**
```
Example mental check:
function spawnMeteor()          -- 1 function (needs 1 end)
    if distance < 10 then       -- 1 if (needs 1 end)
        for i = 1, 5 do         -- 1 for (needs 1 end)
            -- code
        end                     -- closes for ✓
    end                         -- closes if ✓
end                             -- closes function ✓

Total: 3 opens, 3 closes ✓ VALID
```

**Step 3: Verify nesting depth**
```
function test()              -- depth 1
    if x then                -- depth 2
        for i = 1, 5 do      -- depth 3
            while true do    -- depth 4
            end              -- back to 3
        end                  -- back to 2
    end                      -- back to 1
end                          -- back to 0 ✓
```

**Step 4: Check edge cases**
- Anonymous functions: `table.sort(arr, function(a, b) return a < b end)`
- Nested tables: `local data = {items = {a = 1, b = 2}}`
- Multi-line strings: `[[text]]` or `[=[text]=]`
- Comments don't need closing: `-- comment` or `--[[ block comment ]]`

### Common Luau Syntax Patterns

**Correct:**
```lua
-- Simple if
if condition then
    action()
end

-- If-elseif-else
if x > 10 then
    big()
elseif x > 5 then
    medium()
else
    small()
end

-- For loop
for i = 1, 10 do
    print(i)
end

-- For-in loop
for key, value in pairs(table) do
    print(key, value)
end

-- While loop
while running do
    update()
end

-- Function
function calculate(a, b)
    return a + b
end

-- Anonymous function
local func = function(x)
    return x * 2
end

-- Nested everything
function complex()
    if true then
        for i = 1, 5 do
            while condition do
                if nested then
                    process()
                end
            end
        end
    end
end -- Count: 1 function + 3 ifs + 1 for + 1 while = 6 ends ✓
```

**Incorrect (DO NOT GENERATE):**
```lua
-- Missing end
function broken()
    if x then
        print("oops")
    -- MISSING: end for if
-- MISSING: end for function

-- Extra end  
function broken()
    print("done")
end
end -- EXTRA end!

-- Mismatched brackets
local data = {
    items = [1, 2, 3}  -- [ and } don't match!

-- Unclosed string
local text = "Hello
local other = "World" -- First string never closed!
```

### Validation Output Format

When generating code, output a brief validation summary:

```
[Syntax Validation]
✓ Function blocks: 2 opens, 2 closes
✓ If statements: 1 open, 1 close  
✓ For loops: 1 open, 1 close
✓ String literals: 3 opens, 3 closes
✓ Total depth check: Max 3 levels
✓ SYNTAX VALID - Generating code...
```

### If Validation Fails

If you detect a syntax error AFTER generating code:
1. **STOP immediately**
2. **Show the error**: "⚠️ Syntax error detected: Missing `end` for function at line X"
3. **Fix it**: Regenerate the corrected code
4. **Re-validate**: Count blocks again
5. **Only then** save the file

### Luau-Specific Reminders

- Use `and`, `or`, `not` (not `&&`, `||`, `!`)
- Tables use `{key = value}` not `{key: value}`
- No `continue` keyword (use conditional nesting instead)
- Type annotations: `function foo(x: number): string` (optional but recommended)
- String interpolation: Use `string.format()` or concatenation
- No `nil` coalescing operator (use `x or default`)

## Code Templates

### Manager Script Template
```lua
-- [ManagerName].server.lua
-- Description: [What this manager does]

-- SERVICES
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- MODULES
local SomeModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("SomeModule"))

-- CONFIG
local SOME_CONSTANT = 10
local ANOTHER_VALUE = 5

-- STATE
local activeItems = {}

-- FUNCTIONS
local function initializeManager()
    -- Implementation
end

local function handleSomething(player, data)
    -- Implementation
end

-- EVENTS
Players.PlayerAdded:Connect(function(player)
    -- Implementation
end)

-- INITIALIZATION
initializeManager()
```

### ModuleScript Template
```lua
-- [ModuleName].lua
-- Description: [What this module provides]

local Module = {}

-- CONFIG
Module.DEFAULT_VALUE = 100

-- TYPES (optional, for clarity)
export type ConfigData = {
    Name: string,
    Value: number,
    Enabled: boolean
}

-- FUNCTIONS
function Module.calculateSomething(input: number): number
    return input * 2
end

function Module.validateData(data: ConfigData): boolean
    return data.Name ~= "" and data.Value > 0
end

return Module
```

### RemoteEvent Setup
```lua
-- In shared/Events/SomeEvent.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SomeEvent = Instance.new("RemoteEvent")
SomeEvent.Name = "SomeEvent"
SomeEvent.Parent = ReplicatedStorage:WaitForChild("Events")

return SomeEvent
```

## Game-Specific Patterns

### Brainrot/Unit System
```lua
-- Spawning a brainrot with rarity and income
local function spawnBrainrot(rarity: string, position: Vector3)
    local brainrotModel = ServerStorage.BrainrotBase:Clone()
    
    -- Apply rarity color
    for _, part in brainrotModel:GetDescendants() do
        if part:IsA("BasePart") then
            part.Color = RARITY_COLORS[rarity]
        end
    end
    
    -- Set income rate
    local incomeConfig = TIER_CONFIG[rarity]
    local incomePerSecond = incomeConfig.Base + math.random(0, incomeConfig.Var)
    
    brainrotModel:SetAttribute("IncomeRate", incomePerSecond)
    brainrotModel:SetAttribute("Rarity", rarity)
    brainrotModel.Parent = workspace.ActiveBrainrots
    brainrotModel:SetPrimaryPartCFrame(CFrame.new(position))
    
    return brainrotModel
end
```

### Economy/Income Pattern
```lua
-- Calculate and award income from units
local function awardIncome(player)
    local unitsFolder = workspace.ActiveBrainrots:FindFirstChild(player.UserId)
    if not unitsFolder then return end
    
    local totalIncome = 0
    for _, unit in unitsFolder:GetChildren() do
        local incomeRate = unit:GetAttribute("IncomeRate") or 0
        totalIncome += incomeRate
    end
    
    -- Award to player (integrate with your data system)
    local profile = ProfileService:GetProfile(player)
    if profile then
        profile.Data.Money += totalIncome
    end
end
```

### Event System Pattern (for your roadmap)
```lua
-- EventManager pattern for rotating events
local EVENTS = {
    {Name = "MeteorShower", Duration = 120, Weight = 10},
    {Name = "LavaRise", Duration = 60, Weight = 15},
    {Name = "CelestialBrainrots", Duration = 180, Weight = 5},
}

local activeEvent = nil
local eventEndTime = 0

local function selectRandomEvent()
    local totalWeight = 0
    for _, event in EVENTS do
        totalWeight += event.Weight
    end
    
    local roll = math.random(1, totalWeight)
    local currentWeight = 0
    
    for _, event in EVENTS do
        currentWeight += event.Weight
        if roll <= currentWeight then
            return event
        end
    end
end

local function startEvent(eventData)
    activeEvent = eventData.Name
    eventEndTime = os.time() + eventData.Duration
    
    -- Trigger event-specific logic
    if eventData.Name == "MeteorShower" then
        -- Start meteor spawning
    elseif eventData.Name == "LavaRise" then
        -- Increase lava speed
    end
    
    -- Notify clients
    ReplicatedStorage.Events.EventStarted:FireAllClients(eventData.Name, eventData.Duration)
end
```

## Quality Standards

### ✅ GOOD Code (Production-Ready)
```lua
-- Complete implementation with all logic
local function spawnMutation(brainrot, mutationType)
    if mutationType == "Radioactive" then
        -- Create particle emitter
        local particles = Instance.new("ParticleEmitter")
        particles.Color = ColorSequence.new(Color3.fromRGB(0, 255, 0))
        particles.Rate = 20
        particles.Lifetime = NumberRange.new(1, 2)
        particles.Parent = brainrot.PrimaryPart
        
        -- Apply mesh modification
        for _, part in brainrot:GetDescendants() do
            if part:IsA("MeshPart") then
                part.Material = Enum.Material.Neon
                part.Color = Color3.fromRGB(100, 255, 100)
            end
        end
        
        -- Increase income multiplier
        local baseIncome = brainrot:GetAttribute("IncomeRate") or 0
        brainrot:SetAttribute("IncomeRate", baseIncome * 2)
        brainrot:SetAttribute("Mutation", "Radioactive")
    end
end
```

### ❌ BAD Code (Avoid This)
```lua
-- Incomplete with placeholder comments
local function spawnMutation(brainrot, mutationType)
    -- TODO: Add particle effects here
    -- TODO: Modify mesh appearance
    -- TODO: Increase income based on mutation type
    
    brainrot:SetAttribute("Mutation", mutationType)
end
```

### 🚫 SYNTAX ERRORS (Never Generate These)

**Error 1: Missing `end`**
```lua
-- WRONG - Missing end for function
function broken()
    if x > 5 then
        print("big")
    end
-- ERROR: Missing end for function!

-- CORRECT
function fixed()
    if x > 5 then
        print("big")
    end
end -- ✓
```

**Error 2: Extra `end`**
```lua
-- WRONG - Extra end
function broken()
    print("done")
end
end -- ERROR: Extra end!

-- CORRECT
function fixed()
    print("done")
end -- ✓
```

**Error 3: Mismatched `end` count**
```lua
-- WRONG - Nested blocks not closed properly
function broken()
    if condition then
        for i = 1, 5 do
            print(i)
        end
    -- ERROR: Missing end for if!
end

-- CORRECT
function fixed()
    if condition then
        for i = 1, 5 do
            print(i)
        end -- closes for
    end -- closes if
end -- closes function ✓
```

**Error 4: Unclosed string**
```lua
-- WRONG - String not closed
local text = "Hello
local other = "World"
-- ERROR: First string never closed!

-- CORRECT
local text = "Hello"
local other = "World" -- ✓
```

**Error 5: Mixing Lua 5.1 and Luau**
```lua
-- WRONG - Using Lua 5.1 syntax
function broken()
    continue -- ERROR: `continue` doesn't exist in Luau!
end

-- CORRECT - Use Luau alternative
function fixed()
    if shouldSkip then
        -- Use conditional instead
    else
        process()
    end
end -- ✓
```

### Before Saving ANY File

**MANDATORY: Count all blocks one final time:**
```
1. Count `function` → count `end`
2. Count `if`/`elseif` → count corresponding `end`
3. Count `for` → count corresponding `end`
4. Count `while` → count corresponding `end`
5. Verify: Opens == Closes
```

If counts don't match → **DO NOT SAVE** → Fix first → Recount → Then save.

## Advanced References

For complex implementations and setup, read these reference files:

- **references/installation-guide.md**: **START HERE** - Install luau-analyze, selene, stylua, and configure the validation pipeline
- **references/syntax-debugging.md**: Common syntax errors, counting strategies, emergency fixes (read if validation fails)
- **references/event-system-patterns.md**: Detailed patterns for event rotation, super events, and scheduling
- **references/mutation-system-guide.md**: Mesh modification, particle effects, and spawn rate calculations
- **references/optimization-tips.md**: Performance best practices for spawning many units

**First-time setup:** Read installation-guide.md to install validation tools (~20-30 minutes one-time setup)

Load these files when implementing their respective systems or troubleshooting errors.

## Completion Checklist

After completing a roadmap task:
- ✅ **MENTAL VALIDATION PASSED** (counted all blocks, verified pairing)
- ✅ **HEADLESS VALIDATION PASSED** (executed validate_and_continue.py with exit code 0)
- ✅ All code is complete (no TODOs or placeholders)
- ✅ Files created in correct directories
- ✅ Follows established naming conventions
- ✅ Includes necessary error handling
- ✅ References existing modules correctly
- ✅ Tested logic paths mentally
- ✅ Marked task as complete with ✓ [X.Y] COMPLETED & VALIDATED

**CRITICAL REMINDER:** NEVER mark a task as complete without running headless validation first. If you encounter `expected eof, got end` or similar syntax errors, it means validation was skipped or failed. Always execute `python3 scripts/validate_and_continue.py <file>` and wait for ✅ VALIDACIÓN EXITOSA before proceeding.
