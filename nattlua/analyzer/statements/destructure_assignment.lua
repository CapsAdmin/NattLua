local tostring = tostring
local ipairs = ipairs
local NodeToString = require("nattlua.types.string").NodeToString
local Nil = require("nattlua.types.symbol").Nil
return {
	AnalyzeDestructureAssignment = function(self, statement)
		local obj = self:AnalyzeExpression(statement.right)

		if obj.Type == "union" then
			obj = obj:GetData()[1]
		end

		if obj.Type == "tuple" then
			obj = obj:Get(1)
		end

		if obj.Type ~= "table" then
			self:Error(statement.right, "expected a table on the right hand side, got " .. tostring(obj.Type))
		end

		if statement.default then
			if statement.kind == "local_destructure_assignment" then
				self:CreateLocalValue(statement.default.value.value, obj)
			elseif statement.kind == "destructure_assignment" then
				self:SetLocalOrGlobalValue(NodeToString(statement.default), obj)
			end
		end

		for _, node in ipairs(statement.left) do
			local obj = node.value and obj:Get(NodeToString(node))

			if not obj then
				if self:IsRuntime() then
					obj = Nil():SetNode(node)
				else
					self:Error(node, "field " .. tostring(node.value.value) .. " does not exist")
				end
			end

			if statement.kind == "local_destructure_assignment" then
				self:CreateLocalValue(node.value.value, obj)
			elseif statement.kind == "destructure_assignment" then
				self:SetLocalOrGlobalValue(NodeToString(node), obj)
			end
		end
	end,
}
