local Tuple = require("nattlua.types.tuple").Tuple
local AnalyzeFunction = require("nattlua.analyzer.expressions.function").AnalyzeFunction

return
	{
		AnalyzeFunctionSignature = function(analyzer, node, env)
			return AnalyzeFunction(analyzer, node)
		end,
	}

