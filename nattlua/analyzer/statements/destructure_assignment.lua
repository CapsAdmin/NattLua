local tostring = tostring
local ipairs = ipairs
local ConstString = require("nattlua.types.string").ConstString
local Nil = require("nattlua.types.symbol").Nil
local error_messages = require("nattlua.error_messages")
return {
	AnalyzeDestructureAssignment = function(self, statement)
		local obj, err = self:AnalyzeExpression(statement.right)

		if obj.Type == "union" then obj = obj:GetData()[1] end

		if obj.Type == "tuple" then obj = obj:GetWithNumber(1) end

		if obj.Type ~= "table" then
			self:Error(error_messages.destructure_assignment(obj.Type))
			return
		end

		if statement.default then
			if statement.Type == "statement_local_destructure_assignment" then
				self:MapTypeToNode(
					self:CreateLocalValue(statement.default.value:GetValueString(), obj),
					statement.default
				)
			elseif statement.Type == "statement_destructure_assignment" then
				self:SetLocalOrGlobalValue(ConstString(statement.default.value:GetValueString()), obj)
			end
		end

		for _, node in ipairs(statement.left) do
			local obj = node.value and obj:Get(ConstString(node.value:GetValueString()))

			if not obj then
				if self:IsRuntime() then
					obj = Nil()
				else
					self:Error(error_messages.destructure_assignment_missing(node.value:GetValueString()))
				end
			end

			if obj then
				if statement.Type == "statement_local_destructure_assignment" then
					self:MapTypeToNode(self:CreateLocalValue(node.value:GetValueString(), obj), node.value)
				elseif statement.Type == "statement_destructure_assignment" then
					self:SetLocalOrGlobalValue(ConstString(node.value:GetValueString()), obj)
				end
			end
		end
	end,
}
