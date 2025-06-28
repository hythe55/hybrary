local RunService = game:GetService("RunService")
local IsServer = RunService:IsServer()

assert(IsServer, "Client side is not currently supported")

local DataSaveService = {}
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Table = require(ReplicatedStorage.Classes.Table)

if IsServer then
	assert(ServerStorage:FindFirstChild("Services"), "ProfileStore must be a child of ServerStorage.Services")
	assert(ServerStorage.Services:FindFirstChild("ProfileStore"), "ProfileStore must be a child of ServerStorage.Services")
end

local ProfileService = require(ServerStorage.Services.ProfileStore)
local Players = game:GetService("Players")

local ProfileTemplate: {}? = nil
local ProfileStore: ProfileService.ProfileStore? = nil
local ProfileName = "MAIN_PROFILE"
local ProfileKeyTemplate = "%s"
local Profiles: {[Player]: ProfileService.Profile} = {}
local silentMode = false
local p = print

script:SetAttribute("ProfileStoreCreated", false)

export type ProfileSignal = {
	Connect: (self: ProfileSignal, (player: Player) -> ()) -> RBXScriptConnection,
	Once: (self: ProfileSignal, (player: Player) -> ()) -> RBXScriptConnection,
	Wait: (self: ProfileSignal, (player: Player) -> ()) -> RBXScriptConnection,
	ConnectParallel: (self: ProfileSignal, (player: Player) -> ()) -> RBXScriptConnection
}

export type ProfileStore = ProfileService.ProfileStore
export type Profile = ProfileService.Profile

--Creates communication folder and remote events
local function startup()
	local communication = Instance.new("Folder")
	communication.Name = "Communication"
	communication.Parent = script
	local profileAdded = Instance.new("BindableEvent")
	profileAdded.Name = "ProfileAdded"
	profileAdded.Parent = communication
	local profileRemoving = Instance.new("BindableEvent")
	profileRemoving.Name = "ProfileRemoving"
	profileRemoving.Parent = communication
	local profileRemoved = Instance.new("BindableEvent")
	profileRemoved.Name = "ProfileRemoved"
	profileRemoved.Parent = communication
	local requestProfile = Instance.new("RemoteEvent")
	requestProfile.Name = "RequestProfile"
	requestProfile.Parent = communication
end

--Replaces default print behavior to include silent mode setting
local function print(...: any)
	if not silentMode then
		p(...)
	end
end

--[[Enables or disables prints coming from DataSaveService.
Errors and warnings will always be turned on.]]
function DataSaveService:SetSilentMode(enabled: boolean?)
	silentMode = enabled or false
end

--[[Waits for a profile to be loaded.
Returns nil if player leaves before the profile is loaded.]]
function DataSaveService:WaitForProfile(player: Player): Profile?
	assert(IsServer, "DataSaveService:WaitForProfile() can only be called from the server.")
	if not Players:FindFirstChild(player.Name) then
		return
	end
	local playerLeft = false
	local connection = Players.PlayerRemoving:Connect(function(playerLeaving)
		if playerLeaving == player then
			playerLeft = true
		end
	end)
	while not DataSaveService:GetProfile(player) do
		task.wait(0.1) --disgusting but i can't think of another way to do this right now
		if playerLeft then
			break
		end
	end
	connection:Disconnect()
	return DataSaveService:GetProfile(player)
end

--[[Returns the profile key for the given userId.]]
function DataSaveService:GetProfileKey(userId: number): string
	assert(IsServer, "DataSaveService:GetProfileKey() can only be called from the server.")
	return string.format(ProfileKeyTemplate, userId)
end

--[[Returns the profile store.
Yields until DataSaveService:CreateProfileStore() is called.]]
function DataSaveService:GetProfileStore(): ProfileService.ProfileStore
	assert(IsServer, "DataSaveService:GetProfileStore() can only be called from the server.")
	if script:GetAttribute("ProfileStoreCreated") == false then
		script:GetAttributeChangedSignal("ProfileStoreCreated"):Wait()
	end
	return ProfileStore
end

--[[Returns a dictionary of all profiles with <strong>player</strong> being used as the key.]]
function DataSaveService:GetProfiles(): {[Player]: Profile}
	assert(IsServer, "DataSaveService:GetProfiles() can only be called from the server.")
	return Profiles
end

--[[Returns the Profile for <strong>player</strong>
Returns nil if no Profile is found]]
function DataSaveService:GetProfile(player: Player): Profile?
	assert(player:IsA("Player"), "player must be a Player.")
	if IsServer then
		return Profiles[player]
	else
		script.Communication.RequestProfile:FireServer()
		script.Communication.RequestProfile.OnClientEvent:Once(function(profile: Profile)
			return profile
		end)
	end
end

--[[Sets the template the Profile will use.]]
function DataSaveService:SetTemplate(template: {any})
	assert(IsServer, "DataSaveService:SetTemplate() can only be called from the server.")
	assert(typeof(template) == "table", "Template must be a table.")
	ProfileTemplate = template
end

--[[Returns the template Profiles use.]]
function DataSaveService:GetTemplate(): {any}
	assert(ProfileTemplate, "Profile template has not been created.")
	return ProfileTemplate
end

--[[Adds a dictionary into the ProfileTemplate.
The location should be seperated using peroids.
If only the index name is provided in <strong>location</strong> the value with be placed directly into Template.
More information can be found on the documentation.]]
function DataSaveService:AddToTemplate(location: string, value: any)
	assert(IsServer, "DataSaveService:AddToTemplate() can only be called from the server.")
	assert(ProfileTemplate, "Default Profile template must first be created.")
	local currentLocation = ProfileTemplate
	for i,v in string.split(location, ".") do
		if currentLocation[v] then
			currentLocation = currentLocation[v]
			continue
		else
			currentLocation[v] = value
			for i, profile in DataSaveService:GetProfiles() do
				profile:Reconcile()
			end
			return
		end
	end
	error("Attempted to replace existing location.")
end

--[[Sets the name of the ProfileStore.
Must be called before DataSaveService:CreateProfileStore.
Defaults to <strong>MAIN_PROFILE</strong>.]]
function DataSaveService:SetProfileStoreName(storeName: string)
	assert(IsServer, "DataSaveService:SetProfileStoreName() can only be called from the server.")
	assert(typeof(storeName) == "string", "storeName must be a string.")
	assert(ProfileStore, "DataSaveService:SetProfileStoreName must be called before DataSaveService:CreateProfileStore().")
	ProfileName = storeName
end

--[[Sets the template for Profile keys to use.
Must include <strong>%s</strong>.
<strong>%s</strong> will be replaced by the player's UserId.]]
function DataSaveService:SetProfileKeyTemplate(keyTemplate: string)
	assert(IsServer, "DataSaveService:SetProfileKeyTemplate() can only be called from the server.")
	assert(ProfileStore, "ProfileKeyTemplate must be set DataSaveService:CreateProfileStore() is called.")
	assert(typeof(keyTemplate) == "string", "keyTemplate must be a string.")
	assert(string.find(keyTemplate, "%s"), "keyTemplate must contain '%s'.")
	ProfileKeyTemplate = keyTemplate
end

--[[Starts the module and automatically loads profiles.]]
function DataSaveService:CreateProfileStore(): ProfileService.ProfileStore
	assert(IsServer, "DataSaveService:CreateProfileStore() can only be called from the server.")
	assert(ProfileTemplate, "Profile template has not be set using DataSaveService:SetTemplate().")
	assert(not ProfileStore, "DataSave has already been created.")
	ProfileStore = ProfileService.New(ProfileName, ProfileTemplate)
	local function loadProfile(player: Player)
		local profile = ProfileStore:StartSessionAsync(DataSaveService:GetProfileKey(player.UserId), {
			Cancel = function()
				return player.Parent ~= Players
			end,
		})

		if profile then
			profile:AddUserId(player.UserId)
			profile:Reconcile()
			
			profile.Data = Table.new(profile.Data)
			
			profile.OnSessionEnd:Connect(function()
				if DataSaveService:GetProfile(player) then
					Profiles[player] = nil
					script.Communication.ProfileRemoving:Fire(player)
					Profiles[player]:EndSession()
					script.Communication.ProfileRemoved:Fire(player)
					print("Profile session ended for ".. player.DisplayName.. ".")
					player:Kick("Profile session ended - Please rejoin.")
				end
			end)

			if Players:FindFirstChild(player.Name) then
				Profiles[player] = profile
				print("Profile loaded for ".. player.DisplayName.. ".")
				script.Communication.ProfileAdded:Fire(player)
			else
				--Player left before Profile loaded.
				profile:EndSession()
			end
		else
			--Profile failed to load (probably server shutdown)
			player:Kick("Profile failed to load - Please rejoin.")
		end
	end
	local function removeProfile(player: Player)
		local profile = DataSaveService:GetProfile(player)
		if profile then
			Profiles[player] = nil
			script.Communication.ProfileRemoving:Fire(player)
			profile:EndSession()
			print("Profile session ended for ".. player.DisplayName.. ".")
			script.Communication.ProfileRemoved:Fire(player)
		end
	end

	for i, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end
	Players.PlayerAdded:Connect(function(player)
		loadProfile(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		removeProfile(player)
	end)
	
	script:SetAttribute("ProfileStoreCreated", true)
end

--[[If the player's most recent save falls within the times given their Profile will revert to closest save to <strong>revertTime</strong> that falls before the time given in <strong>revertTime</strong>.]]
--[[function DataSaveService:RevertProfile(startTime: number, endTime: number, revertTime: number)
	--will just do this whenever i feel its needed
end]]

startup()

if IsServer then
	script.Communication.RequestProfile.OnServerEvent:Connect(function(player: Player)
		return DataSaveService:GetProfile(player)
	end)
end

DataSaveService.ProfileAdded = script.Communication.ProfileAdded.Event:: ProfileSignal
DataSaveService.ProfileRemoving = script.Communication.ProfileRemoving.Event:: ProfileSignal
DataSaveService.ProfileRemoved = script.Communication.ProfileRemoved.Event:: ProfileSignal

return DataSaveService