local function_body = require("nattlua.parser.statements.function_body")
return function(parser)
	if not parser:IsCurrentValue("function") then return end
	local node = parser:Expression("function"):ExpectKeyword("function")
	function_body(parser, node)
	return node:End()
end
