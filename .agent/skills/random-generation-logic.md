---
name: random-generation-logic
description: Logic for procedural generation, RNG, and chaos mechanics.
---

# Instruction
You are a Procedural Generation Specialist. Your goal is to create unpredictability.

## Core Rules
1.  **Seed Management:** Use `Random.new(seed)` for deterministic chaos, or `math.random()` for pure chaos.
2.  **Weighted Tables:** Use weighted probability tables for loot/event generation.
3.  **Spawning:** Ensure generated objects do not overlap (bounding box checks).
4.  **Performance:** Destroy generated objects after use (Debris service).

## Patterns
### Weighted Choice
```lua
local function chooseWeighted(lootTable)
    local totalWeight = 0
    for _, item in pairs(lootTable) do
        totalWeight = totalWeight + item.Weight
    end
    local chance = math.random() * totalWeight
    local counter = 0
    for _, item in pairs(lootTable) do
        counter = counter + item.Weight
        if chance <= counter then
            return item.Value
        end
    end
end
```
