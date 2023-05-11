local type_errors = require("nattlua.types.error_messages")
return {
	AnalyzeWhile = function(self, statement)
		local obj = self:AnalyzeExpression(statement.expression)
		local upvalues = self:GetTrackedUpvalues()
		local tables = self:GetTrackedTables()
		self:ClearTracked()

		if obj:IsCertainlyFalse() then
			self:Warning(type_errors.loop_always_false())
		end

		if obj:IsTruthy() then
			self:ApplyMutationsInIf(upvalues, tables)

			for i = 1, 32 do
				self:PushConditionalScope(statement, obj:IsTruthy(), obj:IsFalsy())
				self:PushUncertainLoop(obj:IsTruthy() and obj:IsFalsy())
				self:GetScope():SetLoopScope(true)
				self:AnalyzeStatements(statement.statements)
				self:PopUncertainLoop()
				self:PopConditionalScope()

				if self:DidCertainBreak() or self:DidUncertainBreak() then
					self:ClearBreak()

					break
				end

				if self:GetScope():DidCertainReturn() then break end

				local obj = self:AnalyzeExpression(statement.expression)

				if obj:IsUncertain() or obj:IsFalsy() then break end

				if i == 32 and self:IsRuntime() then
					self:Warning(type_errors.too_many_iterations())
				end
			end
		end
	end,
}