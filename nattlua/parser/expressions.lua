local table_insert = _G.table.insert
local table_remove = _G.table.remove
local ipairs = _G.ipairs
local math_huge = math.huge
local io_open = _G.io.open
local package = _G.package
local runtime_syntax = require("nattlua.syntax.runtime")
local typesystem_syntax = require("nattlua.syntax.typesystem")
local path_util = require("nattlua.other.path")

--[[#local type { Node } = import("~/nattlua/parser/node.lua")]]

return function(META)
	function META:ParseValueExpressionToken(expect_value--[[#: nil | string]])
		local node = self:StartNode("expression_value")
		node.value = expect_value and self:ExpectTokenValue(expect_value) or self:ParseToken()
		node = self:EndNode(node)
		return node
	end

	function META:ParseAnalyzerFunctionExpression()
		if not (self:IsToken("analyzer") and self:IsTokenOffset("function", 1)) then
			return
		end

		local node = self:StartNode("expression_analyzer_function")
		node.tokens["analyzer"] = self:ExpectToken("analyzer")
		node.tokens["function"] = self:ExpectToken("function")
		self:ParseAnalyzerFunctionBody(node)
		node = self:EndNode(node)
		return node
	end

	function META:ParseFunctionExpression()
		if not self:IsToken("function") then return end

		local node = self:StartNode("expression_function")
		node.tokens["function"] = self:ExpectToken("function")
		self:ParseFunctionBody(node)
		node = self:EndNode(node)
		return node
	end

	function META:ParseIndexSubExpression(left_node--[[#: Node]])
		if not (self:IsToken(".") and self:IsTokenTypeOffset("letter", 1)) then
			return
		end

		local node = self:StartNode("expression_binary_operator")
		node.value = self:ParseToken()
		node.right = self:ParseValueExpressionType("letter")
		node.left = left_node
		node = self:EndNode(node)
		return node
	end

	function META:IsCallExpression(offset--[[#: number]])
		local tk = self:GetTokenOffset(offset)
		return (
				tk.sub_type == "(" or
				tk.sub_type == "<|" or
				tk.sub_type == "{"
			)
			or
			tk.type == "string" or
			(
				tk.sub_type == "!" and
				self:IsTokenOffset("(", offset + 1)
			)
	end

	function META:ParseSelfCallSubExpression(left_node--[[#: Node]])
		if
			not (
				self:IsToken(":") and
				self:IsTokenTypeOffset("letter", 1) and
				self:IsCallExpression(2)
			)
		then
			return
		end

		local node = self:StartNode("expression_binary_operator", left_node)
		node.value = self:ParseToken()
		node.right = self:ParseValueExpressionType("letter")
		node.left = left_node
		node = self:EndNode(node)
		return node
	end

	do -- typesystem
		function META:ParseParenthesisOrTupleTypeExpression()
			if not self:IsToken("(") then return end

			local pleft = self:ExpectToken("(")
			local node = self:ParseTypeExpression(0)

			if not node or self:IsToken(",") then
				local first_expression = node
				local node = self:StartNode("expression_tuple", first_expression)

				if self:IsToken(",") then
					first_expression.tokens[","] = self:ExpectToken(",")
					node.expressions = {first_expression}
					self:ParseMultipleValuesAppend(self.ParseTypeExpression, node.expressions, 0)
				else
					node.expressions = {first_expression}
				end

				node.tokens["("] = pleft
				node.tokens[")"] = self:ExpectToken(")", pleft)
				node = self:EndNode(node)
				return node
			end

			node.tokens["("] = node.tokens["("] or {}
			table_insert(node.tokens["("], pleft)
			node.tokens[")"] = node.tokens[")"] or {}
			table_insert(node.tokens[")"], self:ExpectToken(")"))
			return node
		end

		function META:ParsePrefixOperatorTypeExpression()
			if not typesystem_syntax:IsPrefixOperator(self:GetToken()) then return end

			local node = self:StartNode("expression_prefix_operator")
			node.value = self:ParseToken()
			node.tokens[1] = node.value

			if node.value.sub_type == "expand" then
				self:PushParserEnvironment("runtime")
			end

			node.right = self:ParseTypeExpression(math_huge)

			if node.value.sub_type == "expand" then self:PopParserEnvironment() end

			node = self:EndNode(node)
			return node
		end

		function META:ParseValueTypeExpression()
			if not self:IsToken("...") then return end

			local node = self:StartNode("expression_vararg")
			node.tokens["..."] = self:ExpectToken("...")

			if not self:GetToken():HasWhitespace() then
				node.value = self:ParseTypeExpression(0) or false
			end

			node = self:EndNode(node)
			return node
		end

		function META:ParseTypeSignatureFunctionArgument(expect_type)
			if self:IsToken(")") then return end

			if
				expect_type or
				(
					(
						self:IsTokenType("letter") or
						self:IsToken("...")
					) and
					self:IsTokenOffset(":", 1)
				)
			then
				local identifier = self:ParseToken()
				local token = self:ExpectToken(":")
				local modifiers = self:ParseModifiers()
				local exp = self:ExpectTypeExpression(0)
				exp.tokens[":"] = token
				exp.identifier = identifier
				exp.modifiers = modifiers
				return exp
			end

			local modifiers = self:ParseModifiers()
			local exp = self:ExpectTypeExpression(0)
			exp.modifiers = modifiers
			return exp
		end

		function META:ParseFunctionSignatureExpression()
			if not (self:IsToken("function") and self:IsTokenOffset("=", 1)) then
				return
			end

			local node = self:StartNode("expression_function_signature")
			node.tokens["function"] = self:ExpectToken("function")
			node.tokens["="] = self:ExpectToken("=")
			node.tokens["arguments("] = self:ExpectToken("(")
			node.identifiers = self:ParseMultipleValues(self.ParseTypeSignatureFunctionArgument)
			node.tokens["arguments)"] = self:ExpectToken(")")
			node.tokens[">"] = self:ExpectToken(">")
			node.tokens["return("] = self:ExpectToken("(")
			node.return_types = self:ParseMultipleValues(self.ParseTypeSignatureFunctionArgument)
			node.tokens["return)"] = self:ExpectToken(")")
			node = self:EndNode(node)
			return node
		end

		function META:ParseTypeFunctionExpression()
			if not (self:IsToken("function") and self:IsTokenOffset("<|", 1)) then
				return
			end

			local node = self:StartNode("expression_type_function")
			node.tokens["function"] = self:ExpectToken("function")
			self:ParseTypeFunctionBody(node)
			node = self:EndNode(node)
			return node
		end

		function META:ParseKeywordValueTypeExpression()
			if not typesystem_syntax:IsValue(self:GetToken()) then return end

			local node = self:StartNode("expression_value")
			node.value = self:ParseToken()
			node = self:EndNode(node)
			return node
		end

		do
			function META:read_type_table_entry(i--[[#: number]])
				if self:IsToken("[") then
					local node = self:StartNode("sub_statement_table_expression_value")
					node.tokens["["] = self:ExpectToken("[")
					node.key_expression = self:ParseTypeExpression(0)
					node.tokens["]"] = self:ExpectToken("]")
					node.tokens["="] = self:ExpectToken("=")
					node.value_expression = self:ParseTypeExpression(0)
					node = self:EndNode(node)
					return node
				elseif self:IsTokenType("letter") and self:IsTokenOffset("=", 1) then
					local node = self:StartNode("sub_statement_table_key_value")
					node.tokens["identifier"] = self:ExpectTokenType("letter")
					node.tokens["="] = self:ExpectToken("=")
					node.value_expression = self:ParseTypeExpression(0)
					node = self:EndNode(node)
					return node
				end

				local node = self:StartNode("sub_statement_table_index_value")
				local spread = self:read_table_spread()

				if spread then
					node.spread = spread
				else
					node.key = i
					node.value_expression = self:ParseTypeExpression(0)
				end

				node = self:EndNode(node)
				return node
			end

			function META:ParseTableTypeExpression()
				if not self:IsToken("{") then return end

				local tree = self:StartNode("expression_type_table")
				tree.tokens["{"] = self:ExpectToken("{")
				tree.children = {}
				tree.tokens["separators"] = {}
				local i = 1

				for _ = self:GetPosition(), self:GetLength() do
					if self:IsToken("}") then break end

					local entry = self:read_type_table_entry(i)

					if entry.spread then tree.spread = true end

					tree.children[i] = entry

					if
						not self:IsToken(",") and
						not self:IsToken(";")
						and
						not self:IsToken("}")
					then
						self:Error(
							"expected $1 got $2",
							nil,
							nil,
							{",", ";", "}"},
							self:GetToken():GetValueString()
						)
						tree.tokens["separators"][i] = self:NewToken(",")
					else
						if not self:IsToken("}") then
							tree.tokens["separators"][i] = self:ParseToken()
						end
					end

					i = i + 1
				end

				tree.tokens["}"] = self:ExpectToken("}")
				tree = self:EndNode(tree)
				return tree
			end
		end

		function META:ParseStringTypeExpression()
			if not self:IsToken("$") or not self:IsTokenTypeOffset("string", 1) then
				return
			end

			local node = self:StartNode("expression_type_string")
			node.tokens["$"] = self:ParseToken("$")
			node.value = self:ExpectTokenType("string")
			return node
		end

		function META:ParseEmptyUnionTypeExpression()
			if not self:IsToken("|") then return end

			local node = self:StartNode("expression_empty_union")
			node.tokens["|"] = self:ParseToken("|")
			node = self:EndNode(node)
			return node
		end

		function META:ParseAsSubExpression(node--[[#: Node]])
			if not self:IsToken("as") then return end

			node.tokens["as"] = self:ExpectToken("as")
			node.type_expression = self:ParseTypeExpression(0)
		end

		function META:ParsePostfixTypeOperatorSubExpression(left_node--[[#: Node]])
			if not typesystem_syntax:IsPostfixOperator(self:GetToken()) then return end

			local node = self:StartNode("expression_postfix_operator")
			node.value = self:ParseToken()
			node.left = left_node
			node = self:EndNode(node)
			return node
		end

		function META:ParseTypeCallSubExpression(left_node--[[#: Node]], primary_node--[[#: Node]])
			if not self:IsCallExpression(0) then return end

			local node = self:StartNode("expression_postfix_call")
			local start = self:GetToken()

			if self:IsToken("{") then
				node.expressions = {self:ParseTableTypeExpression()}
			elseif self:IsTokenType("string") then
				node.expressions = {self:ParseValueExpressionToken()}
			elseif self:IsToken("<|") then
				node.tokens["call("] = self:ExpectToken("<|")
				node.expressions = self:ParseMultipleValues(self.ParseTypeExpression, 0)
				node.tokens["call)"] = self:ExpectToken("|>")
			else
				node.tokens["call("] = self:ExpectToken("(")
				node.expressions = self:ParseMultipleValues(self.ParseTypeExpression, 0)
				node.tokens["call)"] = self:ExpectToken(")")
			end

			if
				primary_node.Type == "expression_value" and
				node.expressions[1] and
				node.expressions[1].value and
				node.expressions[1].value.type == "string"
			then
				if primary_node.value.sub_type == "import" then
					self:HandleImportExpression(node, primary_node.value, node.expressions[1].value, start)
				elseif primary_node.value.sub_type == "import_data" then
					self:HandleImportDataExpression(node, node.expressions[1].value, start)
				end
			end

			node.left = left_node
			node.type_call = true
			node = self:EndNode(node)
			return node
		end

		function META:ParsePostfixTypeIndexExpressionSubExpression(left_node--[[#: Node]])
			if not self:IsToken("[") then return end

			local node = self:StartNode("expression_postfix_expression_index")
			node.tokens["["] = self:ExpectToken("[")
			node.expression = self:ExpectTypeExpression(0)
			node.tokens["]"] = self:ExpectToken("]")
			node.left = left_node
			node = self:EndNode(node)
			return node
		end

		function META:ParseTypeSubExpression(node--[[#: Node]])
			for _ = self:GetPosition(), self:GetLength() do
				local left_node = node
				local found = self:ParseIndexSubExpression(left_node) or
					self:ParseSelfCallSubExpression(left_node) or
					self:ParsePostfixTypeOperatorSubExpression(left_node) or
					self:ParseTypeCallSubExpression(left_node, node) or
					self:ParsePostfixTypeIndexExpressionSubExpression(left_node) or
					self:ParseAsSubExpression(left_node)

				if not found then break end

				if
					left_node.Type == "expression_binary_operator" and
					left_node.value.sub_type == ":"
				then
					found.parser_call = true
				end

				node = found
			end

			return node
		end

		function META:ParseTypeExpression(priority--[[#: number]])
			if self.TealCompat then return self:ParseTealExpression(priority) end

			self:PushParserEnvironment("typesystem")
			local node
			local force_upvalue

			if self:IsToken("^") then force_upvalue = self:ExpectToken("^") end

			node = self:ParseParenthesisOrTupleTypeExpression() or
				self:ParseEmptyUnionTypeExpression() or
				self:ParsePrefixOperatorTypeExpression() or
				self:ParseAnalyzerFunctionExpression() or -- shared
				self:ParseFunctionSignatureExpression() or
				self:ParseTypeFunctionExpression() or -- shared
				self:ParseFunctionExpression() or -- shared
				self:ParseValueTypeExpression() or
				self:ParseKeywordValueTypeExpression() or
				self:ParseTableTypeExpression() or
				self:ParseStringTypeExpression()
			local first = node

			if node then
				node = self:ParseTypeSubExpression(node)

				if
					first.Type == "expression_value" and
					(
						first.value.type == "letter" or
						first.value.sub_type == "..."
					)
				then
					first.standalone_letter = node

					if force_upvalue then
						first.force_upvalue = true
						first.tokens["^"] = force_upvalue
					end
				end
			end

			for _ = self:GetPosition(), self:GetLength() do
				local info = typesystem_syntax:GetBinaryOperatorInfo(self:GetToken())

				if not (info and info.left_priority > priority) then break end

				local left_node = node
				node = self:StartNode("expression_binary_operator", left_node)
				node.value = self:ParseToken()
				node.left = left_node
				node.right = self:ParseTypeExpression(info.right_priority)
				node = self:EndNode(node)
			end

			self:PopParserEnvironment()

			if node then node.modifiers = modifiers end

			return node
		end

		function META:IsTypeExpression()
			local token = self:GetToken()

			if token.type == "string" or token.type == "number" then return true end

			return not (
				not token or
				token.type == "end_of_file" or
				token.sub_type == (
					"}"
				)
				or
				token.sub_type == (
					","
				)
				or
				token.sub_type == (
					"]"
				)
				or
				(
					typesystem_syntax:IsKeyword(token) and
					not typesystem_syntax:IsPrefixOperator(token)
					and
					not typesystem_syntax:IsValue(token)
					and
					token.sub_type ~= "function"
				)
			)
		end

		function META:ExpectTypeExpression(priority--[[#: number]])
			local token = self:GetToken()

			if not typesystem_syntax:IsTypesystemExpression(token) then
				self:Error("expected beginning of expression, got $1", nil, nil, token.type)
				return self:ErrorExpression()
			end

			local exp = self:ParseTypeExpression(priority)

			if not exp then
				self:Error("faiiled to parse type expression, got $1", nil, nil, token.type)
				return self:ErrorExpression()
			end

			return exp
		end
	end

	do -- runtime
		local ParseTableExpression

		do
			function META:read_table_spread()
				if
					not (
						self:IsToken("...") and
						(
							self:IsTokenTypeOffset("letter", 1) or
							(
								self:IsTokenOffset("{", 1) or
								self:IsTokenOffset("(", 1)
							)
						)
					)
				then
					return
				end

				local node = self:StartNode("expression_table_spread")
				node.tokens["..."] = self:ExpectToken("...")
				node.expression = self:ExpectRuntimeExpression()
				node = self:EndNode(node)
				return node
			end

			function META:read_table_entry(i--[[#: number]])
				if self:IsToken("[") then
					local node = self:StartNode("sub_statement_table_expression_value")
					node.tokens["["] = self:ExpectToken("[")
					node.key_expression = self:ExpectRuntimeExpression(0)
					node.tokens["]"] = self:ExpectToken("]")

					if self:IsToken(":") and not self:IsTokenOffset("(", 2) then
						node.tokens[":"] = self:ExpectToken(":")
						node.type_expression = self:ExpectTypeExpression(0)
					end

					if self:IsToken("=") then
						node.tokens["="] = self:ExpectToken("=")
						node.value_expression = self:ExpectRuntimeExpression(0)
					end

					node = self:EndNode(node)
					return node
				elseif self:IsTokenType("letter") and self:IsTokenOffset("=", 1) then
					local node = self:StartNode("sub_statement_table_key_value")
					node.tokens["identifier"] = self:ExpectTokenType("letter")

					if self:IsToken(":") and not self:IsTokenOffset("(", 2) then
						node.tokens[":"] = self:ExpectToken(":")
						node.type_expression = self:ExpectTypeExpression(0)
					end

					node.tokens["="] = self:ExpectToken("=")
					local spread = self:read_table_spread()

					if spread then
						node.spread = spread
					else
						node.value_expression = self:ExpectRuntimeExpression()
					end

					node = self:EndNode(node)
					return node
				elseif
					self:IsTokenType("letter") and
					self:IsTokenOffset(":", 1) and
					not self:IsTokenOffset("(", 3)
				then
					local node = self:StartNode("sub_statement_table_key_value")
					node.tokens["identifier"] = self:ExpectTokenType("letter")
					node.tokens[":"] = self:ExpectToken(":")
					node.type_expression = self:ExpectTypeExpression(0)

					if self:IsToken("=") then
						node.tokens["="] = self:ExpectToken("=")
						local spread = self:read_table_spread()

						if spread then
							node.spread = spread
						else
							node.value_expression = self:ExpectRuntimeExpression()
						end
					end

					node = self:EndNode(node)
					return node
				end

				local node = self:StartNode("sub_statement_table_index_value")
				local spread = self:read_table_spread()

				if spread then
					node.spread = spread
				else
					node.value_expression = self:ExpectRuntimeExpression()
				end

				node.key = i
				node = self:EndNode(node)
				return node
			end

			function META:ParseTableExpression()
				if not self:IsToken("{") then return end

				local tree = self:StartNode("expression_table")
				tree.tokens["{"] = self:ExpectToken("{")
				tree.children = {}
				tree.tokens["separators"] = {}
				local i = 1

				for _ = self:GetPosition(), self:GetLength() do
					if self:IsToken("}") then break end

					local entry = self:read_table_entry(i)

					if entry.Type == "sub_statement_table_index_value" then
						tree.is_array = true
					else
						tree.is_dictionary = true
					end

					if entry.Type == "sub_statement_table_index_value" and entry.spread then
						tree.spread = true
					end

					tree.children[i] = entry

					if
						not self:IsToken(",") and
						not self:IsToken(";")
						and
						not self:IsToken("}")
					then
						self:Error(
							"expected $1 got $2",
							nil,
							nil,
							{",", ";", "}"},
							self:GetToken():GetValueString()
						)
						tree.tokens["separators"][i] = self:NewToken(",")
					else
						if not self:IsToken("}") then
							tree.tokens["separators"][i] = self:ParseToken()
						end
					end

					i = i + 1
				end

				tree.tokens["}"] = self:ExpectToken("}")
				tree = self:EndNode(tree)
				return tree
			end
		end

		function META:ParsePostfixOperatorSubExpression(left_node--[[#: Node]])
			if not runtime_syntax:IsPostfixOperator(self:GetToken()) then return end

			local node = self:StartNode("expression_postfix_operator")
			node.value = self:ParseToken()
			node.left = left_node
			node = self:EndNode(node)
			return node
		end

		function META:ParseCallSubExpression(left_node--[[#: Node]], primary_node--[[#: Node]])
			if not self:IsCallExpression(0) then return end

			if primary_node and primary_node.Type == "expression_function" then
				if not primary_node.tokens[")"] then return end
			end

			local node = self:StartNode("expression_postfix_call", left_node)
			local start = self:GetToken()

			if self:IsToken("{") then
				node.expressions = {self:ParseTableExpression()}
			elseif self:IsTokenType("string") then
				node.expressions = {self:ParseValueExpressionToken()}
			elseif self:IsToken("<|") then
				node.tokens["call("] = self:ExpectToken("<|")
				node.expressions = self:ParseMultipleValues(self.ParseTypeExpression, 0)
				node.tokens["call)"] = self:ExpectToken("|>")
				node.type_call = true

				if self:IsToken("(") then
					local lparen = self:ExpectToken("(")
					local expressions = self:ParseMultipleValues(self.ParseTypeExpression, 0)
					local rparen = self:ExpectToken(")")
					node.expressions_typesystem = node.expressions
					node.expressions = expressions
					node.tokens["call_typesystem("] = node.tokens["call("]
					node.tokens["call_typesystem)"] = node.tokens["call)"]
					node.tokens["call("] = lparen
					node.tokens["call)"] = rparen
				end
			elseif self:IsToken("!") then
				node.tokens["!"] = self:ExpectToken("!")
				node.tokens["call("] = self:ExpectToken("(")
				node.expressions = self:ParseMultipleValues(self.ParseTypeExpression, 0)
				node.tokens["call)"] = self:ExpectToken(")")
				node.type_call = true
			else
				node.tokens["call("] = self:ExpectToken("(")

				if
					-- hack for sizeof as it expects a c declaration expression in the C declaration parser
					self.FFI_DECLARATION_PARSER and
					primary_node.Type == "expression_value" and
					primary_node.value.sub_type == "sizeof"
				then
					node.expressions = self:ParseMultipleValues(self.ParseCDeclaration, 0)
				else
					node.expressions = self:ParseMultipleValues(self.ParseRuntimeExpression, 0)
				end

				node.tokens["call)"] = self:ExpectToken(")")
			end

			if
				primary_node.Type == "expression_value" and
				node.expressions[1] and
				node.expressions[1].Type == "expression_value" and
				node.expressions[1].value and
				node.expressions[1].value.type == "string" and
				(
					primary_node.value.sub_type == "import" or
					primary_node.value.sub_type == "dofile" or
					primary_node.value.sub_type == "loadfile" or
					primary_node.value.sub_type == "require" or
					primary_node.value.sub_type == "import_data"
				)
			then
				if primary_node.value.sub_type == "import_data" then
					self:HandleImportDataExpression(node, node.expressions[1].value, start)
				else
					self:HandleImportExpression(node, primary_node.value, node.expressions[1].value, start)
				end
			end

			node.left = left_node
			node = self:EndNode(node)
			return node
		end

		function META:ParsePostfixIndexExpressionSubExpression(left_node--[[#: Node]])
			if not self:IsToken("[") then return end

			local node = self:StartNode("expression_postfix_expression_index")
			node.tokens["["] = self:ExpectToken("[")
			node.expression = self:ExpectRuntimeExpression()
			node.tokens["]"] = self:ExpectToken("]")
			node.left = left_node
			node = self:EndNode(node)
			return node
		end

		function META:ParseSubExpression(node--[[#: Node]])
			for _ = self:GetPosition(), self:GetLength() do
				local left_node = node

				if
					self:IsToken(":") and
					(
						not self:IsTokenTypeOffset("letter", 1) or
						not self:IsCallExpression(2)
					)
					and
					-- special case for autocompletion to work while typing and : is the last character of the code
					not self:IsTokenTypeOffset("end_of_file", 2)
				then
					node.tokens[":"] = self:ExpectToken(":")
					node.type_expression = self:ExpectTypeExpression(0)
				elseif self:IsToken("as") then
					node.tokens["as"] = self:ExpectToken("as")
					node.type_expression = self:ExpectTypeExpression(0)
				end

				local found = self:ParseIndexSubExpression(left_node) or
					self:ParseSelfCallSubExpression(left_node) or
					self:ParseCallSubExpression(left_node, node) or
					self:ParsePostfixOperatorSubExpression(left_node) or
					self:ParsePostfixIndexExpressionSubExpression(left_node)

				if not found then break end

				if left_node.Type == "expression_value" and left_node.value.sub_type == ":" then
					found.parser_call = true
				end

				node = found
			end

			return node
		end

		function META:ParsePrefixOperatorExpression()
			if not runtime_syntax:IsPrefixOperator(self:GetToken()) then return end

			local node = self:StartNode("expression_prefix_operator")
			node.value = self:ParseToken()
			node.tokens[1] = node.value
			node.right = self:ExpectRuntimeExpression(math_huge)
			node = self:EndNode(node)
			return node
		end

		function META:ParseParenthesisExpression()
			if not self:IsToken("(") then return end

			local pleft = self:ExpectToken("(")
			local node = self:ExpectRuntimeExpression(0)
			node.tokens["("] = node.tokens["("] or {}
			table_insert(node.tokens["("], pleft)
			node.tokens[")"] = node.tokens[")"] or {}
			table_insert(node.tokens[")"], self:ExpectToken(")"))
			return node
		end

		function META:ParseValueExpression()
			if not runtime_syntax:IsValue(self:GetToken()) then return end

			return self:ParseValueExpressionToken()
		end

		function META:HandleImportExpression(
			node--[[#: Node]],
			tkname--[[#: Token]],
			tk_path--[[#: string]],
			start--[[#: number]]
		)
			assert(tk_path.type == "string", "expected string token for import path")

			if self.config.skip_import then return end

			if self.dont_hoist_next_import then
				self.dont_hoist_next_import = false
				return
			end

			local str = tk_path:GetStringValue()
			local path

			if tkname.sub_type == "require" then path = path_util.ResolveRequire(str) end

			path = path_util.Resolve(
				path or str,
				self.config.root_directory,
				self.config.working_directory,
				self.config.file_path
			)

			if tkname.sub_type == "require" then
				if not path_util.Exists(path) then return end
			end

			if not path then return end

			local dont_hoist_import = _G.dont_hoist_import and _G.dont_hoist_import > 0
			node.import_expression = true
			node.path = path
			local key = tkname.sub_type == "require" and str or path
			local root_node = self.config.root_statement_override_data or
				self.config.root_statement_override or
				self.RootStatement
			root_node.imported = root_node.imported or {}
			local imported = root_node.imported
			node.key = key
			local key = path

			if key:sub(1, 2) == "./" then key = key:sub(3) end

			if imported[key] == nil then
				imported[key] = node
				local root, err = self:ParseFile(
					path,
					{
						root_statement_override = root_node,
						path = node.path,
						working_directory = self.config.working_directory,
						inline_require = not root_node.data_import,
						on_parsed_node = self.config.on_parsed_node,
						pre_read_file = self.config.pre_read_file,
						on_read_file = self.config.on_read_file,
						on_parsed_file = self.config.on_parsed_file,
						root_directory = self.config.root_directory,
					}
				)

				if not root then
					self:Error("error importing file: $1", start, start, err)
				end

				imported[key] = root
				node.RootStatement = root
			else
				-- ugly way of dealing with recursive require
				node.RootStatement = imported[key]
			end

			if root_node.data_import and dont_hoist_import then
				root_node.imports = root_node.imports or {}
				table_insert(root_node.imports, node)
				return
			end

			if tkname.sub_type == "require" and not self.config.inline_require then
				root_node.imports = root_node.imports or {}
				table_insert(root_node.imports, node)
				return
			end

			self.RootStatement.imports = self.RootStatement.imports or {}
			table_insert(self.RootStatement.imports, node)
		end

		function META:HandleImportDataExpression(node--[[#: Node]], tk_path--[[#: string]], start--[[#: number]])
			assert(tk_path.type == "string", "expected string token for import path")

			if self.config.skip_import then return end

			local path = tk_path:GetStringValue()
			node.import_expression = true
			node.path = path_util.Resolve(
				path,
				self.config.root_directory,
				self.config.working_directory,
				self.config.file_path
			)
			self.imported = self.imported or {}
			local key = "DATA_" .. node.path
			node.key = key
			local root_node = self.config.root_statement_override_data or
				self.config.root_statement_override or
				self.RootStatement
			local root_node = self.config.root_statement_override or self.RootStatement
			root_node.imported = root_node.imported or {}
			local imported = root_node.imported
			root_node.data_import = true
			local data
			local err
			local key = path

			if key:sub(1, 2) == "./" then key = key:sub(3) end

			if imported[key] == nil then
				imported[key] = node

				if node.path:sub(-4) == "lua" or node.path:sub(-5) ~= "nlua" then
					local root, err = self:ParseFile(
						node.path,
						{
							root_statement_override_data = root_node,
							path = node.path,
							working_directory = self.config.working_directory,
							on_parsed_node = self.config.on_parsed_node,
							pre_read_file = self.config.pre_read_file,
							on_read_file = self.config.on_read_file,
							on_parsed_file = self.config.on_parsed_file,
							root_directory = self.config.root_directory,
						--inline_require = true,
						}
					)

					if not root then
						self:Error("error importing file: $1", start, start, err .. ": " .. node.path)
						data = self:ErrorExpression()
					end

					imported[key] = root
					data = root:Render(
						{
							pretty_print = true,
							comment_type_annotations = false,
							type_annotations = true,
							inside_data_import = true,
							no_newlines = false,
						}
					)
				else
					local f
					f, err = io_open(node.path, "rb")

					if f then
						data = f:read("*a")
						f:close()
					end
				end

				if not data then
					self:Error("error importing file: $1", start, start, err .. ": " .. node.path)
					data = self:ErrorExpression()
				end

				node.data = data
			else
				node.data = imported[key].data
			end

			if _G.dont_hoist_import and _G.dont_hoist_import > 0 then return end

			self.RootStatement.imports = self.RootStatement.imports or {}
			table_insert(self.RootStatement.imports, node)
			return node
		end

		function META:ParseRuntimeExpression(priority--[[#: number]])
			if self:GetCurrentParserEnvironment() == "typesystem" then
				return self:ParseTypeExpression(priority)
			end

			priority = priority or 0
			local node = self:ParseParenthesisExpression() or
				self:ParsePrefixOperatorExpression() or
				self:ParseAnalyzerFunctionExpression() or
				self:ParseFunctionExpression() or
				self:ParseValueExpression() or
				self:ParseTableExpression() or
				self:ParseLSXExpression()
			local first = node or false

			if node then
				node = self:ParseSubExpression(node)

				if
					first.Type == "expression_value" and
					(
						first.value.type == "letter" or
						first.value.sub_type == "..."
					)
				then
					first.standalone_letter = node
				end
			end

			for _ = self:GetPosition(), self:GetLength() do
				if self:IsTokenOffset("=", 1) then break end

				local info = runtime_syntax:GetBinaryOperatorInfo(self:GetToken())

				if not info or info.left_priority <= priority then break end

				local left_node = node or false
				node = self:StartNode("expression_binary_operator", left_node)
				node.value = self:ParseToken()
				node.left = left_node

				if node.left then node.left.parent = node end

				node.right = self:ExpectRuntimeExpression(info.right_priority)
				node = self:EndNode(node)

				if not node.right then
					local token = self:GetToken()
					self:Error(
						"expected right side to be an expression, got $1",
						nil,
						nil,
						token.type
					)
					return self:ErrorExpression()
				end
			end

			if node then node.first_node = first end

			return node or false
		end

		function META:ExpectRuntimeExpression(priority--[[#: number]])
			local token = self:GetToken()

			if not runtime_syntax:IsRuntimeExpression(token) then
				self:Error("expected beginning of expression, got $1", nil, nil, token.type)
				return self:ErrorExpression()
			end

			return self:ParseRuntimeExpression(priority)
		end
	end
end
