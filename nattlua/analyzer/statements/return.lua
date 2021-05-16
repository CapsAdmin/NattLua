return function(analyzer, statement)
	local ret = analyzer:AnalyzeExpressions(statement.expressions)
	
	-- do return end > do return nil end
	if not ret[1] then
		ret[1] = analyzer:NewType(statement, "nil")
	end

	analyzer:Return(statement, ret)
	analyzer:FireEvent("return", ret)
end
