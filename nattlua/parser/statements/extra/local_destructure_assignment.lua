local ReadMultipleValues = require("nattlua.parser.statements.multiple_values").ReadMultipleValues
local expression = require("nattlua.parser.expressions.expression").ReadExpression
local ReadIdentifier = require("nattlua.parser.expressions.identifier").ReadIdentifier

local function IsDestructureNode(parser, offset)
	offset = offset or 0
	return
		(parser:IsValue("{", offset + 0) and parser:IsType("letter", offset + 1)) or
		(parser:IsType("letter", offset + 0) and parser:IsValue(",", offset + 1) and parser:IsValue("{", offset + 2))
end

local function read_remaining(parser, node)
	if parser:IsType("letter") then
		local val = parser:Node("expression", "value")
		val.value = parser:ReadToken()
		node.default = val:End()
		node.default_comma = parser:ExpectValue(",")
	end

	node.tokens["{"] = parser:ExpectValue("{")
	node.left = ReadMultipleValues(parser, nil, ReadIdentifier)
	node.tokens["}"] = parser:ExpectValue("}")
	node.tokens["="] = parser:ExpectValue("=")
	node.right = expression(parser, 0)
end

local function IsLocalDestructureAssignmentNode(parser)
	if parser:IsValue("local") then
		if parser:IsValue("type", 1) then return IsDestructureNode(parser, 2) end
		return IsDestructureNode(parser, 1)
	end
end

return
	{
		ReadLocalDestructureAssignment = function(parser)
			if not IsLocalDestructureAssignmentNode(parser) then return end
			local node = parser:Node("statement", "local_destructure_assignment")
			node.tokens["local"] = parser:ExpectValue("local")

			if parser:IsValue("type") then
				node.tokens["type"] = parser:ExpectValue("type")
				node.environment = "typesystem"
			end

			read_remaining(parser, node)
			return node:End()
		end,
	}
