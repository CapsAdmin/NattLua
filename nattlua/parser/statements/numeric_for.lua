local identifier_list = require("nattlua.parser.statements.identifier_list")
local expression_list = require("nattlua.parser.expressions.expression").expression_list

return function(parser)
	if not (parser:IsCurrentValue("for") and parser:IsValue("=", 2)) then return nil end
	local node = parser:Node("statement", "numeric_for")
	node:ExpectKeyword("for")
	node.identifiers = identifier_list(parser, 1)
	node:ExpectKeyword("=")
	node.expressions = expression_list(parser, 3)
	
	return node:ExpectKeyword("do"):ExpectStatementsUntil("end")
		:ExpectKeyword("end", "do")
		:End()
end
