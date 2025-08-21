local ipairs = _G.ipairs
local Union = require("nattlua.types.union").Union
local type_errors = require("nattlua.types.error_messages")
return {
	AnalyzeIf = function(self, statement)
		local prev_expression
		local blocks = {}
		local og_statement = statement

		for i, statements in ipairs(statement.statements) do
			if statement.expressions[i] then
				self.current_if_statement = statement
				local exp = statement.expressions[i]
				self:PushCurrentExpression(exp)
				local no_operator_expression = exp.kind ~= "binary_operator" and
					exp.kind ~= "prefix_operator" or
					(
						exp.kind == "binary_operator" and
						exp.value.value == "."
					)

				if no_operator_expression then self:PushTruthyExpressionContext() end

				local obj = self:Assert(self:AnalyzeExpression(exp))
				self:TrackDependentUpvalues(obj)

				if no_operator_expression then self:PopTruthyExpressionContext() end

				if no_operator_expression then
					-- track "if x then" which has no binary or prefix operators
					if obj.Type == "union" then
						self:TrackUpvalueUnion(obj, obj:GetTruthy(), obj:GetFalsy())
					end
				end

				self.current_if_statement = false
				prev_expression = obj

				if obj:IsTruthy() then
					local upvalues = self:GetTrackedUpvalues()
					local tables = self:GetTrackedTables()
					self:ClearTracked()
					table.insert(
						blocks,
						{
							statements = statements,
							upvalues = upvalues,
							tables = tables,
							expression = obj,
						}
					)
				end

				if self:IsRuntime() then
					if obj:IsCertainlyFalse() then
						self:ConstantIfExpressionWarning(type_errors.if_always_false())

						for _, statement in ipairs(statements) do
							statement:SetUnreachable(true)
						end
					elseif obj:IsCertainlyTrue() then
						self:ConstantIfExpressionWarning(type_errors.if_always_true())
					else
						self:ConstantIfExpressionWarning()
					end
				end

				self:PopCurrentExpression()

				if obj:IsCertainlyTrue() then break end
			else
				local exp = statement.expressions[i - 1]
				self:PushCurrentExpression(exp)
				local caller = self:GetCallFrame(1)

				if self:IsRuntime() then
					if prev_expression:IsUncertain() then
						self:ConstantIfExpressionWarning(nil, og_statement.tokens["if/else/elseif"][i])
					elseif prev_expression:IsCertainlyFalse() then
						self:ConstantIfExpressionWarning(type_errors.if_else_always_true(), og_statement.tokens["if/else/elseif"][i])
					end
				end

				if prev_expression:IsFalsy() then
					table.insert(
						blocks,
						{
							statements = statements,
							upvalues = blocks[#blocks] and blocks[#blocks].upvalues,
							tables = blocks[#blocks] and blocks[#blocks].tables,
							expression = prev_expression,
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
			local scope = self:PushConditionalScope(statement, block.expression:IsTruthy(), block.expression:IsFalsy())

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
