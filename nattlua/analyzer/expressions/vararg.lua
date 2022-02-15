local VarArg = require("nattlua.types.tuple").VarArg

return
	{
		AnalyzeVararg = function(self, node)
			return VarArg(self:AnalyzeExpression(node.value)):SetNode(node)
		end,
	}



