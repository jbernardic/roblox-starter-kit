--!strict
--[[
	Net - Networking abstraction that auto-creates RemoteEvents/RemoteFunctions

	Usage (shared/Events.luau):
		local Net = require(shared.Net)
		local Events = {}
		Events.WaveStart    = Net.CreateEvent("WaveStart")
		Events.ShopBuy      = Net.CreateEvent("ShopBuy")
		Events.GetInventory = Net.CreateFunction("GetInventory")
		return Events

	Usage (server):
		local Events = require(shared.Events)
		Events.WaveStart.FireClient(player, waveNumber)
		Events.ShopBuy.OnServer(function(player, itemName, price) end)
		Events.GetInventory.OnServerInvoke(function(player) return inventory end)

	Usage (client):
		local Events = require(shared.Events)
		Events.WaveStart.OnClient(function(waveNumber) end)
		Events.ShopBuy.FireServer("Zombie", 50)
		local inventory = Events.GetInventory.InvokeServer()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()

local Net = {}

local function getFolder(): Folder
	if IS_SERVER then
		local folder = ReplicatedStorage:FindFirstChild("NetEvents")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "NetEvents"
			folder.Parent = ReplicatedStorage
		end
		return folder :: Folder
	else
		return ReplicatedStorage:WaitForChild("NetEvents") :: Folder
	end
end

local function getRemoteEvent(name: string): RemoteEvent
	local folder = getFolder()
	if IS_SERVER then
		local remote = folder:FindFirstChild(name)
		if not remote then
			remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
		return remote :: RemoteEvent
	else
		return folder:WaitForChild(name) :: RemoteEvent
	end
end

local function getRemoteFunction(name: string): RemoteFunction
	local folder = getFolder()
	if IS_SERVER then
		local remote = folder:FindFirstChild(name)
		if not remote then
			remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
		return remote :: RemoteFunction
	else
		return folder:WaitForChild(name) :: RemoteFunction
	end
end

function Net.CreateEvent(name: string)
	local remote: RemoteEvent? = nil

	local function get(): RemoteEvent
		if not remote then
			remote = getRemoteEvent(name)
		end
		return remote :: RemoteEvent
	end

	return {
		FireClient = function(player: Player, ...: any)
			get():FireClient(player, ...)
		end,

		FireAllClients = function(...: any)
			get():FireAllClients(...)
		end,

		OnServer = function(callback: (player: Player, ...any) -> ()): RBXScriptConnection
			return get().OnServerEvent:Connect(callback)
		end,

		FireServer = function(...: any)
			get():FireServer(...)
		end,

		OnClient = function(callback: (...any) -> ()): RBXScriptConnection
			return get().OnClientEvent:Connect(callback)
		end,
	}
end

function Net.CreateFunction(name: string)
	local remote: RemoteFunction? = nil

	local function get(): RemoteFunction
		if not remote then
			remote = getRemoteFunction(name)
		end
		return remote :: RemoteFunction
	end

	return {
		OnServerInvoke = function(callback: (player: Player, ...any) -> ...any)
			get().OnServerInvoke = callback
		end,

		InvokeServer = function(...: any): ...any
			return get():InvokeServer(...)
		end,

		OnClientInvoke = function(callback: (...any) -> ...any)
			get().OnClientInvoke = callback
		end,
	}
end

return Net
