local ipairs = ipairs
local tostring = tostring
local table = _G.table
local ConstString = require("nattlua.types.string").ConstString
local Union = require("nattlua.types.union").Union
local Nil = require("nattlua.types.symbol").Nil
local Deferred = require("nattlua.types.deferred").Deferred
local shared = require("nattlua.types.shared")
local binary_ops = require("nattlua.analyzer.operators.binary")
local Binary = binary_ops.Binary
local BinaryWithUnion = binary_ops.BinaryCustom
local error_messages = require("nattlua.error_messages")

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

	local ok, reason = shared.IsSubsetOf(val, contract)

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
	AnalyzeAssignment = function(self, statement)
		local left = {}
		local right = {}

		-- first we evaluate the left hand side
		for left_pos, exp_key in ipairs(statement.left) do
			if exp_key.Type == "expression_value" then
				-- local foo, bar = *
				left[left_pos] = ConstString(exp_key.value:GetValueString())
			elseif exp_key.Type == "expression_postfix_expression_index" then
				-- foo[bar] = *
				left[left_pos] = self:AnalyzeExpression(exp_key.expression)
			elseif exp_key.Type == "expression_binary_operator" then
				-- foo.bar = *
				left[left_pos] = self:AnalyzeExpression(exp_key.right)
			else
				self:FatalError("unhandled assignment expression " .. tostring(exp_key:Render()))
			end
		end

		if statement.right then
			for right_pos, exp_val in ipairs(statement.right) do
				-- when "self" is looked up in the typesystem in analyzer:AnalyzeExpression, we refer left[right_pos]
				-- use context?
				self.left_assigned = left[right_pos] or false
				local obj = self:Assert(self:AnalyzeExpression(exp_val))
				self:ClearTracked()

				if obj.Type == "union" and obj:GetCardinality() == 1 then
					obj = obj:GetData()[1]
				end

				if obj.Type == "tuple" and obj:HasOneValue() then
					obj = obj:GetWithNumber(1)
				end

				if obj.Type == "tuple" then
					if self:IsRuntime() then
						-- at runtime unpack the tuple
						for i = 1, #statement.left do
							local index = right_pos + i - 1
							right[index] = obj:GetWithNumber(i)
						end
					end

					if self:IsTypesystem() then
						if obj:HasTuples() then
							-- if we have a tuple with, plainly unpack the tuple while preserving the tuples inside
							for i = 1, #statement.left do
								local index = right_pos + i - 1
								right[index] = obj:GetWithoutExpansion(i)
							end
						else
							if #statement.left > 1 then
								-- at runtime unpack the tuple
								for i = 1, #statement.left do
									local index = right_pos + i - 1
									right[index] = obj:GetWithNumber(i)
								end
							else
								-- otherwise plainly assign it
								right[right_pos] = obj
							end
						end
					end
				elseif obj.Type == "union" then
					-- if the union is empty or has no tuples, just assign it
					if obj:IsEmpty() or not obj:HasTuples() then
						right[right_pos] = obj
					else
						for i = 1, #statement.left do
							-- unpack unions with tuples
							-- ⦗false, string, 2⦘ | ⦗true, 1⦘ at first index would be true | false
							local index = right_pos + i - 1
							local val = obj:GetAtTupleIndex(index)

							if val and val.Type == "union" then
								val:SetTupleSourceUnion(obj, index)
							end

							right[index] = val
						end
					end
				else
					right[right_pos] = obj
				end

				self.left_assigned = false
			end

			-- cuts the last arguments
			-- local funciton test() return 1,2,3 end
			-- local a,b,c = test(), 1337
			-- a should be 1
			-- b should be 1337
			-- c should be nil
			local last = statement.right[#statement.right]

			if
				last.Type == "expression_value" and
				last.value.type ~= "symbol" and
				last.value.sub_type ~= "..."
			then
				for _ = 1, #right - #statement.right do
					table.remove(right, #right)
				end
			end
		end

		-- here we check the types
		for left_pos, exp_key in ipairs(statement.left) do
			local val = right[left_pos]

			if
				not val and
				self.TealCompat and
				not exp_key.type_expression and
				self:GetCurrentAnalyzerEnvironment() == "typesystem" and
				statement.Type == "statement_local_assignment"
			then
				val = Deferred(exp_key.value:GetValueString())
			end

			val = val or Nil()

			-- do we have a type expression? 
			-- local a: >>number<< = 1
			if exp_key.type_expression then
				self:PushAnalyzerEnvironment("typesystem")
				local contract = self:Assert(self:AnalyzeExpression(exp_key.type_expression))
				self:PopAnalyzerEnvironment()

				if right[left_pos] then
					local contract = contract

					if contract.Type == "tuple" and contract:HasOneValue() then
						contract = contract:GetWithNumber(1)
					end

					-- we copy the literalness of the contract so that
					-- local a: number = 1
					-- becomes
					-- local a: number = number
					val = val:CopyLiteralness(contract)

					if val.Type == "table" and contract.Type == "table" then
						-- coerce any untyped functions based on contract
						self:ErrorIfFalse(val:CoerceUntypedFunctions(contract))
					end

					if val.Type == "function" and contract.Type == "function" then
						if val:IsCallbackSubsetOf(contract) then
							val:SetInputSignature(contract:GetInputSignature():Copy())
							val:SetOutputSignature(contract:GetOutputSignature():Copy())
							val:SetArgumentsInferred(true)
						end
					end

					self:PushCurrentExpression(exp_key)
					self:ErrorIfFalse(check_type_against_contract(val, contract))
					self:PopCurrentExpression()
				else
					if contract.Type == "tuple" and contract:HasOneValue() then
						contract = contract:GetWithNumber(1)
					end
				end

				-- we set a's contract to be number
				val:SetContract(contract)

				-- this is for "local a: number" without the right side being assigned
				if not right[left_pos] then
					-- make a copy of the contract and use it
					-- so the value can change independently from the contract
					val = contract:Copy()
					val:SetContract(contract)
				end
			end

			-- used by the emitter
			exp_key:AssociateType(val)

			if val.Type == "table" then
				val:SetAnalyzerEnvironment(self:GetCurrentAnalyzerEnvironment())
			end

			-- if all is well, create or mutate the value
			if statement.Type == "statement_local_assignment" then
				local immutable = false

				if statement.tokens["const"] then
					immutable = true
				elseif exp_key.attribute then
					if exp_key.attribute.value == "const" or exp_key.attribute.sub_type == "const" then
						immutable = true
					end
				end

				if exp_key.modifiers then
					if exp_key.modifiers.const then immutable = true end
				end

				-- local assignment: local a = 1
				self:CreateLocalValue(exp_key.value:GetValueString(), val, immutable, exp_key)
			elseif statement.Type == "statement_assignment" then
				local key = left[left_pos]

				-- TODO: LLM SLOP!!
				-- compound assignment with dotted LHS: x.y.z.field += b
				if
					statement.is_compound_assignment and
					exp_key.Type == "expression_binary_operator" and
					exp_key.value.sub_type == "." and
					#statement.left == 1
				then
					-- Extract base operator from compound token (e.g., "+=" -> "+")
					local compound_str = statement.tokens["="]:GetValueString()
					local base_op = compound_str:sub(1, compound_str:len() - 1)
					-- The LHS is a chain of "." binary operators
					-- x.y.z.field = ((x . y) . z) . field
					-- We need to get the object (x.y.z) and the key (field)
					local obj_expr = exp_key.left
					local field_name = exp_key.right.value:GetValueString()
					-- Analyze the object once
					local obj = self:Assert(self:AnalyzeExpression(obj_expr))
					self:ClearTracked()
					-- Get the current value at obj[field_name]
					local field_val = self:Assert(self:IndexOperator(obj, ConstString(field_name)))
					-- Analyze the right side
					local right_val = self:Assert(self:AnalyzeExpression(statement.right[1]))
					-- Apply the binary operation
					local result = self:AssertWithNode(exp_key, BinaryWithUnion(self, exp_key, field_val, right_val, base_op))
					-- Write result back
					self:PushCurrentExpression(statement.left[1])
					self:NewIndexOperator(obj, ConstString(field_name), result)
					self:PopCurrentExpression()
				elseif
					statement.is_compound_assignment and
					(
						exp_key.Type == "expression_postfix_expression_index" or
						exp_key.Type == "expression_postfix_call" or
						exp_key.Type == "expression_postfix_operator"
					)
					and
					#statement.left == 1
				then
					-- Extract base operator from compound token (e.g., "+=" -> "+")
					local compound_str = statement.tokens["="]:GetValueString()
					local base_op = compound_str:sub(1, compound_str:len() - 1)
					-- For indexed access: get the object part (everything except last index)
					local obj_expr = exp_key
					local idx_key = key

					-- Unwrap nested postfix: for x.y.z.field, obj_expr = x.y.z, idx_key = "field"
					if exp_key.Type == "expression_postfix_expression_index" then
						idx_key = self:Assert(self:AnalyzeExpression(exp_key.expression))
						obj_expr = exp_key.left
						-- Analyze the object once
						local obj = self:Assert(self:AnalyzeExpression(obj_expr))
						self:ClearTracked()

						if self:IsRuntime() then idx_key = self:GetFirstValue(idx_key) or Nil() end

						-- Read current value at obj[idx_key]
						local current_val = self:Assert(self:IndexOperator(obj, idx_key))
						-- Create binary operator: current_val op right
						local bop = {
							Type = "expression_binary_operator",
							value = {
								GetValueString = function()
									return base_op
								end,
								sub_type = base_op,
							},
							left = {
								Type = "expression_value",
								value = {
									GetValueString = function()
										return "__tmp"
									end,
								},
							},
							right = statement.right[1],
							parent = statement,
						}
						-- We need to analyze the binary op with current_val as the left operand
						-- Reuse BinaryWithUnion pattern: analyze left and right, then combine
						local right_val = self:Assert(self:AnalyzeExpression(statement.right[1]))
						local result = self:AssertWithNode(bop, BinaryWithUnion(self, bop, current_val, right_val, base_op))
						-- Write result back
						self:PushCurrentExpression(statement.left[1])
						self:NewIndexOperator(obj, idx_key, result)
						self:PopCurrentExpression()
					end
				elseif
					statement.is_compound_assignment and
					exp_key.Type == "expression_value" and
					#statement.left == 1
				then
					-- compound assignment: a += 1, a *= 2, etc.
					-- Extract base operator from compound token (e.g., "+=" -> "+")
					local compound_str = statement.tokens["="]:GetValueString()
					local base_op = compound_str:sub(1, compound_str:len() - 1)
					-- Create a binary operator node: left op right
					local bop = {
						Type = "expression_binary_operator",
						value = {
							GetValueString = function()
								return base_op
							end,
							sub_type = base_op,
						},
						left = statement.left[1],
						right = statement.right[1],
						parent = statement,
					}
					-- Analyze the binary operation to get the result type
					local result = self:AssertWithNode(bop, Binary(self, bop))
					-- Assign the result back to the variable
					val = result
					self:SetLocalOrGlobalValue(key, val, nil, exp_key)
					self:MapTypeToNode(val, exp_key)
				elseif exp_key.Type == "expression_value" then
					-- plain assignment: a = 1
					if self:IsRuntime() then -- check for any previous upvalues
						local existing_value = self:GetLocalOrGlobalValue(key)
						local contract = existing_value and existing_value:GetContract()

						if contract then
							if contract.Type == "tuple" then
								contract = self:GetFirstValue(contract)
							end

							if contract then
								val = val:CopyLiteralness(contract)
								self:PushCurrentExpression(exp_key)
								self:ErrorIfFalse(check_type_against_contract(val, contract))
								self:PopCurrentExpression()
								val:SetContract(contract)
							end
						end
					end

					local val = self:SetLocalOrGlobalValue(key, val, nil, exp_key)
					self:MapTypeToNode(val, exp_key)

					if false and val then
						-- this is used for tracking function dependencies
						if val.Type == "upvalue" then
							self:GetScope():AddDependency(val)
						else
							self:GetScope():AddDependency{key = key, val = val}
						end
					end
				else
					-- TODO: refactor out to mutation assignment?
					-- index assignment: foo[a] = 1
					local obj = self:Assert(self:AnalyzeExpression(exp_key.left))
					self:ClearTracked()

					if self:IsRuntime() then key = self:GetFirstValue(key) or Nil() end

					self:PushCurrentExpression(exp_key)
					self:NewIndexOperator(obj, key, val)
					self:PopCurrentExpression()
				end
			end
		end
	end,
}
