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
                        condition = obj
                    })
                        
                    self:AnalyzeStatements(statements)

                    self:PopScope()
                    self:OnExitConditionalScope({
                        type = "if",
                        if_position = i, 
                        condition = obj
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
                        condition = prev_expression
                    })

                    self:AnalyzeStatements(statements)

                    self:PopScope()
                    self:OnExitConditionalScope({
                        type = "if",
                        if_position = i,
                        is_else = true,
                        condition = prev_expression
                    })
                end
            end
        end
        self:OnLeaveIfStatement()
    end
end