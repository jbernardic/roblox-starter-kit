--!strict
--[[
	Net - Auto-creates RemoteEvents/RemoteFunctions and returns the actual instances.

	Usage (shared/Events.luau):
		local Net = require(ReplicatedStorage.Shared.Net)
		local Events = {}
		Events.WaveStart    = Net.CreateEvent("WaveStart")
		Events.GetInventory = Net.CreateFunction("GetInventory")
		return Events

	Usage (server):
		local Events = require(ReplicatedStorage.Shared.Events)
		Events.WaveStart:FireClient(player, waveNumber)
		Events.WaveStart.OnServerEvent:Connect(function(player, ...) end)
		Events.GetInventory.OnServerInvoke = function(player) return inventory end

	Usage (client):
		local Events = require(ReplicatedStorage.Shared.Events)
		Events.WaveStart.OnClientEvent:Connect(function(waveNumber) end)
		Events.WaveStart:FireServer(waveNumber)
		local inventory = Events.GetInventory:InvokeServer()
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

function Net.CreateEvent(name: string): RemoteEvent
	local folder = getFolder()
	if IS_SERVER then
		local existing = folder:FindFirstChild(name)
		if existing then
			return existing :: RemoteEvent
		end
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		return remote
	else
		return folder:WaitForChild(name) :: RemoteEvent
	end
end

function Net.CreateFunction(name: string): RemoteFunction
	local folder = getFolder()
	if IS_SERVER then
		local existing = folder:FindFirstChild(name)
		if existing then
			return existing :: RemoteFunction
		end
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
		return remote
	else
		return folder:WaitForChild(name) :: RemoteFunction
	end
end

return Net
