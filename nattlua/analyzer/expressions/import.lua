local table = require("table")
return {
	AnalyzeImport = function(self, node)
		local args = self:AnalyzeExpressions(node.expressions)
		return self:AnalyzeRootStatement(node.root, table.unpack(args))
	end,
}
