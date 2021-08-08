local math_huge = math.huge
local table_insert = require("table").insert
local ReadMultipleValues = require("nattlua.parser.statements.multiple_values").ReadMultipleValues
local ExpectTypeExpression = require("nattlua.parser.expressions.typesystem.expression").ExpectExpression
local ReadTypeExpression = require("nattlua.parser.expressions.typesystem.expression").ReadExpression

local function ReadTypeFunctionArgument(parser, expect_type)
	if parser:IsValue(")") then return end
	if parser:IsValue("...") then return end

	if expect_type or parser:IsType("letter") and parser:IsValue(":", 1) then
		local identifier = parser:ReadToken()
		local token = parser:ExpectValue(":")
		local exp = ExpectTypeExpression(parser)
		exp.tokens[":"] = token
		exp.identifier = identifier
		return exp
	end

	return ExpectTypeExpression(parser)
end

return
	{
		ReadAnalyzerFunctionBody = function(parser, node, type_args)
			node.tokens["arguments("] = parser:ExpectValue("(")

			node.identifiers = ReadMultipleValues(parser, math_huge, ReadTypeFunctionArgument, type_args)

			if parser:IsValue("...") then
				local vararg = parser:Node("expression", "value")
				vararg.value = parser:ExpectValue("...")

				if parser:IsValue(":") or type_args then
					vararg.tokens[":"] = parser:ExpectValue(":")
					vararg.type_expression = ExpectTypeExpression(parser)
				else
					if parser:IsType("letter") then
						vararg.type_expression = ExpectTypeExpression(parser)
					end
				end

				vararg:End()
				table_insert(node.identifiers, vararg)
			end

			node.tokens["arguments)"] = parser:ExpectValue(")", node.tokens["arguments("])

			if parser:IsValue(":") then
				node.tokens[":"] = parser:ExpectValue(":")
				node.return_types = ReadMultipleValues(parser, math.huge, ReadTypeExpression)
			elseif not parser:IsValue(",") then
				local start = parser:GetToken()
				node.statements = parser:ReadNodes({["end"] = true})
				node.tokens["end"] = parser:ExpectValue("end", start, start)
			end

			return node
		end,
	}
