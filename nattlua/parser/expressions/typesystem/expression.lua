local table_insert = require("table").insert
local syntax = require("nattlua.syntax.syntax")
local math_huge = math.huge
local ReadMultipleValues = require("nattlua.parser.statements.multiple_values")
local read_expression

local function expect_expression(parser, priority)
	local token = parser:GetCurrentToken()

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

	return read_expression(parser, priority)
end

local function type_expression_list(parser, max)
	return ReadMultipleValues(parser, max, read_expression)
end

local function type_table_entry(self, i)
	if self:IsCurrentValue("[") then
		local node = self:Node("expression", "table_expression_value"):Store("expression_key", true):ExpectKeyword("[")
		node.key_expression = expect_expression(self, 0)
		node:ExpectKeyword("]"):ExpectKeyword("=")
		node.value_expression = expect_expression(self, 0)
		return node:End()
	elseif self:IsCurrentType("letter") and self:IsValue("=", 1) then
		local node = self:Node("expression", "table_key_value"):ExpectSimpleIdentifier():ExpectKeyword("=")
		node.value_expression = expect_expression(self, 0)
		return node:End()
	end

	local node = self:Node("expression", "table_index_value"):Store("key", i)
	node.value_expression = read_expression(self, 0)
	return node:End()
end

local function type_table(parser)
	local tree = parser:Node("expression", "type_table")
	tree:ExpectKeyword("{")
	tree.children = {}
	tree.tokens["separators"] = {}

	for i = 1, math_huge do
		if parser:IsCurrentValue("}") then break end
		local entry = type_table_entry(parser, i)

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

local function read_parenthesis(parser)
	if not parser:IsCurrentValue("(") then return end
	local pleft = parser:ReadValue("(")
	local node = read_expression(parser, 0)

	if not node then
		parser:Error("empty parentheses group", pleft)
		return
	end

	node.tokens["("] = node.tokens["("] or {}
	table_insert(node.tokens["("], 1, pleft)
	node.tokens[")"] = node.tokens[")"] or {}
	table_insert(node.tokens[")"], parser:ReadValue(")"))
	return node
end

local function read_prefix_operator(parser)
	if not syntax.typesystem.IsPrefixOperator(parser:GetCurrentToken()) then return end
	local node = parser:Node("expression", "prefix_operator")
	node.value = parser:ReadTokenLoose()
	node.tokens[1] = node.value
	node.right = read_expression(parser, math_huge)
	return node
end

local function read_value(parser)
	if not (parser:IsCurrentValue("...") and parser:IsType("letter", 1)) then return end
	local node = parser:Node("expression", "value")
	node.value = parser:ReadValue("...")
	node.as_expression = read_expression(parser)
	return node
end

local function read_type_function(parser)
	if not (parser:IsCurrentValue("function") and parser:IsValue("(", 1)) then return end
	local function_body = require("nattlua.parser.statements.typesystem.function_body")
	local node = parser:Node("expression", "type_function")
	node.stmnt = false
	node.tokens["function"] = parser:ReadValue("function")
	return function_body(parser, node)
end

local function read_keyword_value(parser)
	if not syntax.typesystem.IsValue(parser:GetCurrentToken()) then return end
	local node = parser:Node("expression", "value")
	node.value = parser:ReadTokenLoose()
	return node
end

local function read_table(parser)
	if not parser:IsCurrentValue("{") then return end
	return type_table(parser)
end

local function read_string(parser)
	if not (parser:IsCurrentType("$") and parser:IsType("string", 1)) then return end
	local node = parser:Node("expression", "type_string")
	node.tokens["$"] = parser:ReadTokenLoose("...")
	node.value = parser:ReadType("string")
	return node
end

local read_sub_expression

do
	local function is_call_expression(parser, offset)
		return
			parser:IsValue("(", offset) or
			parser:IsCurrentValue("<|", offset) or
			parser:IsValue("{", offset) or
			parser:IsType("string", offset)
	end

	local function read_as_expression(parser, node)
		if not parser:IsCurrentValue("as") then return end
		node.tokens["as"] = parser:ReadValue("as")
		node.as_expression = read_expression(parser)
	end

	local function read_call_expression(parser)
		local type_expression_list = require("nattlua.parser.expressions.typesystem.expression").expression_list
		local optional_expression_list = require("nattlua.parser.expressions.expression").optional_expression_list
		local node = parser:Node("expression", "postfix_call")

		if parser:IsCurrentValue("{") then
			node.expressions = {read_table(parser)}
		elseif parser:IsCurrentType("string") then
			node.expressions = {
					parser:Node("expression", "value"):Store("value", parser:ReadTokenLoose()):End(),
				}
		elseif parser:IsCurrentValue("<|") then
			node.tokens["call("] = parser:ReadValue("<|")
			node.expressions = type_expression_list(parser)
			node.tokens["call)"] = parser:ReadValue("|>")
		else
			node.tokens["call("] = parser:ReadValue("(")
			node.expressions = optional_expression_list(parser)
			node.tokens["call)"] = parser:ReadValue(")")
		end
		node.type_call = true

		return node:End()
	end

	local function read_index(parser)
		if not (parser:IsCurrentValue(".") and parser:IsType("letter", 1)) then return end
		local node = parser:Node("expression", "binary_operator")
		node.value = parser:ReadTokenLoose()
		node.right = parser:Node("expression", "value"):Store("value", parser:ReadType("letter")):End()
		return node:End()
	end

	local function read_self_call(parser)
		if not (parser:IsCurrentValue(":") and parser:IsType("letter", 1) and is_call_expression(parser, 2)) then return end
		local node = parser:Node("expression", "binary_operator")
		node.value = parser:ReadTokenLoose()
		node.right = parser:Node("expression", "value"):Store("value", parser:ReadType("letter")):End()
		return node:End()
	end

	local function read_postfix_operator(parser)
		if not syntax.typesystem.IsPostfixOperator(parser:GetCurrentToken()) then return end
		return
			parser:Node("expression", "postfix_operator"):Store("value", parser:ReadTokenLoose()):End()
	end

	local function read_call(parser)
		if not is_call_expression(parser, 0) then return end
		return read_call_expression(parser)
	end

	local function read_postfix_index_expression(parser)
		if not parser:IsCurrentValue("[") then return end
		return
			parser:Node("expression", "postfix_expression_index"):ExpectKeyword("["):ExpectExpression()
			:ExpectKeyword("]")
			:End()
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

read_expression = function(parser, priority)
	priority = priority or 0

	local node
	local force_upvalue

	if parser:IsCurrentValue("^") then
		force_upvalue = true
		parser:Advance(1)
	end

	node = read_parenthesis(parser) or
		read_prefix_operator(parser) or
		read_value(parser) or
		read_type_function(parser) or
		read_keyword_value(parser) or
		read_table(parser) or
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

	while syntax.typesystem.GetBinaryOperatorInfo(parser:GetCurrentToken()) and
	syntax.typesystem.GetBinaryOperatorInfo(parser:GetCurrentToken()).left_priority > priority do
		local left_node = node
		node = parser:Node("expression", "binary_operator")
		node.value = parser:ReadTokenLoose()
		node.left = left_node
		node.right = read_expression(parser, syntax.typesystem.GetBinaryOperatorInfo(node.value).right_priority)
		node:End()
	end

	return node
end
return
	{
		expression = read_expression,
		expect_expression = expect_expression,
		expression_list = type_expression_list,
	}
