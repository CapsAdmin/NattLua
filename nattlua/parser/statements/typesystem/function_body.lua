local math_huge = math.huge
local table_insert = require("table").insert
local expression_list = require("nattlua.parser.statements.typesystem.expression_list")
local identifier_list = require("nattlua.parser.statements.identifier_list")

local function ReadTypeFunctionArgument(parser)
	if
		(parser:IsCurrentType("letter") or parser:IsCurrentValue("...")) and
		parser:IsValue(":", 1)
	then
		local identifier = parser:ReadTokenLoose()
		local token = parser:ReadValue(":")
		local exp = parser:ReadTypeExpression()
		exp.tokens[":"] = token
		exp.identifier = identifier
		return exp
	end

	return parser:ReadTypeExpression()
end

return function(parser, node, plain_args)
	node.tokens["arguments("] = parser:ReadValue("(")

	if plain_args then
		node.identifiers = identifier_list(parser)
	else
		node.identifiers = {}

		for i = 1, math_huge do
			if parser:HandleListSeparator(node.identifiers, i, ReadTypeFunctionArgument(parser)) then break end
		end
	end

	if parser:IsCurrentValue("...") then
		local vararg = parser:Node("expression", "value")
		vararg.value = parser:ReadValue("...")

		if parser:IsCurrentType("letter") then
			vararg.as_expression = parser:ReadValue()
		end

		table_insert(node.identifiers, vararg)
	end

	node.tokens["arguments)"] = parser:ReadValue(")", node.tokens["arguments("])

	if parser:IsCurrentValue(":") then
		node.tokens[":"] = parser:ReadValue(":")
		node.return_types = expression_list(parser)
	elseif not parser:IsCurrentValue(",") then
		local start = parser:GetCurrentToken()
		node.statements = parser:ReadStatements({["end"] = true})
		node.tokens["end"] = parser:ReadValue("end", start, start)
	end

	return node
end
