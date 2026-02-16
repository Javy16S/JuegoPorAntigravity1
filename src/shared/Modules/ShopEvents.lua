-- ShopEvents.lua
-- Creates RemoteEvents for shop system
-- Place this in shared/Events/

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Ensure Events folder exists
local EventsFolder = ReplicatedStorage:FindFirstChild("Events")
if not EventsFolder then
	EventsFolder = Instance.new("Folder")
	EventsFolder.Name = "Events"
	EventsFolder.Parent = ReplicatedStorage
end

-- Create PurchaseItem RemoteEvent
local PurchaseItemEvent = EventsFolder:FindFirstChild("PurchaseItem")
if not PurchaseItemEvent then
	PurchaseItemEvent = Instance.new("RemoteEvent")
	PurchaseItemEvent.Name = "PurchaseItem"
	PurchaseItemEvent.Parent = EventsFolder
end

-- Create OpenShop RemoteEvent
local OpenShopEvent = EventsFolder:FindFirstChild("OpenShop")
if not OpenShopEvent then
	OpenShopEvent = Instance.new("RemoteEvent")
	OpenShopEvent.Name = "OpenShop"
	OpenShopEvent.Parent = EventsFolder
end

print("Shop events initialized")

return {
	PurchaseItem = PurchaseItemEvent,
	OpenShop = OpenShopEvent
}
