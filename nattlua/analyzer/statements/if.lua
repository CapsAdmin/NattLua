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
					if obj:IsCertainlyFalse() or obj:IsUncertain() then
						self:ConstantIfExpressionWarning(error_messages.if_always_false())

						for _, statement in ipairs(statements) do
							if statement.Unreachable == nil then
								statement:SetUnreachable(true)
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
									self:ConstantIfExpressionWarning(nil, og_statement.tokens["if/else/elseif"][i])
									self:PopCurrentExpression()
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

		for i, block in ipairs(blocks) do
			block.scope = self:GetScope()
			local scope = self:PushConditionalScope(statement, block.obj:IsTruthy(), block.obj:IsFalsy())

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

			self:AnalyzeStatements(block.statements)
			self:PopConditionalScope()
		end

		self:ClearTracked()
	end,
}