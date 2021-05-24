local table = require("table")
return function(META)
	local math_huge = math.huge
	local syntax = require("nattlua.syntax.syntax")

	function META:ReadInlineTypeCode()
		if not self:IsCurrentType("type_code") then return end
		local node = self:Statement("type_code")
		local code = self:Expression("value")
		code.value = self:ReadType("type_code")
		node.lua_code = code
		return node
	end

	function META:HandleTypeListSeparator(out, i, node)
		if not node then return true end
		out[i] = node
		if not self:IsCurrentValue(",") and not self:IsCurrentValue(";") then return true end

		if self:IsCurrentValue(";") then
			node.tokens[","] = self:ReadValue(";")
		else
			node.tokens[","] = self:ReadValue(",")
		end
	end

	function META:ReadTypeExpressionList(max)
		local out = {}

		for i = 1, math_huge do
			if self:HandleTypeListSeparator(out, i, self:ReadTypeExpression()) then break end

			if max then
				max = max - 1
				if max == 0 then break end
			end
		end

		return out
	end

	function META:ReadLocalTypeFunctionStatement()
		if not (self:IsCurrentValue("local") and self:IsValue("type", 1) and self:IsValue("function", 2)) then return end
		local node = self:Statement("local_type_function"):ExpectKeyword("local"):ExpectKeyword("type"):ExpectKeyword("function")
			:ExpectSimpleIdentifier()
		self:ReadTypeFunctionBody(node, true)
		return node:End()
	end

	function META:ReadTypeFunctionStatement()
		if not (self:IsCurrentValue("type") and self:IsValue("function", 1)) then return end
		local node = self:Statement("type_function")
		node.tokens["type"] = self:ReadValue("type")
		node.tokens["function"] = self:ReadValue("function")
		local force_upvalue

		if self:IsCurrentValue("^") then
			force_upvalue = true
			node.tokens["^"] = self:ReadTokenLoose()
		end

		node.expression = self:ReadIndexExpression()

		do -- hacky
            if node.expression.left then
				node.expression.left.standalone_letter = node
				node.expression.left.force_upvalue = force_upvalue
			else
				node.expression.standalone_letter = node
				node.expression.force_upvalue = force_upvalue
			end

			if node.expression.value.value == ":" then
				node.self_call = true
			end
		end

		self:ReadTypeFunctionBody(node, true)
		return node
	end

	function META:ReadLocalGenericsTypeFunctionStatement()
		if not (self:IsCurrentValue("local") and self:IsValue("function", 1) and self:IsValue("<|", 3)) then return end
		local node = self:Statement("local_generics_type_function"):ExpectKeyword("local"):ExpectKeyword("function")
			:ExpectSimpleIdentifier()
		self:ReadGenericsTypeFunctionBody(node)
		return node:End()
	end

	function META:ReadGenericsTypeFunctionStatement()
		if not (self:IsValue("function") and self:IsValue("<|", 2)) then return end
		local node = self:Statement("generics_type_function"):ExpectKeyword("function")
		node.expression = self:ReadIndexExpression()
		node:ExpectSimpleIdentifier()
		self:ReadGenericsTypeFunctionBody(node)
		return node:End()
	end

	function META:ReadTypeFunctionArgument()
		if (self:IsCurrentType("letter") or self:IsCurrentValue("...")) and self:IsValue(":", 1) then
			local identifier = self:ReadTokenLoose()
			local token = self:ReadValue(":")
			local exp = self:ReadTypeExpression()
			exp.tokens[":"] = token
			exp.identifier = identifier
			return exp
		end

		return self:ReadTypeExpression()
	end

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

	function META:ReadTypeFunctionBody(node, plain_args)
		node.tokens["arguments("] = self:ReadValue("(")

		if plain_args then
			node.identifiers = self:ReadIdentifierList()
		else
			node.identifiers = {}

			for i = 1, math_huge do
				if self:HandleListSeparator(node.identifiers, i, self:ReadTypeFunctionArgument()) then break end
			end
		end

		if self:IsCurrentValue("...") then
			local vararg = self:Expression("value")
			vararg.value = self:ReadValue("...")

			if self:IsCurrentType("letter") then
				vararg.explicit_type = self:ReadValue()
			end

			table.insert(node.identifiers, vararg)
		end

		node.tokens["arguments)"] = self:ReadValue(")", node.tokens["arguments("])

		if self:IsCurrentValue(":") then
			node.tokens[":"] = self:ReadValue(":")
			node.return_types = self:ReadTypeExpressionList()
		elseif not self:IsCurrentValue(",") then
			local start = self:GetCurrentToken()
			node.statements = self:ReadStatements({["end"] = true})
			node.tokens["end"] = self:ReadValue("end", start, start)
		end

		return node
	end

	function META:ReadGenericsTypeFunctionBody(node)
		node.tokens["arguments("] = self:ReadValue("<|")
		node.identifiers = self:ReadIdentifierList()

		if self:IsCurrentValue("...") then
			local vararg = self:Expression("value")
			vararg.value = self:ReadValue("...")
			table.insert(node.identifiers, vararg)
		end

		node.tokens["arguments)"] = self:ReadValue("|>", node.tokens["arguments("])

		if self:IsCurrentValue(":") then
			node.tokens[":"] = self:ReadValue(":")
			node.return_types = self:ReadTypeExpressionList()
		else
			local start = self:GetCurrentToken()
			node.statements = self:ReadStatements({["end"] = true})
			node.tokens["end"] = self:ReadValue("end", start, start)
		end

		return node
	end

	function META:ReadTypeFunction(plain_args)
		local node = self:Expression("type_function")
		node.stmnt = false
		node.tokens["function"] = self:ReadValue("function")
		return self:ReadTypeFunctionBody(node, plain_args)
	end

	function META:ExpectTypeExpression(node)
		if node.expressions then
			table.insert(node.expressions, self:ReadTypeExpression())
		elseif node.expression then
			node.expressions = {node.expression}
			node.expression = nil
			table.insert(node.expressions, self:ReadTypeExpression())
		else
			node.expression = self:ReadTypeExpression()
		end

		return node
	end

	function META:ReadTypeTableEntry(i)
		local node

		if self:IsCurrentValue("[") then
			node = self:Expression("table_expression_value"):Store("expression_key", true):ExpectKeyword("[")
			self:ExpectTypeExpression(node)
			node:ExpectKeyword("]"):ExpectKeyword("=")
		elseif self:IsCurrentType("letter") and self:IsValue("=", 1) then
			node = self:Expression("table_key_value"):ExpectSimpleIdentifier():ExpectKeyword("=")
		else
			node = self:Expression("table_index_value"):Store("key", i)
		end

		self:ExpectTypeExpression(node)
		return node:End()
	end

	function META:ReadTypeTable()
		local tree = self:Expression("type_table")
		tree:ExpectKeyword("{")
		tree.children = {}
		tree.tokens["separators"] = {}

		for i = 1, math_huge do
			if self:IsCurrentValue("}") then break end
			local entry = self:ReadTypeTableEntry(i)

			if entry.spread then
				tree.spread = true
			end

			tree.children[i] = entry

			if not self:IsCurrentValue(",") and not self:IsCurrentValue(";") and not self:IsCurrentValue("}") then
				self:Error(
					"expected $1 got $2",
					nil,
					nil,
					{",", ";", "}"},
					(self:GetCurrentToken() and self:GetCurrentToken().value) or
					"no token"
				)

				break
			end

			if not self:IsCurrentValue("}") then
				tree.tokens["separators"][i] = self:ReadTokenLoose()
			end
		end

		tree:ExpectKeyword("}")
		return tree:End()
	end

	function META:ReadTypeCall()
		local node = self:Expression("postfix_call")
		node.tokens["call("] = self:ReadValue("<|")
		node.expressions = self:ReadTypeExpressionList()
		node.tokens["call)"] = self:ReadValue("|>")
		node.type_call = true
		return node:End()
	end

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
			table.insert(node.tokens["("], 1, pleft)
			node.tokens[")"] = node.tokens[")"] or {}
			table.insert(node.tokens[")"], self:ReadValue(")"))
		elseif syntax.typesystem.IsPrefixOperator(self:GetCurrentToken()) then
			node = self:Expression("prefix_operator")
			node.value = self:ReadTokenLoose()
			node.tokens[1] = node.value
			node.right = self:ReadTypeExpression(math_huge)
		elseif self:IsCurrentValue("...") and self:IsType("letter", 1) then
			node = self:Expression("value")
			node.value = self:ReadValue("...")
			node.explicit_type = self:ReadTypeExpression()
		elseif self:IsCurrentValue("function") and self:IsValue("(", 1) then
			node = self:ReadTypeFunction()
		elseif syntax.typesystem.IsValue(self:GetCurrentToken()) then
			node = self:Expression("value")
			node.value = self:ReadTokenLoose()
		elseif self:IsCurrentValue("{") then
			node = self:ReadTypeTable()
		elseif self:IsCurrentType("$") and self:IsType("string", 1) then
			node = self:Expression("type_string")
			node.tokens["$"] = self:ReadTokenLoose("...")
			node.value = self:ReadType("string")
		elseif self:IsCurrentValue("[") then
			node = self:Expression("type_list")
			node.tokens["["] = self:ReadValue("[")
			node.expressions = self:ReadTypeExpressionList()
			node.tokens["]"] = self:ReadValue("]")
		end

		local first = node

		if node then
			for _ = 1, self:GetLength() do
				local left = node
				if not self:GetCurrentToken() then break end

				if self:IsCurrentValue(".") or self:IsCurrentValue(":") then
					if self:IsCurrentValue(".") or self:IsCallExpression(2) then
						node = self:Expression("binary_operator")
						node.value = self:ReadTokenLoose()
						node.right = self:Expression("value"):Store("value", self:ReadType("letter")):End()
						node.left = left
						node:End()
					elseif self:IsCurrentValue(":") then
						node.tokens[":"] = self:ReadValue(":")
						node.explicit_type = self:ReadTypeExpression()
					end
				elseif syntax.typesystem.IsPostfixOperator(self:GetCurrentToken()) then
					node = self:Expression("postfix_operator")
					node.left = left
					node.value = self:ReadTokenLoose()
				elseif self:IsCurrentValue("[") and self:IsValue("]", 1) then
					node = self:Expression("type_list")
					node.tokens["["] = self:ReadValue("[")
					node.expressions = self:ReadTypeExpressionList()
					node.tokens["]"] = self:ReadValue("]")
					node.left = left
				elseif self:IsCurrentValue("<|") then
					node = self:ReadTypeCall()
					node.left = left
				elseif self:IsCallExpression() then
					node = self:ReadCallExpression()
					node.left = left

					if left.value and left.value.value == ":" then
						node.self_call = true
					end
				elseif self:IsCurrentValue("[") then
					node = self:ReadPostfixExpressionIndex()
					node.left = left
				elseif self:IsCurrentValue("as") then
					node.tokens["as"] = self:ReadValue("as")
					node.explicit_type = self:ReadTypeExpression()
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

	function META:ReadLocalTypeDeclarationStatement()
		if not (
			self:IsCurrentValue("local") and self:IsValue("type", 1) and
			syntax.GetTokenType(self:GetToken(2)) == "letter"
		) then return end
		local node = self:Statement("local_assignment")
		node.tokens["local"] = self:ReadValue("local")
		node.tokens["type"] = self:ReadValue("type")
		node.left = self:ReadIdentifierList()
		node.environment = "typesystem"

		if self:IsCurrentValue("=") then
			node.tokens["="] = self:ReadValue("=")
			node.right = self:ReadTypeExpressionList()
		end

		return node
	end

	function META:ReadInterfaceStatement()
		if not (self:IsCurrentValue("interface") and self:IsType("letter", 1)) then return end
		local node = self:Statement("type_interface")
		node.tokens["interface"] = self:ReadValue("interface")
		node.key = self:ReadIndexExpression()
		node.tokens["{"] = self:ReadValue("{")
		local list = {}

		for i = 1, math_huge do
			if not self:IsCurrentType("letter") then break end
			local node = self:Statement("interface_declaration")
			node.left = self:ReadType("letter")
			node.tokens["="] = self:ReadValue("=")
			node.right = self:ReadTypeExpression()
			list[i] = node
		end

		node.expressions = list
		node.tokens["}"] = self:ReadValue("}")
		return node
	end

	function META:ReadTypeAssignment()
		if not (self:IsCurrentValue("type") and (self:IsType("letter", 1) or self:IsValue("^", 1))) then return end
		local node = self:Statement("assignment")
		node.tokens["type"] = self:ReadValue("type")
		node.left = self:ReadTypeExpressionList()
		node.environment = "typesystem"

		if self:IsCurrentValue("=") then
			node.tokens["="] = self:ReadValue("=")
			node.right = self:ReadTypeExpressionList()
		end

		return node
	end

	function META:ReadImportStatement()
		if not (self:IsCurrentValue("import") and not self:IsValue("(", 1)) then return end
		local node = self:Statement("import")
		node.tokens["import"] = self:ReadValue("import")
		node.left = self:ReadIdentifierList()
		node.tokens["from"] = self:ReadValue("from")
		local start = self:GetCurrentToken()
		node.expressions = self:ReadExpressionList()
		local root = self.config.path:match("(.+/)")
		node.path = root .. node.expressions[1].value.value:sub(2, -2)
		local nl = require("nattlua")
		local root, err = nl.ParseFile(node.path, self.root).SyntaxTree

		if not root then
			self:Error("error importing file: $1", start, start, err)
		end

		node.root = root
		self.root.imports = self.root.imports or {}
		table.insert(self.root.imports, node)
		return node
	end

	function META:ReadImportExpression()
		if not (self:IsCurrentValue("import") and self:IsValue("(", 1)) then return end
		local node = self:Expression("import")
		node.tokens["import"] = self:ReadValue("import")
		node.tokens["("] = {self:ReadValue("(")}
		local start = self:GetCurrentToken()
		node.expressions = self:ReadExpressionList()
		local root = self.config.path and self.config.path:match("(.+/)") or ""
		node.path = root .. node.expressions[1].value.value:sub(2, -2)
		local nl = require("nattlua")
		local root, err = nl.ParseFile(self:ResolvePath(node.path), self.root)

		if not root then
			self:Error("error importing file: $1", start, start, err)
		end

		node.root = root.SyntaxTree
		node.analyzer = root
		node.tokens[")"] = {self:ReadValue(")")}
		self.root.imports = self.root.imports or {}
		table.insert(self.root.imports, node)
		return node
	end
end
