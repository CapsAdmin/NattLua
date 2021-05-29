local math = require("math")
local table_insert = require("table").insert
local table_remove = require("table").remove
local ipairs = _G.ipairs
local syntax = require("nattlua.syntax.syntax")
local ReadFunction = require("nattlua.parser.expressions.function").ReadFunction
local ReadImport = require("nattlua.parser.expressions.extra.import").ReadImport
local ReadTable = require("nattlua.parser.expressions.table").ReadTable
local ExpectTypeExpression = require("nattlua.parser.expressions.typesystem.expression").ExpectExpression
local ReadTypeExpression = require("nattlua.parser.expressions.typesystem.expression").ReadExpression
local ReadMultipleValues = require("nattlua.parser.statements.multiple_values").ReadMultipleValues
local read_sub_expression
local ReadExpression
local ExpectExpression

do
	local function is_call_expression(parser, offset)
		return
			parser:IsValue("(", offset) or
			parser:IsCurrentValue("<|", offset) or
			parser:IsValue("{", offset) or
			parser:IsType("string", offset)
	end

	local function read_call_expression(parser)
		local node = parser:Node("expression", "postfix_call")

		if parser:IsCurrentValue("{") then
			node.expressions = {ReadTable(parser)}
		elseif parser:IsCurrentType("string") then
			node.expressions = {
					parser:Node("expression", "value"):Store("value", parser:ReadTokenLoose()):End(),
				}
		elseif parser:IsCurrentValue("<|") then
			node.tokens["call("] = parser:ReadValue("<|")
			node.expressions = ReadMultipleValues(parser, nil, ReadTypeExpression, 0)
			node.tokens["call)"] = parser:ReadValue("|>")
			node.type_call = true
		else
			node.tokens["call("] = parser:ReadValue("(")
			node.expressions = ReadMultipleValues(parser, nil, ReadExpression, 0)
			node.tokens["call)"] = parser:ReadValue(")")
		end

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
		if not syntax.IsPostfixOperator(parser:GetCurrentToken()) then return end
		return
			parser:Node("expression", "postfix_operator"):Store("value", parser:ReadTokenLoose()):End()
	end

	local function read_call(parser)
		if not is_call_expression(parser, 0) then return end
		return read_call_expression(parser)
	end

	local function read_postfix_index_expression(parser)
		if not parser:IsCurrentValue("[") then return end
		local node = parser:Node("expression", "postfix_expression_index"):ExpectKeyword("[")
		node.expression = ExpectExpression(parser)
		return node:ExpectKeyword("]"):End()
	end

	local function read_and_add_explicit_type(parser, node)
		if parser:IsCurrentValue(":") and (not parser:IsType("letter", 1) or not is_call_expression(parser, 2)) then
			node.tokens[":"] = parser:ReadValue(":")
			node.as_expression = ExpectTypeExpression(parser, 0)
		elseif parser:IsCurrentValue("as") then
			node.tokens["as"] = parser:ReadValue("as")
			node.as_expression = ExpectTypeExpression(parser, 0)
		elseif parser:IsCurrentValue("is") then
			node.tokens["is"] = parser:ReadValue("is")
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
		if not syntax.IsPrefixOperator(parser:GetCurrentToken()) then return end
		local node = parser:Node("expression", "prefix_operator")
		node.value = parser:ReadTokenLoose()
		node.tokens[1] = node.value
		node.right = ExpectExpression(parser, math.huge)
		return node:End()
	end

	local function parenthesis(parser)
		if not parser:IsCurrentValue("(") then return end
		local pleft = parser:ReadValue("(")
		local node = ReadExpression(parser, 0)

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

	local function value(parser)
		if not syntax.IsValue(parser:GetCurrentToken()) then return end
		return
			parser:Node("expression", "value"):Store("value", parser:ReadTokenLoose()):End()
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

		check_integer_division_operator(parser, parser:GetCurrentToken())

		while syntax.GetBinaryOperatorInfo(parser:GetCurrentToken()) and
		syntax.GetBinaryOperatorInfo(parser:GetCurrentToken()).left_priority > priority do
			local left_node = node
			node = parser:Node("expression", "binary_operator")
			node.value = parser:ReadTokenLoose()
			node.left = left_node
			node.right = ReadExpression(parser, syntax.GetBinaryOperatorInfo(node.value).right_priority)
			node:End()
		end

		return node
	end
end

ExpectExpression = function(parser, priority)
	local token = parser:GetCurrentToken()

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
