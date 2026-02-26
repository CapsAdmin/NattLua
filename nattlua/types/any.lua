local setmetatable = _G.setmetatable
local error_messages = require("nattlua.error_messages")
local shared = require("nattlua.types.shared")
local META = require("nattlua.types.base")()
--[[#local type TBaseType = META.TBaseType]]
--[[#type META.@Name = "TAny"]]
--[[#local type TAny = META.@SelfArgument]]
--[[#type TAny.Type = "any"]]
META.Type = "any"

function META:Get(key--[[#: TBaseType]])
	return shared.Get(self, key)
end

function META:Set(key--[[#: TBaseType]], val--[[#: TBaseType]])
	return shared.Set(self, key, val)
end

function META:Copy()
	return self
end

function META.IsSubsetOf(A--[[#: TAny]], B--[[#: TBaseType]])
	return shared.IsSubsetOf(A, B)
end

function META:GetHashForMutationTracking() end

function META:__tostring()
	return "any"
end

function META:IsNil()
	return false
end

function META:CanBeNil()
	return true
end

function META.Equal(a--[[#: TAny]], b--[[#: TBaseType]])
	return shared.Equal(a, b)
end

function META:GetHash()
	return "?"
end

function META.LogicalComparison(l--[[#: TAny]], r--[[#: TBaseType]], op--[[#: string]])
	return shared.LogicalComparison(l, r, op)
end

function META:IsLiteral()
	return false
end

function META.New()
	return META.NewObject(
		{
			Type = "any",
			TruthyFalsy = "unknown",
			Data = false,
			Upvalue = false,
			Contract = false,
		}
	)
end

return {
	TAny = TAny,
	Any = META.New,
}