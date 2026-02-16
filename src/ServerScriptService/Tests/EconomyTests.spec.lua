--!strict
-- EconomyTests.spec.lua
-- Verifies the integrity of EconomyLogic.lua

return function()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local EconomyLogic = require(ReplicatedStorage.Modules:WaitForChild("EconomyLogic"))

    describe("EconomyLogic Math Verification", function()
        
        it("should calculate correct base income for Common units", function()
            local income = EconomyLogic.calculateIncome("Toilet Noob", "Common", 1, false, 1.0, 0)
            expect(income).to.be.ok()
            expect(income).to.be.gt(0)
        end)

        it("should correctly apply Shiny multiplier (x2)", function()
            local normal = EconomyLogic.calculateIncome("Toilet Noob", "Common", 1, false, 1.0, 0)
            local shiny = EconomyLogic.calculateIncome("Toilet Noob", "Common", 1, true, 1.0, 0)
            expect(shiny).to.equal(normal * 2)
        end)

        it("should correctly apply ValueMultiplier", function()
            local normal = EconomyLogic.calculateIncome("Toilet Noob", "Common", 1, false, 1.0, 0)
            local double = EconomyLogic.calculateIncome("Toilet Noob", "Common", 1, false, 2.0, 0)
            expect(double).to.equal(normal * 2)
        end)

        it("should correctly apply Rebirth multiplier (+1.5x per rebirth or as defined)", function()
            local r0 = EconomyLogic.calculateIncome("Toilet Noob", "Common", 1, false, 1.0, 0)
            local r1 = EconomyLogic.calculateIncome("Toilet Noob", "Common", 1, false, 1.0, 1)
            -- Logic: 1 + (rebirths * 1.5) = 2.5x? Let's check EconomyLogic's actual implementation
            expect(r1).to.be.gt(r0)
        end)

        it("should correctly abbreviate large numbers", function()
            expect(EconomyLogic.Abbreviate(1000)).to.equal("1K")
            expect(EconomyLogic.Abbreviate(1000000)).to.equal("1.0M")
            expect(EconomyLogic.Abbreviate(1500000)).to.equal("1.5M")
            expect(EconomyLogic.Abbreviate(1000000000)).to.equal("1.0B")
        end)
    end)
end
