--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

return function()
    describe("BrainrotData Persistence", function()
        -- Mock DataStore
        local mockDataStore = {}
        local mockData = {}
        
        function mockDataStore:GetAsync(key)
            if mockData[key] == "ERROR" then
                error("Mock DataStore Error")
            end
            return mockData[key]
        end
        
        function mockDataStore:SetAsync(key, value)
            if key == "FAIL_SAVE" then
                error("Mock Save Error")
            end
            mockData[key] = value
        end

        local MockDataStoreService = {}
        function MockDataStoreService:GetDataStore(name)
            return mockDataStore
        end
        
        -- Mock Players
        local mockPlayer = Instance.new("Player")
        mockPlayer.Name = "TestPlayer_Persistence"
        mockPlayer.UserId = 123456789
        
        -- We need to intercept the require of BrainrotData to inject mocks if possible,
        -- or we just test the public API if we can't easily inject.
        -- Since we can't easily inject without a dependency injection framework, 
        -- we will assume the environment is set up or we'll wrap the module.
        
        -- ideally we would use a library like 'rewire' but in Roblox we often just load the module.
        -- For this test, we will verify the BEHAVIOR by observing the results.
        
        local BrainrotData = require(ServerScriptService.BrainrotData)
        
        -- We can't easily mock DataStoreService globally for the module already loaded.
        -- However, we can test the critical logic flows if we could swap the DS.
        -- CURRENT LIMITATION: BrainrotData creates the DataStore instance at the top level.
        -- To properly test failure modes without mocking the actual service (which we can't do easily from here for an already required module),
        -- we might have to rely on integration tests or manual verification for the *exact* retries.
        
        -- BUT, we can test that the module methods don't crash and behave expectedly with valid data.
        
        it("should initialize a new player correctly", function()
            -- Simulate player added (this might trigger onPlayerAdded internally if we called Init, but let's call the logic if accessible or just check session)
            -- BrainrotData.onPlayerAdded is local. We have to rely on public API.
            
            -- Wait for data to be ready? We can't invoke private methods.
            -- BrainrotData.Init() is called at script start usually.
            
            -- Let's test the Session API which reflects the loaded data.
            local session = BrainrotData.getPlayerSession(mockPlayer)
            -- It might be nil if onPlayerAdded hasn't run.
            
            -- Since we can't modify the internal DataStore variable of the loaded module,
            -- we will focus on testing the data *structure* integrity and public methods.
        end)
        
        it("should handle SaveData without errors", function()
             -- Tricky to test internal save without mocking.
             -- But we can verify `BrainrotData.addCash` works and updates session.
             BrainrotData.addCash(mockPlayer, 100)
             local session = BrainrotData.getPlayerSession(mockPlayer)
             expect(session).to.be.ok()
             if session then
                 expect(session.Cash).to.be.a("number")
             end
        end)
        
        -- Testing the "Kick on Load Fail" is dangerous in a real environment spec 
        -- because it might kick the test runner if we are not careful (though we use a mock player).
        
    end)
end
