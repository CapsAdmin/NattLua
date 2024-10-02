local tostring = tostring
local ipairs = ipairs
local LNumber = require("nattlua.types.number").LNumber
local LNumberRange = require("nattlua.types.number").LNumberRange
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

		self:PushCurrentType(tbl, "table")
		tbl:SetCreationScope(self:GetScope())
		local numerical_index = 0

		for _, node in ipairs(tree.children) do
			if node.kind == "table_key_value" then
				local key = ConstString(node.tokens["identifier"].value)

				if node.type_expression then
					self:PushAnalyzerEnvironment("typesystem")
					local contract = self:AnalyzeExpression(node.type_expression):GetFirstValue() or Nil()
					self:PopAnalyzerEnvironment()

					if node.value_expression then
						local val = node.value_expression and
							self:AnalyzeExpression(node.value_expression):GetFirstValue() or
							Nil()
						self:Assert(check_type_against_contract(val, contract))
					end

					self:NewIndexOperator(tbl, key, contract)
				else
					local val = self:AnalyzeExpression(node.value_expression):GetFirstValue() or Nil()
					val:SetNode(node.value_expression)
					self:NewIndexOperator(tbl, key, val)
				end
			elseif node.kind == "table_expression_value" then
				local key = self:AnalyzeExpression(node.key_expression):GetFirstValue()

				if node.type_expression then
					self:PushAnalyzerEnvironment("typesystem")
					local contract = self:AnalyzeExpression(node.type_expression):GetFirstValue() or Nil()
					self:PopAnalyzerEnvironment()

					if node.value_expression then
						local val = node.value_expression and
							self:AnalyzeExpression(node.value_expression):GetFirstValue() or
							Nil()
						self:Assert(check_type_against_contract(val, contract))
					end

					self:NewIndexOperator(tbl, key, contract)
				else
					local val = self:AnalyzeExpression(node.value_expression):GetFirstValue()
					self:NewIndexOperator(tbl, key, val)
				end
			elseif node.kind == "table_index_value" then
				if node.spread then
					local val = self:AnalyzeExpression(node.spread.expression):GetFirstValue()

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
							node.value_expression.kind ~= "value" or
							node.value_expression.value.value ~= "..."
						)
						and
						node.value_expression.kind ~= "postfix_call"
					then
						obj = obj:GetFirstValue()
					end

					if obj.Type == "tuple" then
						if tree.children[numerical_index + 1 + 1] then
							self:NewIndexOperator(tbl, LNumber(numerical_index + 1), obj:Get(1))
							numerical_index = numerical_index + 1
						else
							local len = obj:GetElementCount()

							if len == math.huge then len = obj:GetMinimumLength() end

							for i = 1, len do
								self:NewIndexOperator(tbl, LNumber(numerical_index + 1), obj:Get(i))
								numerical_index = numerical_index + 1
							end

							if obj.Remainder then
								local max = obj.Remainder:GetElementCount()
								self:NewIndexOperator(tbl, LNumberRange(numerical_index + 1, max), obj.Remainder:Get(1))
								numerical_index = max + 1
							end
						end
					elseif obj then
						self:NewIndexOperator(tbl, LNumber(numerical_index + 1), obj)
						numerical_index = numerical_index + 1
					end
				end
			end

			self:ClearTracked()
		end

		tbl:RemoveRedundantNilValues()
		self:PopCurrentType("table")
		return tbl
	end,
}
