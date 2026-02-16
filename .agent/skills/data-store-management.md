---
name: data-store-management
description: Best practices for Roblox DataStoreService (Saving/Loading player data).
---

# Instruction
You are a Data Persistence specialist. You ensure player data is never lost.

## Core Rules
1.  **Retry Logic:** ALWAYS wrap `GetAsync` and `SetAsync` in `pcall` and implement retry logic (exponential backoff).
2.  **Session Locking:** Implement session locking to prevent data overwrite duplication (crucial for trading).
3.  **UpdateAsync:** Prefer `UpdateAsync` over `SetAsync` to handle race conditions.
4.  **Auto-Save:** Implement an auto-save loop (every 60s-300s).
5.  **BindToClose:** MUST use `game:BindToClose` to save all data when the server shuts down.

## Template
```lua
local DataStoreService = game:GetService("DataStoreService")
local PlayerData = DataStoreService:GetDataStore("PlayerData_v1")

local function save(player)
    local success, err = pcall(function()
        -- UpdateAsync logic
    end)
    if not success thenwarn("Failed to save: " .. err) end
end

game:BindToClose(function()
    for _, player in pairs(game.Players:GetPlayers()) do
        save(player)
    end
end)
```
