local Nil = require("nattlua.types.symbol").Nil
return function(analyzer, statement)
	local ret = analyzer:AnalyzeExpressions(statement.expressions)
	
	-- do return end > do return nil end
	if not ret[1] then
		ret[1] = Nil():SetNode(statement)
	end

	analyzer:Return(statement, ret)
	analyzer:FireEvent("return", ret)
end
