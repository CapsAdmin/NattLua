return function(analyzer, statement)
	analyzer:CreateAndPushScope()
		analyzer:AnalyzeStatements(statement.statements)

		if analyzer:AnalyzeExpression(statement.expression):IsTruthy() then
			analyzer:FireEvent("break")
		end

	analyzer:PopScope()
end