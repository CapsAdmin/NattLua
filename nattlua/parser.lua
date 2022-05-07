local META = require("nattlua.parser.base")
local runtime_syntax = require("nattlua.syntax.runtime")
local typesystem_syntax = require("nattlua.syntax.typesystem")
local Code = require("nattlua.code").New
local Lexer = require("nattlua.lexer").New
local math = _G.math
local math_huge = math.huge
local table_insert = _G.table.insert
local table_remove = _G.table.remove
local ipairs = _G.ipairs

--[[#local type { Token, TokenType } = import("~/nattlua/lexer/token.lua")]]

--[[#local type { ExpressionKind, StatementKind, statement, expression } = import("./parser/nodes.nlua")]]

function META:ReadIdentifier(expect_type--[[#: nil | boolean]])
	if not self:IsType("letter") and not self:IsValue("...") then return end

	local node = self:StartNode("expression", "value") -- as ValueExpression ]]
	node.is_identifier = true

	if self:IsValue("...") then
		node.value = self:ExpectValue("...")
	else
		node.value = self:ExpectType("letter")

		if self:IsValue("<") then
			node.tokens["<"] = self:ExpectValue("<")
			node.attribute = self:ExpectType("letter")
			node.tokens[">"] = self:ExpectValue(">")
		end
	end

	if expect_type ~= false then
		if self:IsValue(":") or expect_type then
			node.tokens[":"] = self:ExpectValue(":")
			node.type_expression = self:ExpectTypeExpression(0)
		end
	end

	node = self:EndNode(node)
	return node
end

function META:ReadValueExpressionToken(expect_value--[[#: nil | string]])
	local node = self:StartNode("expression", "value")
	node.value = expect_value and self:ExpectValue(expect_value) or self:ReadToken()
	node = self:EndNode(node)
	return node
end

function META:ReadValueExpressionType(expect_value--[[#: TokenType]])
	local node = self:StartNode("expression", "value")
	node.value = self:ExpectType(expect_value)
	node = self:EndNode(node)
	return node
end

function META:ReadFunctionBody(
	node--[[#: expression.analyzer_function | expression["function"] | statement["local_function"] | statement["function"] ]]
)
	if self.TealCompat then
		if self:IsValue("<") then
			node.tokens["arguments_typesystem("] = self:ExpectValue("<")
			node.identifiers_typesystem = self:ReadMultipleValues(nil, self.ReadIdentifier)
			node.tokens["arguments_typesystem)"] = self:ExpectValue(">")
		end
	end

	node.tokens["arguments("] = self:ExpectValue("(")
	node.identifiers = self:ReadMultipleValues(nil, self.ReadIdentifier)
	node.tokens["arguments)"] = self:ExpectValue(")", node.tokens["arguments("])

	if self:IsValue(":") then
		node.tokens["return:"] = self:ExpectValue(":")
		self:PushParserEnvironment("typesystem")
		node.return_types = self:ReadMultipleValues(nil, self.ReadTypeExpression, 0)
		self:PopParserEnvironment()
	end

	node.statements = self:ReadNodes({["end"] = true})
	node.tokens["end"] = self:ExpectValue("end", node.tokens["function"])
	return node
end

function META:ReadTypeFunctionBody(
	node--[[#: statement["type_function"] | expression["type_function"] | statement["type_function"] ]]
)
	if self:IsValue("!") then
		node.tokens["!"] = self:ExpectValue("!")
		node.tokens["arguments("] = self:ExpectValue("(")
		node.identifiers = self:ReadMultipleValues(nil, self.ReadIdentifier, true)

		if self:IsValue("...") then
			table_insert(node.identifiers, self:ReadValueExpressionToken("..."))
		end

		node.tokens["arguments)"] = self:ExpectValue(")")
	else
		node.tokens["arguments("] = self:ExpectValue("<|")
		node.identifiers = self:ReadMultipleValues(nil, self.ReadIdentifier, true)

		if self:IsValue("...") then
			table_insert(node.identifiers, self:ReadValueExpressionToken("..."))
		end

		node.tokens["arguments)"] = self:ExpectValue("|>", node.tokens["arguments("])

		if self:IsValue("(") then
			local lparen = self:ExpectValue("(")
			local identifiers = self:ReadMultipleValues(nil, self.ReadIdentifier, true)
			local rparen = self:ExpectValue(")")
			node.identifiers_typesystem = node.identifiers
			node.identifiers = identifiers
			node.tokens["arguments_typesystem("] = node.tokens["arguments("]
			node.tokens["arguments_typesystem)"] = node.tokens["arguments)"]
			node.tokens["arguments("] = lparen
			node.tokens["arguments)"] = rparen
		end
	end

	if self:IsValue(":") then
		node.tokens["return:"] = self:ExpectValue(":")
		self:PushParserEnvironment("typesystem")
		node.return_types = self:ReadMultipleValues(math.huge, self.ExpectTypeExpression, 0)
		self:PopParserEnvironment("typesystem")
	end

	node.environment = "typesystem"
	self:PushParserEnvironment("typesystem")
	local start = self:GetToken()
	node.statements = self:ReadNodes({["end"] = true})
	node.tokens["end"] = self:ExpectValue("end", start, start)
	self:PopParserEnvironment()
	return node
end

function META:ReadTypeFunctionArgument(expect_type--[[#: nil | boolean]])
	if self:IsValue(")") then return end

	if self:IsValue("...") then return end

	if expect_type or self:IsType("letter") and self:IsValue(":", 1) then
		local identifier = self:ReadToken()
		local token = self:ExpectValue(":")
		local exp = self:ExpectTypeExpression(0)
		exp.tokens[":"] = token
		exp.identifier = identifier
		return exp
	end

	return self:ExpectTypeExpression(0)
end

function META:ReadAnalyzerFunctionBody(
	node--[[#: statement["analyzer_function"] | expression["analyzer_function"] | statement["local_analyzer_function"] ]],
	type_args--[[#: boolean]]
)
	self:PushParserEnvironment("runtime")
	node.tokens["arguments("] = self:ExpectValue("(")
	node.identifiers = self:ReadMultipleValues(math_huge, self.ReadTypeFunctionArgument, type_args)

	if self:IsValue("...") then
		local vararg = self:StartNode("expression", "value")
		vararg.value = self:ExpectValue("...")

		if self:IsValue(":") or type_args then
			vararg.tokens[":"] = self:ExpectValue(":")
			vararg.type_expression = self:ExpectTypeExpression(0)
		else
			if self:IsType("letter") then
				vararg.type_expression = self:ExpectTypeExpression(0)
			end
		end

		vararg = self:EndNode(vararg)
		table_insert(node.identifiers, vararg)
	end

	node.tokens["arguments)"] = self:ExpectValue(")", node.tokens["arguments("])

	if self:IsValue(":") then
		node.tokens["return:"] = self:ExpectValue(":")
		self:PushParserEnvironment("typesystem")
		node.return_types = self:ReadMultipleValues(math.huge, self.ReadTypeExpression, 0)
		self:PopParserEnvironment()
		local start = self:GetToken()
		_G.dont_hoist_import = (_G.dont_hoist_import or 0) + 1
		node.statements = self:ReadNodes({["end"] = true})
		_G.dont_hoist_import = (_G.dont_hoist_import or 0) - 1
		node.tokens["end"] = self:ExpectValue("end", start, start)
	elseif not self:IsValue(",") then
		local start = self:GetToken()
		_G.dont_hoist_import = (_G.dont_hoist_import or 0) + 1
		node.statements = self:ReadNodes({["end"] = true})
		_G.dont_hoist_import = (_G.dont_hoist_import or 0) - 1
		node.tokens["end"] = self:ExpectValue("end", start, start)
	end

	self:PopParserEnvironment()
	return node
end

assert(loadfile("nattlua/parser/expressions.lua"))(META)
assert(loadfile("nattlua/parser/statements.lua"))(META)
assert(loadfile("nattlua/parser/teal.lua"))(META)

function META:LexString(str--[[#: string]], config--[[#: nil | any]])
	config = config or {}
	local code = Code(str, config.file_path)
	local lexer = Lexer(code, config)
	local ok, tokens = xpcall(lexer.GetTokens, debug.traceback, lexer)

	if not ok then return nil, tokens end

	return tokens, code
end

function META:ParseString(str--[[#: string]], config--[[#: nil | any]])
	local tokens, code = self:LexString(str, config)

	if not tokens then return nil, code end

	local parser = self.New(tokens, code, config)
	local ok, node = xpcall(parser.ReadRootNode, debug.traceback, parser)

	if not ok then return nil, node end

	return node
end

function META:ParseFile(path--[[#: string]], config--[[#: nil | any]])
	config = config or {}
	config.file_path = config.file_path or path
	config.file_name = config.file_name or path
	local f, err = io.open(path, "rb")

	if not f then return nil, err end

	local code = f:read("*a")
	f:close()

	if not code then return nil, "file is empty" end

	return self:ParseString(code, config)
end

local imported_index = nil

function META:ReadRootNode()
	local node = self:StartNode("statement", "root")
	self.RootStatement = self.config and self.config.root_statement_override or node
	local shebang

	if self:IsType("shebang") then
		shebang = self:StartNode("statement", "shebang")
		shebang.tokens["shebang"] = self:ExpectType("shebang")
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
				table.insert(self.RootStatement.imports, import)
			end

			import_tree = imported_index
		end
	end

	node.statements = self:ReadNodes()

	if shebang then table.insert(node.statements, 1, shebang) end

	if import_tree then
		table.insert(node.statements, 1, import_tree.statements[1])
	end

	if self:IsType("end_of_file") then
		local eof = self:StartNode("statement", "end_of_file")
		eof.tokens["end_of_file"] = self.tokens[#self.tokens]
		eof = self:EndNode(eof)
		table.insert(node.statements, eof)
		node.tokens["eof"] = eof.tokens["end_of_file"]
	end

	node = self:EndNode(node)
	return node
end

function META:ReadNode()
	if self:IsType("end_of_file") then return end

	return self:ReadDebugCodeStatement() or
		self:ReadReturnStatement() or
		self:ReadBreakStatement() or
		self:ReadContinueStatement() or
		self:ReadSemicolonStatement() or
		self:ReadGotoStatement() or
		self:ReadGotoLabelStatement() or
		self:ReadRepeatStatement() or
		self:ReadAnalyzerFunctionStatement() or
		self:ReadFunctionStatement() or
		self:ReadLocalTypeFunctionStatement() or
		self:ReadLocalFunctionStatement() or
		self:ReadLocalAnalyzerFunctionStatement() or
		self:ReadLocalTypeAssignmentStatement() or
		self:ReadLocalDestructureAssignmentStatement() or
		self.TealCompat and
		self:ReadLocalTealRecord()
		or
		self.TealCompat and
		self:ReadLocalTealEnumStatement()
		or
		self:ReadLocalAssignmentStatement() or
		self:ReadTypeAssignmentStatement() or
		self:ReadDoStatement() or
		self:ReadIfStatement() or
		self:ReadWhileStatement() or
		self:ReadNumericForStatement() or
		self:ReadGenericForStatement() or
		self:ReadDestructureAssignmentStatement() or
		self:ReadCallOrAssignmentStatement()
end

return META