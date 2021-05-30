local expression = require("nattlua.parser.expressions.expression").ReadExpression
local ReadMultipleValues = require("nattlua.parser.statements.multiple_values").ReadMultipleValues
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
		node.default = val
		node.default_comma = parser:ReadValue(",")
	end

	node.tokens["{"] = parser:ReadValue("{")
	node.left = ReadMultipleValues(parser, nil, ReadIdentifier)
	node.tokens["}"] = parser:ReadValue("}")
	node.tokens["="] = parser:ReadValue("=")
	node.right = expression(parser, 0)
end

return
	{
		ReadDestructureAssignment = function(self)
			if not IsDestructureNode(self) then return end
			local node = self:Node("statement", "destructure_assignment")
			read_remaining(self, node)
			return node
		end,
	}
