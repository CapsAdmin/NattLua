return
	{
		AnalyzeWhile = function(self, statement)
			local obj = self:AnalyzeExpression(statement.expression)

			if obj:IsTruthy() then
				for i = 1, 32 do
					self:PushConditionalScope(statement, obj:IsTruthy(), obj:IsFalsy())
					self:FireEvent("while", obj)
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
