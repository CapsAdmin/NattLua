local Tuple = require("nattlua.types.tuple").Tuple

return
	{
		AnalyzeTuple = function(analyzer, node, env)
			return Tuple(analyzer:AnalyzeExpressions(node.expressions, env)):SetNode(node):SetUnpackable(true)
		end,
	}

