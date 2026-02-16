-- AchievementDefinitions.lua
-- Description: Defines all achievements, their criteria, and rewards.

local Achievements = {}

Achievements.LIST = {
    -- MONEY MILESTONES
    {
        Id = "Money_1k",
        Title = "Getting Started",
        Description = "Accumulate $1,000 Cash",
        Type = "Cash",
        Target = 1000,
        Reward = 100, -- Bonus cash
        ImageId = "rbxassetid://13583569479" -- Placeholder coin
    },
    {
        Id = "Money_1M",
        Title = "Millionaire",
        Description = "Accumulate $1,000,000 Cash",
        Type = "Cash",
        Target = 1000000,
        Reward = 50000,
        ImageId = "rbxassetid://13583569479"
    },
    {
        Id = "Money_1B",
        Title = "Billionaire",
        Description = "Accumulate $1,000,000,000 Cash",
        Type = "Cash",
        Target = 1000000000,
        Reward = 50000000,
        ImageId = "rbxassetid://13583569479"
    },

    -- COLLECTION MILESTONES (Unique Discoveries)
    {
        Id = "Collector_5",
        Title = "Novice Collector",
        Description = "Discover 5 Unique Brainrots",
        Type = "Discoveries",
        Target = 5,
        Reward = 500,
        ImageId = "rbxassetid://13583568864" -- Placeholder generic
    },
    {
        Id = "Collector_20",
        Title = "Expert Collector",
        Description = "Discover 20 Unique Brainrots",
        Type = "Discoveries",
        Target = 20,
        Reward = 10000,
        ImageId = "rbxassetid://13583568864"
    },

    -- RARITY DISCOVERIES
    {
        Id = "Find_Legendary",
        Title = "Legendary Find",
        Description = "Discover a Legendary Brainrot",
        Type = "Rarity",
        Target = "Legendary",
        Reward = 10000,
        ImageId = "rbxassetid://13583568864"
    },
    {
        Id = "Find_Mythic",
        Title = "MYTHICAL!",
        Description = "Discover a Mythic Brainrot",
        Type = "Rarity",
        Target = "Mythic",
        Reward = 100000,
        ImageId = "rbxassetid://13583568864"
    },
    {
        Id = "Find_Supreme",
        Title = "SUPREME BEING",
        Description = "Discover any Divine+ Brainrot",
        Type = "RarityGroup",
        Target = {"Divine", "Celestial", "Cosmic", "Eternal", "Transcendent", "Infinite"},
        Reward = 10000000,
        ImageId = "rbxassetid://13583568864"
    }
}

return Achievements
