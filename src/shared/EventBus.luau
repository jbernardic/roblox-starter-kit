--!strict
--[[
	EventBus - Decoupled pub/sub event system

	Usage:
		-- Subscribe
		local unsub = EventBus.Subscribe("EnemyKilled", function(player, mobType)
			print(player.Name, "killed", mobType)
		end)

		-- Publish
		EventBus.Publish("EnemyKilled", player, "Zombie")

		-- Unsubscribe
		unsub()
]]

local EventBus = {}

local subscribers: { [string]: { (...any) -> () } } = {}

function EventBus.Subscribe(eventName: string, callback: (...any) -> ()): () -> ()
	if not subscribers[eventName] then
		subscribers[eventName] = {}
	end

	table.insert(subscribers[eventName], callback)

	return function()
		EventBus.Unsubscribe(eventName, callback)
	end
end

function EventBus.Unsubscribe(eventName: string, callback: (...any) -> ())
	local subs = subscribers[eventName]
	if not subs then return end

	for i, sub in ipairs(subs) do
		if sub == callback then
			table.remove(subs, i)
			break
		end
	end

	if #subs == 0 then
		subscribers[eventName] = nil
	end
end

function EventBus.Publish(eventName: string, ...: any): { any }?
	local subs = subscribers[eventName]
	if not subs then return nil end

	local results = {}
	for _, callback in ipairs(subs) do
		local success, result = pcall(callback, ...)
		if success then
			table.insert(results, result)
		else
			warn(`[EventBus] Error in '{eventName}': {result}`)
		end
	end

	return results
end

function EventBus.Clear()
	table.clear(subscribers)
end

return EventBus
