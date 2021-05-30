return
	{
		AnalyzeDo = function(analyzer, statement)
			analyzer:CreateAndPushScope()
				analyzer:FireEvent("do")
				analyzer:AnalyzeStatements(statement.statements)
			analyzer:PopScope()
		end,
	}
