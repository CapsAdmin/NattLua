local Binary = require("nattlua.analyzer.operators.binary").Binary
return {
	AnalyzeBinaryOperator = function(self, node)
		return self:Assert(Binary(self, node))
	end,
}
