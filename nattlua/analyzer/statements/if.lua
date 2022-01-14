local ipairs = ipairs
local Union = require("nattlua.types.union").Union

return
	{
		AnalyzeIf = function(self, statement)
			local prev_expression
			local blocks = {}
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

					prev_expression = obj
					
					if obj:IsTruthy() then
						local upvalues, objects = self:GetTrackedObjectMap()
						self:ClearTrackedObjects()

						table.insert(blocks, {
							statements = statements,
							upvalues = upvalues,
							objects = objects,
							expression = obj,
						})

						if not obj:IsFalsy() then break end
					end
				else
					if prev_expression:IsFalsy() then
						table.insert(blocks, {
							statements = statements,
							upvalues = blocks[#blocks].upvalues,
							objects = blocks[#blocks].objects,
							expression = prev_expression,
							is_else = true,
						})

					end
				end
			end

			for i, block in ipairs(blocks) do
				if block.is_else then
					self:FireEvent("if", "else", true)
				else
					self:FireEvent("if", i == 1 and "if" or "elseif", true)
				end
					self:PushConditionalScope(statement, block.expression)
					self:GetScope():SetTrackedObjects(block.upvalues, block.objects)
					if block.is_else then
						self:MutateTrackedFromIfElse(blocks)
					else
						self:MutateTrackedFromIf(block.upvalues, block.objects)
					end
					self:AnalyzeStatements(block.statements)
					self:PopConditionalScope()

				if block.is_else then
					self:FireEvent("if", "else", false)
				else
					self:FireEvent("if", i == 1 and "if" or "elseif", false)
				end
			end

			self:ClearTrackedObjects()
		end,
	}
