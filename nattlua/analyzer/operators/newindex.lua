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

			if
				val.Type == "function" and
				val:GetFunctionBodyNode() and
				val:GetFunctionBodyNode().self_call
			then
				local arg = val:GetInputSignature():Get(1)

				if arg and not arg:GetContract() and not arg.Self and not self:IsTypesystem() then
					val:SetCalled(true)
					val = val:Copy()
					val:SetCalled(nil)
					val:GetInputSignature():Set(1, Union({Any(), obj}))
					self:AddToUnreachableCodeAnalysis(val, val:GetInputSignature(), val:GetFunctionBodyNode(), true)
				end
			end

			return obj:NewIndex(self, key, val)
		end
	end,
}