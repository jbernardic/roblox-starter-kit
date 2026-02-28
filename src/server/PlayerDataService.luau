--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProfileStore = require(ReplicatedStorage.Shared.ProfileStore)

local PlayerDataService = {}
PlayerDataService.Priority = 1

local STORE_NAME = "PlayerData"

export type PlayerData = {
	currency: number,
}

local template: PlayerData = {
	currency = 10,
}

local store = ProfileStore.New(STORE_NAME, template)
local profiles: { [number]: typeof(store:GetAsync("")) } = {} -- userId -> profile

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------

-- Returns profile.Data for the player, or nil if not yet loaded.
function PlayerDataService.Get(player: Player): PlayerData?
	local profile = profiles[player.UserId]
	return if profile ~= nil then profile.Data else nil
end

-- Returns the raw Profile object (for advanced use: OnSave, EndSession, etc.)
function PlayerDataService.GetProfile(player: Player)
	return profiles[player.UserId]
end

function PlayerDataService.IsLoaded(player: Player): boolean
	return profiles[player.UserId] ~= nil
end

------------------------------------------------------------------------
-- Init / PlayerInit
------------------------------------------------------------------------

function PlayerDataService.Init()
	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player.UserId]
		if profile then
			profile:EndSession()
			profiles[player.UserId] = nil
		end
	end)
end

function PlayerDataService.PlayerInit(player: Player)
	local profile = store:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return not player:IsDescendantOf(Players)
		end,
	})

	if profile == nil or not player:IsDescendantOf(Players) then
		player:Kick("Failed to load data. Please rejoin.")
		return
	end

	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		profiles[player.UserId] = nil
		player:Kick("Your session ended. Please rejoin.")
	end)

	profiles[player.UserId] = profile
end

return PlayerDataService
