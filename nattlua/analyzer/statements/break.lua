return function(analyzer, statement)
    analyzer.break_out_scope = analyzer:GetScope()
    analyzer.break_loop = true
    analyzer:FireEvent("break")
end