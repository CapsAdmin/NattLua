local function read_table_spread(parser)
	if not (
		parser:IsCurrentValue("...") and
		(parser:IsType("letter", 1) or parser:IsValue("{", 1) or parser:IsValue("(", 1))
	) then return end
	return
		parser:Node("expression", "table_spread"):ExpectKeyword("..."):ExpectExpression():End()
end

local function read_table_entry(parser, i)
	local ExpectExpression = require("nattlua.parser.expressions.expression").expect_expression

	if parser:IsCurrentValue("[") then
		local node = parser:Node("expression", "table_expression_value"):Store("expression_key", true):ExpectKeyword("[")
		node.key_expression = ExpectExpression(parser, 0)
		node:ExpectKeyword("]"):ExpectKeyword("=")
		node.value_expression = ExpectExpression(parser, 0)
		return node:End()
	elseif parser:IsCurrentType("letter") and parser:IsValue("=", 1) then
		local node = parser:Node("expression", "table_key_value"):ExpectSimpleIdentifier():ExpectKeyword("=")
		local spread = read_table_spread(parser)

		if spread then
			node.spread = spread
		else
			node.value_expression = ExpectExpression(parser, 0)
		end

		return node:End()
	end

	local node = parser:Node("expression", "table_index_value")
	local spread = read_table_spread(parser)

	if spread then
		node.spread = spread
	else
		node.value_expression = ExpectExpression(parser, 0)
	end

	node.key = i
	return node:End()
end

return function(parser)
	if not parser:IsCurrentValue("{") then return end
	local tree = parser:Node("expression", "table")
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
