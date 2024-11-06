--[[
Automatically extends all CollectionService methods and adds new ones.
]]

local _CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local extender = require(ReplicatedStorage.Modules.extender)

local CollectionService = {}

--[[
Private function used for GetTaggedChildren and GetTaggedDescendants.
]]
local function _getTaggedChildren(ancestor: Instance, tag: string, recursive: boolean?)
	local objs: {Instance} = {}
	if recursive then
		objs = ancestor:GetDescendants()
	else
		objs = ancestor:GetChildren()
	end

	local tagged = {}
	for i,v in objs do
		if v:HasTag(tag) then
			table.insert(tagged, v)
		end
	end
	return tagged:: {Instance}
end

--[[
Returns the first child with the given tag.
tag: The tag to search for.
ancestor: The Ancestor instance to search.
recursive: Should descendants be searched?
]]
function CollectionService:FindFirstChildWithTag(tag: string, ancestor: Instance, recursive: boolean?): Instance?
	if not ancestor then 
		ancestor = workspace
	end
	
	local objectToReturn
	for _, object in ipairs(_CollectionService:GetTagged(tag)) do
		if object:IsDescendantOf(ancestor) then
			if recursive or object.Parent == ancestor then
				assert(not objectToReturn, "Multiple objects with tag ".. tag.. " found in ".. ancestor.Name.. "!")
				objectToReturn = object
			end
		end
	end
	return objectToReturn
end

--[[
Returns an array containing all of the instance's children with the tag.
]]
function CollectionService:GetTaggedChildren(parent: Instance, tag: string): {Instance}
	return _getTaggedChildren(parent, tag)
end
--[[
Returns an array containing all of the instance's descendants with the tag.
]]
function CollectionService:GetTaggedDescendants(ancestor: Instance, tag: string): {Instance}
	return _getTaggedChildren(ancestor, tag, true)
end

extender(CollectionService, script, _CollectionService)

return CollectionService:: typeof(CollectionService) & typeof(_CollectionService)
