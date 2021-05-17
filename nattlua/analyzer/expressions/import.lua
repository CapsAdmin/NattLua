local table = require("table")
return function(analyzer, node, env)
	local args = analyzer:AnalyzeExpressions(node.expressions, env)
	return analyzer:AnalyzeRootStatement(node.root, table.unpack(args))
end
