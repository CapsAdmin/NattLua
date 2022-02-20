local tostring = tostring
local ipairs = ipairs
local LNumber = require("nattlua.types.number").LNumber
local LString = require("nattlua.types.string").LString
local Table = require("nattlua.types.table").Table
local table = require("table")
return {
	AnalyzeTable = function(self, node)
		local tbl = Table():SetNode(node):SetLiteral(self:IsTypesystem())

		if self:IsRuntime() then tbl:SetReferenceId(tostring(tbl:GetData())) end

		self:PushCurrentType(tbl, "table")

		local tree = node
		tbl.scope = self:GetScope()

		for i, node in ipairs(node.children) do
			if node.kind == "table_key_value" then
				local key = LString(node.tokens["identifier"].value):SetNode(node.tokens["identifier"])
				node.tokens["identifier"].inferred_type = key
				local val = self:AnalyzeExpression(node.value_expression):GetFirstValue()
				self:NewIndexOperator(node, tbl, key, val)
			elseif node.kind == "table_expression_value" then
				local key = self:AnalyzeExpression(node.key_expression):GetFirstValue()
				local val = self:AnalyzeExpression(node.value_expression):GetFirstValue()
				self:NewIndexOperator(node, tbl, key, val)
			elseif node.kind == "table_index_value" then
				local obj = self:AnalyzeExpression(node.value_expression)

				if
					node.value_expression.kind ~= "value" or
					node.value_expression.value.value ~= "..."
				then
					obj = obj:GetFirstValue()
				end

				if obj.Type == "tuple" then
					if tree.children[i + 1] then
						tbl:Insert(obj:Get(1))
					else
						for i = 1, obj:GetMinimumLength() do
							tbl:Set(LNumber(#tbl:GetData() + 1), obj:Get(i))
						end

						if obj.Remainder then
							local current_index = LNumber(#tbl:GetData() + 1)
							local max = LNumber(obj.Remainder:GetLength())
							tbl:Set(current_index:SetMax(max), obj.Remainder:Get(1))
						end
					end
				else
					if node.i then
						tbl:Insert(LNumber(obj))
					elseif obj then
						tbl:Insert(obj)
					end
				end
			end

			self:ClearTracked()
		end

		self:PopCurrentType("table")
		return tbl
	end,
}
