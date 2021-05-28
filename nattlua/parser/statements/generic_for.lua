local identifier_list = require("nattlua.parser.statements.identifier_list")
return function(parser)
	if not parser:IsCurrentValue("for") then return nil end
	local node = parser:Node("statement", "generic_for")
	node:ExpectKeyword("for")
	node.identifiers = identifier_list(parser)
	return
		node:ExpectKeyword("in"):ExpectExpressionList():ExpectKeyword("do"):ExpectStatementsUntil("end")
		:ExpectKeyword("end", "do")
		:End()
end
