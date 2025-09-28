local ipairs = ipairs
local tostring = tostring
local table = _G.table
local ConstString = require("nattlua.types.string").ConstString
local Union = require("nattlua.types.union").Union
local Nil = require("nattlua.types.symbol").Nil

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
							right[index] = obj:GetAtTupleIndex(index)
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
			local val = right[left_pos] or Nil()

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

				if exp_key.attribute then
					if exp_key.attribute.sub_type == "const" then immutable = true end
				end

				-- local assignment: local a = 1
				self:MapTypeToNode(self:CreateLocalValue(exp_key.value:GetValueString(), val, immutable), exp_key)
			elseif statement.Type == "statement_assignment" then
				local key = left[left_pos]

				-- plain assignment: a = 1
				if exp_key.Type == "expression_value" then
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

					local val = self:SetLocalOrGlobalValue(key, val)

					if false and val then
						-- this is used for tracking function dependencies
						if val.Type == "upvalue" then
							self:GetScope():AddDependency(val)
						else
							self:GetScope():AddDependency({key = key, val = val})
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
