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
	function META:ParseAnalyzerFunctionExpression()
		if not (self:IsTokenValue("analyzer") and self:IsTokenValue("function", 1)) then
			return
		end

		local node = self:StartNode("expression", "analyzer_function")
		node.tokens["analyzer"] = self:ExpectTokenValue("analyzer")
		node.tokens["function"] = self:ExpectTokenValue("function")
		self:ParseAnalyzerFunctionBody(node)
		node = self:EndNode(node)
		return node
	end

	function META:ParseFunctionExpression()
		if not self:IsTokenValue("function") then return end

		local node = self:StartNode("expression", "function")
		node.tokens["function"] = self:ExpectTokenValue("function")
		self:ParseFunctionBody(node)
		node = self:EndNode(node)
		return node
	end

	function META:ParseIndexSubExpression(left_node--[[#: Node]])
		if not (self:IsTokenValue(".") and self:IsTokenType("letter", 1)) then return end

		local node = self:StartNode("expression", "binary_operator")
		node.value = self:ParseToken()
		node.right = self:ParseValueExpressionType("letter")
		node.left = left_node
		node = self:EndNode(node)
		return node
	end

	function META:IsCallExpression(offset--[[#: number]])
		return self:IsTokenValue("(", offset) or
			self:IsTokenValue("<|", offset) or
			self:IsTokenValue("{", offset) or
			self:IsTokenType("string", offset) or
			(
				self:IsTokenValue("!", offset) and
				self:IsTokenValue("(", offset + 1)
			)
	end

	function META:ParseSelfCallSubExpression(left_node--[[#: Node]])
		if
			not (
				self:IsTokenValue(":") and
				self:IsTokenType("letter", 1) and
				self:IsCallExpression(2)
			)
		then
			return
		end

		local node = self:StartNode("expression", "binary_operator", left_node)
		node.value = self:ParseToken()
		node.right = self:ParseValueExpressionType("letter")
		node.left = left_node
		node = self:EndNode(node)
		return node
	end

	do -- typesystem
		function META:ParseParenthesisOrTupleTypeExpression()
			if not self:IsTokenValue("(") then return end

			local pleft = self:ExpectTokenValue("(")
			local node = self:ParseTypeExpression(0)

			if not node or self:IsTokenValue(",") then
				local first_expression = node
				local node = self:StartNode("expression", "tuple", first_expression)

				if self:IsTokenValue(",") then
					first_expression.tokens[","] = self:ExpectTokenValue(",")
					node.expressions = {first_expression}
					self:ParseMultipleValuesAppend(self.ParseTypeExpression, node.expressions, 0)
				else
					node.expressions = {first_expression}
				end

				node.tokens["("] = pleft
				node.tokens[")"] = self:ExpectTokenValue(")", pleft)
				node = self:EndNode(node)
				return node
			end

			node.tokens["("] = node.tokens["("] or {}
			table_insert(node.tokens["("], pleft)
			node.tokens[")"] = node.tokens[")"] or {}
			table_insert(node.tokens[")"], self:ExpectTokenValue(")"))
			return node
		end

		function META:ParsePrefixOperatorTypeExpression()
			if not typesystem_syntax:IsPrefixOperator(self:GetToken()) then return end

			local node = self:StartNode("expression", "prefix_operator")
			node.value = self:ParseToken()
			node.tokens[1] = node.value

			if node.value.value == "expand" then
				self:PushParserEnvironment("runtime")
			end

			node.right = self:ParseRuntimeExpression(math_huge)

			if node.value.value == "expand" then self:PopParserEnvironment() end

			node = self:EndNode(node)
			return node
		end

		function META:ParseValueTypeExpression()
			if not self:IsTokenValue("...") then return end

			local node = self:StartNode("expression", "vararg")
			node.tokens["..."] = self:ExpectTokenValue("...")

			if not self:GetToken().whitespace then
				node.value = self:ParseTypeExpression(0)
			end

			node = self:EndNode(node)
			return node
		end

		function META:ParseTypeSignatureFunctionArgument(expect_type)
			if self:IsTokenValue(")") then return end

			if
				expect_type or
				(
					(
						self:IsTokenType("letter") or
						self:IsTokenValue("...")
					) and
					self:IsTokenValue(":", 1)
				)
			then
				local identifier = self:ParseToken()
				local token = self:ExpectTokenValue(":")
				local exp = self:ExpectTypeExpression(0)
				exp.tokens[":"] = token
				exp.identifier = identifier
				return exp
			end

			return self:ExpectTypeExpression(0)
		end

		function META:ParseFunctionSignatureExpression()
			if not (self:IsTokenValue("function") and self:IsTokenValue("=", 1)) then
				return
			end

			local node = self:StartNode("expression", "function_signature")
			node.tokens["function"] = self:ExpectTokenValue("function")
			node.tokens["="] = self:ExpectTokenValue("=")
			node.tokens["arguments("] = self:ExpectTokenValue("(")
			node.identifiers = self:ParseMultipleValues(self.ParseTypeSignatureFunctionArgument)
			node.tokens["arguments)"] = self:ExpectTokenValue(")")
			node.tokens[">"] = self:ExpectTokenValue(">")
			node.tokens["return("] = self:ExpectTokenValue("(")
			node.return_types = self:ParseMultipleValues(self.ParseTypeSignatureFunctionArgument)
			node.tokens["return)"] = self:ExpectTokenValue(")")
			node = self:EndNode(node)
			return node
		end

		function META:ParseTypeFunctionExpression()
			if not (self:IsTokenValue("function") and self:IsTokenValue("<|", 1)) then
				return
			end

			local node = self:StartNode("expression", "type_function")
			node.tokens["function"] = self:ExpectTokenValue("function")
			self:ParseTypeFunctionBody(node)
			node = self:EndNode(node)
			return node
		end

		function META:ParseKeywordValueTypeExpression()
			if not typesystem_syntax:IsValue(self:GetToken()) then return end

			local node = self:StartNode("expression", "value")
			node.value = self:ParseToken()
			node = self:EndNode(node)
			return node
		end

		do
			function META:read_type_table_entry(i--[[#: number]])
				if self:IsTokenValue("[") then
					local node = self:StartNode("sub_statement", "table_expression_value")
					node.tokens["["] = self:ExpectTokenValue("[")
					node.key_expression = self:ParseTypeExpression(0)
					node.tokens["]"] = self:ExpectTokenValue("]")
					node.tokens["="] = self:ExpectTokenValue("=")
					node.value_expression = self:ParseTypeExpression(0)
					node = self:EndNode(node)
					return node
				elseif self:IsTokenType("letter") and self:IsTokenValue("=", 1) then
					local node = self:StartNode("sub_statement", "table_key_value")
					node.tokens["identifier"] = self:ExpectTokenType("letter")
					node.tokens["="] = self:ExpectTokenValue("=")
					node.value_expression = self:ParseTypeExpression(0)
					node = self:EndNode(node)
					return node
				end

				local node = self:StartNode("sub_statement", "table_index_value")
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
				if not self:IsTokenValue("{") then return end

				local tree = self:StartNode("expression", "type_table")
				tree.tokens["{"] = self:ExpectTokenValue("{")
				tree.children = {}
				tree.tokens["separators"] = {}
				local i = 1

				for _ = self:GetPosition(), self:GetLength() do
					if self:IsTokenValue("}") then break end

					local entry = self:read_type_table_entry(i)

					if entry.spread then tree.spread = true end

					tree.children[i] = entry

					if
						not self:IsTokenValue(",") and
						not self:IsTokenValue(";")
						and
						not self:IsTokenValue("}")
					then
						self:Error(
							"expected $1 got $2",
							nil,
							nil,
							{",", ";", "}"},
							(self:GetToken() and self:GetToken().value) or "no token"
						)
						tree.tokens["separators"][i] = self:NewToken(",")
					else
						if not self:IsTokenValue("}") then
							tree.tokens["separators"][i] = self:ParseToken()
						end
					end

					i = i + 1
				end

				tree.tokens["}"] = self:ExpectTokenValue("}")
				tree = self:EndNode(tree)
				return tree
			end
		end

		function META:ParseStringTypeExpression()
			if not (self:IsTokenType("$") and self:IsTokenType("string", 1)) then return end

			local node = self:StartNode("expression", "type_string")
			node.tokens["$"] = self:ParseToken("...")
			node.value = self:ExpectTokenType("string")
			return node
		end

		function META:ParseEmptyUnionTypeExpression()
			if not self:IsTokenValue("|") then return end

			local node = self:StartNode("expression", "empty_union")
			node.tokens["|"] = self:ParseToken("|")
			node = self:EndNode(node)
			return node
		end

		function META:ParseAsSubExpression(node--[[#: Node]])
			if not self:IsTokenValue("as") then return end

			node.tokens["as"] = self:ExpectTokenValue("as")
			node.type_expression = self:ParseTypeExpression(0)
		end

		function META:ParsePostfixTypeOperatorSubExpression(left_node--[[#: Node]])
			if not typesystem_syntax:IsPostfixOperator(self:GetToken()) then return end

			local node = self:StartNode("expression", "postfix_operator")
			node.value = self:ParseToken()
			node.left = left_node
			node = self:EndNode(node)
			return node
		end

		function META:ParseTypeCallSubExpression(left_node--[[#: Node]], primary_node--[[#: Node]])
			if not self:IsCallExpression(0) then return end

			local node = self:StartNode("expression", "postfix_call")
			local start = self:GetToken()

			if self:IsTokenValue("{") then
				node.expressions = {self:ParseTableTypeExpression()}
			elseif self:IsTokenType("string") then
				node.expressions = {self:ParseValueExpressionToken()}
			elseif self:IsTokenValue("<|") then
				node.tokens["call("] = self:ExpectTokenValue("<|")
				node.expressions = self:ParseMultipleValues(self.ParseTypeExpression, 0)
				node.tokens["call)"] = self:ExpectTokenValue("|>")
			else
				node.tokens["call("] = self:ExpectTokenValue("(")
				node.expressions = self:ParseMultipleValues(self.ParseTypeExpression, 0)
				node.tokens["call)"] = self:ExpectTokenValue(")")
			end

			if primary_node.kind == "value" then
				local name = primary_node.value.value

				if name == "import" then
					self:HandleImportExpression(node, name, node.expressions[1].value:GetStringValue(), start)
				elseif name == "import_data" then
					self:HandleImportDataExpression(node, node.expressions[1].value:GetStringValue(), start)
				end
			end

			node.left = left_node
			node.type_call = true
			node = self:EndNode(node)
			return node
		end

		function META:ParsePostfixTypeIndexExpressionSubExpression(left_node--[[#: Node]])
			if not self:IsTokenValue("[") then return end

			local node = self:StartNode("expression", "postfix_expression_index")
			node.tokens["["] = self:ExpectTokenValue("[")
			node.expression = self:ExpectTypeExpression(0)
			node.tokens["]"] = self:ExpectTokenValue("]")
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

				if left_node.value and left_node.value.value == ":" then
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

			if self:IsTokenValue("^") then
				force_upvalue = self:ExpectTokenValue("^")
			end

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
					first.kind == "value" and
					(
						first.value.type == "letter" or
						first.value.value == "..."
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
				if
					not (
						typesystem_syntax:GetBinaryOperatorInfo(self:GetToken()) and
						typesystem_syntax:GetBinaryOperatorInfo(self:GetToken()).left_priority > priority
					)
				then
					break
				end

				local left_node = node
				node = self:StartNode("expression", "binary_operator", left_node)
				node.value = self:ParseToken()
				node.left = left_node
				node.right = self:ParseTypeExpression(typesystem_syntax:GetBinaryOperatorInfo(node.value).right_priority)
				node = self:EndNode(node)
			end

			self:PopParserEnvironment()
			return node
		end

		function META:IsTypeExpression()
			local token = self:GetToken()
			return not (
				not token or
				token.type == "end_of_file" or
				token.value == "}" or
				token.value == "," or
				token.value == "]" or
				(
					typesystem_syntax:IsKeyword(token) and
					not typesystem_syntax:IsPrefixOperator(token)
					and
					not typesystem_syntax:IsValue(token)
					and
					token.value ~= "function"
				)
			)
		end

		function META:ExpectTypeExpression(priority--[[#: number]])
			if not self:IsTypeExpression() then
				local token = self:GetToken()
				self:Error(
					"expected beginning of expression, got $1",
					nil,
					nil,
					token and token.value ~= "" and token.value or token.type
				)
				return self:ErrorExpression()
			end

			local exp = self:ParseTypeExpression(priority)

			if not exp then
				local token = self:GetToken()
				self:Error(
					"faiiled to parse type expression, got $1",
					nil,
					nil,
					token and token.value ~= "" and token.value or token.type
				)
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
						self:IsTokenValue("...") and
						(
							self:IsTokenType("letter", 1) or
							self:IsTokenValue("{", 1) or
							self:IsTokenValue("(", 1)
						)
					)
				then
					return
				end

				local node = self:StartNode("expression", "table_spread")
				node.tokens["..."] = self:ExpectTokenValue("...")
				node.expression = self:ExpectRuntimeExpression()
				node = self:EndNode(node)
				return node
			end

			function META:read_table_entry(i--[[#: number]])
				if self:IsTokenValue("[") then
					local node = self:StartNode("sub_statement", "table_expression_value")
					node.tokens["["] = self:ExpectTokenValue("[")
					node.key_expression = self:ExpectRuntimeExpression(0)
					node.tokens["]"] = self:ExpectTokenValue("]")

					if self:IsTokenValue(":") and not self:IsTokenValue("(", 2) then
						node.tokens[":"] = self:ExpectTokenValue(":")
						node.type_expression = self:ExpectTypeExpression(0)
					end

					if self:IsTokenValue("=") then
						node.tokens["="] = self:ExpectTokenValue("=")
						node.value_expression = self:ExpectRuntimeExpression(0)
					end

					node = self:EndNode(node)
					return node
				elseif self:IsTokenType("letter") and self:IsTokenValue("=", 1) then
					local node = self:StartNode("sub_statement", "table_key_value")
					node.tokens["identifier"] = self:ExpectTokenType("letter")
					node.tokens["="] = self:ExpectTokenValue("=")
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
					self:IsTokenValue(":", 1) and
					not self:IsTokenValue("(", 3)
				then
					local node = self:StartNode("sub_statement", "table_key_value")
					node.tokens["identifier"] = self:ExpectTokenType("letter")
					node.tokens[":"] = self:ExpectTokenValue(":")
					node.type_expression = self:ExpectTypeExpression(0)

					if self:IsTokenValue("=") then
						node.tokens["="] = self:ExpectTokenValue("=")
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

				local node = self:StartNode("sub_statement", "table_index_value")
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
				if not self:IsTokenValue("{") then return end

				local tree = self:StartNode("expression", "table")
				tree.tokens["{"] = self:ExpectTokenValue("{")
				tree.children = {}
				tree.tokens["separators"] = {}
				local i = 1

				for _ = self:GetPosition(), self:GetLength() do
					if self:IsTokenValue("}") then break end

					local entry = self:read_table_entry(i)

					if entry.kind == "table_index_value" then
						tree.is_array = true
					else
						tree.is_dictionary = true
					end

					if entry.kind == "table_index_value" and entry.spread then
						tree.spread = true
					end

					tree.children[i] = entry

					if
						not self:IsTokenValue(",") and
						not self:IsTokenValue(";")
						and
						not self:IsTokenValue("}")
					then
						self:Error(
							"expected $1 got $2",
							nil,
							nil,
							{",", ";", "}"},
							(self:GetToken() and self:GetToken().value) or "no token"
						)
						tree.tokens["separators"][i] = self:NewToken(",")
					else
						if not self:IsTokenValue("}") then
							tree.tokens["separators"][i] = self:ParseToken()
						end
					end

					i = i + 1
				end

				tree.tokens["}"] = self:ExpectTokenValue("}")
				tree = self:EndNode(tree)
				return tree
			end
		end

		function META:ParsePostfixOperatorSubExpression(left_node--[[#: Node]])
			if not runtime_syntax:IsPostfixOperator(self:GetToken()) then return end

			local node = self:StartNode("expression", "postfix_operator")
			node.value = self:ParseToken()
			node.left = left_node
			node = self:EndNode(node)
			return node
		end

		function META:ParseCallSubExpression(left_node--[[#: Node]], primary_node--[[#: Node]])
			if not self:IsCallExpression(0) then return end

			if primary_node and primary_node.kind == "function" then
				if not primary_node.tokens[")"] then return end
			end

			local node = self:StartNode("expression", "postfix_call", left_node)
			local start = self:GetToken()

			if self:IsTokenValue("{") then
				node.expressions = {self:ParseTableExpression()}
			elseif self:IsTokenType("string") then
				node.expressions = {self:ParseValueExpressionToken()}
			elseif self:IsTokenValue("<|") then
				node.tokens["call("] = self:ExpectTokenValue("<|")
				node.expressions = self:ParseMultipleValues(self.ParseTypeExpression, 0)
				node.tokens["call)"] = self:ExpectTokenValue("|>")
				node.type_call = true

				if self:IsTokenValue("(") then
					local lparen = self:ExpectTokenValue("(")
					local expressions = self:ParseMultipleValues(self.ParseTypeExpression, 0)
					local rparen = self:ExpectTokenValue(")")
					node.expressions_typesystem = node.expressions
					node.expressions = expressions
					node.tokens["call_typesystem("] = node.tokens["call("]
					node.tokens["call_typesystem)"] = node.tokens["call)"]
					node.tokens["call("] = lparen
					node.tokens["call)"] = rparen
				end
			elseif self:IsTokenValue("!") then
				node.tokens["!"] = self:ExpectTokenValue("!")
				node.tokens["call("] = self:ExpectTokenValue("(")
				node.expressions = self:ParseMultipleValues(self.ParseTypeExpression, 0)
				node.tokens["call)"] = self:ExpectTokenValue(")")
				node.type_call = true
			else
				node.tokens["call("] = self:ExpectTokenValue("(")

				if
					-- hack for sizeof as it expects a c declaration expression in the C declaration parser
					self.FFI_DECLARATION_PARSER and
					primary_node.kind == "value" and
					primary_node.value.value == "sizeof"
				then
					node.expressions = self:ParseMultipleValues(self.ParseCDeclaration, 0)
				else
					node.expressions = self:ParseMultipleValues(self.ParseRuntimeExpression, 0)
				end

				node.tokens["call)"] = self:ExpectTokenValue(")")
			end

			if
				primary_node.kind == "value" and
				node.expressions[1] and
				node.expressions[1].value and
				node.expressions[1].value:GetStringValue()
			then
				local name = primary_node.value.value

				if
					name == "import" or
					name == "dofile" or
					name == "loadfile" or
					name == "require"
				then
					self:HandleImportExpression(node, name, node.expressions[1].value:GetStringValue(), start)
				elseif name == "import_data" then
					self:HandleImportDataExpression(node, node.expressions[1].value:GetStringValue(), start)
				end
			end

			node.left = left_node
			node = self:EndNode(node)
			return node
		end

		function META:ParsePostfixIndexExpressionSubExpression(left_node--[[#: Node]])
			if not self:IsTokenValue("[") then return end

			local node = self:StartNode("expression", "postfix_expression_index")
			node.tokens["["] = self:ExpectTokenValue("[")
			node.expression = self:ExpectRuntimeExpression()
			node.tokens["]"] = self:ExpectTokenValue("]")
			node.left = left_node
			node = self:EndNode(node)
			return node
		end

		function META:ParseSubExpression(node--[[#: Node]])
			for _ = self:GetPosition(), self:GetLength() do
				local left_node = node

				if
					self:IsTokenValue(":") and
					(
						not self:IsTokenType("letter", 1) or
						not self:IsCallExpression(2)
					)
					and
					-- special case for autocompletion to work while typing and : is the last character of the code
					not self:IsTokenType("end_of_file", 2)
				then
					node.tokens[":"] = self:ExpectTokenValue(":")
					node.type_expression = self:ExpectTypeExpression(0)
				elseif self:IsTokenValue("as") then
					node.tokens["as"] = self:ExpectTokenValue("as")
					node.type_expression = self:ExpectTypeExpression(0)
				end

				local found = self:ParseIndexSubExpression(left_node) or
					self:ParseSelfCallSubExpression(left_node) or
					self:ParseCallSubExpression(left_node, node) or
					self:ParsePostfixOperatorSubExpression(left_node) or
					self:ParsePostfixIndexExpressionSubExpression(left_node)

				if not found then break end

				if left_node.kind == "value" and left_node.value.value == ":" then
					found.parser_call = true
				end

				node = found
			end

			return node
		end

		function META:ParsePrefixOperatorExpression()
			if not runtime_syntax:IsPrefixOperator(self:GetToken()) then return end

			local node = self:StartNode("expression", "prefix_operator")
			node.value = self:ParseToken()
			node.tokens[1] = node.value
			node.right = self:ExpectRuntimeExpression(math_huge)
			node = self:EndNode(node)
			return node
		end

		function META:ParseParenthesisExpression()
			if not self:IsTokenValue("(") then return end

			local pleft = self:ExpectTokenValue("(")
			local node = self:ExpectRuntimeExpression(0)
			node.tokens["("] = node.tokens["("] or {}
			table_insert(node.tokens["("], pleft)
			node.tokens[")"] = node.tokens[")"] or {}
			table_insert(node.tokens[")"], self:ExpectTokenValue(")"))
			return node
		end

		function META:ParseValueExpression()
			if not runtime_syntax:IsValue(self:GetToken()) then return end

			return self:ParseValueExpressionToken()
		end

		function META:HandleImportExpression(node--[[#: Node]], name--[[#: string]], str--[[#: string]], start--[[#: number]])
			if self.config.skip_import then return end

			if self.dont_hoist_next_import then
				self.dont_hoist_next_import = false
				return
			end

			local path

			if name == "require" then path = path_util.ResolveRequire(str) end

			path = path_util.Resolve(
				path or str,
				self.config.root_directory,
				self.config.working_directory,
				self.config.file_path
			)

			if name == "require" then if not path_util.Exists(path) then return end end

			if not path then return end

			local dont_hoist_import = _G.dont_hoist_import and _G.dont_hoist_import > 0
			node.import_expression = true
			node.path = path
			local key = name == "require" and str or path
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

			if name == "require" and not self.config.inline_require then
				root_node.imports = root_node.imports or {}
				table_insert(root_node.imports, node)
				return
			end

			self.RootStatement.imports = self.RootStatement.imports or {}
			table_insert(self.RootStatement.imports, node)
		end

		function META:HandleImportDataExpression(node--[[#: Node]], path--[[#: string]], start--[[#: number]])
			if self.config.skip_import then return end

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
							preserve_whitespace = false,
							comment_type_annotations = false,
							type_annotations = true,
							inside_data_import = true,
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

		function META:check_integer_division_operator(node--[[#: Node]])
			if not node.potential_idiv then return end

			if not node or node.idiv_resolved then return end

			for i, token in ipairs(node.whitespace) do
				if token.value:find("\n", nil, true) then break end

				if token.type == "line_comment" and token.value:sub(1, 2) == "//" then
					table_remove(node.whitespace, i)
					local tokens = self:LexString("/idiv" .. token.value:sub(2))

					for _, token in ipairs(tokens) do
						self:check_integer_division_operator(token)
					end

					self:AddTokens(tokens)
					node.idiv_resolved = true

					break
				end
			end
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
					first.kind == "value" and
					(
						first.value.type == "letter" or
						first.value.value == "..."
					)
				then
					first.standalone_letter = node
				end
			end

			self:check_integer_division_operator(self:GetToken())

			for _ = self:GetPosition(), self:GetLength() do
				if
					not (
						(
							runtime_syntax:GetBinaryOperatorInfo(self:GetToken()) and
							not self:IsTokenValue("=", 1)
						)
						and
						runtime_syntax:GetBinaryOperatorInfo(self:GetToken()).left_priority > priority
					)
				then
					break
				end

				local left_node = node or false
				node = self:StartNode("expression", "binary_operator", left_node)
				node.value = self:ParseToken()
				node.left = left_node

				if node.left then node.left.parent = node end

				node.right = self:ExpectRuntimeExpression(runtime_syntax:GetBinaryOperatorInfo(node.value).right_priority)
				node = self:EndNode(node)

				if not node.right then
					local token = self:GetToken()
					self:Error(
						"expected right side to be an expression, got $1",
						nil,
						nil,
						token and token.value ~= "" and token.value or token.type
					)
					return self:ErrorExpression()
				end
			end

			if node then node.first_node = first end

			return node or false
		end

		function META:IsRuntimeExpression()
			local token = self:GetToken()
			return not (
				token.type == "end_of_file" or
				token.value == "}" or
				token.value == "," or
				token.value == "]" or
				token.value == ")" or
				(
					(
						runtime_syntax:IsKeyword(token) or
						runtime_syntax:IsNonStandardKeyword(token)
					) and
					not runtime_syntax:IsPrefixOperator(token)
					and
					not runtime_syntax:IsValue(token)
					and
					token.value ~= "function"
				)
			)
		end

		function META:ExpectRuntimeExpression(priority--[[#: number]])
			if not self:IsRuntimeExpression() then
				local token = self:GetToken()
				self:Error(
					"expected beginning of expression, got $1",
					nil,
					nil,
					token and token.value ~= "" and token.value or token.type
				)
				return self:ErrorExpression()
			end

			return self:ParseRuntimeExpression(priority)
		end
	end
end
