return
	{
		AnalyzeCall = function(self, statement)
			local foo = self:AnalyzeExpression(statement.value)
			self:FireEvent("call", statement.value, {foo})
		end,
	}
