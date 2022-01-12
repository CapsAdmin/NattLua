local ipairs = ipairs
return
	{
		AnalyzeIf = function(self, statement)
			local prev_expression
			local last_upvalues
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
						local l = obj
						if l.Type == "union" then
							local upvalue = l:GetUpvalue()

							if upvalue then
								local truthy_union = l:GetTruthy()
								local falsy_union = l:GetFalsy()
		
								upvalue.exp_stack = upvalue.exp_stack or {}
								table.insert(upvalue.exp_stack, {truthy = truthy_union, falsy = falsy_union})
			
								self.affected_upvalues = self.affected_upvalues or {}
								table.insert(self.affected_upvalues, upvalue)
							end		
						end
					end

					self.current_if_statement = nil

					local upvalues = {}
					local objects = {}
					if self.affected_upvalues then
						for _, upvalue in ipairs(self.affected_upvalues) do
							if upvalue.exp_stack_map then
								for k,v in pairs(upvalue.exp_stack_map) do
									table.insert(objects, {obj = upvalue, key = v[#v].key, val = v[#v].truthy})
								end
							else
								upvalues[upvalue] = upvalue.exp_stack
							end
						end
					end
					self:ClearAffectedUpvalues()

					last_upvalues = upvalues
					prev_expression = obj

					if obj:IsTruthy() then
						self:FireEvent("if", i == 1 and "if" or "elseif", true)
							self:PushConditionalScope(statement, obj, upvalues)

							for _, v in ipairs(objects) do
								self:MutateValue(v.obj, v.key, v.val)
							end

							self:AnalyzeStatements(statements)
							self:PopConditionalScope()
						self:FireEvent("if", i == 1 and "if" or "elseif", false)
						if not obj:IsFalsy() then break end
					end
				else
					if prev_expression:IsFalsy() then
						self:FireEvent("if", "else", true)
							self:PushConditionalScope(statement, prev_expression, last_upvalues)
							self:GetScope():InvertIfStatement(true)
							self:AnalyzeStatements(statements)
							self:PopConditionalScope()
						self:FireEvent("if", "else", false)
					end
				end
			end
		end,
	}
