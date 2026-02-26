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
	return self
end

function META:Set(key--[[#: TBaseType]], val--[[#: TBaseType]])
	return true
end

function META:Copy()
	return self
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

function META:GetHash()
	return "?"
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