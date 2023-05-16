local LString = require("nattlua.types.string").LString
local Nil = require("nattlua.types.symbol").Nil
local Tuple = require("nattlua.types.tuple").Tuple
local Union = require("nattlua.types.union").Union
local type_errors = require("nattlua.types.error_messages")
return {
	Index = function(META)
		function META:IndexOperator(obj, key)
			if obj.Type == "union" then return obj:Index(self, key) end

			if self:IsRuntime() and obj.Type == "tuple" and obj:GetLength() == 1 then
				obj = obj:Get(1)
			end

			return obj:Index(self, key)
		end
	end,
}