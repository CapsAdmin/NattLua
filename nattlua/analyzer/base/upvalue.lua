local class = require("nattlua.other.class")
local mutation_solver = require("nattlua.analyzer.mutation_solver")
local tostring = _G.tostring
local assert = _G.assert
local table_insert = _G.table.insert
local setmetatable = _G.setmetatable
local META = class.CreateTemplate("upvalue")
META:GetSet("Value")
META:GetSet("Key")
META:IsSet("Immutable")
META:GetSet("Position")
META:GetSet("Shadow")
META:GetSet("Scope")
META:GetSet("Mutations")
META:IsSet("FromForLoop")

function META:SetTruthyFalsyUnion(t, f)
	self.truthy_falsy_union = {truthy = t, falsy = f}
end

function META:GetTruthyFalsyUnion()
	return self.truthy_falsy_union
end

function META:__tostring()
	return "[" .. tostring(self.Scope) .. ":" .. tostring(self.Position) .. ":" .. tostring(self.key) .. ":" .. tostring(self.value) .. "]"
end

function META:GetHashForMutationTracking()
	return self
end

function META:SetValue(value)
	self.Value = value

	if not value then debug.trace() end

	value:SetUpvalue(self)
end

do
	function META:GetMutatedValue(scope)
		self.Mutations = self.Mutations or {}
		return mutation_solver(self.Mutations, scope, self)
	end

	function META:Mutate(val, scope, from_tracking)
		val:SetUpvalue(self)
		self.Mutations = self.Mutations or {}
		table_insert(self.Mutations, {scope = scope, value = val, from_tracking = from_tracking})

		if from_tracking then scope:AddTrackedObject(self) end
	end

	function META:ClearMutations()
		self.Mutations = false
	end

	function META:HasMutations()
		return self.Mutations ~= false
	end

	function META:ClearTrackedMutations()
		local mutations = self:GetMutations()

		for i = #mutations, 1, -1 do
			local mut = mutations[i]

			if mut.from_tracking then table.remove(mutations, i) end
		end
	end
end

local id = 0

function META.New(obj)
	local self = setmetatable(
		{
			Type = "upvalue",
			truthy_falsy_union = false,
			Value = false,
			Key = false,
			FromForLoop = false,
			Immutable = false,
			Shadow = false,
			Position = false,
			Scope = false,
			Mutations = false,
		},
		META
	)
	id = id + 1
	self:SetValue(obj)
	return self
end

return META
