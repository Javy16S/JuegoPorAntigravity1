local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

print("[LocalUpgrade] STARTING UP...") 

local player = Players.LocalPlayer
local upgradeFunc = ReplicatedStorage:WaitForChild("UpgradeUnit", 10)

if not upgradeFunc then
    warn("[LocalUpgrade] UpgradeUnit remote missing!")
else
    print("[LocalUpgrade] Remote Found.")
end

-- ============================================================================
-- BUTTON LOGIC
-- ============================================================================
local function setupButton(btn)
    btn.MouseButton1Click:Connect(function()
        local unitId = btn:GetAttribute("UnitId")
        if not unitId then return end
        
        if btn:GetAttribute("Processing") then return end
        btn:SetAttribute("Processing", true)
        
        local oldText = btn.Text
        btn.Text = "..."
        
        local result = upgradeFunc:InvokeServer(unitId)
        
        if result.success then
            local sfx = Instance.new("Sound")
            sfx.SoundId = "rbxassetid://160715357"
            sfx.Parent = player.Character or player.PlayerGui
            sfx:Play()
            btn.Text = "UPGRADE"
        else
            local sfx = Instance.new("Sound")
            sfx.SoundId = "rbxassetid://4612375233"
            sfx.Parent = player.Character or player.PlayerGui
            sfx:Play()
            btn.Text = result.msg or "Error"
            task.wait(1)
            btn.Text = "UPGRADE"
        end
        btn:SetAttribute("Processing", nil)
    end)
end

CollectionService:GetInstanceAddedSignal("UpgradeButton"):Connect(setupButton)
for _, btn in pairs(CollectionService:GetTagged("UpgradeButton")) do
    setupButton(btn)
end

-- ============================================================================
-- HOLD 'F' LOGIC (DISABLED BY USER REQUEST 2026-02-04)
-- ============================================================================
--[[
local UPGRADE_COOLDOWN = 0.15 
local MAX_DISTANCE = 16
local lastUpgradeTime = 0

local function getClosestPrompt()
    local char = player.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    local myPos = hrp.Position
    local closest = nil
    local minDst = MAX_DISTANCE
    
    for _, prompt in ipairs(CollectionService:GetTagged("UpgradePrompt")) do
        if prompt.Enabled and prompt.Parent then
            local dist = (prompt.Parent.Position - myPos).Magnitude
            if dist < minDst then
                minDst = dist
                closest = prompt
            end
        end
    end
    return closest
end

RunService.Heartbeat:Connect(function()
    if UserInputService:IsKeyDown(Enum.KeyCode.F) then
        local now = tick()
        if now - lastUpgradeTime >= UPGRADE_COOLDOWN then
             local prompt = getClosestPrompt()
             if prompt and prompt.Parent then
                 -- Extract unitId from slot
                 local uId = nil
                 for _, child in pairs(prompt.Parent:GetChildren()) do
                     if child:IsA("Model") and child:GetAttribute("UnitId") then
                         uId = child:GetAttribute("UnitId")
                         break
                     end
                 end
                 
                 if uId then
                     -- Reuse remote
                     spawn(function()
                         upgradeFunc:InvokeServer(uId)
                     end)
                     lastUpgradeTime = now
                 end
             end
        end
    end
end)
]]

print("[LocalUpgrade] Button Logic Ready (Hold-F Disabled).")
