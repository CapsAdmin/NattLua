--ANALYZE
local type = type
local tostring = tostring
local setmetatable = _G.setmetatable
local error_messages = require("nattlua.error_messages")
local META = require("nattlua.types.base")()
--[[#local type TBaseType = META.TBaseType]]
local TRUE = {"true"}
local FALSE = {"false"}
local NIL = {"nil"}
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
--[[#type META.@Name = "TSymbol"]]
--[[#local type TSymbol = META.@Self]]
--[[#type TSymbol.Type = "symbol"]]
META.Type = "symbol"
META:GetSet("Data", false--[[# as TRUE | FALSE | NIL | {}]])
META:GetSet("Hash", ""--[[# as string]])

function META:SetData()
	if false--[[# as true]] then return end

	error("cannot mutate data")
end

function META:GetData()
	if self.Data == NIL then return nil end

	if self.Data == TRUE then return true end

	if self.Data == FALSE then return false end

	return self.Data--[[# as {}]]
end

function META.Equal(a--[[#: TSymbol]], b--[[#: TBaseType]])
	if a.Type ~= b.Type then return false, "types differ" end

	if a.Data == b.Data then return true, "symbol values match" end

	return false, "values are not equal"
end

function META.LogicalComparison(l--[[#: TSymbol]], r--[[#: TBaseType]], op--[[#: string]])
	if op == "==" then return l.Data == r.Data end

	return false, error_messages.binary(op, l, r)
end

function META:GetLuaType()
	return symbol_to_type[self.Data] or type(self.Data)
end

function META:__tostring()
	return tostring(self:GetData())
end

function META:GetHashForMutationTracking()
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

function META:CanBeNil()
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
	if b.Type == "tuple" then b = b:GetWithNumber(1) end

	if b.Type == "any" then return true end

	if b.Type == "union" then return b:IsTargetSubsetOfChild(a--[[# as any]]) end

	if b.Type ~= "symbol" then return false, error_messages.subset(a, b) end

	if a.Data ~= b.Data then return false, error_messages.subset(a, b) end

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

function META.New(data--[[#: true | false | nil | TSymbol.Data]])
	if data == nil then data = NIL end

	if data == true then data = TRUE end

	if data == false then data = FALSE end

	local self = META.NewObject(
		{
			Type = META.Type,
			Data = data,
			Falsy = false,
			Truthy = false,
			Upvalue = false,
			Parent = false,
			Contract = false,
			Hash = "",
		}
	)
	self.Hash = tostring(self)
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
	TSymbol = TSymbol,
}
