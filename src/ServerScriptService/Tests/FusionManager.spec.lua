--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local FusionManager = require(ServerScriptService.FusionManager)
local FusionData = require(ServerScriptService.FusionData)
local BrainrotData = require(ServerScriptService.BrainrotData)

return function()
    describe("FusionManager", function()
        
        -- MOCK PLAYER
        local mockPlayer = {
            Name = "TestPlayer",
            UserId = 123456,
            FindFirstChild = function(self, name) return nil end
        } :: any
        
        -- SETUP / TEARDOWN
        beforeEach(function()
            -- Reset inventory via raw data manipulation if exposed, or just allow side effects
            -- Ideally we would clear the session data here
        end)

        it("should return correct random model from tier", function()
            local model = FusionManager.getRandomModelFromTier("Common")
            expect(typeof(model)).to.equal("string")
        end)
        
        it("should validate fusion requirements correctly", function()
             -- Need 3 units
             local success, err = FusionManager.validateFusion(mockPlayer, {"1", "2"})
             expect(success).to.equal(false)
             expect(err).to.be.ok()
        end)

        -- Note: Deeper logic testing requires mocking BrainrotData state 
        -- which depends on how the TestRunner sets up the environment.
        -- Assuming Functional Test environment where we can add items to player.
        
    end)
end
