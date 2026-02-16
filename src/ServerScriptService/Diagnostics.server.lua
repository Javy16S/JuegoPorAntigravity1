-- Diagnostics.server.lua
print("--- DIAGNOSTICS START ---")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("Checking ReplicatedStorage Children:")
for _, c in pairs(ReplicatedStorage:GetChildren()) do
    print(" - " .. c.Name .. " (".. c.ClassName ..")")
end

if ReplicatedStorage:FindFirstChild("EconomyLogic") then
    print("SUCCESS: EconomyLogic found in ReplicatedStorage.")
    local status, result = pcall(require, ReplicatedStorage.EconomyLogic)
    if status then
        print("SUCCESS: EconomyLogic required successfully.")
    else
        warn("ERROR: EconomyLogic found but failed to require: " .. tostring(result))
    end
else
    warn("FAILURE: EconomyLogic NOT found in ReplicatedStorage.")
end
print("--- DIAGNOSTICS END ---")
