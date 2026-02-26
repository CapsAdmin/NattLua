local type = type
local tostring = tostring
local setmetatable = _G.setmetatable
local error_messages = require("nattlua.error_messages")
local shared = require("nattlua.types.shared")
local META = require("nattlua.types.base")()
--[[#local type TBaseType = META.TBaseType]]
local TRUE = {"true"}
local FALSE = {"false"}
local NIL = {"nil"}
--[[#type META.@Name = "TSymbol"]]
--[[#local type TSymbol = META.@SelfArgument]]
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
	return shared.Equal(a, b)
end

function META.LogicalComparison(l--[[#: TSymbol]], r--[[#: TBaseType]], op--[[#: string]])
	return shared.LogicalComparison(l, r, op)
end

do
	local symbol_to_type = {
		[TRUE] = "boolean",
		[FALSE] = "boolean",
		[NIL] = "nil",
	}

	function META:GetLuaType()
		return symbol_to_type[self.Data] or type(self.Data)
	end
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
	return shared.IsSubsetOf(a, b)
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
			TruthyFalsy = (
					data == NIL or
					data == FALSE
				)
				and
				"falsy" or
				data == TRUE and
				"truthy" or
				"unknown",
			Upvalue = false,
			Contract = false,
			Hash = data == NIL and
				"nil" or
				data == TRUE and
				"true" or
				data == FALSE and
				"false" or
				tostring(data),
		}
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
	TSymbol = TSymbol,
}