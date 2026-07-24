local class = require("nattlua.other.class")
local mutator = require("nattlua.analyzer.mutator")
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
	return "[" .. tostring(self.Scope) .. ":" .. tostring(self.Position) .. ":" .. (
			self.key and
			tostring(self.key) or
			"??"
		) .. ":" .. tostring(self:GetValue()) .. "]"
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
		self.mutator:Init()
		self.UseCount = self.UseCount + 1
		return self.mutator:Resolve(scope, self)
	end

	function META:Mutate(val, scope, from_tracking)
		val:SetUpvalue(self)
		local ok, err = self.mutator:Track{scope = scope, value = val, from_tracking = from_tracking}

		if from_tracking then scope:AddTrackedObject(self) end

		return ok, err
	end
end

local id = 0

function META.New(obj)
	local self = META.NewObject{
		Type = "upvalue",
		truthy_falsy_union = false,
		Value = false,
		Key = false,
		FromForLoop = false,
		Immutable = false,
		Shadow = false,
		Position = false,
		Scope = false,
		mutator = mutator.Linear(),
		UseCount = 0,
		RuntimeUseCount = 0,
		TypesystemUseCount = 0,
		statement = false,
	}
	id = id + 1
	self:SetValue(obj)
	return self
end

return META
