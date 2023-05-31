local META = require("nattlua.parser.base")
local Code = require("nattlua.code").New
local Lexer = require("nattlua.lexer").New
local math = _G.math
local math_huge = math.huge
local table_insert = _G.table.insert
local ipairs = _G.ipairs
local pcall = _G.pcall
local xpcall = _G.xpcall
local assert = _G.assert
local debug = _G.debug
local io = _G.io

--[[#local type { Token, TokenType } = import("~/nattlua/lexer/token.lua")]]

--[[#local type { ExpressionKind, StatementKind, statement, expression } = import("./parser/nodes.nlua")]]

function META:ParseIdentifier(expect_type--[[#: nil | boolean]])
	if not self:IsTokenType("letter") and not self:IsTokenValue("...") then
		return
	end

	local node = self:StartNode("expression", "value") -- as ValueExpression ]]
	node.is_identifier = true

	if self:IsTokenValue("...") then
		node.value = self:ExpectTokenValue("...")
	else
		node.value = self:ExpectTokenType("letter")

		if self:IsTokenValue("<") then
			node.tokens["<"] = self:ExpectTokenValue("<")
			node.attribute = self:ExpectTokenType("letter")
			node.tokens[">"] = self:ExpectTokenValue(">")
		end
	end

	if expect_type ~= false then
		if self:IsTokenValue(":") or expect_type then
			node.tokens[":"] = self:ExpectTokenValue(":")
			node.type_expression = self:ExpectTypeExpression(0)
		end
	end

	node = self:EndNode(node)
	return node
end

function META:ParseValueExpressionToken(expect_value--[[#: nil | string]])
	local node = self:StartNode("expression", "value")
	node.value = expect_value and self:ExpectTokenValue(expect_value) or self:ParseToken()
	node = self:EndNode(node)
	return node
end

function META:ParseValueExpressionType(expect_value--[[#: TokenType]])
	local node = self:StartNode("expression", "value")
	node.value = self:ExpectTokenType(expect_value)
	node = self:EndNode(node)
	return node
end

function META:ParseFunctionBody(
	node--[[#: expression.analyzer_function | expression["function"] | statement["local_function"] | statement["function"] ]]
)
	if self.TealCompat then
		if self:IsTokenValue("<") then
			node.tokens["arguments_typesystem("] = self:ExpectTokenValue("<")
			node.identifiers_typesystem = self:ParseMultipleValues(nil, self.ParseIdentifier)
			node.tokens["arguments_typesystem)"] = self:ExpectTokenValue(">")
		end
	end

	node.tokens["arguments("] = self:ExpectTokenValue("(")
	node.identifiers = self:ParseMultipleValues(nil, self.ParseIdentifier)
	node.tokens["arguments)"] = self:ExpectTokenValue(")", node.tokens["arguments("])

	if self:IsTokenValue(":") then
		node.tokens["return:"] = self:ExpectTokenValue(":")
		self:PushParserEnvironment("typesystem")
		node.return_types = self:ParseMultipleValues(nil, self.ParseTypeExpression, 0)
		self:PopParserEnvironment()
	end

	node.statements = self:ParseStatements({["end"] = true})
	node.tokens["end"] = self:ExpectTokenValue("end", node.tokens["function"])
	return node
end

function META:ParseTypeFunctionBody(
	node--[[#: statement["type_function"] | expression["type_function"] | statement["type_function"] ]]
)
	if self:IsTokenValue("!") then
		node.tokens["!"] = self:ExpectTokenValue("!")
		node.tokens["arguments("] = self:ExpectTokenValue("(")
		node.identifiers = self:ParseMultipleValues(nil, self.ParseIdentifier, true)

		if self:IsTokenValue("...") then
			table_insert(node.identifiers, self:ParseValueExpressionToken("..."))
		end

		node.tokens["arguments)"] = self:ExpectTokenValue(")")
	else
		node.tokens["arguments("] = self:ExpectTokenValue("<|")
		node.identifiers = self:ParseMultipleValues(nil, self.ParseIdentifier, true)

		if self:IsTokenValue("...") then
			table_insert(node.identifiers, self:ParseValueExpressionToken("..."))
		end

		node.tokens["arguments)"] = self:ExpectTokenValue("|>", node.tokens["arguments("])

		if self:IsTokenValue("(") then
			local lparen = self:ExpectTokenValue("(")
			local identifiers = self:ParseMultipleValues(nil, self.ParseIdentifier, true)
			local rparen = self:ExpectTokenValue(")")
			node.identifiers_typesystem = node.identifiers
			node.identifiers = identifiers
			node.tokens["arguments_typesystem("] = node.tokens["arguments("]
			node.tokens["arguments_typesystem)"] = node.tokens["arguments)"]
			node.tokens["arguments("] = lparen
			node.tokens["arguments)"] = rparen
		end
	end

	if self:IsTokenValue(":") then
		node.tokens["return:"] = self:ExpectTokenValue(":")
		self:PushParserEnvironment("typesystem")
		node.return_types = self:ParseMultipleValues(math.huge, self.ExpectTypeExpression, 0)
		self:PopParserEnvironment()
	end

	if node.identifiers_typesystem then
		node.environment = "runtime"
		self:PushParserEnvironment("runtime")
	else
		node.environment = "typesystem"
		self:PushParserEnvironment("typesystem")
	end

	local start = self:GetToken()
	node.statements = self:ParseStatements({["end"] = true})
	node.tokens["end"] = self:ExpectTokenValue("end", start, start)
	self:PopParserEnvironment()
	return node
end

function META:ParseTypeFunctionArgument(expect_type--[[#: nil | boolean]])
	if self:IsTokenValue(")") then return end

	if self:IsTokenValue("...") then return end

	if expect_type or self:IsTokenType("letter") and self:IsTokenValue(":", 1) then
		local identifier = self:ParseToken()
		local token = self:ExpectTokenValue(":")
		local exp = self:ExpectTypeExpression(0)
		exp.tokens[":"] = token
		exp.identifier = identifier
		return exp
	end

	return self:ExpectTypeExpression(0)
end

function META:ParseAnalyzerFunctionBody(
	node--[[#: statement["analyzer_function"] | expression["analyzer_function"] | statement["local_analyzer_function"] ]],
	type_args--[[#: boolean]]
)
	self:PushParserEnvironment("runtime")
	node.tokens["arguments("] = self:ExpectTokenValue("(")
	node.identifiers = self:ParseMultipleValues(math_huge, self.ParseTypeFunctionArgument, type_args)

	if self:IsTokenValue("...") then
		local vararg = self:StartNode("expression", "value")
		vararg.value = self:ExpectTokenValue("...")

		if self:IsTokenValue(":") or type_args then
			vararg.tokens[":"] = self:ExpectTokenValue(":")
			vararg.type_expression = self:ExpectTypeExpression(0)
		else
			if self:IsTokenType("letter") then
				vararg.type_expression = self:ExpectTypeExpression(0)
			end
		end

		vararg = self:EndNode(vararg)
		table_insert(node.identifiers, vararg)
	end

	node.tokens["arguments)"] = self:ExpectTokenValue(")", node.tokens["arguments("])

	if self:IsTokenValue(":") then
		node.tokens["return:"] = self:ExpectTokenValue(":")
		self:PushParserEnvironment("typesystem")
		node.return_types = self:ParseMultipleValues(math.huge, self.ParseTypeExpression, 0)
		self:PopParserEnvironment()
		local start = self:GetToken()
		_G.dont_hoist_import = (_G.dont_hoist_import or 0) + 1
		node.statements = self:ParseStatements({["end"] = true})
		_G.dont_hoist_import = (_G.dont_hoist_import or 0) - 1
		node.tokens["end"] = self:ExpectTokenValue("end", start, start)
	elseif not self:IsTokenValue(",") then
		local start = self:GetToken()
		_G.dont_hoist_import = (_G.dont_hoist_import or 0) + 1
		node.statements = self:ParseStatements({["end"] = true})
		_G.dont_hoist_import = (_G.dont_hoist_import or 0) - 1
		node.tokens["end"] = self:ExpectTokenValue("end", start, start)
	end

	self:PopParserEnvironment()
	return node
end

assert(loadfile("nattlua/parser/expressions.lua"))(META)
assert(loadfile("nattlua/parser/statements.lua"))(META)
assert(loadfile("nattlua/parser/teal.lua"))(META)
assert(loadfile("nattlua/parser/lsx.lua"))(META)

function META:LexString(str--[[#: string]], config--[[#: nil | any]])
	config = config or {}
	local code = Code(str, config.file_path)
	local lexer = Lexer(code)
	lexer.OnError = self.OnError
	local ok, tokens = xpcall(lexer.GetTokens, debug.traceback, lexer)

	if not ok then return nil, tokens end

	return tokens, code
end

function META:ParseString(str--[[#: string]], config--[[#: nil | any]])
	local tokens, code = self:LexString(str, config)

	if not tokens then return nil, code end

	local parser = self.New(tokens, code, config)
	parser.OnError = self.OnError
	local ok, node = xpcall(parser.ParseRootNode, debug.traceback, parser)

	if not ok then return nil, node end

	node.lexer_tokens = tokens
	node.parser = parser
	node.code = code
	return node
end

local function read_file(self, path)
	local code = self.config.on_read_file and self.config.on_read_file(self, path)

	if code then return code end

	local f = assert(io.open(path, "rb"))
	local code = f:read("*a")
	f:close()

	if not code then error("file is empty", 2) end

	return code
end

function META:ParseFile(path--[[#: string]], config--[[#: nil | any]])
	config = config or {}
	config.file_path = config.file_path or path
	config.file_name = config.file_name or path
	local ok, code = pcall(read_file, self, path)

	if not ok then return ok, code end

	return self:ParseString(code, config)
end

local imported_index = nil

function META:ParseRootNode()
	local node = self:StartNode("statement", "root")
	self.RootStatement = self.config and self.config.root_statement_override or node
	local shebang

	if self:IsTokenType("shebang") then
		shebang = self:StartNode("statement", "shebang")
		shebang.tokens["shebang"] = self:ExpectTokenType("shebang")
		shebang = self:EndNode(shebang)
		node.tokens["shebang"] = shebang.tokens["shebang"]
	end

	local import_tree

	if self.config.emit_environment then
		if not imported_index then
			imported_index = true
			imported_index = self:ParseString([[import("nattlua/definitions/index.nlua")]])
		end

		if imported_index and imported_index ~= true then
			self.RootStatement.imports = self.RootStatement.imports or {}

			for _, import in ipairs(imported_index.imports) do
				table_insert(self.RootStatement.imports, import)
			end

			import_tree = imported_index
		end
	end

	node.statements = self:ParseStatements()

	if shebang then table_insert(node.statements, 1, shebang) end

	if import_tree then
		table_insert(node.statements, 1, import_tree.statements[1])
	end

	if self:IsTokenType("end_of_file") then
		local eof = self:StartNode("statement", "end_of_file")
		eof.tokens["end_of_file"] = self.tokens[#self.tokens]
		eof = self:EndNode(eof)
		table_insert(node.statements, eof)
		node.tokens["eof"] = eof.tokens["end_of_file"]
	end

	node = self:EndNode(node)
	return node
end

function META:ParseStatement()
	if self:IsTokenType("end_of_file") then return end

	local node = self:ParseDebugCodeStatement() or
		self:ParseReturnStatement() or
		self:ParseBreakStatement() or
		self:ParseContinueStatement() or
		self:ParseSemicolonStatement() or
		self:ParseGotoStatement() or
		self:ParseGotoLabelStatement() or
		self:ParseRepeatStatement() or
		self:ParseAnalyzerFunctionStatement() or
		self:ParseFunctionStatement() or
		self:ParseLocalTypeFunctionStatement() or
		self:ParseLocalFunctionStatement() or
		self:ParseLocalAnalyzerFunctionStatement() or
		self:ParseLocalTypeAssignmentStatement() or
		self:ParseLocalDestructureAssignmentStatement() or
		(
			self.TealCompat and
			self:ParseLocalTealRecord()
		)
		or
		(
			self.TealCompat and
			self:ParseLocalTealEnumStatement()
		)
		or
		self:ParseLocalAssignmentStatement() or
		self:ParseTypeAssignmentStatement() or
		self:ParseDoStatement() or
		self:ParseIfStatement() or
		self:ParseWhileStatement() or
		self:ParseNumericForStatement() or
		self:ParseGenericForStatement() or
		self:ParseDestructureAssignmentStatement() or
		self:ParseCallOrAssignmentStatement()
	return node
end

return META