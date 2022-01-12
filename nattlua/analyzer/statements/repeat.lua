return
	{
		AnalyzeRepeat = function(self, statement)
			self:CreateAndPushScope()
				self:AnalyzeStatements(statement.statements)

				if self:AnalyzeExpression(statement.expression):IsTruthy() then
					self:FireEvent("break")
				end

			self:PopScope()
		end,
	}
