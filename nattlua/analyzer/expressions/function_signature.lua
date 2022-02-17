local Tuple = require("nattlua.types.tuple").Tuple
local AnalyzeFunction = require("nattlua.analyzer.expressions.function").AnalyzeFunction
return {
	AnalyzeFunctionSignature = function(self, node)
		return AnalyzeFunction(self, node)
	end,
}
