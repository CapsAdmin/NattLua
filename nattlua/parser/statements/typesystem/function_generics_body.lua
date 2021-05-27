local table_insert = table.insert
local expression_list = require("nattlua.parser.statements.typesystem.expression_list")
local identifier_list = require("nattlua.parser.statements.identifier_list")
return function(parser, node)
	node.tokens["arguments("] = parser:ReadValue("<|")
	node.identifiers = identifier_list(parser)

	if parser:IsCurrentValue("...") then
		local vararg = parser:Expression("value")
		vararg.value = parser:ReadValue("...")
		table_insert(node.identifiers, vararg)
	end

	node.tokens["arguments)"] = parser:ReadValue("|>", node.tokens["arguments("])

	if parser:IsCurrentValue(":") then
		node.tokens[":"] = parser:ReadValue(":")
		node.return_types = expression_list(parser)
	else
		local start = parser:GetCurrentToken()
		node.statements = parser:ReadStatements({["end"] = true})
		node.tokens["end"] = parser:ReadValue("end", start, start)
	end

	return node
end
