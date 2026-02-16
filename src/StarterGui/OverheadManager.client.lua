-- OverheadManager.client.lua
-- Skill: ui-polishing
-- Description: Manages Player-Specific Overheads (Just Name/Rank) and Flying Numbers.
-- NOTE: Unit UI is handled by UnitLabels.client.lua

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local FONT_BOLD = Enum.Font.FredokaOne

-- 1. Simple Player Overhead (Name Only)
local function createPlayerOverhead(char)
    local head = char:WaitForChild("Head", 10)
    if not head then return end
    
    if head:FindFirstChild("PlayerNameTag") then return end

    local bb = Instance.new("BillboardGui")
    bb.Name = "PlayerNameTag"
    bb.Size = UDim2.new(4, 0, 1, 0)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Parent = head

    local lbl = Instance.new("TextLabel")
    lbl.Text = char.Name
    lbl.Size = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextStrokeTransparency = 0
    lbl.Font = FONT_BOLD
    lbl.TextScaled = true
    lbl.Parent = bb
end

local function onCharAdded(char)
    createPlayerOverhead(char)
end

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(onCharAdded)
    if p.Character then onCharAdded(p.Character) end
end)
if localPlayer.Character then onCharAdded(localPlayer.Character) end
localPlayer.CharacterAdded:Connect(onCharAdded)

-- 2. Flying Income Numbers (Same as before)
local incomeEvent = ReplicatedStorage:WaitForChild("OnIncomeTick", 5)
if incomeEvent then
    incomeEvent.OnClientEvent:Connect(function(amount)
        local char = localPlayer.Character
        if not char or not char:FindFirstChild("Head") then return end
        
        local p = Instance.new("Part")
        p.Transparency = 1
        p.Anchored = true
        p.CanCollide = false
        p.Position = char.Head.Position + Vector3.new(math.random(-2,2), 2, math.random(-2,2))
        p.Parent = game.Workspace
        
        local bb = Instance.new("BillboardGui")
        bb.Size = UDim2.new(0, 200, 0, 50)
        bb.AlwaysOnTop = true
        bb.Parent = p
        
        local txt = Instance.new("TextLabel")
        txt.Text = "+$" .. amount
        txt.TextColor3 = Color3.fromRGB(100, 255, 100)
        txt.TextStrokeTransparency = 0
        txt.Font = FONT_BOLD
        txt.TextScaled = true
        txt.BackgroundTransparency = 1
        txt.Size = UDim2.new(1,0,1,0)
        txt.Parent = bb
        
        -- Animation
        local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Linear)
        TweenService:Create(p, tweenInfo, {Position = p.Position + Vector3.new(0, 5, 0)}):Play()
        TweenService:Create(txt, tweenInfo, {TextTransparency = 1}):Play()
        
        game:GetService("Debris"):AddItem(p, 1)
    end)
end
