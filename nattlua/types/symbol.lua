local type = type
local tostring = tostring
local setmetatable = _G.setmetatable
local type_errors = require("nattlua.types.error_messages")
local META = dofile("nattlua/types/base.lua")
--[[#local type TBaseType = META.TBaseType]]
--[[#type META.@Name = "TSymbol"]]
--[[#type TSymbol = META.@Self]]
META.Type = "symbol"
META:GetSet("Data", nil--[[# as any]])

function META.Equal(a--[[#: TSymbol]], b--[[#: TBaseType]])
	return a.Type == b.Type and a.Data == b.Data
end

function META.LogicalComparison(l--[[#: TSymbol]], r--[[#: TBaseType]], op--[[#: string]])
	if op == "==" then return l.Data == r.Data end

	return false, type_errors.binary(op, l, r)
end

function META:GetLuaType()
	return type(self.Data)
end

function META:__tostring()
	return tostring(self.Data)
end

function META:GetHash()
	return self.Data
end

function META:Copy()
	local copy = self.New(self.Data)
	copy:CopyInternalsFrom(self)
	return copy
end

function META:CanBeNil()
	return self.Data == nil
end

function META.IsSubsetOf(a--[[#: TSymbol]], b--[[#: TBaseType]])
	if b.Type == "tuple" then b = b:Get(1) end

	if b.Type == "any" then return true end

	if b.Type == "union" then return b:IsTargetSubsetOfChild(a--[[# as any]]) end

	if b.Type ~= "symbol" then return false, type_errors.subset(a, b) end

	local b = b--[[# as TSymbol]]

	if a.Data ~= b.Data then return false, type_errors.subset(a, b) end

	return true
end

function META:IsFalsy()
	return not self.Data
end

function META:IsTruthy()
	return not not self.Data
end

function META:IsLiteral()
	return true
end

function META.New(data--[[#: any]])
	local self = setmetatable(
		{
			Data = data,
			Falsy = false,
			Truthy = false,
			ReferenceType = false,
			left_source = false,
			right_source = false,
			truthy_union = false,
			suppress = false,
			falsy_union = false,
			potential_self = false,
			parent_table = false,
			TypeOverride = false,
			Name = false,
			AnalyzerEnvironment = false,
			Upvalue = false,
			Node = false,
			Parent = false,
			Contract = false,
			MetaTable = false,
		},
		META
	)
	return self
end

local Symbol = META.New
return {
	Symbol = Symbol,
	Nil = function()
		return Symbol(nil)
	end,
	True = function()
		return Symbol(true)
	end,
	False = function()
		return Symbol(false)
	end,
}
