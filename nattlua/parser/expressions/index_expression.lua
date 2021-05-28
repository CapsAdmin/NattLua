local syntax = require("nattlua.syntax.syntax")
return function(parser)
	if not syntax.IsValue(parser:GetCurrentToken()) then return end
	local node = parser:Node("expression", "value"):Store("value", parser:ReadTokenLoose()):End()
	local first = node

	while parser:IsCurrentValue(".") or parser:IsCurrentValue(":") do
		local left = node
		local self_call = parser:IsCurrentValue(":")
		node = parser:Node("expression", "binary_operator")
		node.value = parser:ReadTokenLoose()
		node.right = parser:Node("expression", "value"):Store("value", parser:ReadType("letter")):End()
		node.left = left
		node:End()
		node.right.self_call = self_call
	end

	first.standalone_letter = node
	return node
end
