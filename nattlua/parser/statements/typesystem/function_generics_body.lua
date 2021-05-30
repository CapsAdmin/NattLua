local table_insert = table.insert
local ExpectExpression = require("nattlua.parser.expressions.typesystem.expression").ExpectExpression
local ReadMultipleValues = require("nattlua.parser.statements.multiple_values").ReadMultipleValues
local ReadIdentifier = require("nattlua.parser.expressions.identifier").ReadIdentifier
return
	{
		ReadFunctionGenericsBody = function(parser, node)
			node.tokens["arguments("] = parser:ReadValue("<|")
			node.identifiers = ReadMultipleValues(parser, nil, ReadIdentifier)

			if parser:IsValue("...") then
				local vararg = parser:Node("expression", "value")
				vararg.value = parser:ReadValue("...")
				table_insert(node.identifiers, vararg)
			end

			node.tokens["arguments)"] = parser:ReadValue("|>", node.tokens["arguments("])

			if parser:IsValue(":") then
				node.tokens[":"] = parser:ReadValue(":")
				node.return_types = ReadMultipleValues(parser, math.huge, ExpectExpression)
			else
				local start = parser:GetToken()
				node.statements = parser:ReadNodes({["end"] = true})
				node.tokens["end"] = parser:ReadValue("end", start, start)
			end

			return node
		end,
	}
