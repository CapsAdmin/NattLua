local tostring = tostring
local ipairs = ipairs
local NodeToString = require("nattlua.types.string").NodeToString
local Nil = require("nattlua.types.symbol").Nil
local type_errors = require("nattlua.types.error_messages")
return {
	AnalyzeDestructureAssignment = function(self, statement)
		local obj, err = self:AnalyzeExpression(statement.right)

		if obj.Type == "union" then obj = obj:GetData()[1] end

		if obj.Type == "tuple" then obj = obj:Get(1) end

		if obj.Type ~= "table" then
			self:Error(type_errors.destructure_assignment(obj.Type))
			return
		end

		if statement.default then
			if statement.kind == "local_destructure_assignment" then
				self:CreateLocalValue(statement.default.value.value, obj):SetNode(statement.default)
			elseif statement.kind == "destructure_assignment" then
				self:SetLocalOrGlobalValue(NodeToString(statement.default), obj)
			end
		end

		for _, node in ipairs(statement.left) do
			local obj = node.value and obj:Get(NodeToString(node))

			if not obj then
				if self:IsRuntime() then
					obj = Nil()
				else
					self:Error(type_errors.destructure_assignment_missing(node.value.value))
				end
			end

			if statement.kind == "local_destructure_assignment" then
				self:CreateLocalValue(node.value.value, obj):SetNode(node.value)
			elseif statement.kind == "destructure_assignment" then
				self:SetLocalOrGlobalValue(NodeToString(node), obj)
			end
		end
	end,
}