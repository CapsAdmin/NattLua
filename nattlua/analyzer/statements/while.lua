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

		for i = 1, max_iterations do
			local loop_scope = self:PushConditionalScope(statement, obj:IsTruthy(), obj:IsFalsy())
			loop_scope:SetLoopScope(true)
			self:PushUncertainLoop(obj:IsTruthy() and obj:IsFalsy() and loop_scope or false)
			self:AnalyzeStatements(statement.statements)
			self:PopUncertainLoop()
			self:PopConditionalScope()

			if self:DidCertainBreak() then
				self:ClearBreak()

				if self:IsRuntime() and count == 0 then
					self:PushCurrentExpression(statement.expression)
					self:ConstantIfExpressionWarning(type_errors.useless_while_loop())
					self:PopCurrentExpression()
				end

				break
			end

			if self:DidUncertainBreak() then
				self:ClearBreak()

				if self:IsRuntime() then
					self:PushCurrentExpression(statement.expression)
					self:ConstantIfExpressionWarning()
					self:PopCurrentExpression()
				end

				break
			end

			if self:GetScope():DidCertainReturn() then
				if self:IsRuntime() and count == 0 then
					self:PushCurrentExpression(statement.expression)
					self:ConstantIfExpressionWarning(type_errors.useless_while_loop())
					self:PopCurrentExpression()
				end

				break
			end

			-- Re-analyze with same context as initial analysis
			obj = self:AnalyzeConditionalExpression(statement.expression)

			if obj:IsCertainlyFalse() then
				if self:IsRuntime() and count == 0 then
					self:PushCurrentExpression(statement.expression)
					self:ConstantIfExpressionWarning(type_errors.useless_while_loop())
					self:PopCurrentExpression()
				end

				return
			end

			if obj:IsUncertain() or obj:IsFalsy() then break end

			if i == max_iterations and self:IsRuntime() then
				self:Warning(type_errors.too_many_iterations())
			end

			count = count + 1
		end
	end,
}
