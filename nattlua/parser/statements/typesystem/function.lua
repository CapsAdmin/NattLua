local function_body = require("nattlua.parser.statements.typesystem.function_body")
local index_expression = require("nattlua.parser.expressions.index_expression")
return function(parser)
	if not (parser:IsCurrentValue("type") and parser:IsValue("function", 1)) then return end
	local node = parser:Statement("type_function")
	node.tokens["type"] = parser:ReadValue("type")
	node.tokens["function"] = parser:ReadValue("function")
	local force_upvalue

	if parser:IsCurrentValue("^") then
		force_upvalue = true
		node.tokens["^"] = parser:ReadTokenLoose()
	end

	node.expression = index_expression(parser)

	do -- hacky
        if node.expression.left then
			node.expression.left.standalone_letter = node
			node.expression.left.force_upvalue = force_upvalue
		else
			node.expression.standalone_letter = node
			node.expression.force_upvalue = force_upvalue
		end

		if node.expression.value.value == ":" then
			node.self_call = true
		end
	end

	function_body(parser, node, true)
	return node
end
