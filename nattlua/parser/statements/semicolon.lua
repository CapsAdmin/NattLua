return function(parser)
	if not parser:IsCurrentValue(";") then return end
	local node = parser:Statement("semicolon")
	node.tokens[";"] = parser:ReadValue(";")
	return node
end
