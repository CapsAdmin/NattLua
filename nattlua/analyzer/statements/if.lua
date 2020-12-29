return function(META)
    function META:AnalyzeIfStatement(statement)
        local prev_expression
        for i, statements in ipairs(statement.statements) do
            if statement.expressions[i] then
                local obj = self:AnalyzeExpression(statement.expressions[i], "runtime")
                prev_expression = obj

                if obj:IsTruthy() then
                    self:CreateAndPushScope()
                    self:OnEnterConditionalScope({    
                        type = "if",                        
                        if_position = i, 
                        condition = obj,
                        statement = statement,
                    })
                    self:FireEvent("enter_scope_if", statement.expressions[i], obj, i == 1 and "if" or "elseif")
                        
                    self:AnalyzeStatements(statements)

                    self:FireEvent("leave_scope")
                    self:PopScope()
                    self:OnExitConditionalScope({
                        type = "if",
                        if_position = i, 
                        condition = obj,
                        statement = statement,
                    })

                    if not obj:IsFalsy() then
                        break
                    end
                end
            else
                if prev_expression:IsFalsy() then
                    self:CreateAndPushScope()
                    self:OnEnterConditionalScope({
                        type = "if",
                        if_position = i, 
                        is_else = true,
                        condition = prev_expression,
                        statement = statement,
                    })
                    self:FireEvent("enter_scope_if", obj, "else")

                    self:AnalyzeStatements(statements)

                    self:FireEvent("leave_scope")

                    self:PopScope()
                    self:OnExitConditionalScope({
                        type = "if",
                        if_position = i,
                        is_else = true,
                        condition = prev_expression,
                        statement = statement,
                    })
                end
            end
        end
    end
end