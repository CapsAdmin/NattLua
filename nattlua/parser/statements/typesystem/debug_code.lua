return function(parser)
	if not parser:IsCurrentType("type_code") then return end
	local node = parser:Statement("type_code")
	local code = parser:Expression("value")
	code.value = parser:ReadType("type_code")
	node.lua_code = code
	return node
end
