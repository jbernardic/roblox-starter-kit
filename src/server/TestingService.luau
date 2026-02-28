local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProfileStore = require(ReplicatedStorage.Shared.ProfileStore)
local EventBus = require(ReplicatedStorage.Shared.EventBus)
local PlayerDataService = require(script.Parent.PlayerDataService)
local TestingService = {}


function TestingService.Init()
    EventBus.Subscribe("PlayerDataLoaded", function(player)
        print(PlayerDataService.Get(player).currency)
    end)
end

return TestingService