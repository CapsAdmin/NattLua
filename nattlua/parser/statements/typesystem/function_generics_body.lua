local table_insert = table.insert
local type_expression_list = require("nattlua.parser.statements.typesystem.expression_list")
local ReadMultipleValues = require("nattlua.parser.statements.multiple_values")
local ReadIdentifier = require("nattlua.parser.expressions.identifier")
return function(parser, node)
	node.tokens["arguments("] = parser:ReadValue("<|")
	node.identifiers = ReadMultipleValues(parser, nil, ReadIdentifier)

	if parser:IsCurrentValue("...") then
		local vararg = parser:Node("expression", "value")
		vararg.value = parser:ReadValue("...")
		table_insert(node.identifiers, vararg)
	end

	node.tokens["arguments)"] = parser:ReadValue("|>", node.tokens["arguments("])

	if parser:IsCurrentValue(":") then
		node.tokens[":"] = parser:ReadValue(":")
		node.return_types = type_expression_list(parser)
	else
		local start = parser:GetCurrentToken()
		node.statements = parser:ReadNodes({["end"] = true})
		node.tokens["end"] = parser:ReadValue("end", start, start)
	end

	return node
end
