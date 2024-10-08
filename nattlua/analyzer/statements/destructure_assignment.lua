local tostring = tostring
local ipairs = ipairs
local ConstString = require("nattlua.types.string").ConstString
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
				self:MapTypeToNode(self:CreateLocalValue(statement.default.value.value, obj), statement.default)
			elseif statement.kind == "destructure_assignment" then
				self:SetLocalOrGlobalValue(ConstString(statement.default.value.value), obj)
			end
		end

		for _, node in ipairs(statement.left) do
			local obj = node.value and obj:Get(ConstString(node.value.value))

			if not obj then
				if self:IsRuntime() then
					obj = Nil()
				else
					self:Error(type_errors.destructure_assignment_missing(node.value.value))
				end
			end

			if statement.kind == "local_destructure_assignment" then
				self:MapTypeToNode(self:CreateLocalValue(node.value.value, obj), node.value)
			elseif statement.kind == "destructure_assignment" then
				self:SetLocalOrGlobalValue(ConstString(node.value.value), obj)
			end
		end
	end,
}
