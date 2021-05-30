local Prefix = require("nattlua.analyzer.operators.prefix").Prefix
return
	{
		AnalyzePrefixOperator = function(analyzer, node, env)
			return analyzer:Assert(node, Prefix(analyzer, node, analyzer:AnalyzeExpression(node.right, env), env))
		end,
	}
