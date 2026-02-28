--!strict
--[[
	Panel - Generic UI panel controller

	Usage:
		local Panel = require(shared.Panel)

		local shopPanel = Panel.Create("UI_MobShop", {
			closeTag = "UI_MobShopClose",
			gamepadFocusTag = "UI_MobCash",
			onShow = function() end,
			onHide = function() end,
		})

		shopPanel.Show()
		shopPanel.Hide()
		shopPanel.Toggle()
		shopPanel.IsVisible() -- boolean
]]

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local TagManager = require(script.Parent.TagManager)

local Panel = {}

function Panel.Create(tag: string, config: {
	closeTag: string?,
	gamepadFocusTag: string?,
	onShow: (() -> ())?,
	onHide: (() -> ())?,
}?)
	config = config or {}

	local gui = TagManager.WaitForTagged(tag)[1] :: ScreenGui
	gui.Enabled = false

	local gamepadFocusTag = if config then config.gamepadFocusTag else nil
	local onShow = if config then config.onShow else nil
	local onHide = if config then config.onHide else nil

	local panel = {}

	function panel.Show()
		gui.Enabled = true

		if gamepadFocusTag and UserInputService.GamepadEnabled then
			local candidates = TagManager.GetTagged(gamepadFocusTag)
			if #candidates > 0 then
				local best: GuiObject = candidates[1] :: GuiObject
				for _, c in candidates do
					local obj = c :: GuiObject
					if obj.AbsolutePosition.Y < best.AbsolutePosition.Y then
						best = obj
					end
				end
				GuiService.SelectedObject = best
			end
		end

		if onShow then
			(onShow :: () -> ())()
		end
	end

	function panel.Hide()
		gui.Enabled = false
		GuiService.SelectedObject = nil

		if onHide then
			(onHide :: () -> ())()
		end
	end

	function panel.Toggle()
		if gui.Enabled then
			panel.Hide()
		else
			panel.Show()
		end
	end

	function panel.IsVisible(): boolean
		return gui.Enabled
	end

	-- Auto-wire close button
	local closeTag = if config then config.closeTag else nil
	if closeTag then
		local closeButtons = TagManager.GetTagged(closeTag)
		for _, btn in closeButtons do
			(btn :: GuiButton).Activated:Connect(panel.Hide)
		end
	end

	return panel
end

return Panel
