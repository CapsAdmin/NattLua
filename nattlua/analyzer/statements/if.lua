return function(analyzer, statement)
	local prev_expression

	for i, statements in ipairs(statement.statements) do
		if statement.expressions[i] then
			local obj = analyzer:AnalyzeExpression(statement.expressions[i], "runtime")
			prev_expression = obj

			if obj:IsTruthy() then
				analyzer:FireEvent("if", i == 1 and "if" or "elseif", true)
				analyzer:CreateAndPushScope()
					analyzer:OnEnterConditionalScope(
						{
							type = "if",
							if_position = i,
							condition = obj,
							statement = statement,
						}
					)
					analyzer:AnalyzeStatements(statements)
					analyzer:OnExitConditionalScope(
						{
							type = "if",
							if_position = i,
							condition = obj,
							statement = statement,
						}
					)
				analyzer:PopScope()
				analyzer:FireEvent("if", i == 1 and "if" or "elseif", false)
				if not obj:IsFalsy() then break end
			end
		else
			if prev_expression:IsFalsy() then
				analyzer:FireEvent("if", "else", true)
				analyzer:CreateAndPushScope()
					analyzer:OnEnterConditionalScope(
						{
							type = "if",
							if_position = i,
							is_else = true,
							condition = prev_expression,
							statement = statement,
						}
					)
					analyzer:AnalyzeStatements(statements)
					analyzer:OnExitConditionalScope(
						{
							type = "if",
							if_position = i,
							is_else = true,
							condition = prev_expression,
							statement = statement,
						}
					)
				analyzer:PopScope()
				analyzer:FireEvent("if", "else", false)
			end
		end
	end
end
