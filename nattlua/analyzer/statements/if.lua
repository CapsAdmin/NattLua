local ipairs = ipairs
return
	{
		AnalyzeIf = function(analyzer, statement)
			local prev_expression
			local last_upvalues
			for i, statements in ipairs(statement.statements) do
				if statement.expressions[i] then
					analyzer.current_if_statement = statement
					local exp = statement.expressions[i]				
					local obj = analyzer:AnalyzeExpression(exp)

					if exp.kind ~= "binary_operator" and exp.kind ~= "prefix_operator" then
						-- track "if x then" which has no binary or prefix operators
						local l = obj
						if l.Type == "union" then
							local upvalue = l:GetUpvalue()
					
							if upvalue then
								local truthy_union = l:GetTruthy()
								local falsy_union = l:GetFalsy()
		
								upvalue.exp_stack = upvalue.exp_stack or {}
								table.insert(upvalue.exp_stack, {truthy = truthy_union, falsy = falsy_union})
			
								analyzer.affected_upvalues = analyzer.affected_upvalues or {}
								table.insert(analyzer.affected_upvalues, upvalue)
							end		
						end
					end

					analyzer.current_if_statement = nil

					local upvalues = {}
					local objects = {}
					if analyzer.affected_upvalues then
						for _, upvalue in ipairs(analyzer.affected_upvalues) do
							if upvalue.exp_stack_map then
								for k,v in pairs(upvalue.exp_stack_map) do
									table.insert(objects, {obj = upvalue, key = v[#v].key, val = v[#v].truthy})
								end
							else
								upvalues[upvalue] = upvalue.exp_stack
							end
						end
					end
					analyzer:ClearAffectedUpvalues()

					last_upvalues = upvalues
					prev_expression = obj

					if obj:IsTruthy() then
						analyzer:FireEvent("if", i == 1 and "if" or "elseif", true)
							analyzer:PushConditionalScope(statement, obj, upvalues)

							for _, v in ipairs(objects) do
								analyzer:MutateValue(v.obj, v.key, v.val)
							end

							analyzer:AnalyzeStatements(statements)
							analyzer:PopConditionalScope()
						analyzer:FireEvent("if", i == 1 and "if" or "elseif", false)
						if not obj:IsFalsy() then break end
					end
				else
					if prev_expression:IsFalsy() then
						analyzer:FireEvent("if", "else", true)
							analyzer:PushConditionalScope(statement, prev_expression, last_upvalues)
							analyzer:GetScope():InvertIfStatement(true)
							analyzer:AnalyzeStatements(statements)
							analyzer:PopConditionalScope()
						analyzer:FireEvent("if", "else", false)
					end
				end
			end
		end,
	}
