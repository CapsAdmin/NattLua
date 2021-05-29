local ReadExpression = require("nattlua.parser.expressions.typesystem.expression").ReadExpression
local ReadMultipleValues = require("nattlua.parser.statements.multiple_values").ReadMultipleValues
return
	{
		ReadAssignment = function(parser)
			if not (parser:IsCurrentValue("type") and (parser:IsType("letter", 1) or parser:IsValue("^", 1))) then return end
			local node = parser:Node("statement", "assignment")
			node.tokens["type"] = parser:ReadValue("type")
			node.left = ReadMultipleValues(parser, nil, ReadExpression, 0)
			node.environment = "typesystem"

			if parser:IsCurrentValue("=") then
				node.tokens["="] = parser:ReadValue("=")
				node.right = ReadMultipleValues(parser, nil, ReadExpression, 0)
			end

			return node
		end,
	}
