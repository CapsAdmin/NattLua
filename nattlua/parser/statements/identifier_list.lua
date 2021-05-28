local identifier = require("nattlua.parser.expressions.identifier")
local multiple_values = require("nattlua.parser.statements.multiple_values")

local function read(parser)
	if not parser:IsCurrentType("letter") and not parser:IsCurrentValue("...") then return end
	return identifier(parser)
end

return function(parser, max)
	return multiple_values(parser, max, read)
end
