local error = error
local tostring = tostring
local setmetatable = _G.setmetatable
local types = {}
local type = _G.type

function types.Literal(val)
	if type(val) == "string" then
		return types.String(val):SetLiteral(true)
	elseif type(val) == "boolean" then
		return types.Symbol(val)
	elseif type(val) == "number" then
		return types.Number(val):SetLiteral(true)
	end

	return val
end

function types.IsTypeObject(obj)
	return type(obj) == "table" and obj.Type ~= nil
end

function types.Initialize()
	types.Table = require("nattlua.types.table").Table
	types.Union = require("nattlua.types.union").Union
	types.Nilable = require("nattlua.types.union").Nilable
	types.Tuple = require("nattlua.types.tuple").Tuple
	types.Number = require("nattlua.types.number").Number
	types.Function = require("nattlua.types.function").Function
	types.LuaTypeFunction = require("nattlua.types.function").LuaTypeFunction
	types.String = require("nattlua.types.string").String
	types.Any = require("nattlua.types.any").Any
	types.Symbol = require("nattlua.types.symbol").Symbol
	types.Nil = require("nattlua.types.symbol").Nil
	types.True = require("nattlua.types.symbol").True
	types.False = require("nattlua.types.symbol").False
	types.Boolean = require("nattlua.types.symbol").Boolean
end

return types
