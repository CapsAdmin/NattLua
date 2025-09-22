local setmetatable = _G.setmetatable
local error_messages = require("nattlua.error_messages")
local META = require("nattlua.types.base")()
--[[#local type TBaseType = META.TBaseType]]
--[[#type META.@Name = "TAny"]]
--[[#type TAny = META.@Self]]
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

function META.IsSubsetOf(A--[[#: TAny]], B--[[#: TBaseType]])
	return true
end

function META:GetHashForMutationTracking() end

function META:__tostring()
	return "any"
end

function META:IsFalsy()
	return true
end

function META:IsTruthy()
	return true
end

function META:IsNil()
	return false
end

function META:CanBeNil()
	return true
end

function META.Equal(a--[[#: TAny]], b--[[#: TBaseType]])
	return a.Type == b.Type, "any types match"
end

function META:GetHash()
	return "?"
end

function META.LogicalComparison(l--[[#: TAny]], r--[[#: TBaseType]], op--[[#: string]])
	if op == "==" then return true -- TODO: should be nil (true | false)?
	end

	return false, error_messages.binary(op, l, r)
end

function META:IsLiteral()
	return false
end

function META.New()
	return META.NewObject(
		{
			Type = "any",
			Falsy = false,
			Truthy = false,
			Data = false,
			Upvalue = false,
			ReferenceType = false,
			Contract = false,
			Parent = false,
		}
	)
end

return {
	Any = function()
		return META.New()
	end,
}
