local table = require("table")
return
	{
		AnalyzeImport = function(analyzer, node, env)
			local args = analyzer:AnalyzeExpressions(node.expressions, env)
			return analyzer:AnalyzeRootStatement(node.root, table.unpack(args))
		end,
	}
