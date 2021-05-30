local Postfix = require("nattlua.analyzer.operators.postfix").Postfix
return
	{
		AnalyzePostfixOperator = function(analyzer, node, env)
			return analyzer:Assert(node, Postfix(analyzer, node, analyzer:AnalyzeExpression(node.left, env), env))
		end,
	}
