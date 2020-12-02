return function(META) 
    function META:AnalyzeDoStatement(statement)
        self:CreateAndPushScope()
        self:AnalyzeStatements(statement.statements)
        self:PopScope()
    end
end