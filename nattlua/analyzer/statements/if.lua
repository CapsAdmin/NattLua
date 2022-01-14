local ipairs = ipairs
local Union = require("nattlua.types.union").Union

return
	{
		AnalyzeIf = function(self, statement)
			local prev_expression
			local last_upvalues
			local last_objects
			for i, statements in ipairs(statement.statements) do
				if statement.expressions[i] then
					self.current_if_statement = statement
					local exp = statement.expressions[i]				
					local no_operator_expression = exp.kind ~= "binary_operator" and exp.kind ~= "prefix_operator" or (exp.kind == "binary_operator" and exp.value.value == ".")

					if no_operator_expression then
						self:PushTruthyExpressionContext()
					end

					local obj = self:AnalyzeExpression(exp)

					if no_operator_expression then
						self:PopTruthyExpressionContext()
					end


					if no_operator_expression then
						-- track "if x then" which has no binary or prefix operators
						self:TrackUpvalue(obj)
					end

					self.current_if_statement = nil

					local upvalues, objects = self:GetTrackedObjectMap()
					self:ClearTrackedObjects()

					last_upvalues = upvalues
					last_objects = objects
					prev_expression = obj
					
					if obj:IsTruthy() then
						self:FireEvent("if", i == 1 and "if" or "elseif", true)
						self:PushConditionalScope(statement, obj)
						
							self:GetScope():SetTrackedObjects(upvalues, objects)

							self:MutateTrackedFromIf(upvalues, objects)

							self:AnalyzeStatements(statements)
							self:PopConditionalScope()
						self:FireEvent("if", i == 1 and "if" or "elseif", false)
						if not obj:IsFalsy() then break end
					end
				else
					if prev_expression:IsFalsy() then
						self:FireEvent("if", "else", true)
							self:PushConditionalScope(statement, prev_expression)

							self:GetScope():SetTrackedObjects(last_upvalues, last_objects)

							self:MutateTrackedFromIf(last_upvalues, last_objects, true)

							self:GetScope():InvertIfStatement(true)
							self:AnalyzeStatements(statements)
							self:PopConditionalScope()
						self:FireEvent("if", "else", false)
					end
				end
			end
		end,
	}
