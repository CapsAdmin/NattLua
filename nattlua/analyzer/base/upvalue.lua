local class = require("nattlua.other.class")
local shallow_copy = require("nattlua.other.shallow_copy")
local mutation_solver = require("nattlua.analyzer.mutation_solver")
local META = class.CreateTemplate("upvalue")

function META:__tostring()
	return "[" .. tostring(self.key) .. ":" .. tostring(self.value) .. "]"
end

function META:GetValue()
	return self.value
end

function META:GetKey()
	return self.key
end

function META:SetValue(value)
	self.value = value
	value:SetUpvalue(self)
end

function META:SetImmutable(b)
	self.immutable = b
end

function META:IsImmutable()
	return self.immutable
end

function META:SetNode(node)
	self.Node = node
	return self
end

function META:GetNode()
	return self.Node
end

function META:GetHash()
	return self.hash
end

do
	function META:GetMutatedValue(scope)
		self.mutations = self.mutations or {}
		return mutation_solver(shallow_copy(self.mutations), scope, self)
	end

	function META:Mutate(val, scope, from_tracking)
		val:SetUpvalue(self)
		self.mutations = self.mutations or {}
		table.insert(self.mutations, {scope = scope, value = val, from_tracking = from_tracking})

		if from_tracking then scope:AddTrackedObject(self) end
	end

	function META:ClearMutations()
		self.mutations = nil
	end

	function META:HasMutations()
		return self.mutations ~= nil
	end
end

local id = 0

function META.New(obj)
	local self = setmetatable({}, META)
	self.hash = tostring(id)
	id = id + 1
	self:SetValue(obj)
	return self
end

return META