local ReplicatedFirst = game:GetService("ReplicatedFirst")
-- Remove default immediately
ReplicatedFirst:RemoveDefaultLoadingScreen()

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

print(" [LoadingScreen] Script Started")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local SpinnerImageID = "rbxassetid://4543893907"

print(" [LoadingScreen] PlayerGui found")

-- // GUI CREATION //
local LoadingGui = Instance.new("ScreenGui")
LoadingGui.Name = "DynamicLoadingGui"
LoadingGui.IgnoreGuiInset = true
LoadingGui.ResetOnSpawn = false
LoadingGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
LoadingGui.DisplayOrder = 1001 -- v5.5 FIX: Ensure it stays on top of everything

local Background = Instance.new("Frame")
Background.Name = "Background"
Background.Size = UDim2.new(1, 0, 1, 0)
Background.BackgroundColor3 = Color3.fromRGB(0, 0, 0) -- Pure Black
Background.BorderSizePixel = 0
Background.Parent = LoadingGui

-- Container for center elements
local CenterContainer = Instance.new("Frame")
CenterContainer.Name = "CenterContainer"
CenterContainer.Size = UDim2.new(0.4, 0, 0.4, 0)
CenterContainer.AnchorPoint = Vector2.new(0.5, 0.5)
CenterContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
CenterContainer.BackgroundTransparency = 1
CenterContainer.Parent = Background

-- Spinner Image
local Spinner = Instance.new("ImageLabel")
Spinner.Name = "Spinner"
Spinner.Size = UDim2.new(0, 100, 0, 100) -- Size of the spinner
Spinner.AnchorPoint = Vector2.new(0.5, 0.5)
Spinner.Position = UDim2.new(0.5, 0, 0.4, 0) -- Slightly above center
Spinner.BackgroundTransparency = 1 -- Initially invisible until loaded? Or just default.
-- Note: Setting Image immediately, but we will preload it in the logic block.
Spinner.Image = SpinnerImageID 
Spinner.ImageColor3 = Color3.fromRGB(255, 255, 255)
Spinner.Parent = CenterContainer

local AssetCounter = Instance.new("TextLabel")
AssetCounter.Name = "AssetCounter"
AssetCounter.Size = UDim2.new(1, 0, 0.1, 0)
AssetCounter.AnchorPoint = Vector2.new(0.5, 0)
AssetCounter.Position = UDim2.new(0.5, 0, 0.6, 0) -- Below spinner
AssetCounter.BackgroundTransparency = 1
AssetCounter.TextColor3 = Color3.fromRGB(150, 150, 150)
AssetCounter.TextScaled = true
AssetCounter.Font = Enum.Font.Gotham
AssetCounter.Text = "Initializing..."
AssetCounter.Parent = CenterContainer

LoadingGui.Parent = PlayerGui

-- // LOGIC //

local function getAssets()
	local assets = {}
	
	-- Scan ReplicatedStorage (UI, Tools, Modules)
	for _, descendant in ipairs(ReplicatedStorage:GetDescendants()) do
		if descendant:IsA("ImageLabel") or descendant:IsA("ImageButton") or descendant:IsA("MeshPart") or descendant:IsA("SpecialMesh") or descendant:IsA("Sound") then
			table.insert(assets, descendant)
		end
	end
	
	-- Workspace: Only scan specific high-priority areas if any?
	-- Skipping broad workspace scan to save 10+ seconds on large maps.
	
	return assets
end

local loadedAssets = 0
local totalAssets = 1 

local function updateProgress()
	loadedAssets += 1
	-- Update UI text only
	AssetCounter.Text = "Loading Assets: " .. loadedAssets .. " / " .. totalAssets
end

-- Start Logic
task.spawn(function()
	local startTime = os.clock()
	local minTime = 3 

	-- 1. PRIORITY PRELOAD: Load the spinner first so it appears immediately
	-- We create a temporary instance to preload specifically this ID if needed, 
	-- or just pass the ID string/ImageLabel to PreloadAsync.
	-- Best practice: Pass the instance using the asset.
	AssetCounter.Text = "Starting..."
	ContentProvider:PreloadAsync({Spinner}) 
	
	-- Now that spinner is loaded, start animation
	local spinTweenInfo = TweenInfo.new(1.5, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut, -1)
	local spinTween = TweenService:Create(Spinner, spinTweenInfo, {Rotation = 360})
	spinTween:Play()

	-- 2. WAIT FOR GAME
	if not game:IsLoaded() then
		AssetCounter.Text = "Waiting for game..."
		game.Loaded:Wait()
	end
	
	print(" [LoadingScreen] Game Loaded. Scanning assets...")
	AssetCounter.Text = "Discovering assets..."
	
	local assetsToLoad = getAssets()
	totalAssets = #assetsToLoad
	print(" [LoadingScreen] Found " .. totalAssets .. " assets.")
	
	AssetCounter.Text = "Loading Assets: 0 / " .. totalAssets

	if totalAssets > 0 then
		ContentProvider:PreloadAsync(assetsToLoad, updateProgress)
	end
	
	-- Wait for the remainder of the minimum time
	local elapsed = os.clock() - startTime
	if elapsed < minTime then
		task.wait(minTime - elapsed)
	end

	-- Force complete visuals
	AssetCounter.Text = "Loading Complete!"
	task.wait(0.5) 
	
	-- Fade Out
	local fadeInfo = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	
	-- Tween everything out
	local tweens = {}
	table.insert(tweens, TweenService:Create(Background, fadeInfo, {BackgroundTransparency = 1}))
	table.insert(tweens, TweenService:Create(Spinner, fadeInfo, {ImageTransparency = 1}))
	table.insert(tweens, TweenService:Create(AssetCounter, fadeInfo, {TextTransparency = 1}))
	
	for _, t in ipairs(tweens) do t:Play() end
	
	tweens[1].Completed:Wait()
	spinTween:Cancel()
	LoadingGui:Destroy()
	print(" [LoadingScreen] Screen Destroyed.")
end)
