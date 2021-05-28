local identifier_list = require("nattlua.parser.statements.identifier_list")
local expression_list = require("nattlua.parser.expressions.expression").expression_list

return function(parser)
	if not parser:IsCurrentValue("for") then return nil end
	local node = parser:Node("statement", "generic_for")
	node:ExpectKeyword("for")
	node.identifiers = identifier_list(parser)
	node:ExpectKeyword("in")
	
	node.expressions = expression_list(parser, math.huge)
	
	return node:ExpectKeyword("do"):ExpectStatementsUntil("end")
		:ExpectKeyword("end", "do")
		:End()
end
