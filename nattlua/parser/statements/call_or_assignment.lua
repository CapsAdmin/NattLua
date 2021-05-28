local expression_list = require("nattlua.parser.expressions.expression").expression_list

return function(parser)
	local start = parser:GetCurrentToken()
	local left = expression_list(parser,math.huge)

	if parser:IsCurrentValue("=") then
		local node = parser:Node("statement", "assignment")
		node:ExpectKeyword("=")
		node.left = left
		node.right = expression_list(parser, math.huge)
		return node:End()
	end

	if left[1] and (left[1].kind == "postfix_call" or left[1].kind == "import") and not left[2] then
		local node = parser:Node("statement", "call_expression")
		node.value = left[1]
		node.tokens = left[1].tokens
		return node:End()
	end

	parser:Error(
		"expected assignment or call expression got $1 ($2)",
		start,
		parser:GetCurrentToken(),
		parser:GetCurrentToken().type,
		parser:GetCurrentToken().value
	)
end
