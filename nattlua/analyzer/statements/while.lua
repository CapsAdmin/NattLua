local type_errors = require("nattlua.types.error_messages")
local ipairs = _G.ipairs
return {
	AnalyzeWhile = function(self, statement)
		local obj = self:AnalyzeConditionalExpression(statement.expression)

		if obj:IsCertainlyFalse() then
			for _, statement in ipairs(statement.statements) do
				statement:SetUnreachable(true)
			end

			self:PushCurrentExpression(statement.expression)
			self:ConstantIfExpressionWarning(type_errors.loop_always_false())
			self:PopCurrentExpression()
			return
		end

		local upvalues = self:GetTrackedUpvalues()
		local tables = self:GetTrackedTables()
		self:ClearTracked()
		self:ApplyMutationsInIf(upvalues, tables)
		local max_iterations = self.max_loop_iterations or 32
		local count = 0
		local loop_scope = self:PushLoopContext(statement, obj)

		for i = 1, max_iterations do
			count = count + 1
			self:AnalyzeStatements(statement.statements)
			local should_continue, break_reason = self:ShouldContinueLoop(loop_scope)

			if not should_continue then
				if break_reason == "certain_break" then
					self:ClearBreak()

					if self:IsRuntime() and count == 1 then
						self:PushCurrentExpression(statement.expression)
						self:ConstantIfExpressionWarning(type_errors.useless_while_loop())
						self:PopCurrentExpression()
					end

					break
				elseif break_reason == "uncertain_break" then
					self:ClearBreak()

					if self:IsRuntime() then
						self:PushCurrentExpression(statement.expression)
						self:ConstantIfExpressionWarning()
						self:PopCurrentExpression()
					end

					break
				elseif break_reason == "certain_return" then
					if self:IsRuntime() and count == 1 then
						self:PushCurrentExpression(statement.expression)
						self:ConstantIfExpressionWarning(type_errors.useless_while_loop())
						self:PopCurrentExpression()
					end

					break
				end
			end

			-- Re-analyze with same context as initial analysis
			obj = self:AnalyzeConditionalExpression(statement.expression)

			if obj:IsCertainlyFalse() then
				if self:IsRuntime() and count == 0 then
					self:PushCurrentExpression(statement.expression)
					self:ConstantIfExpressionWarning(type_errors.useless_while_loop())
					self:PopCurrentExpression()
				end

				break
			end

			if obj:IsUncertain() or obj:IsFalsy() then break end

			if i == max_iterations and self:IsRuntime() then
				self:Warning(type_errors.too_many_iterations())
			end

			count = count + 1
		end

		self:PopLoopContext(loop_scope)
	end,
}
