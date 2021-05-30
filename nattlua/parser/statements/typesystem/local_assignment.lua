local syntax = require("nattlua.syntax.syntax")
local ReadExpression = require("nattlua.parser.expressions.typesystem.expression").ReadExpression
local ReadMultipleValues = require("nattlua.parser.statements.multiple_values").ReadMultipleValues
local ReadIdentifier = require("nattlua.parser.expressions.identifier").ReadIdentifier
return
	{
		ReadLocalAssignment = function(parser)
			if not (
				parser:IsValue("local") and parser:IsValue("type", 1) and
				syntax.GetTokenType(parser:GetToken(2)) == "letter"
			) then return end
			local node = parser:Node("statement", "local_assignment")
			node.tokens["local"] = parser:ExpectValue("local")
			node.tokens["type"] = parser:ExpectValue("type")
			node.left = ReadMultipleValues(parser, nil, ReadIdentifier)
			node.environment = "typesystem"

			if parser:IsValue("=") then
				node.tokens["="] = parser:ExpectValue("=")
				node.right = ReadMultipleValues(parser, nil, ReadExpression)
			end

			return node
		end,
	}
