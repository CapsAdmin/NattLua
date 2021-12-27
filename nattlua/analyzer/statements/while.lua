return
	{
		AnalyzeWhile = function(analyzer, statement)
			local obj = analyzer:AnalyzeExpression(statement.expression)

			if obj:IsTruthy() then
				for i = 1, 32 do
					analyzer:PushConditionalScope(statement, obj)
					analyzer:FireEvent("while", obj)
						analyzer:PushUncertainLoop(obj:IsTruthy() and obj:IsFalsy())

						analyzer:AnalyzeStatements(statement.statements)

						analyzer:PopUncertainLoop()
					analyzer:PopConditionalScope()

					if analyzer.break_out_scope then
						analyzer.break_out_scope = nil

						break
					end

					if analyzer:GetScope():DidCertainReturn() then break end
					local obj = analyzer:AnalyzeExpression(statement.expression)
					if obj:IsUncertain() or obj:IsFalsy() then break end

					if i == 32 then
						analyzer:Error(statement, "too many iterations")
					end
				end
			end
		end,
	}
