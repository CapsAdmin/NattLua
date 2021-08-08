local table_insert = require("table").insert
local syntax = require("nattlua.syntax.syntax")
local math_huge = math.huge
local ReadMultipleValues = require("nattlua.parser.statements.multiple_values").ReadMultipleValues
local ReadExpression

local function ExpectExpression(parser, priority)
	local token = parser:GetToken()

	if
		not token or
		token.type == "end_of_file" or
		token.value == "}" or
		token.value == "," or
		token.value == "]" or
		(
			syntax.typesystem.IsKeyword(token) and
			not syntax.typesystem.IsPrefixOperator(token) and
			not syntax.typesystem.IsValue(token) and
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

local function read_parenthesis(parser)
	if not parser:IsValue("(") then return end
	local pleft = parser:ExpectValue("(")
	local node = ReadExpression(parser, 0)

	if not node or parser:IsValue(",") then
		local first_expression = node
		local node = parser:Node("expression", "tuple")
		
		if parser:IsValue(",") then
			first_expression.tokens[","] = parser:ExpectValue(",")
			node.expressions = ReadMultipleValues(parser, nil, ReadExpression, 0)
		else
			node.expressions = {}
		end

		if first_expression then
			table.insert(node.expressions, 1, first_expression)
		end
		node.tokens["("] = pleft
		node:ExpectKeyword(")")
		return node:End()
	end

	node.tokens["("] = node.tokens["("] or {}
	table_insert(node.tokens["("], 1, pleft)
	node.tokens[")"] = node.tokens[")"] or {}
	table_insert(node.tokens[")"], parser:ExpectValue(")"))
	return node:End()
end

local function read_prefix_operator(parser)
	if not syntax.typesystem.IsPrefixOperator(parser:GetToken()) then return end
	local node = parser:Node("expression", "prefix_operator")
	node.value = parser:ReadToken()
	node.tokens[1] = node.value
	node.right = ReadExpression(parser, math_huge)
	return node:End()
end

local function read_value(parser)
	if not (parser:IsValue("...") and parser:IsType("letter", 1)) then return end
	local node = parser:Node("expression", "value")
	node.value = parser:ExpectValue("...")
	node.type_expression = ReadExpression(parser)
	return node:End()
end

local function read_type_function(parser)
	if not (parser:IsValue("function") and parser:IsValue("(", 1)) then return end
	local ReadAnalyzerFunctionBody = require("nattlua.parser.statements.typesystem.analyzer_function_body").ReadAnalyzerFunctionBody
	local node = parser:Node("expression", "analyzer_function")
	node.stmnt = false
	node.tokens["function"] = parser:ExpectValue("function")
	local lol = ReadAnalyzerFunctionBody(parser, node):End()
	return lol
end

local function read_generics_type_function(parser)
	if not (parser:IsValue("function") and parser:IsValue("<|", 1)) then return end
	local ReadTypeFunctionBody = require("nattlua.parser.statements.typesystem.type_function_body").ReadTypeFunctionBody
	local node = parser:Node("expression", "type_function")
	node.stmnt = false
	node.tokens["function"] = parser:ExpectValue("function")
	return ReadTypeFunctionBody(parser, node):End()
end

local function read_keyword_value(parser)
	if not syntax.typesystem.IsValue(parser:GetToken()) then return end
	local node = parser:Node("expression", "value")
	node.value = parser:ReadToken()
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
		local node = parser:Node("expression", "table_key_value"):ExpectSimpleIdentifier():ExpectKeyword("="):End()
		node.value_expression = ExpectExpression(parser, 0)
		return node:End()
	end

	local node = parser:Node("expression", "table_index_value"):Store("key", i)
	node.value_expression = ReadExpression(parser, 0)
	return node:End()
end

local function read_type_table(parser)
	if not parser:IsValue("{") then return end
	local tree = parser:Node("expression", "type_table")
	tree:ExpectKeyword("{")
	tree.children = {}
	tree.tokens["separators"] = {}

	for i = 1, math_huge do
		if parser:IsValue("}") then break end
		local entry = read_table_entry(parser, i)

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

local function read_string(parser)
	if not (parser:IsType("$") and parser:IsType("string", 1)) then return end
	local node = parser:Node("expression", "type_string")
	node.tokens["$"] = parser:ReadToken("...")
	node.value = parser:ExpectType("string")
	return node
end

local function read_empty_union(parser)
	if not parser:IsValue("|") then return end
	local node = parser:Node("expression", "empty_union")
	node.tokens["|"] = parser:ReadToken("|")
	return node
end

local read_sub_expression

do
	local function is_call_expression(parser, offset)
		return
			parser:IsValue("(", offset) or
			parser:IsValue("<|", offset) or
			parser:IsValue("{", offset) or
			parser:IsType("string", offset)
	end

	local function read_as_expression(parser, node)
		if not parser:IsValue("as") then return end
		node.tokens["as"] = parser:ExpectValue("as")
		node.type_expression = ReadExpression(parser)
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
		if not syntax.typesystem.IsPostfixOperator(parser:GetToken()) then return end
		return
			parser:Node("expression", "postfix_operator"):Store("value", parser:ReadToken()):End()
	end

	local function read_call(parser)
		if not is_call_expression(parser, 0) then return end
		local node = parser:Node("expression", "postfix_call")

		if parser:IsValue("{") then
			node.expressions = {read_type_table(parser)}
		elseif parser:IsType("string") then
			node.expressions = {
					parser:Node("expression", "value"):Store("value", parser:ReadToken()):End(),
				}
		elseif parser:IsValue("<|") then
			node.tokens["call("] = parser:ExpectValue("<|")
			node.expressions = ReadMultipleValues(parser, nil, ReadExpression, 0)
			node.tokens["call)"] = parser:ExpectValue("|>")
		else
			node.tokens["call("] = parser:ExpectValue("(")
			node.expressions = ReadMultipleValues(parser, nil, ReadExpression, 0)
			node.tokens["call)"] = parser:ExpectValue(")")
		end

		node.type_call = true
		return node:End()
	end

	local function read_postfix_index_expression(parser)
		if not parser:IsValue("[") then return end
		local node = parser:Node("expression", "postfix_expression_index"):ExpectKeyword("[")
		node.expression = ExpectExpression(parser)
		return node:ExpectKeyword("]"):End()
	end

	function read_sub_expression(parser, node)
		for _ = 1, parser:GetLength() do
			local left_node = node
			local found = read_index(parser) or
				read_self_call(parser) or
				read_postfix_operator(parser) or
				read_call(parser) or
				read_postfix_index_expression(parser) or
				read_as_expression(parser, left_node)
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

ReadExpression = function(parser, priority)
	priority = priority or 0
	local node
	local force_upvalue

	if parser:IsValue("^") then
		force_upvalue = true
		parser:Advance(1)
	end

	node = read_parenthesis(parser) or
		read_empty_union(parser) or
		read_prefix_operator(parser) or
		read_type_function(parser) or
		read_generics_type_function(parser) or
		read_value(parser) or
		read_keyword_value(parser) or
		read_type_table(parser) or
		read_string(parser)
	local first = node

	if node then
		node = read_sub_expression(parser, node)

		if
			first.kind == "value" and
			(first.value.type == "letter" or first.value.value == "...")
		then
			first.standalone_letter = node
			first.force_upvalue = force_upvalue
		end
	end

	while syntax.typesystem.GetBinaryOperatorInfo(parser:GetToken()) and
	syntax.typesystem.GetBinaryOperatorInfo(parser:GetToken()).left_priority > priority do
		local left_node = node
		node = parser:Node("expression", "binary_operator")
		node.value = parser:ReadToken()
		node.left = left_node
		node.right = ReadExpression(parser, syntax.typesystem.GetBinaryOperatorInfo(node.value).right_priority)
		node:End()
	end

	return node
end
return
	{
		ReadExpression = ReadExpression,
		ExpectExpression = ExpectExpression,
	}
