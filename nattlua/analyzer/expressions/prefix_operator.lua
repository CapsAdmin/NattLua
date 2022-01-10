local Prefix = require("nattlua.analyzer.operators.prefix").Prefix
return
	{
		AnalyzePrefixOperator = function(analyzer, node)
			return analyzer:Assert(node, Prefix(analyzer, node))
		end,
	}
