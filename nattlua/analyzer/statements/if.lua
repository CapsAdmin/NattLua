local ipairs = ipairs
local Union = require("nattlua.types.union").Union

return
	{
		AnalyzeIf = function(self, statement)
			local prev_expression
			local tracking = {}
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

					prev_expression = obj
					
					if obj:IsTruthy() then
						self:FireEvent("if", i == 1 and "if" or "elseif", true)
						self:PushConditionalScope(statement, obj)
						
							self:GetScope():SetTrackedObjects(upvalues, objects)

							self:MutateTrackedFromIf(upvalues, objects)
							
							if tracking[1] then
								for i,v in ipairs(tracking) do
									self:MutateTrackedFromIf(v[1], v[2], true)
								end
							end

							self:AnalyzeStatements(statements)
							self:PopConditionalScope()
						self:FireEvent("if", i == 1 and "if" or "elseif", false)
						if not obj:IsFalsy() then break end
					end

					table.insert(tracking, {upvalues, objects})
				else
					if prev_expression:IsFalsy() then
						self:FireEvent("if", "else", true)
							self:PushConditionalScope(statement, prev_expression)

							self:GetScope():SetTrackedObjects(tracking[#tracking][1], tracking[#tracking][2])

							self:MutateTrackedFromIf(tracking[#tracking][1], tracking[#tracking][2], true)

							self:GetScope():InvertIfStatement(true)
							self:AnalyzeStatements(statements)
							self:PopConditionalScope()
						self:FireEvent("if", "else", false)
					end
				end
			end
		end,
	}
