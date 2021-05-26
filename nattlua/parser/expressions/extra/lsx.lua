return function(parser, as_statement)
	if not (parser:IsCurrentValue("[") and parser:IsType("letter", 1)) then return end
	local node = as_statement and parser:Statement("lsx") or parser:Expression("lsx")
	node.tokens["["] = parser:ReadValue("[")
	node.tag = parser:ReadType("letter")
	local props = {}

	while true do
		if parser:IsCurrentType("letter") and parser:IsValue("=", 1) then
			local key = parser:ReadType("letter")
			parser:ReadValue("=")
			local val = parser:ReadExpectExpression()
			table.insert(props, {key = key, val = val,})
		elseif parser:IsCurrentValue("...") then
			parser:ReadTokenLoose() -- !
            table.insert(
				props,
				{
					val = parser:ReadExpression(nil, true),
					spread = true,
				}
			)
		else
			break
		end
	end

	node.tokens["]"] = parser:ReadValue("]")
	node.props = props

	if parser:IsCurrentValue("{") then
		node.tokens["{"] = parser:ReadValue("{")
		node.statements = parser:ReadStatements({["}"] = true})
		node.tokens["}"] = parser:ReadValue("}")
	end

	return node
end
