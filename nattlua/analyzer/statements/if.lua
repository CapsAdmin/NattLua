return function(META)
    function META:AnalyzeIfStatement(statement)
        local prev_expression
        for i, statements in ipairs(statement.statements) do
            if statement.expressions[i] then
                local obj = self:AnalyzeExpression(statement.expressions[i], "runtime")
                prev_expression = obj

                if obj:IsTruthy() then
                    self:FireEvent("if", i == 1 and "if" or "elseif", true)
                    self:CreateAndPushScope()
                    self:OnEnterConditionalScope({    
                        type = "if",                        
                        if_position = i, 
                        condition = obj,
                        statement = statement,
                    })
                        
                    self:AnalyzeStatements(statements)

                    self:OnExitConditionalScope({
                        type = "if",
                        if_position = i, 
                        condition = obj,
                        statement = statement,
                    })
                    self:PopScope()

                    self:FireEvent("if", i == 1 and "if" or "elseif", false)

                    if not obj:IsFalsy() then
                        break
                    end
                end
            else
                if prev_expression:IsFalsy() then
                    self:FireEvent("if", "else", true)
                    self:CreateAndPushScope()
                    self:OnEnterConditionalScope({
                        type = "if",
                        if_position = i, 
                        is_else = true,
                        condition = prev_expression,
                        statement = statement,
                    })

                    self:AnalyzeStatements(statements)

                    self:PopScope()
                    self:OnExitConditionalScope({
                        type = "if",
                        if_position = i,
                        is_else = true,
                        condition = prev_expression,
                        statement = statement,
                    })
                    self:FireEvent("if", "else", false)
                end
            end
        end
    end
end