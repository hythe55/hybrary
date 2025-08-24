--[[
Class that provides an enhanced table wrapper with change tracking,
recursive nesting support, and additional utility methods.
v2.3 - 8/23/2025 11:29PM
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Classes.Signal)
local table: typeof(require(ReplicatedStorage.Libraries.table)) = require(ReplicatedStorage.Libraries.table)
local Table = {}

export type Table = {
	Changed: typeof(Signal.new()),
	IsFrozen: boolean,
	Raw: {any},
	Parent: Table?,

	Insert: <V>(self: V, value: any) -> (),
	Remove: <V>(self: V, pos: number|string?) -> (),
	Clone: <V>(self: V) -> V,
	Find: <V>(self: V, needle: V, init: number?) -> string,
	Freeze: <V>(self: V) -> (),
	Unpack: <V>(self: V, i: number?, j: number?) -> ...V,
	Move: <V>(self: V, a: number, b: number, t: number, dst: {V}?) -> (),
	Sort: <V>(self: V, comp:((V, V) -> boolean)?) -> (),
	Concact: <V>(self: V, sep: string?, i: number?, j: number?) -> string,
	Serialize: <V>(self: V) -> ({any}),
	GetEntries: <V>(self: V) -> V,
	Clear: <V>(self: V) -> (),

	Destroy: <V>(self: V) -> (),
}

local Properties = {}

--[[
Creates a new instance of the Table class with optional initial data and parent.
]]
function Table.new<T>(t: T?, parent: Table?): Table & T
	local self = {}
	self.Changed = Signal.new()
	self.IsFrozen = false
	self.Raw = t
	self.Parent = parent

	local previous = table.clone(t)

	local mt = {
		__index = function(t, i)
			return Table[i] or self.Raw[i]        
		end,
		__newindex = function(t, i, v)
			local oldTab = table.clone(self.Raw)
			self.Raw[i] = v
			if table.isdifferent(self.Raw, oldTab) then
				--self.Changed:Fire()
				self:_fireChangedForParents()
			end
		end,
		__iter = function(t)
			return next, t.Raw
		end,
		__len = function(t)
			local amount = 0
			for i,v in t.Raw do
				amount += 1
			end
			return amount
		end,
	}

	setmetatable(self, mt)

	local function wrapRecursive(t)
		local out = {}
		for k, v in t do
			out[k] = typeof(v) == "table" and Table.new(v, self) or v
		end
		return out
	end

	self.Raw = wrapRecursive(t or {})
	return self
end

--[[
Inserts a value at the end of the table and fires change events.
]]
function Table:Insert(value: any)
	assert(self ~= Table, "Method must be called on Table class")
	assert(value, "wrong number of arguments to 'Insert'")
	table.insert(self.Raw, value)
	--self.Changed:Fire(#self, value)
	self:_fireChangedForParents()
end

--[[
Removes an item from the table by position or value and fires change events.
]]
function Table:Remove(pos: number|string?)
	assert(self ~= Table, "Method must be called on Table class")
	pos = pos or #self
	local oldValue = rawget(self, pos)
	if not pos or typeof(pos) == "number" then
		table.remove(self.Raw, pos)
	elseif table.find(self.Raw, pos) then
		table.remove(self.Raw, table.find(self, pos))
	elseif oldValue then
		rawset(self.Raw, pos, nil)
	else
		error(pos.. " not found in Table")
	end

	--self.Changed:Fire(pos, nil, oldValue)
	self:_fireChangedForParents()
end

--[[
Creates a deep copy of the table with all nested tables preserved.
]]
function Table:Clone()
	assert(self ~= Table, "Method must be called on Table class")
	return Table.new(table.clone(self.Raw))
end

--[[
Searches for a value in the table and returns its index position.
]]
function Table:Find<V>(needle: V, init: number?): number?
	assert(self ~= Table, "Method must be called on Table class")
	return table.find(self.Raw, needle, init)
end

--[[
Freezes the table to prevent further modifications.
]]
function Table:Freeze()
	assert(self ~= Table, "Method must be called on Table class")
	table.freeze(self)
	table.freeze(self.Raw)
	self.IsFrozen = true
end

--[[
Returns all values from the table as separate return values.
]]
function Table:Unpack(i: number?, j: number?)
	assert(self ~= Table, "Method must be called on Table class")
	return table.unpack(self.Raw, i, j)
end

--[[
Moves elements from one part of the table to another position.
]]
function Table:Move(a: number, b: number, t: number, dst: {V}?)
	assert(self ~= Table, "Method must be called on Table class")
	return table.move(self.Raw, a, b, t, dst)
end

--[[
Sorts the table elements using an optional comparison function.
]]
function Table:Sort<V>(comp: ((V, V) -> boolean)?)
	assert(self ~= Table, "Method must be called on Table class")
	return table.sort(self.Raw, comp)
end

--[[
Concatenates table elements into a string with optional separator.
]]
function Table:Concact(sep: string?, i: number?, j: number?): string
	assert(self ~= Table, "Method must be called on Table class")
	return table.concat(self.Raw, sep, i, j)
end

--[[
Converts the table to a plain Lua table for storage or transmission.
]]
function Table:Serialize()
	local function unwrap(value)
		if typeof(value) == "table" then
			local mt = getmetatable(value)
			if mt and mt.__index == Table then
				return unwrap(value.Raw)
			else
				local result = {}
				for k, v in value do
					result[k] = unwrap(v)
				end
				return result
			end
		else
			return value
		end
	end
	return unwrap(self.Raw)
end

--[[
Returns the raw table data without the Table wrapper.
]]
function Table:GetEntries()
	return self.Raw
end

--[[
Removes all elements from the table and fires change events.
]]
function Table:Clear()
	assert(self ~= Table, "Method must be called on Table class")
	table.clear(self.Raw)
	table.clear(self)
	--self.Changed:Fire()
	self:_fireChangedForParents()
end

--[[
Disconnects all connections of the Table and returns it to a raw table.
]]
function Table:ClearConnections()
	assert(self ~= Table, "Method must be called on Table class")

	local function loop(t)
		for i,v in t do
			if typeof(v) == "table" then
				loop(v)
			elseif typeof(t) == "Instance" then
				t:Destroy()
			end
		end
	end
	loop(self)
end

--[[
Destroys the table instance and cleans up all nested tables and events.
]]
function Table:Destroy()
	assert(self ~= Table, "Method must be called on Table class")

	for k, v in pairs(self.Raw) do
		if typeof(v) == "table" then
			local mt = getmetatable(v)
			if mt and mt.__index == Table then
				v:Destroy()
			end
		end
	end
	if self.Changed and typeof(self.Changed.Destroy) == "function" then
		self.Changed:Destroy()
	end
	table.clear(self.Raw)
	table.clear(self)
	setmetatable(self, nil)
end

function Table:_fireChangedForParents()
	local function run(t: Table)
		t.Changed:Fire()
		if t.Parent then
			run(t.Parent)
		end
	end
	self.Changed:Fire()
	if self.Parent then
		run(self.Parent)
	end
end

table.freeze(Table)
return Table:: {
	new: <T>(t: T?) -> Table & T
}
