local function table_spread(parser)
	if not (
		parser:IsCurrentValue("...") and
		(parser:IsType("letter", 1) or parser:IsValue("{", 1) or parser:IsValue("(", 1))
	) then return end
	return
		parser:Expression("table_spread"):ExpectKeyword("..."):ExpectExpression():End()
end

local function read_table_entry(parser, i)
	local node

	if parser:IsCurrentValue("[") then
		node = parser:Expression("table_expression_value"):Store("expression_key", true):ExpectKeyword("[")
			:ExpectExpression()
			:ExpectKeyword("]")
			:ExpectKeyword("=")
	elseif parser:IsCurrentType("letter") and parser:IsValue("=", 1) then
		node = parser:Expression("table_key_value"):ExpectSimpleIdentifier():ExpectKeyword("=")
	else
		node = parser:Expression("table_index_value")
		node.key = i
	end

	node.spread = table_spread(parser)

	if not node.spread then
		node:ExpectExpression()
	end

	return node:End()
end

return function(parser)
	if not parser:IsCurrentValue("{") then return end
	local tree = parser:Expression("table")
	tree:ExpectKeyword("{")
	tree.children = {}
	tree.tokens["separators"] = {}

	for i = 1, parser:GetLength() do
		if parser:IsCurrentValue("}") then break end
		local entry = read_table_entry(parser, i)

		if entry.kind == "table_index_value" then
			tree.is_array = true
		else
			tree.is_dictionary = true
		end

		if entry.spread then
			tree.spread = true
		end

		tree.children[i] = entry

		if not parser:IsCurrentValue(",") and not parser:IsCurrentValue(";") and not parser:IsCurrentValue("}") then
			parser:Error(
				"expected $1 got $2",
				nil,
				nil,
				{",", ";", "}"},
				(parser:GetCurrentToken() and parser:GetCurrentToken().value) or
				"no token"
			)

			break
		end

		if not parser:IsCurrentValue("}") then
			tree.tokens["separators"][i] = parser:ReadTokenLoose()
		end
	end

	tree:ExpectKeyword("}")
	return tree:End()
end
