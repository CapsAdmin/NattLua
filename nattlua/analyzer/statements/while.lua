return function(META)
    function META:AnalyzeWhileStatement(statement)
        local obj = self:AnalyzeExpression(statement.expression)
        if obj:IsTruthy() then
            self:CreateAndPushScope({
                type = "while",
                condition = obj
            })
            self:AnalyzeStatements(statement.statements)
            self:PopScope({
                condition = obj
            })
        end
    end
end