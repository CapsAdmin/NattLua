return function(META)
    function META:AnalyzeRepeatStatement(statement)
        self:CreateAndPushScope()
        self:AnalyzeStatements(statement.statements)
        if self:AnalyzeExpression(statement.expression):IsTruthy() then
            self:FireEvent("break")
        end
        self:PopScope()
    end
end