local table_insert = require("table").insert
local syntax = require("nattlua.syntax.syntax")
local multiple_values = require("nattlua.parser.statements.multiple_values")
local math_huge = math.huge

local expression
local expect_type_expression

local function type_expression_list(parser, max)
	return multiple_values(parser, max, expression)
end


local function type_function(parser, plain_args)
	local function_body = require("nattlua.parser.statements.typesystem.function_body")
	local node = parser:Node("expression", "type_function")
	node.stmnt = false
	node.tokens["function"] = parser:ReadValue("function")
	return function_body(parser, node, plain_args)
end

local function optional_expression_list(parser)
	return multiple_values(parser, nil, expression, 0)
end

local function call_expression(parser)
	local node = parser:Node("expression", "postfix_call")

	if parser:IsCurrentValue("{") then
		node.expressions = {table(parser)}
	elseif parser:IsCurrentType("string") then
		node.expressions = {
				parser:Node("expression", "value"):Store("value", parser:ReadTokenLoose()):End(),
			}
	elseif parser:IsCurrentValue("<|") then
		node.tokens["call("] = parser:ReadValue("<|")
		node.expressions = type_expression_list(parser)
		node.tokens["call)"] = parser:ReadValue("|>")
		node.type_call = true
	else
		node.tokens["call("] = parser:ReadValue("(")
		node.expressions = optional_expression_list(parser)
		node.tokens["call)"] = parser:ReadValue(")")
	end

	return node:End()
end

local function ReadTypeTableEntry(self, i)
	local node

	if self:IsCurrentValue("[") then
		node = self:Node("expression", "table_expression_value"):Store("expression_key", true):ExpectKeyword("[")
		expect_type_expression(self, node)
		node:ExpectKeyword("]"):ExpectKeyword("=")
	elseif self:IsCurrentType("letter") and self:IsValue("=", 1) then
		node = self:Node("expression", "table_key_value"):ExpectSimpleIdentifier():ExpectKeyword("=")
	else
		node = self:Node("expression", "table_index_value"):Store("key", i)
	end

	expect_type_expression(self, node)
	return node:End()
end

local function table(parser)
	local tree = parser:Node("expression", "type_table")
	tree:ExpectKeyword("{")
	tree.children = {}
	tree.tokens["separators"] = {}

	for i = 1, math_huge do
		if parser:IsCurrentValue("}") then break end
		local entry = ReadTypeTableEntry(parser, i)

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

expect_type_expression = function(parser, node)
	if node.expressions then
		table_insert(node.expressions, expression(parser))
	elseif node.expression then
		node.expressions = {node.expression}
		node.expression = nil
		table_insert(node.expressions, expression(parser))
	else
		node.expression = expression(parser)
	end

	return node
end
local function ReadTypeCall(parser)
	local node = parser:Node("expression", "postfix_call")
	node.tokens["call("] = parser:ReadValue("<|")
	node.expressions = type_expression_list(parser)
	node.tokens["call)"] = parser:ReadValue("|>")
	node.type_call = true
	return node:End()
end

local function IsCallExpression(parser, offset)
	offset = offset or 0
	return
		parser:IsValue("(", offset) or
		parser:IsCurrentValue("<|", offset) or
		parser:IsValue("{", offset) or
		parser:IsType("string", offset)
end


expression = function(parser, priority)
	priority = priority or 0
	local node
	local force_upvalue

	if parser:IsCurrentValue("^") then
		force_upvalue = true
		parser:Advance(1)
	end

	if parser:IsCurrentValue("(") then
		local pleft = parser:ReadValue("(")
		node = expression(parser, 0)

		if not node then
			parser:Error("empty parentheses group", pleft)
			return
		end

		node.tokens["("] = node.tokens["("] or {}
		table_insert(node.tokens["("], 1, pleft)
		node.tokens[")"] = node.tokens[")"] or {}
		table_insert(node.tokens[")"], parser:ReadValue(")"))
	elseif syntax.typesystem.IsPrefixOperator(parser:GetCurrentToken()) then
		node = parser:Node("expression", "prefix_operator")
		node.value = parser:ReadTokenLoose()
		node.tokens[1] = node.value
		node.right = expression(parser, math_huge)
	elseif parser:IsCurrentValue("...") and parser:IsType("letter", 1) then
		node = parser:Node("expression", "value")
		node.value = parser:ReadValue("...")
		node.as_expression = expression(parser)
	elseif parser:IsCurrentValue("function") and parser:IsValue("(", 1) then
		node = type_function(parser)
	elseif syntax.typesystem.IsValue(parser:GetCurrentToken()) then
		node = parser:Node("expression", "value")
		node.value = parser:ReadTokenLoose()
	elseif parser:IsCurrentValue("{") then
		node = table(parser)
	elseif parser:IsCurrentType("$") and parser:IsType("string", 1) then
		node = parser:Node("expression", "type_string")
		node.tokens["$"] = parser:ReadTokenLoose("...")
		node.value = parser:ReadType("string")
	end

	local first = node

	if node then
		for _ = 1, parser:GetLength() do
			local left = node
			if not parser:GetCurrentToken() then break end

			if parser:IsCurrentValue(".") or parser:IsCurrentValue(":") then
				if parser:IsCurrentValue(".") or IsCallExpression(parser, 2) then
					node = parser:Node("expression", "binary_operator")
					node.value = parser:ReadTokenLoose()
					node.right = parser:Node("expression", "value"):Store("value", parser:ReadType("letter")):End()
					node.left = left
					node:End()
				elseif parser:IsCurrentValue(":") then
					node.tokens[":"] = parser:ReadValue(":")
					node.as_expression = expression(parser)
				end
			elseif syntax.typesystem.IsPostfixOperator(parser:GetCurrentToken()) then
				node = parser:Node("expression", "postfix_operator")
				node.left = left
				node.value = parser:ReadTokenLoose()
			elseif parser:IsCurrentValue("<|") then
				node = ReadTypeCall(parser)
				node.left = left
			elseif IsCallExpression(parser) then
				node = call_expression(parser)
				node.left = left

				if left.value and left.value.value == ":" then
					node.self_call = true
				end
			elseif parser:IsCurrentValue("[") then
				node = parser:Node("expression", "postfix_expression_index"):ExpectKeyword("["):ExpectExpression()
					:ExpectKeyword("]")
					:End()
				node.left = left
			elseif parser:IsCurrentValue("as") then
				node.tokens["as"] = parser:ReadValue("as")
				node.as_expression = expression(parser)
			else
				break
			end
		end
	end

	if
		first and
		first.kind == "value" and
		(first.value.type == "letter" or first.value.value == "...")
	then
		first.standalone_letter = node
		first.force_upvalue = force_upvalue
	end

	while syntax.typesystem.GetBinaryOperatorInfo(parser:GetCurrentToken()) and
	syntax.typesystem.GetBinaryOperatorInfo(parser:GetCurrentToken()).left_priority > priority do
		local op = parser:GetCurrentToken()
		local right_priority = syntax.typesystem.GetBinaryOperatorInfo(op).right_priority
		if not op or not right_priority then break end
		parser:Advance(1)
		local left = node
		local right = expression(parser, right_priority)
		node = parser:Node("expression", "binary_operator")
		node.value = op
		node.left = node.left or left
		node.right = node.right or right
	end

	return node
end

return
	{
		expression = expression,
		expect_expression = expect_type_expression,
		expression_list = type_expression_list,
	}
