local ipairs = ipairs
return
	{
		AnalyzeIf = function(analyzer, statement)
			local prev_expression

			for i, statements in ipairs(statement.statements) do
				if statement.expressions[i] then
					local obj = analyzer:AnalyzeExpression(statement.expressions[i])
					prev_expression = obj

					if obj:IsTruthy() then
						analyzer:FireEvent("if", i == 1 and "if" or "elseif", true)
						analyzer:CreateAndPushScope()
							analyzer:EnterConditionalScope(statement, obj)
							analyzer:AnalyzeStatements(statements)
							analyzer:ExitConditionalScope()
						analyzer:PopScope()
						analyzer:FireEvent("if", i == 1 and "if" or "elseif", false)
						if not obj:IsFalsy() then break end
					end
				else
					if prev_expression:IsFalsy() then
						analyzer:FireEvent("if", "else", true)
						analyzer:CreateAndPushScope()
							analyzer:EnterConditionalScope(statement, prev_expression)
							analyzer:GetScope():InvertIfStatement(true)
							analyzer:AnalyzeStatements(statements)
							analyzer:ExitConditionalScope()
						analyzer:PopScope()
						analyzer:FireEvent("if", "else", false)
					end
				end
			end
		end,
	}
