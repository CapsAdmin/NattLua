local math = require("math")
local table_insert = require("table").insert
local table_remove = require("table").remove
local ipairs = _G.ipairs
local syntax = require("nattlua.syntax.syntax")
local ReadFunction = require("nattlua.parser.expressions.function").ReadFunction
local ReadImport = require("nattlua.parser.expressions.extra.import").ReadImport
local ExpectTypeExpression = require("nattlua.parser.expressions.typesystem.expression").ExpectExpression
local ReadTypeExpression = require("nattlua.parser.expressions.typesystem.expression").ReadExpression
local ReadMultipleValues = require("nattlua.parser.statements.multiple_values").ReadMultipleValues
local read_sub_expression
local ReadExpression
local ExpectExpression

local function read_table_spread(parser)
	if not (
		parser:IsValue("...") and
		(parser:IsType("letter", 1) or parser:IsValue("{", 1) or parser:IsValue("(", 1))
	) then return end
	local node = parser:Node("expression", "table_spread"):ExpectKeyword("...")
	node.expression = ExpectExpression(parser)
	return node:End()
end

local function read_table_entry(parser, i)

	if parser:IsValue("[") then
		local node = parser:Node("expression", "table_expression_value"):Store("expression_key", true):ExpectKeyword("[")
		node.key_expression = ExpectExpression(parser, 0)
		node:ExpectKeyword("]"):ExpectKeyword("=")
		node.value_expression = ExpectExpression(parser, 0)
		return node:End()
	elseif parser:IsType("letter") and parser:IsValue("=", 1) then
		local node = parser:Node("expression", "table_key_value"):ExpectSimpleIdentifier():ExpectKeyword("=")
		local spread = read_table_spread(parser)

		if spread then
			node.spread = spread
		else
			node.value_expression = ExpectExpression(parser)
		end

		return node:End()
	end

	local node = parser:Node("expression", "table_index_value")
	local spread = read_table_spread(parser)

	if spread then
		node.spread = spread
	else
		node.value_expression = ExpectExpression(parser)
	end

	node.key = i
	return node:End()
end

local function ReadTable(parser)
	if not parser:IsValue("{") then return end
	local tree = parser:Node("expression", "table")
	tree:ExpectKeyword("{")
	tree.children = {}
	tree.tokens["separators"] = {}

	for i = 1, parser:GetLength() do
		if parser:IsValue("}") then break end
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

		if not parser:IsValue(",") and not parser:IsValue(";") and not parser:IsValue("}") then
			parser:Error(
				"expected $1 got $2",
				nil,
				nil,
				{",", ";", "}"},
				(parser:GetToken() and parser:GetToken().value) or
				"no token"
			)

			break
		end

		if not parser:IsValue("}") then
			tree.tokens["separators"][i] = parser:ReadToken()
		end
	end

	tree:ExpectKeyword("}")
	return tree:End()
end

do
	local function is_call_expression(parser, offset)
		return
			parser:IsValue("(", offset) or
			parser:IsValue("<|", offset) or
			parser:IsValue("{", offset) or
			parser:IsType("string", offset)
	end

	local function read_call_expression(parser)
		local node = parser:Node("expression", "postfix_call")

		if parser:IsValue("{") then
			node.expressions = {ReadTable(parser)}
		elseif parser:IsType("string") then
			node.expressions = {
					parser:Node("expression", "value"):Store("value", parser:ReadToken()):End(),
				}
		elseif parser:IsValue("<|") then
			node.tokens["call("] = parser:ExpectValue("<|")
			node.expressions = ReadMultipleValues(parser, nil, ReadTypeExpression, 0)
			node.tokens["call)"] = parser:ExpectValue("|>")
			node.type_call = true
		else
			node.tokens["call("] = parser:ExpectValue("(")
			node.expressions = ReadMultipleValues(parser, nil, ReadExpression, 0)
			node.tokens["call)"] = parser:ExpectValue(")")
		end

		return node:End()
	end

	local function read_index(parser)
		if not (parser:IsValue(".") and parser:IsType("letter", 1)) then return end
		local node = parser:Node("expression", "binary_operator")
		node.value = parser:ReadToken()
		node.right = parser:Node("expression", "value"):Store("value", parser:ExpectType("letter")):End()
		return node:End()
	end

	local function read_self_call(parser)
		if not (parser:IsValue(":") and parser:IsType("letter", 1) and is_call_expression(parser, 2)) then return end
		local node = parser:Node("expression", "binary_operator")
		node.value = parser:ReadToken()
		node.right = parser:Node("expression", "value"):Store("value", parser:ExpectType("letter")):End()
		return node:End()
	end

	local function read_postfix_operator(parser)
		if not syntax.IsPostfixOperator(parser:GetToken()) then return end
		return
			parser:Node("expression", "postfix_operator"):Store("value", parser:ReadToken()):End()
	end

	local function read_call(parser)
		if not is_call_expression(parser, 0) then return end
		return read_call_expression(parser)
	end

	local function read_postfix_index_expression(parser)
		if not parser:IsValue("[") then return end
		local node = parser:Node("expression", "postfix_expression_index"):ExpectKeyword("[")
		node.expression = ExpectExpression(parser)
		return node:ExpectKeyword("]"):End()
	end

	local function read_and_add_explicit_type(parser, node)
		if parser:IsValue(":") and (not parser:IsType("letter", 1) or not is_call_expression(parser, 2)) then
			node.tokens[":"] = parser:ExpectValue(":")
			node.as_expression = ExpectTypeExpression(parser, 0)
		elseif parser:IsValue("as") then
			node.tokens["as"] = parser:ExpectValue("as")
			node.as_expression = ExpectTypeExpression(parser, 0)
		elseif parser:IsValue("is") then
			node.tokens["is"] = parser:ExpectValue("is")
			node.as_expression = ExpectTypeExpression(parser, 0)
		end
	end

	function read_sub_expression(parser, node)
		for _ = 1, parser:GetLength() do
			local left_node = node
			read_and_add_explicit_type(parser, node)
			local found = read_index(parser) or
				read_self_call(parser) or
				read_postfix_operator(parser) or
				read_call(parser) or
				read_postfix_index_expression(parser)
			if not found then break end
			found.left = left_node

			if left_node.value and left_node.value.value == ":" then
				found.parser_call = true
			end

			node = found
		end

		return node
	end
end

do
	local function prefix_operator(parser)
		if not syntax.IsPrefixOperator(parser:GetToken()) then return end
		local node = parser:Node("expression", "prefix_operator")
		node.value = parser:ReadToken()
		node.tokens[1] = node.value
		node.right = ExpectExpression(parser, math.huge)
		return node:End()
	end

	local function parenthesis(parser)
		if not parser:IsValue("(") then return end
		local pleft = parser:ExpectValue("(")
		local node = ReadExpression(parser, 0)

		if not node then
			parser:Error("empty parentheses group", pleft)
			return
		end

		node.tokens["("] = node.tokens["("] or {}
		table_insert(node.tokens["("], 1, pleft)
		node.tokens[")"] = node.tokens[")"] or {}
		table_insert(node.tokens[")"], parser:ExpectValue(")"))
		return node
	end

	local function value(parser)
		if not syntax.IsValue(parser:GetToken()) then return end
		return
			parser:Node("expression", "value"):Store("value", parser:ReadToken()):End()
	end

	local function check_integer_division_operator(parser, node)
		if node and not node.idiv_resolved then
			for i, token in ipairs(node.whitespace) do
				if token.type == "line_comment" and token.value:sub(1, 2) == "//" then
					table_remove(node.whitespace, i)
					local tokens = require("nattlua.lexer.lexer")("/idiv" .. token.value:sub(2)):GetTokens()

					for _, token in ipairs(tokens) do
						check_integer_division_operator(parser, token)
					end

					parser:AddTokens(tokens)
					node.idiv_resolved = true

					break
				end
			end
		end
	end

	function ReadExpression(parser, priority)
		priority = priority or 0
		local node = parenthesis(parser) or
			prefix_operator(parser) or
			ReadFunction(parser) or
			ReadImport(parser) or
			value(parser) or
			ReadTable(parser)
		local first = node

		if node then
			node = read_sub_expression(parser, node)

			if
				first.kind == "value" and
				(first.value.type == "letter" or first.value.value == "...")
			then
				first.standalone_letter = node
			end
		end

		check_integer_division_operator(parser, parser:GetToken())

		while syntax.GetBinaryOperatorInfo(parser:GetToken()) and
		syntax.GetBinaryOperatorInfo(parser:GetToken()).left_priority > priority do
			local left_node = node
			node = parser:Node("expression", "binary_operator")
			node.value = parser:ReadToken()
			node.left = left_node
			node.left.parent = node
			node.right = ReadExpression(parser, syntax.GetBinaryOperatorInfo(node.value).right_priority)
			node:End()
		end

		return node
	end
end

ExpectExpression = function(parser, priority)
	local token = parser:GetToken()

	if
		not token or
		token.type == "end_of_file" or
		token.value == "}" or
		token.value == "," or
		token.value == "]" or
		(
			syntax.IsKeyword(token) and
			not syntax.IsPrefixOperator(token) and
			not syntax.IsValue(token) and
			token.value ~= "function"
		)
	then
		parser:Error(
			"expected beginning of expression, got $1",
			nil,
			nil,
			token and
			token.value ~= "" and
			token.value or
			token.type
		)
		return
	end

	return ReadExpression(parser, priority)
end
return
	{
		ReadExpression = ReadExpression,
		ExpectExpression = ExpectExpression,
	}
