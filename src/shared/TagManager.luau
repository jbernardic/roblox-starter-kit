--!strict
--[[
	TagManager - CollectionService wrapper with filtering and waiting

	Usage:
		-- Get all instances with a tag (filters out StarterGui on client)
		local mobs = TagManager.GetTagged("Mob")

		-- Get tagged instances under a specific ancestor
		local buttons = TagManager.GetTagged("UI_BuyBtn", shopPanel)

		-- Wait until at least 1 instance exists
		local panels = TagManager.WaitForTagged("UI_Shop")

		-- React to current + future tagged instances
		TagManager.OnTaggedInstance("ShopPrompt", function(prompt)
			prompt.Triggered:Connect(onTriggered)
		end)
]]

local CollectionService = game:GetService("CollectionService")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")

local TagManager = {}

function TagManager.GetTagged(tag: string, ancestor: Instance?): { Instance }
	local tagged = CollectionService:GetTagged(tag)
	local filtered = {}

	for _, instance in tagged do
		if RunService:IsClient() and instance:IsDescendantOf(StarterGui) then
			continue
		end
		if ancestor and not instance:IsDescendantOf(ancestor) then
			continue
		end
		table.insert(filtered, instance)
	end

	return filtered
end

function TagManager.WaitForTagged(tag: string, minCount: number?, parent: Instance?): { Instance }
	minCount = minCount or 1

	local elapsed = 0
	local warned = false

	while true do
		local current = TagManager.GetTagged(tag, parent)
		if #current >= (minCount :: number) then
			return current
		end

		task.wait(0.1)
		elapsed += 0.1
		if not warned and elapsed >= 5 then
			warn(`[TagManager] Possible infinite yield on WaitForTagged for tag '{tag}'`)
			warned = true
		end
	end
end

function TagManager.OnTaggedInstance(tag: string, callback: (Instance) -> ())
	for _, instance in TagManager.GetTagged(tag) do
		task.spawn(callback, instance)
	end

	CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
		if not instance:IsDescendantOf(StarterGui) then
			callback(instance)
		end
	end)
end

function TagManager.AddTag(instance: Instance, tag: string)
	CollectionService:AddTag(instance, tag)
end

function TagManager.RemoveTag(instance: Instance, tag: string)
	CollectionService:RemoveTag(instance, tag)
end

function TagManager.HasTag(instance: Instance, tag: string): boolean
	return CollectionService:HasTag(instance, tag)
end

return TagManager
