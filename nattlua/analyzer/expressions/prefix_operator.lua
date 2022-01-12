local Prefix = require("nattlua.analyzer.operators.prefix").Prefix
return
	{
		AnalyzePrefixOperator = function(self, node)
			return self:Assert(node, Prefix(self, node))
		end,
	}
