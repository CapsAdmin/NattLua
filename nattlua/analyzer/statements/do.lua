return function(META) 
    function META:AnalyzeDoStatement(statement)
        self:CreateAndPushScope({
            type = "do"
        })
        self:AnalyzeStatements(statement.statements)
        self:PopScope()
    end
end