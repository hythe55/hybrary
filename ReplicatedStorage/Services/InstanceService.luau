--[[
Service that provides utility methods for working with Roblox instances,
including property checking, visibility management, and descendant operations.
]]
local InstanceService = {}
local hiddenInstances = {}

--[[
Checks if an instance has a specific property.
]]
function InstanceService:HasProperty(instance: Instance, property: string): boolean
	local success, _ = pcall(function()
		return instance[property]
	end)
	return success
end

--[[
Hides all descendants of an instance by setting visibility properties and optionally collision.
]]
function InstanceService:HideDescendants(instance: Instance, changeCollision: boolean)
	--clean up any existing data for this instance
	if hiddenInstances[instance] then
		InstanceService:ShowDescendants(instance)
	end

	hiddenInstances[instance] = {
		cachedProperties = {},
		connections = {},
		changeCollision = changeCollision
	}

	local function hideDescendant(descendant)
		local cached = {}

		-- Handle transparency
		if InstanceService:HasProperty(descendant, "Transparency") then
			cached.Transparency = descendant.Transparency
			descendant.Transparency = 1
		end

		-- Handle visibility
		if InstanceService:HasProperty(descendant, "Visible") then
			cached.Visible = descendant.Visible
			descendant.Visible = false
		end

		-- Handle enabled state
		if InstanceService:HasProperty(descendant, "Enabled") then
			cached.Enabled = descendant.Enabled
			descendant.Enabled = false
		end

		-- Handle collision if requested
		if changeCollision and InstanceService:HasProperty(descendant, "CanCollide") then
			cached.CanCollide = descendant.CanCollide
			descendant.CanCollide = false
		end

		-- Store cached properties
		if next(cached) then
			hiddenInstances[instance].cachedProperties[descendant] = cached
		end
	end

	-- Hide existing descendants
	for _, descendant in pairs(instance:GetDescendants()) do
		hideDescendant(descendant)
	end

	-- Set up connections for new descendants and cleanup
	local descendantAddedConnection = instance.DescendantAdded:Connect(hideDescendant)
	local ancestryChangedConnection = instance.AncestryChanged:Connect(function()
		if not instance.Parent then
			InstanceService:ShowDescendants(instance)
		end
	end)

	hiddenInstances[instance].connections = {
		descendantAddedConnection,
		ancestryChangedConnection
	}
end

--[[
Shows all descendants of an instance by restoring cached visibility properties.
]]
function InstanceService:ShowDescendants(instance: Instance)
	local data = hiddenInstances[instance]
	if not data then return end

	for _, connection in data.connections do
		connection:Disconnect()
	end

	for descendant, cached in data.cachedProperties do
		if descendant.Parent then -- Check if descendant still exists
			for property, value in cached do
				if InstanceService:HasProperty(descendant, property) then
					descendant[property] = value
				end
			end
		end
	end

	hiddenInstances[instance] = nil
end

--[[
Sets a property value for all descendants that have that property.
]]
function InstanceService:SetDescendantsProperty(instance: Instance, property: string, value: any)
	for _, descendant in pairs(instance:GetDescendants()) do
		if InstanceService:HasProperty(descendant, property) then
			descendant[property] = value
		end
	end
end

return InstanceService