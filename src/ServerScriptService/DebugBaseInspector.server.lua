local ServerStorage = game:GetService("ServerStorage")
print("[DebugBaseInspector] Waiting for BaseBrainrots...")
local baseBrainrots = ServerStorage:WaitForChild("BaseBrainrots", 10)

print("--- INSPECTING BASE BRAINROTS ---")
if baseBrainrots then
    print("Found BaseBrainrots folder.")
    for _, child in pairs(baseBrainrots:GetChildren()) do
        print("Model: " .. child.Name)
        if child.Name == "BaseBasica" then
            print("  > Inspecting BaseBasica Children:")
            for _, grandChild in pairs(child:GetChildren()) do
                print("    - " .. grandChild.Name .. " (" .. grandChild.ClassName .. ")")
                if grandChild.Name == "BaseUpgrader" then
                    print("      > FOUND BaseUpgrader!")
                    for _, ggChild in pairs(grandChild:GetChildren()) do
                         print("        - " .. ggChild.Name)
                    end
                end
            end
        end
    end
else
    print("CRITICAL: BaseBrainrots folder NOT FOUND in ServerStorage.")
    local wsBase = workspace:FindFirstChild("BaseBrainrots")
    if wsBase then print("  > But found it in Workspace!") end
end
print("--------------------------------")
