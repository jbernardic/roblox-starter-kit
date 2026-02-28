--[[
	Server Auto-Init

	Automatically discovers and initializes all service modules in this script.
	No more manually adding require lines when you create a new service.

	Priority: Services with a .Priority number init first (lower = earlier).
	Default priority is 100. Use this for services that others depend on:
		MyService.Priority = 1  -- inits before everything else

	Each service must export:
		{ Init: () -> (), Priority: number? }
]]

local services: { { module: any, name: string, priority: number } } = {}

for _, child in script:GetChildren() do
	if child:IsA("ModuleScript") then
		local success, module = pcall(require, child)
		if success and type(module) == "table" and type(module.Init) == "function" then
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
	local success, err = pcall(entry.module.Init)
	if not success then
		warn(`[Server] Failed to init {entry.name}: {err}`)
	end
end

print(`[Server] {#services} services initialized`)
