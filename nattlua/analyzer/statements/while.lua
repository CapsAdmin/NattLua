return function(analyzer, statement)
	local obj = analyzer:AnalyzeExpression(statement.expression)

	if obj:IsTruthy() then
		analyzer:CreateAndPushScope()
			analyzer:FireEvent("while", obj)
			analyzer:OnEnterConditionalScope({type = "while", condition = obj,})
			analyzer:AnalyzeStatements(statement.statements)
		analyzer:PopScope()
		analyzer:OnExitConditionalScope({condition = obj})
		analyzer.break_out_scope = nil
	end
end