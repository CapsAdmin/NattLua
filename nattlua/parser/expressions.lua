local META = ...
local table_insert = require("table").insert
local table_remove = require("table").remove
local math_huge = math.huge
local runtime_syntax = require("nattlua.syntax.runtime")
local typesystem_syntax = require("nattlua.syntax.typesystem")

function META:ReadAnalyzerFunctionExpression()
	if not (self:IsValue("analyzer") and self:IsValue("function", 1)) then return end

	local node = self:StartNode("expression", "analyzer_function")
	node.tokens["analyzer"] = self:ExpectValue("analyzer")
	node.tokens["function"] = self:ExpectValue("function")
	self:ReadAnalyzerFunctionBody(node)
	self:EndNode(node)
	return node
end

function META:ReadFunctionExpression()
	if not self:IsValue("function") then return end

	local node = self:StartNode("expression", "function")
	node.tokens["function"] = self:ExpectValue("function")
	self:ReadFunctionBody(node)
	self:EndNode(node)
	return node
end

function META:ReadIndexSubExpression()
	if not (self:IsValue(".") and self:IsType("letter", 1)) then return end

	local node = self:StartNode("expression", "binary_operator")
	node.value = self:ReadToken()
	node.right = self:ReadValueExpressionType("letter")
	self:EndNode(node)
	return node
end

function META:IsCallExpression(offset)
	return self:IsValue("(", offset) or
		self:IsValue("<|", offset) or
		self:IsValue("{", offset) or
		self:IsType("string", offset) or
		(
			self:IsValue("!", offset) and
			self:IsValue("(", offset + 1)
		)
end

function META:ReadSelfCallSubExpression()
	if not (self:IsValue(":") and self:IsType("letter", 1) and self:IsCallExpression(2)) then
		return
	end

	local node = self:StartNode("expression", "binary_operator")
	node.value = self:ReadToken()
	node.right = self:ReadValueExpressionType("letter")
	self:EndNode(node)
	return node
end

do -- typesystem
	function META:ReadParenthesisOrTupleTypeExpression()
		if not self:IsValue("(") then return end

		local pleft = self:ExpectValue("(")
		local node = self:ReadTypeExpression(0)

		if not node or self:IsValue(",") then
			local first_expression = node
			local node = self:StartNode("expression", "tuple")

			if self:IsValue(",") then
				first_expression.tokens[","] = self:ExpectValue(",")
				node.expressions = self:ReadMultipleValues(nil, self.ReadTypeExpression, 0)
			else
				node.expressions = {}
			end

			if first_expression then
				table.insert(node.expressions, 1, first_expression)
			end

			node.tokens["("] = pleft
			node.tokens[")"] = self:ExpectValue(")", pleft)
			self:EndNode(node)
			return node
		end

		node.tokens["("] = node.tokens["("] or {}
		table_insert(node.tokens["("], 1, pleft)
		node.tokens[")"] = node.tokens[")"] or {}
		table_insert(node.tokens[")"], self:ExpectValue(")"))
		self:EndNode(node)
		return node
	end

	function META:ReadPrefixOperatorTypeExpression()
		if not typesystem_syntax:IsPrefixOperator(self:GetToken()) then return end

		local node = self:StartNode("expression", "prefix_operator")
		node.value = self:ReadToken()
		node.tokens[1] = node.value

		if node.value.value == "expand" then
			self:PushParserEnvironment("runtime")
		end

		node.right = self:ReadRuntimeExpression(math_huge)

		if node.value.value == "expand" then self:PopParserEnvironment() end

		self:EndNode(node)
		return node
	end

	function META:ReadValueTypeExpression()
		if not (self:IsValue("...") and self:IsType("letter", 1)) then return end

		local node = self:StartNode("expression", "vararg")
		node.tokens["..."] = self:ExpectValue("...")
		node.value = self:ReadTypeExpression(0)
		self:EndNode(node)
		return node
	end

	function META:ReadTypeSignatureFunctionArgument(expect_type)
		if self:IsValue(")") then return end

		if
			expect_type or
			(
				(
					self:IsType("letter") or
					self:IsValue("...")
				) and
				self:IsValue(":", 1)
			)
		then
			local identifier = self:ReadToken()
			local token = self:ExpectValue(":")
			local exp = self:ExpectTypeExpression(0)
			exp.tokens[":"] = token
			exp.identifier = identifier
			return exp
		end

		return self:ExpectTypeExpression(0)
	end

	function META:ReadFunctionSignatureExpression()
		if not (self:IsValue("function") and self:IsValue("=", 1)) then return end

		local node = self:StartNode("expression", "function_signature")
		node.tokens["function"] = self:ExpectValue("function")
		node.tokens["="] = self:ExpectValue("=")
		node.tokens["arguments("] = self:ExpectValue("(")
		node.identifiers = self:ReadMultipleValues(nil, self.ReadTypeSignatureFunctionArgument)
		node.tokens["arguments)"] = self:ExpectValue(")")
		node.tokens[">"] = self:ExpectValue(">")
		node.tokens["return("] = self:ExpectValue("(")
		node.return_types = self:ReadMultipleValues(nil, self.ReadTypeSignatureFunctionArgument)
		node.tokens["return)"] = self:ExpectValue(")")
		self:EndNode(node)
		return node
	end

	function META:ReadTypeFunctionExpression()
		if not (self:IsValue("function") and self:IsValue("<|", 1)) then return end

		local node = self:StartNode("expression", "type_function")
		node.tokens["function"] = self:ExpectValue("function")
		self:ReadTypeFunctionBody(node)
		self:EndNode(node)
		return node
	end

	function META:ReadKeywordValueTypeExpression()
		if not typesystem_syntax:IsValue(self:GetToken()) then return end

		local node = self:StartNode("expression", "value")
		node.value = self:ReadToken()
		self:EndNode(node)
		return node
	end

	do
		function META:read_type_table_entry(i)
			if self:IsValue("[") then
				local node = self:StartNode("expression", "table_expression_value")
				node.expression_key = true
				node.tokens["["] = self:ExpectValue("[")
				node.key_expression = self:ReadTypeExpression(0)
				node.tokens["]"] = self:ExpectValue("]")
				node.tokens["="] = self:ExpectValue("=")
				node.value_expression = self:ReadTypeExpression(0)
				self:EndNode(node)
				return node
			elseif self:IsType("letter") and self:IsValue("=", 1) then
				local node = self:StartNode("expression", "table_key_value")
				node.tokens["identifier"] = self:ExpectType("letter")
				node.tokens["="] = self:ExpectValue("=")
				node.value_expression = self:ReadTypeExpression(0)
				return node
			end

			local node = self:StartNode("expression", "table_index_value")
			node.key = i
			node.value_expression = self:ReadTypeExpression(0)
			self:EndNode(node)
			return node
		end

		function META:ReadTableTypeExpression()
			if not self:IsValue("{") then return end

			local tree = self:StartNode("expression", "type_table")
			tree.tokens["{"] = self:ExpectValue("{")
			tree.children = {}
			tree.tokens["separators"] = {}

			for i = 1, math_huge do
				if self:IsValue("}") then break end

				local entry = self:read_type_table_entry(i)

				if entry.spread then tree.spread = true end

				tree.children[i] = entry

				if not self:IsValue(",") and not self:IsValue(";") and not self:IsValue("}") then
					self:Error(
						"expected $1 got $2",
						nil,
						nil,
						{",", ";", "}"},
						(self:GetToken() and self:GetToken().value) or "no token"
					)

					break
				end

				if not self:IsValue("}") then
					tree.tokens["separators"][i] = self:ReadToken()
				end
			end

			tree.tokens["}"] = self:ExpectValue("}")
			self:EndNode(tree)
			return tree
		end
	end

	function META:ReadStringTypeExpression()
		if not (self:IsType("$") and self:IsType("string", 1)) then return end

		local node = self:StartNode("expression", "type_string")
		node.tokens["$"] = self:ReadToken("...")
		node.value = self:ExpectType("string")
		return node
	end

	function META:ReadEmptyUnionTypeExpression()
		if not self:IsValue("|") then return end

		local node = self:StartNode("expression", "empty_union")
		node.tokens["|"] = self:ReadToken("|")
		self:EndNode(node)
		return node
	end

	function META:ReadAsSubExpression(node)
		if not self:IsValue("as") then return end

		node.tokens["as"] = self:ExpectValue("as")
		node.type_expression = self:ReadTypeExpression(0)
	end

	function META:ReadPostfixTypeOperatorSubExpression()
		if not typesystem_syntax:IsPostfixOperator(self:GetToken()) then return end

		local node = self:StartNode("expression", "postfix_operator")
		node.value = self:ReadToken()
		self:EndNode(node)
		return node
	end

	function META:ReadTypeCallSubExpression(primary_node)
		if not self:IsCallExpression(0) then return end

		local node = self:StartNode("expression", "postfix_call")
		local start = self:GetToken()

		if self:IsValue("{") then
			node.expressions = {self:ReadTableTypeExpression()}
		elseif self:IsType("string") then
			node.expressions = {self:ReadValueExpressionToken()}
		elseif self:IsValue("<|") then
			node.tokens["call("] = self:ExpectValue("<|")
			node.expressions = self:ReadMultipleValues(nil, self.ReadTypeExpression, 0)
			node.tokens["call)"] = self:ExpectValue("|>")
		else
			node.tokens["call("] = self:ExpectValue("(")
			node.expressions = self:ReadMultipleValues(nil, self.ReadTypeExpression, 0)
			node.tokens["call)"] = self:ExpectValue(")")
		end

		if primary_node.kind == "value" then
			if primary_node.value.value == "import" then
				self:HandleImportExpression(node, node.expressions[1].value.string_value, start)
			elseif primary_node.value.value == "import_data" then
				self:HandleImportDataExpression(node, node.expressions[1].value.string_value, start)
			end
		end

		node.type_call = true
		self:EndNode(node)
		return node
	end

	function META:ReadPostfixTypeIndexExpressionSubExpression()
		if not self:IsValue("[") then return end

		local node = self:StartNode("expression", "postfix_expression_index")
		node.tokens["["] = self:ExpectValue("[")
		node.expression = self:ExpectTypeExpression(0)
		node.tokens["]"] = self:ExpectValue("]")
		self:EndNode(node)
		return node
	end

	function META:ReadTypeSubExpression(node)
		for _ = 1, self:GetLength() do
			local left_node = node
			local found = self:ReadIndexSubExpression() or
				self:ReadSelfCallSubExpression() or
				self:ReadPostfixTypeOperatorSubExpression() or
				self:ReadTypeCallSubExpression(node) or
				self:ReadPostfixTypeIndexExpressionSubExpression() or
				self:ReadAsSubExpression(left_node)

			if not found then break end

			found.left = left_node

			if left_node.value and left_node.value.value == ":" then
				found.parser_call = true
			end

			node = found
		end

		return node
	end

	function META:ReadTypeExpression(priority)
		if self.TealCompat then return self:ReadTealExpression(priority) end

		self:PushParserEnvironment("typesystem")
		local node
		local force_upvalue

		if self:IsValue("^") then
			force_upvalue = true
			self:Advance(1)
		end

		node = self:ReadParenthesisOrTupleTypeExpression() or
			self:ReadEmptyUnionTypeExpression() or
			self:ReadPrefixOperatorTypeExpression() or
			self:ReadAnalyzerFunctionExpression() or -- shared
			self:ReadFunctionSignatureExpression() or
			self:ReadTypeFunctionExpression() or -- shared
			self:ReadFunctionExpression() or -- shared
			self:ReadValueTypeExpression() or
			self:ReadKeywordValueTypeExpression() or
			self:ReadTableTypeExpression() or
			self:ReadStringTypeExpression()
		local first = node

		if node then
			node = self:ReadTypeSubExpression(node)

			if
				first.kind == "value" and
				(
					first.value.type == "letter" or
					first.value.value == "..."
				)
			then
				first.standalone_letter = node
				first.force_upvalue = force_upvalue
			end
		end

		while
			typesystem_syntax:GetBinaryOperatorInfo(self:GetToken()) and
			typesystem_syntax:GetBinaryOperatorInfo(self:GetToken()).left_priority > priority
		do
			local left_node = node
			node = self:StartNode("expression", "binary_operator")
			node.value = self:ReadToken()
			node.left = left_node
			node.right = self:ReadTypeExpression(typesystem_syntax:GetBinaryOperatorInfo(node.value).right_priority)
			self:EndNode(node)
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

	function META:ExpectTypeExpression(priority)
		if not self:IsTypeExpression() then
			local token = self:GetToken()
			self:Error(
				"expected beginning of expression, got $1",
				nil,
				nil,
				token and token.value ~= "" and token.value or token.type
			)
			return
		end

		return self:ReadTypeExpression(priority)
	end
end

do -- runtime
	local ReadTableExpression

	do
		function META:read_table_spread()
			if
				not (
					self:IsValue("...") and
					(
						self:IsType("letter", 1) or
						self:IsValue("{", 1) or
						self:IsValue("(", 1)
					)
				)
			then
				return
			end

			local node = self:StartNode("expression", "table_spread")
			node.tokens["..."] = self:ExpectValue("...")
			node.expression = self:ExpectRuntimeExpression()
			self:EndNode(node)
			return node
		end

		function META:read_table_entry(i)
			if self:IsValue("[") then
				local node = self:StartNode("expression", "table_expression_value")
				node.expression_key = true
				node.tokens["["] = self:ExpectValue("[")
				node.key_expression = self:ExpectRuntimeExpression(0)
				node.tokens["]"] = self:ExpectValue("]")
				node.tokens["="] = self:ExpectValue("=")
				node.value_expression = self:ExpectRuntimeExpression(0)
				self:EndNode(node)
				return node
			elseif self:IsType("letter") and self:IsValue("=", 1) then
				local node = self:StartNode("expression", "table_key_value")
				node.tokens["identifier"] = self:ExpectType("letter")
				node.tokens["="] = self:ExpectValue("=")
				local spread = self:read_table_spread()

				if spread then
					node.spread = spread
				else
					node.value_expression = self:ExpectRuntimeExpression()
				end

				self:EndNode(node)
				return node
			end

			local node = self:StartNode("expression", "table_index_value")
			local spread = self:read_table_spread()

			if spread then
				node.spread = spread
			else
				node.value_expression = self:ExpectRuntimeExpression()
			end

			node.key = i
			self:EndNode(node)
			return node
		end

		function META:ReadTableExpression()
			if not self:IsValue("{") then return end

			local tree = self:StartNode("expression", "table")
			tree.tokens["{"] = self:ExpectValue("{")
			tree.children = {}
			tree.tokens["separators"] = {}

			for i = 1, self:GetLength() do
				if self:IsValue("}") then break end

				local entry = self:read_table_entry(i)

				if entry.kind == "table_index_value" then
					tree.is_array = true
				else
					tree.is_dictionary = true
				end

				if entry.spread then tree.spread = true end

				tree.children[i] = entry

				if not self:IsValue(",") and not self:IsValue(";") and not self:IsValue("}") then
					self:Error(
						"expected $1 got $2",
						nil,
						nil,
						{",", ";", "}"},
						(self:GetToken() and self:GetToken().value) or "no token"
					)

					break
				end

				if not self:IsValue("}") then
					tree.tokens["separators"][i] = self:ReadToken()
				end
			end

			tree.tokens["}"] = self:ExpectValue("}")
			self:EndNode(tree)
			return tree
		end
	end

	function META:ReadPostfixOperatorSubExpression()
		if not runtime_syntax:IsPostfixOperator(self:GetToken()) then return end

		local node = self:StartNode("expression", "postfix_operator")
		node.value = self:ReadToken()
		self:EndNode(node)
		return node
	end

	function META:ReadCallSubExpression(primary_node)
		if not self:IsCallExpression(0) then return end

		if primary_node and primary_node.kind == "function" then
			if not primary_node.tokens[")"] then return end
		end

		local node = self:StartNode("expression", "postfix_call")
		local start = self:GetToken()

		if self:IsValue("{") then
			node.expressions = {self:ReadTableExpression()}
		elseif self:IsType("string") then
			node.expressions = {self:ReadValueExpressionToken()}
		elseif self:IsValue("<|") then
			node.tokens["call("] = self:ExpectValue("<|")
			node.expressions = self:ReadMultipleValues(nil, self.ReadTypeExpression, 0)
			node.tokens["call)"] = self:ExpectValue("|>")
			node.type_call = true

			if self:IsValue("(") then
				local lparen = self:ExpectValue("(")
				local expressions = self:ReadMultipleValues(nil, self.ReadTypeExpression, 0)
				local rparen = self:ExpectValue(")")
				node.expressions_typesystem = node.expressions
				node.expressions = expressions
				node.tokens["call_typesystem("] = node.tokens["call("]
				node.tokens["call_typesystem)"] = node.tokens["call)"]
				node.tokens["call("] = lparen
				node.tokens["call)"] = rparen
			end
		elseif self:IsValue("!") then
			node.tokens["!"] = self:ExpectValue("!")
			node.tokens["call("] = self:ExpectValue("(")
			node.expressions = self:ReadMultipleValues(nil, self.ReadTypeExpression, 0)
			node.tokens["call)"] = self:ExpectValue(")")
			node.type_call = true
		else
			node.tokens["call("] = self:ExpectValue("(")
			node.expressions = self:ReadMultipleValues(nil, self.ReadRuntimeExpression, 0)
			node.tokens["call)"] = self:ExpectValue(")")
		end

		self:EndNode(node)

		if primary_node.kind == "value" then
			if primary_node.value.value == "require" then
				self:HandleRuntimeRequire(node, node.expressions[1].value.string_value, start)
			elseif primary_node.value.value == "import" then
				self:HandleImportExpression(node, node.expressions[1].value.string_value, start)
			elseif primary_node.value.value == "import_data" then
				self:HandleImportDataExpression(node, node.expressions[1].value.string_value, start)
			end
		end

		return node
	end

	function META:ReadPostfixIndexExpressionSubExpression()
		if not self:IsValue("[") then return end

		local node = self:StartNode("expression", "postfix_expression_index")
		node.tokens["["] = self:ExpectValue("[")
		node.expression = self:ExpectRuntimeExpression()
		node.tokens["]"] = self:ExpectValue("]")
		self:EndNode(node)
		return node
	end

	function META:ReadSubExpression(node)
		for _ = 1, self:GetLength() do
			local left_node = node

			if
				self:IsValue(":") and
				(
					not self:IsType("letter", 1) or
					not self:IsCallExpression(2)
				)
			then
				node.tokens[":"] = self:ExpectValue(":")
				node.type_expression = self:ExpectTypeExpression(0)
			elseif self:IsValue("as") then
				node.tokens["as"] = self:ExpectValue("as")
				node.type_expression = self:ExpectTypeExpression(0)
			elseif self:IsValue("is") then
				node.tokens["is"] = self:ExpectValue("is")
				node.type_expression = self:ExpectTypeExpression(0)
			end

			local found = self:ReadIndexSubExpression() or
				self:ReadSelfCallSubExpression() or
				self:ReadCallSubExpression(node) or
				self:ReadPostfixOperatorSubExpression() or
				self:ReadPostfixIndexExpressionSubExpression()

			if not found then break end

			found.left = left_node

			if left_node.value and left_node.value.value == ":" then
				found.parser_call = true
			end

			node = found
		end

		return node
	end

	function META:ReadPrefixOperatorExpression()
		if not runtime_syntax:IsPrefixOperator(self:GetToken()) then return end

		local node = self:StartNode("expression", "prefix_operator")
		node.value = self:ReadToken()
		node.tokens[1] = node.value
		node.right = self:ExpectRuntimeExpression(math.huge)
		self:EndNode(node)
		return node
	end

	function META:ReadParenthesisExpression()
		if not self:IsValue("(") then return end

		local pleft = self:ExpectValue("(")
		local node = self:ReadRuntimeExpression(0)

		if not node then
			self:Error("empty parentheses group", pleft)
			return
		end

		node.tokens["("] = node.tokens["("] or {}
		table_insert(node.tokens["("], 1, pleft)
		node.tokens[")"] = node.tokens[")"] or {}
		table_insert(node.tokens[")"], self:ExpectValue(")"))
		return node
	end

	function META:ReadValueExpression()
		if not runtime_syntax:IsValue(self:GetToken()) then return end

		return self:ReadValueExpressionToken()
	end

	local function resolve_import_path(self, path)
		local working_directory = self.config.working_directory or ""

		if path:sub(1, 1) == "~" then
			path = path:sub(2)

			if path:sub(1, 1) == "/" then path = path:sub(2) end
		elseif path:sub(1, 2) == "./" then
			working_directory = self.config.file_path and
				self.config.file_path:match("(.+/)") or
				working_directory
			path = path:sub(3)
		end

		return working_directory .. path
	end

	function META:HandleImportExpression(node, path, start)
		node.import_expression = true

		if self.config.skip_import then return node end

		node.path = resolve_import_path(self, path)
		self.imported = self.imported or {}

		if self.imported[node.path] then return self.imported[node.path] end

		local nl = require("nattlua")
		local compiler, err = nl.ParseFile(
			node.path,
			{
				root_statement_override = self.RootStatement,
				path = node.path,
				working_directory = self.config.working_directory,
			}
		)

		if not compiler then
			self:Error("error importing file: $1", start, start, err)
		end

		if self.RootStatement.data_import then
			node.data = compiler.SyntaxTree:Render({
				preserve_whitespace = false,
				uncomment_types = true,
			})
		end

		node.RootStatement = compiler.SyntaxTree
		self.RootStatement.imports = self.RootStatement.imports or {}
		table.insert(self.RootStatement.imports, node)
		self.imported[node.path] = node
		return node
	end

	function META:HandleImportDataExpression(node, path, start)
		node.import_expression = true

		if self.config.skip_import then return node end

		node.path = resolve_import_path(self, path)
		self.imported = self.imported or {}

		if self.imported[node.path] then return self.imported[node.path] end

		self.RootStatement.data_import = true
		local data
		local err

		if node.path:sub(-4) == "lua" or node.path:sub(-5) ~= "nlua" then
			local nl = require("nattlua")
			local compiler, err = nl.ParseFile(
				node.path,
				{
					path = node.path,
					working_directory = self.config.working_directory,
					inline_require = true,
				}
			)
			data = compiler.SyntaxTree:Render({
				preserve_whitespace = false,
				uncomment_types = true,
			})
		else
			local f
			f, err = io.open(node.path, "rb")

			if f then
				data = f:read("*all")
				f:close()
			end
		end

		if not data then
			self:Error("error importing file: $1", start, start, err)
		end

		node.data = data
		self.RootStatement.imports = self.RootStatement.imports or {}
		table.insert(self.RootStatement.imports, node)
		self.imported[node.path] = node
		return node
	end

	local function require_path_to_path(require_path)
		require_path = require_path:gsub("%.", "/")

		for package_path in (package.path .. ";"):gmatch("(.-);") do
			local lua_path = package_path:gsub("%?", require_path)
			local f = io.open(lua_path, "r")

			if f then
				f:close()
				return lua_path
			end
		end

		return nil
	end

	function META:HandleRuntimeRequire(node, module_name, start)
		if not self.config.inline_require then return end

		local root_node = self.config.root_statement_override or self.RootStatement
		root_node.required_files = root_node.required_files or {}
		local cache = root_node.required_files
		local path = require_path_to_path(module_name)

		if path then
			node.path = path

			if cache[path] == nil then
				if cache[path] == true then
					self:Error("circular dependency: $1", start, start, path)
				end

				local config = {}

				for k, v in pairs(self.config) do
					config[k] = v
				end

				config.root_statement_override = self.RootStatement
				config.file_path = path
				config.friendly_name = module_name
				cache[path] = false
				local nl = require("nattlua")
				local compiler, err = nl.ParseFile(path, config)

				if not compiler then
					self:Error("error requiring file: $1", start, start, err)
					cache[path] = nil
				else
					node.RootStatement = compiler.SyntaxTree
					cache[path] = compiler.SyntaxTree
				end
			else
				node.RootStatement = cache[path]
			end
		end

		self.RootStatement.required_files = self.RootStatement.required_files or {}
		table.insert(self.RootStatement.required_files, node)
		return node
	end

	function META:check_integer_division_operator(node)
		if node and not node.idiv_resolved then
			for i, token in ipairs(node.whitespace) do
				if token.value:find("\n", nil, true) then break end

				if token.type == "line_comment" and token.value:sub(1, 2) == "//" then
					table_remove(node.whitespace, i)
					local Code = require("nattlua.code.code")
					local tokens = require("nattlua.lexer.lexer")(Code("/idiv" .. token.value:sub(2), "")):GetTokens()

					for _, token in ipairs(tokens) do
						self:check_integer_division_operator(token)
					end

					self:AddTokens(tokens)
					node.idiv_resolved = true

					break
				end
			end
		end
	end

	function META:ReadRuntimeExpression(priority)
		if self:GetCurrentParserEnvironment() == "typesystem" then
			return self:ReadTypeExpression(priority)
		end

		priority = priority or 0
		local node = self:ReadParenthesisExpression() or
			self:ReadPrefixOperatorExpression() or
			self:ReadAnalyzerFunctionExpression() or
			self:ReadFunctionExpression() or
			self:ReadValueExpression() or
			self:ReadTableExpression()
		local first = node

		if node then
			node = self:ReadSubExpression(node)

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

		while
			runtime_syntax:GetBinaryOperatorInfo(self:GetToken()) and
			runtime_syntax:GetBinaryOperatorInfo(self:GetToken()).left_priority > priority
		do
			local left_node = node
			node = self:StartNode("expression", "binary_operator")
			node.value = self:ReadToken()
			node.left = left_node

			if node.left then node.left.parent = node end

			node.right = self:ExpectRuntimeExpression(runtime_syntax:GetBinaryOperatorInfo(node.value).right_priority)
			self:EndNode(node)

			if not node.right then
				local token = self:GetToken()
				self:Error(
					"expected right side to be an expression, got $1",
					nil,
					nil,
					token and token.value ~= "" and token.value or token.type
				)
				return
			end
		end

		if node then node.first_node = first end

		return node
	end

	function META:IsRuntimeExpression()
		local token = self:GetToken()
		return not (
			token.type == "end_of_file" or
			token.value == "}" or
			token.value == "," or
			token.value == "]" or
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

	function META:ExpectRuntimeExpression(priority)
		if not self:IsRuntimeExpression() then
			local token = self:GetToken()
			self:Error(
				"expected beginning of expression, got $1",
				nil,
				nil,
				token and token.value ~= "" and token.value or token.type
			)
			return
		end

		return self:ReadRuntimeExpression(priority)
	end
end
