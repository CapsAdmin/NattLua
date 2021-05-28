local table_insert = require("table").insert
return function(META)
	local math_huge = math.huge
	local syntax = require("nattlua.syntax.syntax")

	function META:ReadExplicitFunctionReturnType(node)
		if not self:IsCurrentValue(":") then return end
		node.tokens[":"] = self:ReadValue(":")
		local out = {}

		for i = 1, self:GetLength() do
			local typ = self:ReadTypeExpression()
			if self:HandleListSeparator(out, i, typ) then break end
		end

		node.return_types = out
	end

	function META:ExpectTypeExpression(node)
		if node.expressions then
			table_insert(node.expressions, self:ReadTypeExpression())
		elseif node.expression then
			node.expressions = {node.expression}
			node.expression = nil
			table_insert(node.expressions, self:ReadTypeExpression())
		else
			node.expression = self:ReadTypeExpression()
		end

		return node
	end

	local expression_list = require("nattlua.parser.statements.typesystem.expression_list")

	local function ReadTypeCall(parser)
		local node = parser:Expression("postfix_call")
		node.tokens["call("] = parser:ReadValue("<|")
		node.expressions = expression_list(parser)
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

	local table = require("nattlua.parser.expressions.typesystem.table")
	local type_function = require("nattlua.parser.expressions.typesystem.function")
	local call_expression = require("nattlua.parser.expressions.call")

	function META:ReadTypeExpression(priority)
		priority = priority or 0
		local node
		local force_upvalue

		if self:IsCurrentValue("^") then
			force_upvalue = true
			self:Advance(1)
		end

		if self:IsCurrentValue("(") then
			local pleft = self:ReadValue("(")
			node = self:ReadTypeExpression(0)

			if not node then
				self:Error("empty parentheses group", pleft)
				return
			end

			node.tokens["("] = node.tokens["("] or {}
			table_insert(node.tokens["("], 1, pleft)
			node.tokens[")"] = node.tokens[")"] or {}
			table_insert(node.tokens[")"], self:ReadValue(")"))
		elseif syntax.typesystem.IsPrefixOperator(self:GetCurrentToken()) then
			node = self:Expression("prefix_operator")
			node.value = self:ReadTokenLoose()
			node.tokens[1] = node.value
			node.right = self:ReadTypeExpression(math_huge)
		elseif self:IsCurrentValue("...") and self:IsType("letter", 1) then
			node = self:Expression("value")
			node.value = self:ReadValue("...")
			node.as_expression = self:ReadTypeExpression()
		elseif self:IsCurrentValue("function") and self:IsValue("(", 1) then
			node = type_function(self)
		elseif syntax.typesystem.IsValue(self:GetCurrentToken()) then
			node = self:Expression("value")
			node.value = self:ReadTokenLoose()
		elseif self:IsCurrentValue("{") then
			node = table(self)
		elseif self:IsCurrentType("$") and self:IsType("string", 1) then
			node = self:Expression("type_string")
			node.tokens["$"] = self:ReadTokenLoose("...")
			node.value = self:ReadType("string")
		end

		local first = node

		if node then
			for _ = 1, self:GetLength() do
				local left = node
				if not self:GetCurrentToken() then break end

				if self:IsCurrentValue(".") or self:IsCurrentValue(":") then
					if self:IsCurrentValue(".") or IsCallExpression(self, 2) then
						node = self:Expression("binary_operator")
						node.value = self:ReadTokenLoose()
						node.right = self:Expression("value"):Store("value", self:ReadType("letter")):End()
						node.left = left
						node:End()
					elseif self:IsCurrentValue(":") then
						node.tokens[":"] = self:ReadValue(":")
						node.as_expression = self:ReadTypeExpression()
					end
				elseif syntax.typesystem.IsPostfixOperator(self:GetCurrentToken()) then
					node = self:Expression("postfix_operator")
					node.left = left
					node.value = self:ReadTokenLoose()
				elseif self:IsCurrentValue("<|") then
					node = ReadTypeCall(self)
					node.left = left
				elseif IsCallExpression(self) then
					node = call_expression(self)
					node.left = left

					if left.value and left.value.value == ":" then
						node.self_call = true
					end
				elseif self:IsCurrentValue("[") then
					node = self:Expression("postfix_expression_index"):ExpectKeyword("["):ExpectExpression():ExpectKeyword("]"):End()
					node.left = left
				elseif self:IsCurrentValue("as") then
					node.tokens["as"] = self:ReadValue("as")
					node.as_expression = self:ReadTypeExpression()
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

		while syntax.typesystem.GetBinaryOperatorInfo(self:GetCurrentToken()) and
		syntax.typesystem.GetBinaryOperatorInfo(self:GetCurrentToken()).left_priority > priority do
			local op = self:GetCurrentToken()
			local right_priority = syntax.typesystem.GetBinaryOperatorInfo(op).right_priority
			if not op or not right_priority then break end
			self:Advance(1)
			local left = node
			local right = self:ReadTypeExpression(right_priority)
			node = self:Expression("binary_operator")
			node.value = op
			node.left = node.left or left
			node.right = node.right or right
		end

		return node
	end
end
