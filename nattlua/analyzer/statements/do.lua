return function(META) 
    function META:AnalyzeDoStatement(statement)
        self:CreateAndPushScope()
        self:FireEvent("enter_do_scope")
        self:AnalyzeStatements(statement.statements)
        self:FireEvent("leave_scope")
        self:PopScope()
    end
end