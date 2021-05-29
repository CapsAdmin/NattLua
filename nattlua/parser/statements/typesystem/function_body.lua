local math_huge = math.huge
local table_insert = require("table").insert
local ReadMultipleValues = require("nattlua.parser.statements.multiple_values")
local multiple_values = require("nattlua.parser.statements.multiple_values")
local ExpectTypeExpression = require("nattlua.parser.expressions.typesystem.expression").expect_expression
local type_expression_list = require("nattlua.parser.expressions.typesystem.expression").expression_list
local ReadIdentifier = require("nattlua.parser.expressions.identifier")

local function ReadTypeFunctionArgument(parser)
	if
		(parser:IsCurrentType("letter") or parser:IsCurrentValue("...")) and
		parser:IsValue(":", 1)
	then
		local identifier = parser:ReadTokenLoose()
		local token = parser:ReadValue(":")
		local exp = ExpectTypeExpression(parser)
		exp.tokens[":"] = token
		exp.identifier = identifier
		return exp
	end

	return ExpectTypeExpression(parser)
end

return function(parser, node, plain_args)
	node.tokens["arguments("] = parser:ReadValue("(")

	if plain_args then
		node.identifiers = ReadMultipleValues(parser, nil, ReadIdentifier)
	else
		node.identifiers = multiple_values(parser, math_huge, ReadTypeFunctionArgument)
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
		node.return_types = type_expression_list(parser)
	elseif not parser:IsCurrentValue(",") then
		local start = parser:GetCurrentToken()
		node.statements = parser:ReadNodes({["end"] = true})
		node.tokens["end"] = parser:ReadValue("end", start, start)
	end

	return node
end
