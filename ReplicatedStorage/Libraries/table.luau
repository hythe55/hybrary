local ReplicatedStorage = game:GetService("ReplicatedStorage")
local extend = require(ReplicatedStorage.Modules.extend)
local _table = table
local table = {}

extend(table, _table)

--Returns the index associated with <strong>value</strong> in nested tables if found.
function table.deepsearch<V>(t: {V}, value: any): string?
	for key, v in t do
		if v == value then
			return key
		elseif typeof(v) == "table" then
			local found = table.deepsearch(v, value)
			if found ~= nil then
				return found
			end
		end
	end
	return nil
end

--[[Returns the path associated with <strong>value</strong> in nested tables if found as a table.

Do not use <strong>path</strong>.]]
function table.findpath<V>(t: {V}, value: any, path: {}?): {string}?
	path = path or {}

	for key, v in t do
		local currentPath = { unpack(path) }
		table.insert(currentPath, key)

		if v == value then
			return currentPath
		elseif typeof(v) == "table" then
			local result = table.findpath(v, value, currentPath)
			if result then
				return result
			end
		end
	end

	return nil
end

function table.isdifferent<V>(t1: {V}, t2: {V}): boolean
	if t1 == t2 then
		return false
	end

	for key, value in t1 do
		local otherValue = t2[key]

		if typeof(value) == "table" and typeof(otherValue) == "table" then
			if table.isdifferent(value, otherValue) then
				return true
			end
		elseif value ~= otherValue then
			return true
		end
	end

	-- Also check if t2 has extra keys not in t1
	for key in t2 do
		if t1[key] == nil then
			return true
		end
	end

	return false
end


return table:: typeof(_table) & typeof(table)