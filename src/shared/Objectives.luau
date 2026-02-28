--!strict
--[[
	Objectives - Data-driven quest/tutorial system

	Instead of scattering tutorial checks across every service:
		-- In WaveService:
		if TutorialService.GetPlayerObjective(player) == "start_wave" then
			TutorialService.OnObjectiveComplete(player, "start_wave")
		end
		-- In MobService:
		if TutorialService.GetPlayerObjective(player) == "plant_egg" then
			TutorialService.OnObjectiveComplete(player, "plant_egg")
		end
		-- In LootService:
		if TutorialService.GetPlayerObjective(player) == "pickup_chest" then ...

	Define objectives in a config table, and the system auto-completes them
	by listening to EventBus events. Services stay clean - they just publish events.

	Setup:
		Objectives.Init({
			-- Each objective listens to an EventBus event and auto-completes
			{
				id = "buy_egg",
				event = "ShopBought",  -- EventBus event name
				filter = function(player, itemType)
					return itemType == "Egg"
				end,
				next = "plant_egg",  -- next objective id (nil = end of chain)
			},
			{
				id = "plant_egg",
				event = "MobPlaced",
				next = "hatch_egg",
			},
			{
				id = "hatch_egg",
				event = "EggHatched",
				next = "start_wave",
			},
			{
				id = "start_wave",
				event = "WaveStarted",
				next = "complete_wave",
			},
			{
				id = "complete_wave",
				event = "WaveCompleted",
				next = nil,  -- tutorial done
			},
		})

		-- Set starting objective for new players
		Objectives.SetObjective(player, "buy_egg")

	Querying:
		Objectives.GetObjective(player) --> "plant_egg" or nil
		Objectives.IsComplete(player, "buy_egg") --> true/false

	Events published (via EventBus):
		"ObjectiveCompleted" (player, objectiveId)
		"AllObjectivesCompleted" (player)
]]

local EventBus = require(script.Parent.EventBus)

local Objectives = {}

export type ObjectiveDef = {
	id: string,
	event: string,
	filter: ((Player, ...any) -> boolean)?,
	next: string?,
}

-- State
local objectiveDefs: { [string]: ObjectiveDef } = {} -- id -> def
local playerObjectives: { [number]: string? } = {} -- userId -> current objective id
local completedObjectives: { [number]: { [string]: boolean } } = {} -- userId -> set of completed ids
local subscriptions: { () -> () } = {} -- unsub functions

------------------------------------------------------------------------
-- Core API
------------------------------------------------------------------------

function Objectives.Init(defs: { ObjectiveDef })
	-- Clean up previous subscriptions (hot reload safe)
	for _, unsub in subscriptions do
		unsub()
	end
	table.clear(subscriptions)
	table.clear(objectiveDefs)

	-- Index definitions
	for _, def in defs do
		objectiveDefs[def.id] = def
	end

	-- Subscribe to each unique event
	local subscribedEvents: { [string]: boolean } = {}
	for _, def in defs do
		if not subscribedEvents[def.event] then
			subscribedEvents[def.event] = true

			local unsub = EventBus.Subscribe(def.event, function(player: Player, ...)
				if not player or typeof(player) ~= "Instance" then return end
				Objectives._onEvent(def.event, player, ...)
			end)
			table.insert(subscriptions, unsub)
		end
	end
end

function Objectives.SetObjective(player: Player, objectiveId: string)
	playerObjectives[player.UserId] = objectiveId
	if not completedObjectives[player.UserId] then
		completedObjectives[player.UserId] = {}
	end
end

function Objectives.GetObjective(player: Player): string?
	return playerObjectives[player.UserId]
end

function Objectives.IsComplete(player: Player, objectiveId: string): boolean
	local completed = completedObjectives[player.UserId]
	return completed ~= nil and completed[objectiveId] == true
end

function Objectives.CompleteObjective(player: Player, objectiveId: string)
	local def = objectiveDefs[objectiveId]
	if not def then
		warn(`[Objectives] Unknown objective: {objectiveId}`)
		return
	end

	-- Mark completed
	if not completedObjectives[player.UserId] then
		completedObjectives[player.UserId] = {}
	end
	completedObjectives[player.UserId][objectiveId] = true

	-- Publish completion
	EventBus.Publish("ObjectiveCompleted", player, objectiveId)

	-- Advance to next
	if def.next then
		playerObjectives[player.UserId] = def.next
	else
		playerObjectives[player.UserId] = nil
		EventBus.Publish("AllObjectivesCompleted", player)
	end
end

function Objectives.GetCompletedObjectives(player: Player): { string }
	local completed = completedObjectives[player.UserId]
	if not completed then return {} end

	local list = {}
	for id in completed do
		table.insert(list, id)
	end
	return list
end

function Objectives.Reset(player: Player)
	playerObjectives[player.UserId] = nil
	completedObjectives[player.UserId] = nil
end

function Objectives.Cleanup(player: Player)
	playerObjectives[player.UserId] = nil
	completedObjectives[player.UserId] = nil
end

------------------------------------------------------------------------
-- Internal
------------------------------------------------------------------------

function Objectives._onEvent(eventName: string, player: Player, ...: any)
	local currentId = playerObjectives[player.UserId]
	if not currentId then return end

	local def = objectiveDefs[currentId]
	if not def then return end
	if def.event ~= eventName then return end

	-- Check filter if provided
	if def.filter then
		local pass = (def.filter :: (Player, ...any) -> boolean)(player, ...)
		if not pass then return end
	end

	Objectives.CompleteObjective(player, currentId)
end

return Objectives
