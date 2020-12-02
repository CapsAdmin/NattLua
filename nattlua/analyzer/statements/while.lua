return function(META)
    function META:AnalyzeWhileStatement(statement)
        local obj = self:AnalyzeExpression(statement.expression)
        if obj:IsTruthy() then
            self:CreateAndPushScope()
            self:OnEnterScope({
                type = "while",
                condition = obj
            })
            self:AnalyzeStatements(statement.statements)
            self:PopScope()
            self:OnExitScope({
                condition = obj
            })
        end
    end
end