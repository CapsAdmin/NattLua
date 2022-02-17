local Tuple = require("nattlua.types.tuple").Tuple
return {
	AnalyzeTuple = function(self, node)
		return Tuple(self:AnalyzeExpressions(node.expressions)):SetNode(node):SetUnpackable(true)
	end,
}
