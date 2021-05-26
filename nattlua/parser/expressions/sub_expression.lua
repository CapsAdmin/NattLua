local syntax = require("nattlua.syntax.syntax")

local function ReadAndAddExplicitType(parser, node)
	if parser:IsCurrentValue(":") and (not parser:IsType("letter", 1) or not parser:IsCallExpression(2)) then
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
	local node = parser:Expression("binary_operator")
	node.value = parser:ReadTokenLoose()
	node.right = parser:Expression("value"):Store("value", parser:ReadType("letter")):End()
	return node:End()
end

local function ReadparserCallSubExpression(parser)
	if not (parser:IsCurrentValue(":") and parser:IsType("letter", 1) and parser:IsCallExpression(2)) then return end
	local node = parser:Expression("binary_operator")
	node.value = parser:ReadTokenLoose()
	node.right = parser:Expression("value"):Store("value", parser:ReadType("letter")):End()
	return node:End()
end

local function ReadPostfixOperatorSubExpression(parser)
	if not syntax.IsPostfixOperator(parser:GetCurrentToken()) then return end
	return
		parser:Expression("postfix_operator"):Store("value", parser:ReadTokenLoose()):End()
end

local function ReadCallSubExpression(parser)
	if not parser:IsCallExpression() then return end
	return parser:ReadCallExpression()
end

local function ReadPostfixExpressionIndexSubExpression(parser)
	if not parser:IsCurrentValue("[") then return end
	return parser:ReadPostfixExpressionIndex()
end

return function(parser, node)
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
