local ipairs = _G.ipairs
local Union = require("nattlua.types.union").Union
local error_messages = require("nattlua.error_messages")
local table_insert = _G.table.insert

-- Check if a condition expression has "or" as its top-level operator
-- This is used to skip equality narrowing for or-conditions, since the
-- constraint store handles fork/merge semantics separately
local function IsOrCondition(expr)
	if not expr then return false end

	-- Walk up through parent binary operators to find the top-level operator
	local n = expr

	while n do
		local parent = n.parent

		if not parent or parent.Type ~= "expression_binary_operator" then break end

		n = parent
	end

	-- n is now the top-level expression; check its operator
	if n.Type == "expression_binary_operator" and n.value then
		local op = n.value:GetValueString()

		if op == "or" then return true end
	end

	return false
end

return {
	AnalyzeIf = function(self, statement)
		local prev_obj
		local blocks = {}
		local og_statement = statement

		for i, statements in ipairs(statement.statements) do
			if statement.expressions[i] then
				local exp = statement.expressions[i]
				self:PushCurrentExpression(exp)
				local obj = self:AnalyzeConditionalExpression(exp)

				if obj:IsTruthy() then
					table_insert(
						blocks,
						{
							statements = statements,
							tracked_objects = self:GetTrackedObjects(),
							obj = obj,
						}
					)
					self:ClearTracked()
				elseif self.config.remove_unused and obj:IsFalsy() then
					table_insert(
						blocks,
						{
							statements = statements,
							tracked_objects = self:GetTrackedObjects(),
							obj = obj,
						}
					)
				end

				if self:IsRuntime() then
					if obj:IsCertainlyFalse() then
						self:ConstantIfExpressionWarning(error_messages.if_always_false())

						for _, statement in ipairs(statements) do
							if statement.Unreachable == nil then
								statement:SetUnreachable(true)
							end
						end
					elseif obj:IsUncertain() then
						for _, statement in ipairs(statements) do
							if statement.Unreachable == nil then
								statement:SetUnreachable(false)
							end
						end
					elseif obj:IsCertainlyTrue() then
						self:ConstantIfExpressionWarning(error_messages.if_always_true())

						for _, statement in ipairs(statements) do
							statement:SetUnreachable(false)
						end

						local ii = i

						for i, statements in ipairs(statement.statements) do
							if i ~= ii then
								local exp = statement.expressions[i]

								if exp then
									self:PushCurrentExpression(exp)
									self:ConstantIfExpressionWarning()
									self:PopCurrentExpression()
								else
									local exp = statement.expressions[i - 1]
									self:PushCurrentExpression(exp)

									if og_statement.tokens["if/else/elseif"] then
										self:ConstantIfExpressionWarning(nil, og_statement.tokens["if/else/elseif"][i])
									end

									self:PopCurrentExpression()
								end

								for _, stmt in ipairs(statements) do
									if stmt.Unreachable == nil then stmt:SetUnreachable(true) end
								end
							end
						end
					else
						self:ConstantIfExpressionWarning()

						for _, statement in ipairs(statements) do
							statement:SetUnreachable(false)
						end
					end
				end

				self:PopCurrentExpression()
				prev_obj = obj

				if obj:IsCertainlyTrue() then break end
			else
				self:PushCurrentExpression(statement.expressions[i - 1])

				if self:IsRuntime() then
					if prev_obj:IsUncertain() then
						self:ConstantIfExpressionWarning(nil, og_statement.tokens["if/else/elseif"][i])
					elseif prev_obj:IsCertainlyFalse() then
						self:ConstantIfExpressionWarning(error_messages.if_else_always_true(), og_statement.tokens["if/else/elseif"][i])
					end
				end

				if prev_obj:IsFalsy() then
					table_insert(
						blocks,
						{
							statements = statements,
							tracked_objects = blocks[#blocks] and blocks[#blocks].tracked_objects,
							obj = prev_obj,
							is_else = true,
						}
					)
				end

				self:PopCurrentExpression()
			end
		end

		local last_scope
		-- Save original domains and upvalue values before any branch narrowing (for else branch complement)
		local original_upvalue_values

		if self.constraint_store then
			original_upvalue_values = {}

			for upvalue in pairs(self.constraint_store:GetAllTrackedUpvalues()) do
				original_upvalue_values[upvalue] = upvalue:GetValue()
			end
		end

		for i, block in ipairs(blocks) do
			block.scope = self:GetScope()
			local scope = self:PushConditionalScope(statement, block.obj:IsTruthy(), block.obj:IsFalsy())

			-- Snapshot constraint store for this branch (isolation)
			if self.constraint_store then
				self.constraint_store:PushScope()

				-- Apply equality narrowing before analyzing the block
				-- Skip for or-conditions: the or handler manages fork/merge semantics
				-- via the constraint store, and applying equality narrowing here would
				-- incorrectly treat constraints from both branches as simultaneously true
				if block.is_else and not IsOrCondition(statement.expressions[i]) then
					-- Else branch: restore upvalue values before computing complement
					for upvalue, orig_value in pairs(original_upvalue_values) do
						if upvalue.SetValue then upvalue:SetValue(orig_value) end
					end

					self.constraint_store:ClearDomainsFor(original_upvalue_values)
					self.constraint_store:ApplyRelationalNarrowingElse(self)
				elseif block.obj:IsTruthy() and not IsOrCondition(statement.expressions[i]) then
					self.constraint_store:ApplyEqualityNarrowing()
					self.constraint_store:ApplyRelationalNarrowing(self)
					-- Mark all arithmetic constraints dirty for propagation
					self.constraint_store:MarkConstraintsDirty("arithmetic")
					-- Propagate until fixed point (handles chained arithmetic)
					self.constraint_store:PropagateUntilFixedPoint(self)
				end
			end

			if last_scope then
				last_scope:SetNextConditionalSibling(scope)
				scope:SetPreviousConditionalSibling(last_scope)
			end

			last_scope = scope
			scope:SetTrackedNarrowings(block.tracked_objects or false)

			if block.is_else then
				scope:SetElseConditionalScope(true)
				self:ApplyMutationsInIfElse(blocks)
			else
				if blocks[i - 1] then
					local prev = {}

					for j = 1, i do
						table_insert(prev, blocks[j])
					end

					self:ApplyMutationsInIfElse(prev)
				end

				self:ApplyMutationsInIf(block.tracked_objects)
			end

			-- Recompute arithmetic dependencies after tracked mutations are applied
			if self.constraint_store and block.obj:IsTruthy() then
				self.constraint_store:RecomputeAllArithmetic(self)
				-- Apply table field narrowing
				self.constraint_store:ApplyTableFieldNarrowing(self)
			end

			self:AnalyzeStatements(block.statements)

-- Restore constraint store to before this branch
			if self.constraint_store then self.constraint_store:PopScope() end

			self:PopConditionalScope()
		end

self:ClearTracked()

		-- Check if any branch had a certain return - if so, apply early return narrowing
		-- This narrows variables for code that follows the if-statement
		if self.constraint_store and original_upvalue_values then
			local scope = self:GetScope()
			if scope:DidCertainReturn() or scope:DidUncertainReturn() then
				self.constraint_store:ApplyEarlyReturnNarrowing(self, original_upvalue_values, true)
				-- Propagate narrowing through arithmetic dependencies
				self.constraint_store:MarkConstraintsDirty("arithmetic")
				self.constraint_store:PropagateUntilFixedPoint(self)
				self.constraint_store:RecomputeAllArithmetic(self)
				self.constraint_store:ApplyTableFieldNarrowing(self)
			end
		end

		-- Clear equality constraints to prevent leaking across ifs
		if self.constraint_store then
			self.constraint_store:ClearEqualityConstraints()
		end
	end,
}
