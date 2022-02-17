return {
		AnalyzeWhile = function(self, statement)
			local obj = self:AnalyzeExpression(statement.expression)
			local upvalues = self:GetTrackedUpvalues()
			local tables = self:GetTrackedTables()
			self:ClearTracked()

			if obj:IsCertainlyFalse() then
				self:Warning(statement.expression, "loop expression is always false")
			end

			if obj:IsTruthy() then
				self:ApplyMutationsInIf(upvalues, tables)

				for i = 1, 32 do
					self:PushConditionalScope(statement, obj:IsTruthy(), obj:IsFalsy())
						self:PushUncertainLoop(obj:IsTruthy() and obj:IsFalsy())
						self:AnalyzeStatements(statement.statements)
						self:PopUncertainLoop()
					self:PopConditionalScope()

					if self.break_out_scope then
						self.break_out_scope = nil

						break
					end

					if self:GetScope():DidCertainReturn() then break end
					local obj = self:AnalyzeExpression(statement.expression)
					if obj:IsUncertain() or obj:IsFalsy() then break end

					if i == 32 then
						self:Error(statement, "too many iterations")
					end
				end
			end
		end,
	}
