-- BaseUpgradeClient.client.lua
-- Manages the interaction with BaseUpgrader buttons and displays the Upgrade UI.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- CONSTANTS
local MAX_LEVEL = 5 -- Example Limit
local UPGRADE_COST_BASE = 1500
local UPGRADE_COST_MULT = 2.5

-- STATE
local currentBase = nil
local upgradeUI = nil

-- SETUP UI
local function createUpgradeUI()
    local sg = Instance.new("ScreenGui")
    sg.Name = "BaseUpgradeUI"
    sg.ResetOnSpawn = false
    sg.Enabled = false
    sg.Parent = PlayerGui
    
    local frame = Instance.new("Frame")
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0, 400, 0, 300)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    frame.BorderSizePixel = 0
    frame.Parent = sg
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = frame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 255, 100)
    stroke.Thickness = 2
    stroke.Parent = frame
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Text = "MEJORA DE BASE"
    title.Size = UDim2.new(1, 0, 0.2, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 24
    title.Parent = frame
    
    -- Content
    local info = Instance.new("TextLabel")
    info.Name = "InfoLabel"
    info.Text = "Nivel Actual: 1\nSlots: 8 -> 16"
    info.Size = UDim2.new(0.9, 0, 0.4, 0)
    info.Position = UDim2.new(0.05, 0, 0.25, 0)
    info.BackgroundTransparency = 1
    info.TextColor3 = Color3.fromRGB(200, 200, 200)
    info.Font = Enum.Font.GothamBold
    info.TextSize = 18
    info.Parent = frame
    
    -- Button
    local btn = Instance.new("TextButton")
    btn.Name = "UpgradeButton"
    btn.Size = UDim2.new(0.8, 0, 0.2, 0)
    btn.Position = UDim2.new(0.1, 0, 0.7, 0)
    btn.BackgroundColor3 = Color3.fromRGB(0, 200, 50)
    btn.Text = "MEJORAR ($1,500)"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBlack
    btn.TextSize = 20
    btn.Parent = frame
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = btn
    
    -- Close
    local closeBtn = Instance.new("TextButton")
    closeBtn.Text = "X"
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0, 5)
    closeBtn.BackgroundTransparency = 1
    closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.Font = Enum.Font.GothamBlack
    closeBtn.TextSize = 20
    closeBtn.Parent = frame
    
    closeBtn.MouseButton1Click:Connect(function()
        sg.Enabled = false
    end)
    
    return sg, frame, info, btn
end

upgradeUI, mainFrame, infoLabel, upgradeBtn = createUpgradeUI()

-- LOGIC
local function updateUI(baseModel)
    if not baseModel then return end
    currentBase = baseModel
    
    local level = baseModel:GetAttribute("BaseLevel") or 1
    local nextLevel = level + 1
    local cost = UPGRADE_COST_BASE * (UPGRADE_COST_MULT ^ (level - 1))
    
    local slots = 8 * level
    local nextSlots = 8 * nextLevel
    
    infoLabel.Text = string.format("NIVEL BASE: %d\n\nCapacidad: %d ➜ <font color='#00FF00'>%d</font>", level, slots, nextSlots)
    infoLabel.RichText = true
    
    upgradeBtn.Text = string.format("MEJORAR ($%d)", math.floor(cost))
end

-- CONNECT BUTTON
upgradeBtn.MouseButton1Click:Connect(function()
    if not currentBase then return end
    
    -- Sfx
    local sfx = Instance.new("Sound")
    sfx.SoundId = "rbxassetid://6042053626" -- Interface click
    sfx.Parent = player.PlayerGui
    sfx:Play()
    
    -- Invoke Server
    -- Assuming a RemoteFunction exists. If not, we'll create/find it.
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then remotes = Instance.new("Folder", ReplicatedStorage); remotes.Name = "Remotes" end
    
    local upgradeFunc = remotes:FindFirstChild("UpgradeBaseFunc")
    if not upgradeFunc then
        warn("UpgradeBaseFunc not found!")
        return
    end
    
    local success, msg = upgradeFunc:InvokeServer(currentBase)
    
    if success then
        -- Refresh UI
        task.wait(0.1)
        updateUI(currentBase)
        
        -- Success FX
        local sfx2 = Instance.new("Sound")
        sfx2.SoundId = "rbxassetid://1505373867" -- Upgrade sound
        sfx2.Parent = player.PlayerGui
        sfx2:Play()
    else
        warn("Upgrade Failed: " .. tostring(msg))
        -- Shake UI?
    end
end)


-- DETECT CLICKS ON WORLD
-- We look for SurfaceGui buttons in Workspace
local function connectUpgrader(model)
    local btnPart = model:FindFirstChild("UpgradeButton")
    if btnPart then
        local sg = btnPart:FindFirstChildWhichIsA("SurfaceGui")
        if sg then
            local txtBtn = sg:FindFirstChildWhichIsA("TextButton")
            if txtBtn then
                txtBtn.MouseButton1Click:Connect(function()
                    print("BaseUpgrader Clicked!")
                    -- Identify which base it belongs to
                    local base = model.Parent
                    if base and base:IsA("Model") and base.Name:match("TycoonBase") then
                         -- Check Ownership
                         local owner = base:GetAttribute("Owner")
                         if owner == player.Name then
                             updateUI(base)
                             upgradeUI.Enabled = true
                         else
                             -- Notification: Not your base
                             game.StarterGui:SetCore("SendNotification", {
                                 Title = "Denegado";
                                 Text = "Esta no es tu base.";
                                 Duration = 2;
                             })
                         end
                    end
                end)
            end
        end
    end
end

-- Scan existing
for _, desc in pairs(Workspace:GetDescendants()) do
    if desc.Name == "BaseUpgrader" and desc:IsA("Model") then
        connectUpgrader(desc)
    end
end

-- Listen for new
Workspace.DescendantAdded:Connect(function(desc)
    if desc.Name == "BaseUpgrader" and desc:IsA("Model") then
        task.wait(0.5) -- Wait for children
        connectUpgrader(desc)
    end
end)
