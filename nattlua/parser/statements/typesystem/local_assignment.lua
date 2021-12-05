local runtime_syntax = require("nattlua.syntax.runtime")
local ReadExpression = require("nattlua.parser.expressions.typesystem.expression").ReadExpression
local ReadMultipleValues = require("nattlua.parser.statements.multiple_values").ReadMultipleValues
local ReadIdentifier = require("nattlua.parser.expressions.identifier").ReadIdentifier
return
	{
		ReadLocalAssignment = function(parser)
			if not (
				parser:IsValue("local") and parser:IsValue("type", 1) and
				runtime_syntax:GetTokenType(parser:GetToken(2)) == "letter"
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

			return node:End()
		end,
	}
