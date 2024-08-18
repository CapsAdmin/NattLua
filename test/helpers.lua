local nl = require("nattlua")
local Union = require("nattlua.types.union").Union
local Tuple = require("nattlua.types.tuple").Tuple
local Number = require("nattlua.types.number").Number
local LNumber = require("nattlua.types.number").LNumber
local LString = require("nattlua.types.string").LString
local String = require("nattlua.types.string").String
local Symbol = require("nattlua.types.symbol").Symbol

local helpers = {}

do
	local function cast(...)
		local ret = {}

		for i = 1, select("#", ...) do
			local v = select(i, ...)
			local t = type(v)

			if t == "number" then
				ret[i] = LNumber(v)
			elseif t == "string" then
				ret[i] = LString(v)
			elseif t == "boolean" then
				ret[i] = Symbol(v)
			else
				ret[i] = v
			end
		end

		return ret
	end

	function helpers.Union(...)
		return Union(cast(...))
	end

	function helpers.Tuple(...)
		return Tuple(cast(...))
	end
end

function helpers.TypeExpression(code)
	local _, _, ret = helpers.RunCode("return _ as " .. code)
	return ret
end

return helpers