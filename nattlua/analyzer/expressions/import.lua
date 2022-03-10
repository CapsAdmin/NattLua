local table = require("table")
return {
	AnalyzeImport = function(self, node)
		return self:AnalyzeRootStatement(node.root)
	end,
}
