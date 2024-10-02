local type_errors = require("nattlua.types.error_messages")
local META = dofile("nattlua/types/base.lua")
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

function META:GetHash()
	return self
end

function META:__tostring()
	return "any"
end

function META:IsFalsy()
	return true
end

function META:IsTruthy()
	return true
end

function META:CanBeNil()
	return true
end

function META.Equal(a--[[#: TAny]], b--[[#: TBaseType]])
	return a.Type == b.Type
end

function META.LogicalComparison(l--[[#: TAny]], r--[[#: TBaseType]], op--[[#: string]])
	if op == "==" then return true -- TODO: should be nil (true | false)?
	end

	return false, type_errors.binary(op, l, r)
end

function META:IsLiteral()
	return false
end

function META.New()
	return setmetatable(
		{
			parent_table = false,
			truthy_union = false,
			right_source = false,
			left_source = false,
			TypeOverride = false,
			Falsy = false,
			Truthy = false,
			falsy_union = false,
			right_source = false,
			Data = nil,
            Name = false,
            AnalyzerEnvironment = false,
            Upvalue = false,
            Node = false,
            ReferenceType = false,
            Parent = false,
            Contract = false,
            MetaTable = false,
			UniqueID = false,
		},
		META
	)
end

return {
	Any = function()
		return META.New()
	end,
}
