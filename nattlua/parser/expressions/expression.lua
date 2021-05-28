local math = require("math")
local table_insert = require("table").insert
local table_remove = require("table").remove
local ipairs = _G.ipairs
local _function = require("nattlua.parser.expressions.function")
local table = require("nattlua.parser.expressions.table")
local _import = require("nattlua.parser.expressions.extra.import")

local syntax = require("nattlua.syntax.syntax")
local call_expression = require("nattlua.parser.expressions.call")

local function IsCallExpression(parser, offset)
	return
		parser:IsValue("(", offset) or
		parser:IsCurrentValue("<|", offset) or
		parser:IsValue("{", offset) or
		parser:IsType("string", offset)
end

local function ReadAndAddExplicitType(parser, node)
	if parser:IsCurrentValue(":") and (not parser:IsType("letter", 1) or not IsCallExpression(parser, 2)) then
		node.tokens[":"] = parser:ReadValue(":")
		node.as_expression = parser:ReadTypeExpression()
	elseif parser:IsCurrentValue("as") then
		node.tokens["as"] = parser:ReadValue("as")
		node.as_expression = parser:ReadTypeExpression()
	elseif parser:IsCurrentValue("is") then
		node.tokens["is"] = parser:ReadValue("is")
		node.as_expression = parser:ReadTypeExpression()
	end
end

local function ReadIndexSubExpression(parser)
	if not (parser:IsCurrentValue(".") and parser:IsType("letter", 1)) then return end
	local node = parser:Node("expression", "binary_operator")
	node.value = parser:ReadTokenLoose()
	node.right = parser:Node("expression", "value"):Store("value", parser:ReadType("letter")):End()
	return node:End()
end

local function ReadparserCallSubExpression(parser)
	if not (parser:IsCurrentValue(":") and parser:IsType("letter", 1) and IsCallExpression(parser, 2)) then return end
	local node = parser:Node("expression", "binary_operator")
	node.value = parser:ReadTokenLoose()
	node.right = parser:Node("expression", "value"):Store("value", parser:ReadType("letter")):End()
	return node:End()
end

local function ReadPostfixOperatorSubExpression(parser)
	if not syntax.IsPostfixOperator(parser:GetCurrentToken()) then return end
	return
		parser:Node("expression", "postfix_operator"):Store("value", parser:ReadTokenLoose()):End()
end

local function ReadCallSubExpression(parser)
	if not IsCallExpression(parser, 0) then return end
	return call_expression(parser)
end

local function ReadPostfixExpressionIndexSubExpression(parser)
	if not parser:IsCurrentValue("[") then return end
	return
		parser:Node("expression", "postfix_expression_index"):ExpectKeyword("["):ExpectExpression()
		:ExpectKeyword("]")
		:End()
end

local function sub_expression(parser, node)
	for _ = 1, parser:GetLength() do
		local left_node = node
		ReadAndAddExplicitType(parser, node)
		local found = ReadIndexSubExpression(parser) or
			ReadparserCallSubExpression(parser) or
			ReadPostfixOperatorSubExpression(parser) or
			ReadCallSubExpression(parser) or
			ReadPostfixExpressionIndexSubExpression(parser)
		if not found then break end
		found.left = left_node

		if left_node.value and left_node.value.value == ":" then
			found.parser_call = true
		end

		node = found
	end

	return node
end

local optional_expression_list
local expression_list
local expression
local expect_expression

local function prefix_operator(parser)
    if not syntax.IsPrefixOperator(parser:GetCurrentToken()) then return end
    local node = parser:Node("expression", "prefix_operator")
    node.value = parser:ReadTokenLoose()
    node.tokens[1] = node.value
    node.right = expect_expression(parser, math.huge)
    return node:End()
end

local function parenthesis(parser)
    if not parser:IsCurrentValue("(") then return end
    local pleft = parser:ReadValue("(")
    local node = expression(parser, 0)

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

local function CheckForIntegerDivisionOperator(parser, node)
    if node and not node.idiv_resolved then
        for i, token in ipairs(node.whitespace) do
            if token.type == "line_comment" and token.value:sub(1, 2) == "//" then
                table_remove(node.whitespace, i)
                local tokens = require("nattlua.lexer.lexer")("/idiv" .. token.value:sub(2)):GetTokens()

                for _, token in ipairs(tokens) do
                    CheckForIntegerDivisionOperator(parser, token)
                end

                parser:AddTokens(tokens)
                node.idiv_resolved = true

                break
            end
        end
    end
end

expression = function(parser, priority)
    local node = parenthesis(parser) or
        prefix_operator(parser) or
        _function(parser) or
        _import(parser) or
        value(parser) or
        table(parser)
    local first = node

    if node then
        node = sub_expression(parser, node)

        if
            first.kind == "value" and
            (first.value.type == "letter" or first.value.value == "...")
        then
            first.standalone_letter = node
        end
    end

    CheckForIntegerDivisionOperator(parser, parser:GetCurrentToken())

    while syntax.GetBinaryOperatorInfo(parser:GetCurrentToken()) and
    syntax.GetBinaryOperatorInfo(parser:GetCurrentToken()).left_priority > priority do
        local left_node = node
        node = parser:Node("expression", "binary_operator")
        node.value = parser:ReadTokenLoose()
        node.left = left_node
        node.right = expression(parser, syntax.GetBinaryOperatorInfo(node.value).right_priority)
        node:End()
    end

    return node
end

local function IsDefinetlyNotStartOfExpression(token)
    return
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
end

expect_expression = function(parser, priority)
    if IsDefinetlyNotStartOfExpression(parser:GetCurrentToken()) then
        parser:Error(
            "expected beginning of expression, got $1",
            nil,
            nil,
            parser:GetCurrentToken() and
            parser:GetCurrentToken().value ~= "" and
            parser:GetCurrentToken().value or
            parser:GetCurrentToken().type
        )
        return
    end

    return expression(parser, priority)
end

optional_expression_list = function(parser)
    local out = {}

    for i = 1, parser:GetLength() do
        local exp = expression(parser, 0)
        if parser:HandleListSeparator(out, i, exp) then break end
    end

    return out
end

expression_list = function(parser, max)
    local out = {}

    for i = 1, max do
        local exp = expect_expression(parser, 0)
        if parser:HandleListSeparator(out, i, exp) then break end
    end

    return out
end

return { 
    expression = expression,
    expect_expression = expect_expression,
    expression_list = expression_list,
    optional_expression_list = optional_expression_list,
}