local ipairs = ipairs
local tostring = tostring
local LString = require("nattlua.types.string").LString
local Any = require("nattlua.types.any").Any
local Union = require("nattlua.types.union").Union
local Tuple = require("nattlua.types.tuple").Tuple
local type_errors = require("nattlua.types.error_messages")
return {
	NewIndex = function(META)
		function META:NewIndexOperator(obj, key, val)
			if obj.Type == "union" then return obj:NewIndex(self, key, val) end

			return obj:NewIndex(self, key, val)
		end
	end,
}