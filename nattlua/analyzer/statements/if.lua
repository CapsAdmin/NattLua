local ipairs = _G.ipairs
local Union = require("nattlua.types.union").Union
local error_messages = require("nattlua.error_messages")
local table_insert = _G.table.insert
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
							tracked_objects = self.narrowing_store:GetTrackedObjects(nil, nil, self),
							obj = obj,
						}
					)
					self.narrowing_store:ClearTracked()
				elseif self.config.remove_unused and obj:IsFalsy() then
					table_insert(
						blocks,
						{
							statements = statements,
							tracked_objects = self.narrowing_store:GetTrackedObjects(nil, nil, self),
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
		-- Save original upvalue values before any branch narrowing (for else complement & early return)
		local original_upvalue_values

		if self.constraint_store then
			original_upvalue_values = self.constraint_store:SnapshotOriginalValues()
		end

		for i, block in ipairs(blocks) do
			block.scope = self:GetScope()
			local scope = self:PushConditionalScope(statement, block.obj:IsTruthy(), block.obj:IsFalsy())

			-- Snapshot constraint store for this branch (isolation)
			if self.constraint_store then
				self.constraint_store:PushScope()
				-- Apply narrowing for this branch
				-- Skip for or-conditions: the or handler manages fork/merge semantics
				-- via the constraint store, and applying narrowing here would
				-- incorrectly treat constraints from both branches as simultaneously true
				local cond = statement.expressions[i]
				local branchScope = self:GetScope()

				if block.is_else and not self.constraint_store:IsOrCondition(cond) then
					self.constraint_store:ApplyElseBranchNarrowing(branchScope, original_upvalue_values)
				elseif block.obj:IsTruthy() and not self.constraint_store:IsOrCondition(cond) then
					self.constraint_store:ApplyBranchNarrowing(branchScope)
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
				self.narrowing_store:ApplyMutationsInIfElse(blocks, self)
			else
				if blocks[i - 1] then
					local prev = {}

					for j = 1, i do
						table_insert(prev, blocks[j])
					end

					self.narrowing_store:ApplyMutationsInIfElse(prev, self)
				end

				self.narrowing_store:ApplyMutationsInIf(block.tracked_objects, self)
			end

			-- Recompute arithmetic and table field narrowing after mutations are applied
			if self.constraint_store and block.obj:IsTruthy() then
				self.constraint_store:RecomputeAfterMutations(self:GetScope(), self)
			end

			self:AnalyzeStatements(block.statements)

			-- Restore constraint store to before this branch
			if self.constraint_store then self.constraint_store:PopScope() end

			self:PopConditionalScope()
		end

		self.narrowing_store:ClearTracked()

		-- Apply post-if narrowing (early return narrowing for code after the if)
		if self.constraint_store and original_upvalue_values then
			self.constraint_store:ApplyPostIfNarrowing(self:GetScope(), self, original_upvalue_values)
		end

		-- Clear equality constraints to prevent leaking across ifs
		if self.constraint_store then
			self.constraint_store:ClearEqualityConstraints()
		end
	end,
}
