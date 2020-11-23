return function(META)
    function META:AnalyzeBreakStatement(statement)
        self.break_out = {
            scope = self:GetScope()
        }
        self:FireEvent("break")
    end
end