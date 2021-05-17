local error = error
local tostring = tostring
local setmetatable = _G.setmetatable
local types = {}
local type = _G.type

function types.Cast(val)
	if type(val) == "string" then
		return types.String(val):SetLiteral(true)
	elseif type(val) == "boolean" then
		return types.Symbol(val)
	elseif type(val) == "number" then
		return types.Number(val):SetLiteral(true)
	elseif type(val) == "table" then
		if val.kind == "value" then return types.String(val.value.value):SetLiteral(true) end

		if not val.Type then
			error("cannot cast" .. tostring(val), 2)
		end
	end

	return val
end

function types.IsTypeObject(obj)
	return type(obj) == "table" and obj.Type ~= nil
end

do
	local function cmp(a, b, context, source)
		if not context[a] then
			context[a] = {}
			context[a][b] = types.FindInType(a, b, context, source)
		end

		return context[a][b]
	end

	-- this function is a sympton of me not knowing exactly how to find types in other types
	-- ideally this should be much more general and less complex
	-- i consider this a hack that should be refactored out

	function types.FindInType(a, b, context, source)
		source = source or b
		context = context or {}
		if not a then return false end
		if a == b then return source end

		if a.upvalue and b.upvalue then
			if a.upvalue_keyref or b.upvalue_keyref then return a.upvalue_keyref == b.upvalue_keyref and source or false end
			if a.upvalue == b.upvalue then return source end
		end

		if
			a.source_right and
			a.source_right.upvalue and
			b.upvalue and
			a.source_right.upvalue.node == b.upvalue.node
		then
			return cmp(a.source_right, b, context, source)
		end

		if a.upvalue and a.upvalue.value then return cmp(a.upvalue.value, b, context, a) end
		if a.type_checked then return cmp(a.type_checked, b, context, a) end
		if a.source_left then return cmp(a.source_left, b, context, a) end
		if a.source_right then return cmp(a.source_right, b, context, a) end
		if a.source then return cmp(a.source, b, context, a) end
		return false
	end
end

function types.Initialize()
	types.Table = require("nattlua.types.table").Table
	types.Union = require("nattlua.types.union").Union
	types.Nilable = require("nattlua.types.union").Nilable
	types.List = require("nattlua.types.list").List
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
