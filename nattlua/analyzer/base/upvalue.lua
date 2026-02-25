local class = require("nattlua.other.class")
local mutation_solver = require("nattlua.analyzer.mutation_solver")
local error_messages = require("nattlua.error_messages")
local tostring = _G.tostring
local assert = _G.assert
local table_insert = _G.table.insert
local table_remove = _G.table.remove
local setmetatable = _G.setmetatable
local META = class.CreateTemplate("upvalue")
META:GetSet("Value")
META:GetSet("Key")
META:IsSet("Immutable")
META:GetSet("Position")
META:GetSet("Shadow")
META:GetSet("Scope")
META:GetSet("Mutations")
META:GetSet("UseCount", 0)
META:GetSet("RuntimeUseCount", 0)
META:GetSet("TypesystemUseCount", 0)
META:GetSet("Identifier")
META:IsSet("FromForLoop")

function META:SetTruthyFalsyUnion(t, f)
	self.truthy_falsy_union = {truthy = t, falsy = f}
end

function META:GetTruthyFalsyUnion()
	return self.truthy_falsy_union
end

function META:__tostring()
	return "[" .. tostring(self.Scope) .. ":" .. tostring(self.Position) .. ":" .. (self.key and tostring(self.key) or "??") .. ":" .. tostring(self:GetValue()) .. "]"
end

function META:GetHashForMutationTracking()
	return self
end

function META:GetHash()
	return self
end

local context = require("nattlua.analyzer.context")

local function increment_use_count(self)
	self.UseCount = self.UseCount + 1

	local analyzer = context:GetCurrentAnalyzer()

	if analyzer then
		local env = analyzer:GetCurrentAnalyzerEnvironment()

		if env == "runtime" then
			self.RuntimeUseCount = self.RuntimeUseCount + 1
		elseif env == "typesystem" then
			self.TypesystemUseCount = self.TypesystemUseCount + 1
		end
	end
end

function META:GetValue()
	increment_use_count(self)
	return self.Value
end

do
	function META:GetMutatedValue(scope)
		self.Mutations = self.Mutations or {}
		self.UseCount = self.UseCount + 1
		return mutation_solver(self.Mutations, scope, self)
	end

	function META:Mutate(val, scope, from_tracking)
		val:SetUpvalue(self)
		self.Mutations = self.Mutations or {}

		if self.Mutations[100] then return false, error_messages.too_many_mutations() end

		table_insert(self.Mutations, {scope = scope, value = val, from_tracking = from_tracking})

		if from_tracking then scope:AddTrackedObject(self) end

		return true
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

			if mut.from_tracking then table_remove(mutations, i) end
		end
	end
end

local id = 0

function META.New(obj)
	local self = META.NewObject(
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
			UseCount = 0,
			RuntimeUseCount = 0,
			TypesystemUseCount = 0,
			statement = false,
		}
	)
	id = id + 1
	self:SetValue(obj)
	return self
end

return META
