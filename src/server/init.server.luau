--[[
	Server Auto-Init

	Automatically discovers and initializes all service modules in this script.
	No more manually adding require lines when you create a new service.

	Discovery: Any ModuleScript whose name contains "Service" is treated as a service.

	Priority: Services with a .Priority number init first (lower = earlier).
	Default priority is 100. Use this for services that others depend on:
		MyService.Priority = 1  -- inits before everything else

	Each service may export:
		{ Init: (() -> ())?, PlayerInit: ((Player) -> ())?, Priority: number? }

	PlayerInit is called for each player in priority order, both on join and for
	players already in-game when the server starts. Each player runs concurrently,
	but services are called sequentially per player so higher-priority services
	(e.g. data loading) finish before lower-priority ones run.
]]

local Players = game:GetService("Players")

local services: { { module: any, name: string, priority: number } } = {}

for _, child in script:GetChildren() do
	if child:IsA("ModuleScript") and string.find(child.Name, "Service") then
		local success, module = pcall(require, child)
		if success and type(module) == "table" then
			table.insert(services, {
				module = module,
				name = child.Name,
				priority = module.Priority or 100,
			})
		elseif not success then
			warn(`[Server] Failed to require {child.Name}: {module}`)
		end
	end
end

-- Sort by priority (lower = first)
table.sort(services, function(a, b)
	return a.priority < b.priority
end)

-- Init sequentially in priority order
for _, entry in services do
	if type(entry.module.Init) == "function" then
		local success, err = pcall(entry.module.Init)
		if not success then
			warn(`[Server] Failed to init {entry.name}: {err}`)
		end
	end
end

-- Call PlayerInit on all services in priority order for a given player
local function onPlayerAdded(player: Player)
	for _, entry in services do
		if not player:IsDescendantOf(Players) then break end
		if type(entry.module.PlayerInit) == "function" then
			local success, err = pcall(entry.module.PlayerInit, player)
			if not success then
				warn(`[Server] {entry.name}.PlayerInit failed for {player.Name}: {err}`)
			end
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(onPlayerAdded, player)
end)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

print(`[Server] {#services} services initialized`)
