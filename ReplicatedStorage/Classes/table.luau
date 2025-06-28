--[[
v2 - 6/27/2025 2:46AM
written by hythe55 with some of the metatable stuff taken from xendatro
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Classes.Signal)
local table: typeof(require(ReplicatedStorage.Libraries.table)) = require(ReplicatedStorage.Libraries.table)
local Table = {}

--[[
Changed -> index, value, oldValue
for now all of these will be nil if :Clear() is called
]]

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
		__tonumber = function()
			print('tonumber')
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

function Table:Insert(value: any)
	assert(self ~= Table, "Method must be called on Table class")
	assert(value, "wrong number of arguments to 'Insert'")
	table.insert(self, value)
	--self.Changed:Fire(#self, value)
	self:_fireChangedForParents()
end

--[[When provided with a number behaves like table.remove while firing Table.Changed.
If no position is provided it will default to #Table.
If provided with a string it will first attempt to run Table:Find() and if no value is found it will attempt to locate an index with a matching name.]]
function Table:Remove(pos: number|string?)
	assert(self ~= Table, "Method must be called on Table class")
	pos = pos or #self
	local oldValue = rawget(self, pos)
	if not pos or typeof(pos) == "number" then
		table.remove(self, pos)
	elseif table.find(self, pos) then
		table.remove(self, table.find(self, pos))
	elseif oldValue then
		rawset(self, pos, nil)
	else
		error(pos.. " not found in Table")
	end

	--self.Changed:Fire(pos, nil, oldValue)
	self:_fireChangedForParents()
end

function Table:Clone()
	assert(self ~= Table, "Method must be called on Table class")
	return Table.new(table.clone(self.Raw))
end

function Table:Find<V>(needle: V, init: number?): number?
	assert(self ~= Table, "Method must be called on Table class")
	return table.find(self)
end

function Table:Freeze()
	assert(self ~= Table, "Method must be called on Table class")
	table.freeze(self)
	self.IsFrozen = true
end

function Table:Unpack(i: number?, j: number?)
	assert(self ~= Table, "Method must be called on Table class")
	return table.unpack(self, i, j)
end

function Table:Move(a: number, b: number, t: number, dst: {V}?)
	assert(self ~= Table, "Method must be called on Table class")
	return table.move(self, a, b, t, dst)
end

function Table:Sort<V>(comp: ((V, V) -> boolean)?)
	assert(self ~= Table, "Method must be called on Table class")
	return table.sort(self, comp)
end

function Table:Concact(sep: string?, i: number?, j: number?): string
	assert(self ~= Table, "Method must be called on Table class")
	return table.concat(self, sep, i, j)
end

--Makes the table printable and storable in DataStores.
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

--Returns the raw data stored inside of the Table.
function Table:GetEntries()
	return self.Raw
end

--[[Clears the table.]]
function Table:Clear()
	assert(self ~= Table, "Method must be called on Table class")
	table.clear(self.Raw)
	table.clear(self)
	--self.Changed:Fire()
	self:_fireChangedForParents()
end

--[[Clears the table and its events from memory.]]
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