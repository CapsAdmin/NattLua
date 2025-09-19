local Function = require("nattlua.types.function").Function
local LNumber = require("nattlua.types.number").LNumber
local Table = require("nattlua.types.table").Table
local Symbol = require("nattlua.types.symbol").Symbol
local ffi = jit and require("ffi") or nil
local Tuple = require("nattlua.types.tuple").Tuple
local Any = require("nattlua.types.any").Any
local LString = require("nattlua.types.string").LString
local tonumber = _G.tonumber
local type = _G.type
local ipairs = _G.ipairs
local math_huge = _G.math.huge

local function cast_lua_type_to_type(v)
	local t = type(v)

	if t == "table" and v.Type ~= nil then
		return v
	elseif t == "function" then
		local func = Function()
		func:SetAnalyzerFunction(v)
		func:SetInputSignature(Tuple():AddRemainder(Tuple({Any()}):SetRepeat(math_huge)))
		func:SetOutputSignature(Tuple():AddRemainder(Tuple({Any()}):SetRepeat(math_huge)))
		return func
	elseif t == "number" then
		return LNumber(v)
	elseif t == "string" then
		return LString(v)
	elseif t == "boolean" then
		return Symbol(v)
	elseif t == "table" then
		local t = Table()

		for _, val in ipairs(v) do
			t:Insert(cast_lua_type_to_type(val))
		end

		t:SetContract(t)
		return t
	elseif t == "cdata" and tonumber(v) then
		return LNumber(v)
	end

	self:Print(tostring(v))
	error(debug.traceback("NYI " .. tostring(t)))
end

local function cast_lua_types_to_types(tps)
	local tbl = {}

	for i, v in ipairs(tps) do
		tbl[i] = cast_lua_type_to_type(v)
	end

	return tbl
end

return cast_lua_types_to_types
