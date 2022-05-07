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
	return a.Type == b.Type and a:GetData() == b:GetData()
end

function META:GetLuaType()
	return type(self:GetData())
end

function META:__tostring()
	return tostring(self:GetData())
end

function META:GetHash()
	return tostring(self.Data)
end

function META:Copy()
	local copy = self.New(self:GetData())
	copy:CopyInternalsFrom(self)
	return copy
end

function META:CanBeNil()
	return self:GetData() == nil
end

function META.IsSubsetOf(A--[[#: TSymbol]], B--[[#: TBaseType]])
	if B.Type == "tuple" then B = B:Get(1) end

	if B.Type == "any" then return true end

	if B.Type == "union" then return B:IsTargetSubsetOfChild(A) end

	if B.Type ~= "symbol" then return type_errors.type_mismatch(A, B) end

	if A:GetData() ~= B:GetData() then return type_errors.value_mismatch(A, B) end

	return true
end

function META:IsFalsy()
	return not self.Data
end

function META:IsTruthy()
	return not not self.Data
end

function META.New(data--[[#: any]])
	local self = setmetatable({Data = data}, META)
	self:SetLiteral(true)
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
