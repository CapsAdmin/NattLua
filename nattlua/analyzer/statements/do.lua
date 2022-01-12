return
	{
		AnalyzeDo = function(self, statement)
			self:CreateAndPushScope()
				self:FireEvent("do")
				self:AnalyzeStatements(statement.statements)
			self:PopScope()
		end,
	}
