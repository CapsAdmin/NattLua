local math_huge = math.huge
local table_insert = require("table").insert
local ReadMultipleValues = require("nattlua.parser.statements.multiple_values").ReadMultipleValues
local ExpectTypeExpression = require("nattlua.parser.expressions.typesystem.expression").ExpectExpression
local ReadTypeExpression = require("nattlua.parser.expressions.typesystem.expression").ReadExpression
local ReadIdentifier = require("nattlua.parser.expressions.identifier").ReadIdentifier

local function ReadTypeFunctionArgument(parser)
	if
		(parser:IsType("letter") or parser:IsValue("...")) and
		parser:IsValue(":", 1)
	then
		local identifier = parser:ReadToken()
		local token = parser:ReadValue(":")
		local exp = ExpectTypeExpression(parser)
		exp.tokens[":"] = token
		exp.identifier = identifier
		return exp
	end

	return ExpectTypeExpression(parser)
end

return
	{
		ReadFunctionBody = function(parser, node, plain_args)
			node.tokens["arguments("] = parser:ReadValue("(")

			if plain_args then
				node.identifiers = ReadMultipleValues(parser, nil, ReadIdentifier)
			else
				node.identifiers = ReadMultipleValues(parser, math_huge, ReadTypeFunctionArgument)
			end

			if parser:IsValue("...") then
				local vararg = parser:Node("expression", "value")
				vararg.value = parser:ReadValue("...")

				if parser:IsType("letter") then
					vararg.as_expression = parser:ReadValue()
				end

				table_insert(node.identifiers, vararg)
			end

			node.tokens["arguments)"] = parser:ReadValue(")", node.tokens["arguments("])

			if parser:IsValue(":") then
				node.tokens[":"] = parser:ReadValue(":")
				node.return_types = ReadMultipleValues(parser, math.huge, ReadTypeExpression)
			elseif not parser:IsValue(",") then
				local start = parser:GetToken()
				node.statements = parser:ReadNodes({["end"] = true})
				node.tokens["end"] = parser:ReadValue("end", start, start)
			end

			return node
		end,
	}
