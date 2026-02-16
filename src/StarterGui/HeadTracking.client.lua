-- HeadTracking.client.lua
-- Skill: immersion
-- Description: Makes the ShopNPC look at the player. adapted from TwinPlayz tutorial.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local MAX_DISTANCE = 25
local MAX_ANGLE = math.rad(60)
local SMOOTHING = 0.1

local function getNeck(model)
    local head = model:FindFirstChild("Head")
    if head then
        return head:FindFirstChild("Neck")
    end
    return nil
end

RunService.RenderStepped:Connect(function()
    local char = player.Character
    if not char then return end
    
    local hrp = char:FindFirstChild("Head") -- Look at player eyes
    if not hrp then return end
    
    local shopsFolder = Workspace:FindFirstChild("Shops")
    if not shopsFolder then return end
    
    for _, shop in pairs(shopsFolder:GetChildren()) do
        local npc = shop:FindFirstChild("Npc")
        if npc and npc:IsA("Model") then
             local npcHead = npc:FindFirstChild("Head")
             local neck = getNeck(npc)
             
             if npcHead and neck then
                 if not neck:GetAttribute("OriginalC0") then
                    neck:SetAttribute("OriginalC0", neck.C0)
                 end
                 local originalC0 = neck:GetAttribute("OriginalC0")
                 
                 local dist = (npcHead.Position - hrp.Position).Magnitude
                 
                 if dist < MAX_DISTANCE then
                    local dir = (hrp.Position - npcHead.Position).Unit
                    
                    if npc.PrimaryPart then
                        local vecA = Vector2.new(dir.X, dir.Z)
                        local vecB = Vector2.new(npc.PrimaryPart.CFrame.LookVector.X, npc.PrimaryPart.CFrame.LookVector.Z)
                        local dot = vecA:Dot(vecB)
                        local cross = vecA.X * vecB.Y - vecA.Y * vecB.X
                        local yAngle = math.atan2(cross, dot)
                        
                        yAngle = math.clamp(yAngle, -MAX_ANGLE, MAX_ANGLE)
                        
                        local verticalOffset = hrp.Position.Y - npcHead.Position.Y
                        local angleDistance = (hrp.Position - npcHead.Position).Magnitude
                        local xAngle = math.atan2(verticalOffset, angleDistance)
                        xAngle = math.clamp(xAngle, -math.rad(30), math.rad(30))
                        
                        local targetC0 = originalC0 * CFrame.Angles(xAngle, -yAngle, 0)
                        neck.C0 = neck.C0:Lerp(targetC0, SMOOTHING)
                    end
                 else
                    neck.C0 = neck.C0:Lerp(originalC0, SMOOTHING)
                 end
             end
        end
    end
end)
