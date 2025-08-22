local ipairs = _G.ipairs
local Union = require("nattlua.types.union").Union
local type_errors = require("nattlua.types.error_messages")
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
					table.insert(
						blocks,
						{
							statements = statements,
							upvalues = self:GetTrackedUpvalues(),
							tables = self:GetTrackedTables(),
							obj = obj,
						}
					)
					self:ClearTracked()
				end

				if self:IsRuntime() then
					if obj:IsCertainlyFalse() then
						self:ConstantIfExpressionWarning(type_errors.if_always_false())

						for _, statement in ipairs(statements) do
							statement:SetUnreachable(true)
						end
					elseif obj:IsCertainlyTrue() then
						self:ConstantIfExpressionWarning(type_errors.if_always_true())
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
						self:ConstantIfExpressionWarning(type_errors.if_else_always_true(), og_statement.tokens["if/else/elseif"][i])
					end
				end

				if prev_obj:IsFalsy() then
					table.insert(
						blocks,
						{
							statements = statements,
							upvalues = blocks[#blocks] and blocks[#blocks].upvalues,
							tables = blocks[#blocks] and blocks[#blocks].tables,
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
			scope:SetTrackedUpvalues(block.upvalues or false)
			scope:SetTrackedTables(block.tables or false)

			if block.is_else then
				scope:SetElseConditionalScope(true)
				self:ApplyMutationsInIfElse(blocks)
			else
				if blocks[i - 1] then
					local prev = {}

					for i = 1, i do
						table.insert(prev, blocks[i])
					end

					self:ApplyMutationsInIfElse(prev)
				end

				self:ApplyMutationsInIf(block.upvalues, block.tables)
			end

			self:AnalyzeStatements(block.statements)
			self:PopConditionalScope()
		end

		self:ClearTracked()
	end,
}
