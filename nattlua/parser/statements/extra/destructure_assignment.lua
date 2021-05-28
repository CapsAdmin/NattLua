local expression = require("nattlua.parser.expressions.expression").expression
local identifier_list = require("nattlua.parser.statements.identifier_list")

local function IsDestructureStatement(parser, offset)
	offset = offset or 0
	return
		(parser:IsValue("{", offset + 0) and parser:IsType("letter", offset + 1)) or
		(parser:IsType("letter", offset + 0) and parser:IsValue(",", offset + 1) and parser:IsValue("{", offset + 2))
end

local function read_remaining(parser, node)
	if parser:IsCurrentType("letter") then
		local val = parser:Node("expression", "value")
		val.value = parser:ReadTokenLoose()
		node.default = val
		node.default_comma = parser:ReadValue(",")
	end

	node.tokens["{"] = parser:ReadValue("{")
	node.left = identifier_list(parser)
	node.tokens["}"] = parser:ReadValue("}")
	node.tokens["="] = parser:ReadValue("=")
	node.right = expression(parser, 0)
end

return function(self)
	if not IsDestructureStatement(self) then return end
	local node = self:Node("statement", "destructure_assignment")
	read_remaining(self, node)
	return node
end
