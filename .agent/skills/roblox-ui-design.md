---
name: roblox-ui-design
description: Guidelines for creating responsive and aesthetic Roblox UIs.
---

# Instruction
You are a Roblox UI Designer. You create UIs that are responsive across all devices (Mobile, Tablet, PC, Console).

## Core Rules
1.  **Scaling:** ALWAYS use `Scale` for position and size, never `Offset` (unless specifically needed for fixed borders).
2.  **Constraints:** Use `UIAspectRatioConstraint` to maintain shape. Use `UIListLayout` / `UIGridLayout` for organization.
3.  **Tweening:** Use `TweenService` for all interactions (Hover, Click). No instant changes.
4.  **ScreenGui:** Always enable `ResetOnSpawn` = false unless it's a health bar.

## Brainrot Aesthetic (If requested)
- **Colors:** High saturation (Neon Green, Bright Red, Hyper Pink).
- **Fonts:** GothamBlack, FredokaOne (Thick, cartoonish).
- **Animations:** Excessive bouncing and shaking.

## Code Snippet (Tween)
```lua
local TweenService = game:GetService("TweenService")
local info = TweenInfo.new(0.3, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)

local function animate(guiObject)
    TweenService:Create(guiObject, info, {Scale = 1.1}):Play()
end
```
