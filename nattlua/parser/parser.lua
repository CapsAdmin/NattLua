local syntax = require("nattlua.syntax.syntax")
local math = require("math")
local table_insert = require("table").insert
local table_remove = require("table").remove
local setmetatable = _G.setmetatable
local ipairs = _G.ipairs
local META = {}
META.__index = META
META.Emitter = require("nattlua.transpiler.emitter")
META.syntax = syntax
require("nattlua.parser.base_parser")(META)
require("nattlua.parser.parser_typesystem")(META)

function META:ResolvePath(path)
	return path
end

function META:HandleListSeparator(out, i, node)
	if not node then return true end
	out[i] = node
	if not self:IsCurrentValue(",") then return true end
	node.tokens[","] = self:ReadValue(",")
end

do -- expression
	do
		local function prefix_operator(parser)
			if not syntax.IsPrefixOperator(parser:GetCurrentToken()) then return end
			local node = parser:Expression("prefix_operator")
			node.value = parser:ReadTokenLoose()
			node.tokens[1] = node.value
			node.right = parser:ReadExpectExpression(math.huge)
			return node:End()
		end

		local function parenthesis(parser)
			if not parser:IsCurrentValue("(") then return end
			local pleft = parser:ReadValue("(")
			local node = parser:ReadExpression(0)

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
			return parser:Expression("value"):Store("value", parser:ReadTokenLoose()):End()
		end

		local _function = require("nattlua.parser.expressions.function")
		local sub_expression = require("nattlua.parser.expressions.sub_expression")
		local table = require("nattlua.parser.expressions.table")
		local _import = require("nattlua.parser.expressions.extra.import")

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

		function META:ReadExpression(priority)
			local node = parenthesis(self) or
				prefix_operator(self) or
				_function(self) or
				_import(self) or
				value(self) or
				table(self)
			local first = node

			if node then
				node = sub_expression(self, node)

				if
					first.kind == "value" and
					(first.value.type == "letter" or first.value.value == "...")
				then
					first.standalone_letter = node
				end
			end

			CheckForIntegerDivisionOperator(self, self:GetCurrentToken())

			while syntax.GetBinaryOperatorInfo(self:GetCurrentToken()) and
			syntax.GetBinaryOperatorInfo(self:GetCurrentToken()).left_priority > priority do
				local left_node = node
				node = self:Expression("binary_operator")
				node.value = self:ReadTokenLoose()
				node.left = left_node
				node.right = self:ReadExpression(syntax.GetBinaryOperatorInfo(node.value).right_priority)
				node:End()
			end

			return node
		end
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

	function META:ReadExpectExpression(priority)
		if IsDefinetlyNotStartOfExpression(self:GetCurrentToken()) then
			self:Error(
				"expected beginning of expression, got $1",
				nil,
				nil,
				self:GetCurrentToken() and
				self:GetCurrentToken().value ~= "" and
				self:GetCurrentToken().value or
				self:GetCurrentToken().type
			)
			return
		end

		return self:ReadExpression(priority)
	end

	function META:ReadExpressionList(max)
		local out = {}

		for i = 1, max or self:GetLength() do
			local exp = max and self:ReadExpectExpression(0) or self:ReadExpression(0)
			if self:HandleListSeparator(out, i, exp) then break end
		end

		return out
	end
end


do -- statements
	local _break = require("nattlua.parser.statements.break")
	local _do = require("nattlua.parser.statements.do")
	local generic_for = require("nattlua.parser.statements.generic_for")
	local goto_label = require("nattlua.parser.statements.goto_label")
	local _goto = require("nattlua.parser.statements.goto")
	local _if = require("nattlua.parser.statements.if")
	local local_assignment = require("nattlua.parser.statements.local_assignment")
	local numeric_for = require("nattlua.parser.statements.numeric_for")
	local _repeat = require("nattlua.parser.statements.repeat")
	local semicolon = require("nattlua.parser.statements.semicolon")
	local _return = require("nattlua.parser.statements.return")
	local _while = require("nattlua.parser.statements.while")
	local _function = require("nattlua.parser.statements.function")
	local local_function = require("nattlua.parser.statements.local_function")
	local _continue = require("nattlua.parser.statements.extra.continue")
	local destructure_assignment = require("nattlua.parser.statements.extra.destructure_assignment")
	local local_destructure_assignment = require("nattlua.parser.statements.extra.local_destructure_assignment")
	local type_function = require("nattlua.parser.statements.typesystem.function")
	local local_type_function = require("nattlua.parser.statements.typesystem.local_function")
	local local_type_generics_function = require("nattlua.parser.statements.typesystem.local_generics_function")
	local debug_code = require("nattlua.parser.statements.typesystem.debug_code")
	local local_type_assignment = require("nattlua.parser.statements.typesystem.local_assignment")
	local type_assignment = require("nattlua.parser.statements.typesystem.assignment")
	local call_or_assignment = require("nattlua.parser.statements.call_or_assignment")

	function META:ReadStatement()
		if self:IsCurrentType("end_of_file") then return end

		return
			debug_code(self) or
			_return(self) or
			_break(self) or
			_continue(self) or
			semicolon(self) or
			_goto(self) or
			goto_label(self) or
			_repeat(self) or
			type_function(self) or
			_function(self) or
			local_type_generics_function(self) or
			local_function(self) or
			local_type_function(self) or
			local_type_assignment(self) or
			local_destructure_assignment(self) or
			local_assignment(self) or
			type_assignment(self) or
			_do(self) or
			_if(self) or
			_while(self) or
			numeric_for(self) or
			generic_for(self) or
			destructure_assignment(self) or
			call_or_assignment(self)
	end
end

return function(config)
	return setmetatable(
		{
			config = config,
			nodes = {},
			name = "",
			code = "",
			current_statement = false,
			current_expression = false,
			root = false,
			i = 1,
			tokens = {},
			OnError = function() 
			end,
		},
		META
	)
end
