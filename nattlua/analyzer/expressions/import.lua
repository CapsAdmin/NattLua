local table = require("table")
return
	{
		AnalyzeImport = function(analyzer, node)
			local args = analyzer:AnalyzeExpressions(node.expressions)
			return analyzer:AnalyzeRootStatement(node.root, table.unpack(args))
		end,
	}
