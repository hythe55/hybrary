--[[
Service to handle player data that does not need to be saved between sessions.
Has both client sided only support and server-client replication.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicationService = require(ReplicatedStorage.Services.ReplicationService)
local Table = require(ReplicatedStorage.Classes.Table)
local Signal = require(ReplicatedStorage.Classes.Signal)

local DataService = {}

local REMOTE_EVENT = script.Replicate

local TEMPLATE = Table.new(require(ReplicatedStorage.Config.DataTemplate))
local CLIENT_TEMPLATE = Table.new(require(ReplicatedStorage.Config.ClientDataTemplate))

local Data = {} --indexed by player on server or directly indexed on client
local ClientData = {} --only used on the client
local CreationSignal = Signal.new()

local function playerAdded(player: Player)
	Data[player] = TEMPLATE:Clone()
	ReplicationService:Create(Data[player], REMOTE_EVENT, player)
	CreationSignal:Fire()
end

local function init()
	if RunService:IsServer() then
		for i,v in Players:GetPlayers() do
			playerAdded(v)
		end
		Players.PlayerAdded:Connect(playerAdded)
		Players.PlayerRemoving:Connect(function(player)
			if not Data[player] then return end
			Data[player]:Destroy()
			Data[player] = nil
		end)
	else
		ClientData = CLIENT_TEMPLATE:Clone()
	end
end

--[[
Returns the data associated with the Player as a Table object.
Table.Changed will only fire on the server.
To detect changes on the client use Listen().
]]
function DataService:GetData(player: Player): Table.Table & typeof(TEMPLATE)
	if RunService:IsServer() then
		if not Data[player] then
			print("[DataService]: Waiting data for ".. player.Name)
			while true do
				CreationSignal:Wait()
				if Data[player] then break end
			end
		end
		return Data[player]
	else
		return ReplicationService:RequestData(script.Replicate)
	end
end

--[[
Get the local only data.
Table.Changed works for this method.
]]
function DataService:GetClientData(): Table.Table & typeof(CLIENT_TEMPLATE)
	assert(RunService:IsClient(), "Must be called on the client")
	return ClientData
end

--[[
Listens for changes to the server data associated to the LocalPlayer.
]]
function DataService:Listen(f: (data: Table.Table) -> ())
	assert(RunService:IsClient(), "Use GetData for the server")
	ReplicationService:Listen(REMOTE_EVENT, function(data)
		f(data)
	end)
end

if RunService:IsClient() then
	if not Table.Changed then
		data = Table.new(TEMPLATE)
	end
	ReplicationService:Listen(script.Replicate, function(data)
		Data = data
	end)
end

init()
return DataService