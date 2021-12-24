local Tuple = require("nattlua.types.tuple").Tuple

return
	{
		AnalyzeTuple = function(analyzer, node)
			return Tuple(analyzer:AnalyzeExpressions(node.expressions)):SetNode(node):SetUnpackable(true)
		end,
	}

