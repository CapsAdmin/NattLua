local table = require("table")
local Binary = require("nattlua.analyzer.operators.binary").Binary
local Nil = require("nattlua.types.symbol").Nil
local assert = _G.assert
return
	{
		AnalyzeBinaryOperator = function(analyzer, node)
			return analyzer:Assert(node, Binary(analyzer, node))
		end,
	}
