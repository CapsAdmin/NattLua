local type = type
local tostring = tostring
local setmetatable = _G.setmetatable
local type_errors = require("nattlua.types.error_messages")
local META = dofile("nattlua/types/base.lua")

local TRUE = {}
local FALSE = {}
local NIL = {}

local symbol_to_type = {
	[TRUE] = "boolean",
	[FALSE] = "boolean",
	[NIL] = "nil",
}

local unpack_symbol = {
	 [TRUE] = true,
	 [FALSE] = false,
	 [NIL] = nil,
}

--[[#local type TBaseType = META.TBaseType]]
--[[#type META.@Name = "TSymbol"]]
--[[#type TSymbol = META.@Self]]
META.Type = "symbol"
META:GetSet("Data", false--[[# as any]])

function META:GetData()
	if self.Data == NIL then
		return nil
	end
	if self.Data == TRUE then
		return true
	end

	if self.Data == FALSE then
		return false
	end

	return self.Data
end

function META.Equal(a--[[#: TSymbol]], b--[[#: TBaseType]])
	return a.Type == b.Type and a.Data == b.Data
end

function META.LogicalComparison(l--[[#: TSymbol]], r--[[#: TBaseType]], op--[[#: string]])
	if op == "==" then return l.Data == r.Data end

	return false, type_errors.binary(op, l, r)
end

function META:GetLuaType()
	return symbol_to_type[self.Data] or type(self.Data)
end

function META:__tostring()
	return tostring(self:GetData())
end

function META:GetHash()
	return self.Data
end

function META:Copy()
	local copy = self.New(self.Data)
	copy:CopyInternalsFrom(self)
	return copy
end

function META:IsNil()
	return self.Data == NIL
end

function META:IsBoolean()
	return self.Data == TRUE or self.Data == FALSE
end

function META:IsTrue()
	return self.Data == TRUE
end

function META:IsFalse()
	return self.Data == FALSE
end

function META.IsSubsetOf(a--[[#: TSymbol]], b--[[#: TBaseType]])
	if false --[[#as true]] then return false end
	if b.Type == "tuple" then b = b:Get(1) end

	if b.Type == "any" then return true end

	if b.Type == "union" then return b:IsTargetSubsetOfChild(a--[[# as any]]) end

	if b.Type ~= "symbol" then return false, type_errors.subset(a, b) end

	local b = b--[[# as TSymbol]]

	if a.Data ~= b.Data then return false, type_errors.subset(a, b) end

	return true
end

function META:IsFalsy()
	if self.Data == TRUE then return false end
	if self.Data == FALSE then return true end
	if self.Data == NIL then return true end

	return not self.Data
end

function META:IsTruthy()
	if self.Data == TRUE then return true end
	if self.Data == FALSE then return false end
	if self.Data == NIL then return false end

	return not not self.Data
end

function META:IsLiteral()
	return true
end

function META.New(data--[[#: any]])
	if data == nil then data = NIL end
	if data == true then data = TRUE end
	if data == false then data = FALSE end
	local self = setmetatable(
		{
			Type = "symbol",
			Data = data,
			Falsy = false,
			Truthy = false,
			ReferenceType = false,
			TypeOverride = false,
			Name = false,
			Upvalue = false,
			Node = false,
			Parent = false,
			Contract = false,
			UniqueID = false,
		},
		META
	)
	return self
end

local Symbol = META.New
return {
	Symbol = Symbol,
	Nil = function()
		return Symbol(NIL)
	end,
	True = function()
		return Symbol(TRUE)
	end,
	False = function()
		return Symbol(FALSE)
	end,
}
