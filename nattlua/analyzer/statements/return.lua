local Nil = require("nattlua.types.symbol").Nil
return
	{
		AnalyzeReturn = function(analyzer, statement)
			local ret = analyzer:AnalyzeExpressions(statement.expressions)
			analyzer:Return(statement, ret)
			analyzer:FireEvent("return", ret)
		end,
	}
