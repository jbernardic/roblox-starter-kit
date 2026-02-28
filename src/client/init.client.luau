--[[
	Client Auto-Init

	Automatically discovers and initializes all controller modules in parallel.
	Fires a "ClientLoaded" event when all controllers are ready.

	Priority: Controllers with a .Priority number init in that order.
	Default priority is 100.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = require(ReplicatedStorage.Shared.Events)

local controllers: { { module: any, name: string, priority: number } } = {}

for _, child in script:GetChildren() do
	if child:IsA("ModuleScript") then
		local success, module = pcall(require, child)
		if success and type(module) == "table" and type(module.Init) == "function" then
			table.insert(controllers, {
				module = module,
				name = child.Name,
				priority = module.Priority or 100,
			})
		elseif not success then
			warn(`[Client] Failed to require {child.Name}: {module}`)
		end
	end
end

-- Sort by priority
table.sort(controllers, function(a, b)
	return a.priority < b.priority
end)

-- Init all controllers in parallel
local loadedCount = 0
local totalControllers = #controllers

for _, entry in controllers do
	task.spawn(function()
		entry.module.Init()
		loadedCount += 1

		if loadedCount == totalControllers then
			-- All controllers loaded - notify server
			Events.ClientLoaded:FireServer()

			print(`[Client] {totalControllers} controllers initialized`)
		end
	end)
end
