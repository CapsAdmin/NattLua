return function(META) 
    function META:AnalyzeDoStatement(statement)
        self:CreateAndPushScope(statement, nil, {
            type = "do"
        })
        self:AnalyzeStatements(statement.statements)
        self:PopScope()
    end
end