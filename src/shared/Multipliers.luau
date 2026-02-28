--!strict
--[[
	Multipliers - Centralized multiplier stack

	Instead of manually chaining multiplier checks in MobService:
		currency *= FriendBonusService.GetFactor(player)
		if VipService.HasStatus(player) then currency *= 1.5 end
		currency *= CashMultiplierService.GetMultiplier(player)
		currency *= petCashMult

	Register each source once and query the combined result:
		Multipliers.Get(player, "Cash") --> single combined number

	Setup (each service registers its own source on Init):
		-- In VipService.Init():
		Multipliers.Register("Cash", "VIP", function(player)
			return if VipService.HasStatus(player) then 1.5 else 1
		end)

		-- In FriendBonusService.Init():
		Multipliers.Register("Cash", "FriendBonus", function(player)
			return getFriendBonusFactor(player)
		end)

		-- In PetService.Init():
		Multipliers.Register("Health", "Pet", function(player)
			return getPetHealthMult(player)
		end)
		Multipliers.Register("Damage", "Pet", function(player)
			return getPetDamageMult(player)
		end)

	Usage (in MobService or anywhere):
		local cashDrop = baseDrop * Multipliers.Get(player, "Cash")
		local health = baseHealth * Multipliers.Get(player, "Health")
]]

local Multipliers = {}

type MultiplierSource = {
	name: string,
	getter: (Player) -> number,
}

-- category -> list of sources
local sources: { [string]: { MultiplierSource } } = {}

function Multipliers.Register(category: string, name: string, getter: (Player) -> number)
	if not sources[category] then
		sources[category] = {}
	end

	-- Prevent duplicate registration
	for _, source in sources[category] do
		if source.name == name then
			source.getter = getter
			return
		end
	end

	table.insert(sources[category], {
		name = name,
		getter = getter,
	})
end

function Multipliers.Unregister(category: string, name: string)
	local list = sources[category]
	if not list then return end

	for i, source in list do
		if source.name == name then
			table.remove(list, i)
			return
		end
	end
end

function Multipliers.Get(player: Player, category: string): number
	local list = sources[category]
	if not list then return 1 end

	local combined = 1
	for _, source in list do
		local success, result = pcall(source.getter, player)
		if success then
			combined *= result
		else
			warn(`[Multipliers] Error in '{category}/{source.name}': {result}`)
		end
	end

	return combined
end

function Multipliers.GetBreakdown(player: Player, category: string): { [string]: number }
	local list = sources[category]
	if not list then return {} end

	local breakdown = {}
	for _, source in list do
		local success, result = pcall(source.getter, player)
		if success then
			breakdown[source.name] = result
		end
	end

	return breakdown
end

function Multipliers.GetCategories(): { string }
	local cats = {}
	for category in sources do
		table.insert(cats, category)
	end
	return cats
end

return Multipliers
