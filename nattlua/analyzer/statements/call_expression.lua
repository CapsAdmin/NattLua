return
	{
		AnalyzeCall = function(analyzer, statement)
			local foo = analyzer:AnalyzeExpression(statement.value)
			analyzer:FireEvent("call", statement.value, {foo})
		end,
	}
