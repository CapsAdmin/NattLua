local tostring = tostring
local ipairs = ipairs
local LNumber = require("nattlua.types.number").LNumber
local LNumberRange = require("nattlua.types.range").LNumberRange
local LString = require("nattlua.types.string").LString
local ConstString = require("nattlua.types.string").ConstString
local Table = require("nattlua.types.table").Table
local Nil = require("nattlua.types.symbol").Nil
local table = _G.table

local function check_type_against_contract(val, contract)
	-- if the contract is unique / nominal, ie
	-- local a: Person = {name = "harald"}
	-- Person is not a subset of {name = "harald"} because
	-- Person is only equal to Person
	-- so we need to disable this check during assignment
	if contract.Type == "table" and val.Type == "table" then
		if contract:IsUnique() and not val:IsUnique() then
			contract:DisableUniqueness()
			contract:EnableUniqueness()
			val:SetUniqueID(contract:GetUniqueID())
		end
	end

	local ok, reason = val:IsSubsetOf(contract)

	if not ok then return ok, reason end

	-- make sure the table contains all the keys in the contract as well
	-- since {foo = true, bar = "harald"} 
	-- is technically a subset of 
	-- {foo = true, bar = "harald", baz = "jane"}
	if contract.Type == "table" and val.Type == "table" then
		return val:ContainsAllKeysIn(contract)
	end

	return true
end

return {
	AnalyzeTable = function(self, tree)
		local tbl = Table()

		if self:IsRuntime() then tbl:SetReferenceId(tostring(tbl:GetData())) end

		self:PushCurrentTypeTable(tbl)
		tbl:SetCreationScope(self:GetScope())
		local numerical_index = 0

		for _, node in ipairs(tree.children) do
			if node.Type == "sub_statement_table_key_value" then
				local key = ConstString(node.tokens["identifier"]:GetValueString())

				if node.type_expression then
					self:PushAnalyzerEnvironment("typesystem")
					local contract = self:GetFirstValue(self:AnalyzeExpression(node.type_expression)) or Nil()
					self:PopAnalyzerEnvironment()

					if node.value_expression then
						local val = node.value_expression and
							self:GetFirstValue(self:AnalyzeExpression(node.value_expression)) or
							Nil()
						self:ErrorIfFalse(check_type_against_contract(val, contract))
					end

					self:NewIndexOperator(tbl, key, contract)
				else
					local val = self:GetFirstValue(self:AnalyzeExpression(node.value_expression)) or Nil()
					self:MapTypeToNode(val, node.value_expression)
					self:NewIndexOperator(tbl, key, val)
				end
			elseif node.Type == "sub_statement_table_expression_value" then
				local key = self:GetFirstValue(self:AnalyzeExpression(node.key_expression))

				if node.type_expression then
					self:PushAnalyzerEnvironment("typesystem")
					local contract = self:GetFirstValue(self:AnalyzeExpression(node.type_expression)) or Nil()
					self:PopAnalyzerEnvironment()

					if node.value_expression then
						local val = node.value_expression and
							self:GetFirstValue(self:AnalyzeExpression(node.value_expression)) or
							Nil()
						self:ErrorIfFalse(check_type_against_contract(val, contract))
					end

					self:NewIndexOperator(tbl, key, contract)
				else
					local val = self:Assert(self:GetFirstValue(self:AnalyzeExpression(node.value_expression)))
					self:NewIndexOperator(tbl, key, val)
				end
			elseif node.Type == "sub_statement_table_index_value" then
				if node.spread then
					local val = self:GetFirstValue(self:AnalyzeExpression(node.spread.expression))

					if val.Type == "table" then
						for _, kv in ipairs(val:GetData()) do
							local val = kv.val

							if val.Type == "union" and val:IsNil() then
								val = val:Copy():RemoveType(Nil())
							end

							if kv.key.Type == "number" then
								self:NewIndexOperator(tbl, LNumber(numerical_index + 1), val)
							else
								self:NewIndexOperator(tbl, kv.key, val)
							end

							numerical_index = numerical_index + 1
						end
					end
				else
					local obj = self:AnalyzeExpression(node.value_expression)

					if
						(
							node.value_expression.Type ~= "expression_value" or
							(node.value_expression.value.type == "symbol" and 
							not node.value_expression.value:ValueEquals("..."))
						)
						and
						node.value_expression.Type ~= "expression_postfix_call"
					then
						obj = self:GetFirstValue(obj)
					end

					if obj.Type == "tuple" then
						if tree.children[numerical_index + 1 + 1] then
							self:NewIndexOperator(tbl, LNumber(numerical_index + 1), obj:GetWithNumber(1))
							numerical_index = numerical_index + 1
						else
							for i = 1, obj:GetSafeLength() do
								self:NewIndexOperator(tbl, LNumber(numerical_index + 1), obj:GetWithNumber(i))
								numerical_index = numerical_index + 1
							end

							if obj.Remainder then
								local max = obj.Remainder:GetElementCount()
								self:NewIndexOperator(tbl, LNumberRange(numerical_index + 1, max), obj.Remainder:GetWithNumber(1))
								numerical_index = max + 1
							end
						end
					elseif obj then
						self:NewIndexOperator(tbl, LNumber(numerical_index + 1), obj, nil, true)
						numerical_index = numerical_index + 1
					end
				end
			end

			self:ClearTracked()
		end

		if self:IsRuntime() then tbl:RemoveRedundantNilValues() end

		self:PopCurrentTypeTable()
		return tbl
	end,
}
