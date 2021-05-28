local table = require("nattlua.parser.expressions.table")
local expression_list = require("nattlua.parser.statements.typesystem.expression_list")

return function(parser)
	local expect_expression_list = require("nattlua.parser.expressions.expression").expression_list
	local node = parser:Node("expression", "postfix_call")

	if parser:IsCurrentValue("{") then
		node.expressions = {table(parser)}
	elseif parser:IsCurrentType("string") then
		node.expressions = {
				parser:Node("expression", "value"):Store("value", parser:ReadTokenLoose()):End(),
			}
	elseif parser:IsCurrentValue("<|") then
		node.tokens["call("] = parser:ReadValue("<|")
		node.expressions = expression_list(parser)
		node.tokens["call)"] = parser:ReadValue("|>")
		node.type_call = true
	else
		node.tokens["call("] = parser:ReadValue("(")
		node.expressions = expect_expression_list(parser)
		node.tokens["call)"] = parser:ReadValue(")")
	end

	return node:End()
end
