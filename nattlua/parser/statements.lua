local META = ...
local runtime_syntax = require("nattlua.syntax.runtime")
local typesystem_syntax = require("nattlua.syntax.typesystem")
local math_huge = _G.math.huge
local ipairs = _G.ipairs

do -- destructure statement
	function META:IsDestructureStatement(offset--[[#: number]])
		offset = offset or 0
		return (
				self:IsTokenValue("{", offset + 0) and
				self:IsTokenType("letter", offset + 1)
			) or
			(
				self:IsTokenType("letter", offset + 0) and
				self:IsTokenValue(",", offset + 1) and
				self:IsTokenValue("{", offset + 2)
			)
	end

	function META:IsLocalDestructureAssignmentStatement()
		if self:IsTokenValue("local") then
			if self:IsTokenValue("type", 1) then return self:IsDestructureStatement(2) end

			return self:IsDestructureStatement(1)
		end
	end

	function META:ParseDestructureAssignmentStatement()
		if not self:IsDestructureStatement() then return end

		local node = self:StartNode("statement", "destructure_assignment")

		do
			if self:IsTokenType("letter") then
				node.default = self:ParseValueExpressionToken()
				node.default_comma = self:ExpectTokenValue(",")
			end

			node.tokens["{"] = self:ExpectTokenValue("{")
			node.left = self:ParseMultipleValues(nil, self.ParseIdentifier)
			node.tokens["}"] = self:ExpectTokenValue("}")
			node.tokens["="] = self:ExpectTokenValue("=")
			node.right = self:ExpectRuntimeExpression(0)
		end

		node = self:EndNode(node)
		return node
	end

	function META:ParseLocalDestructureAssignmentStatement()
		if not self:IsLocalDestructureAssignmentStatement() then return end

		local node = self:StartNode("statement", "local_destructure_assignment")
		node.tokens["local"] = self:ExpectTokenValue("local")

		if self:IsTokenValue("type") then
			node.tokens["type"] = self:ExpectTokenValue("type")
			node.environment = "typesystem"
		end

		do -- remaining
			if self:IsTokenType("letter") then
				node.default = self:ParseValueExpressionToken()
				node.default_comma = self:ExpectTokenValue(",")
			end

			node.tokens["{"] = self:ExpectTokenValue("{")
			node.left = self:ParseMultipleValues(nil, self.ParseIdentifier)
			node.tokens["}"] = self:ExpectTokenValue("}")
			node.tokens["="] = self:ExpectTokenValue("=")
			node.right = self:ExpectRuntimeExpression(0)
		end

		node = self:EndNode(node)
		return node
	end
end

do
	function META:ParseFunctionNameIndex()
		if not runtime_syntax:IsValue(self:GetToken()) then return end

		local node = self:ParseValueExpressionToken()
		local first = node
		first.standalone_letter = node

		while self:IsTokenValue(".") or self:IsTokenValue(":") do
			local left = node
			local self_call = self:IsTokenValue(":")
			node = self:StartNode("expression", "binary_operator")
			node.value = self:ParseToken()
			node.right = self:ParseValueExpressionType("letter")
			node.left = left
			node.right.self_call = self_call
			node.is_left_assignment = true
			node = self:EndNode(node)
		end

		return node
	end

	function META:ParseFunctionStatement()
		if not self:IsTokenValue("function") then return end

		local node = self:StartNode("statement", "function")
		node.tokens["function"] = self:ExpectTokenValue("function")
		node.expression = self:ParseFunctionNameIndex()

		if node.expression and node.expression.kind == "binary_operator" then
			node.self_call = node.expression.right.self_call
		end

		if self:IsTokenValue("<|") then
			node.kind = "type_function"
			self:ParseTypeFunctionBody(node)
		else
			self:ParseFunctionBody(node)
		end

		node = self:EndNode(node)
		return node
	end

	function META:ParseAnalyzerFunctionStatement()
		if not (self:IsTokenValue("analyzer") and self:IsTokenValue("function", 1)) then
			return
		end

		local node = self:StartNode("statement", "analyzer_function")
		node.tokens["analyzer"] = self:ExpectTokenValue("analyzer")
		node.tokens["function"] = self:ExpectTokenValue("function")
		local force_upvalue

		if self:IsTokenValue("^") then
			force_upvalue = true
			node.tokens["^"] = self:ParseToken()
		end

		node.expression = self:ParseFunctionNameIndex()

		do -- hacky
			if node.expression.left then
				node.expression.left.standalone_letter = node
				node.expression.left.force_upvalue = force_upvalue
			else
				node.expression.standalone_letter = node
				node.expression.force_upvalue = force_upvalue
			end

			if node.expression.value.value == ":" then node.self_call = true end
		end

		self:ParseAnalyzerFunctionBody(node, true)
		node = self:EndNode(node)
		return node
	end
end

function META:ParseLocalFunctionStatement()
	if not (self:IsTokenValue("local") and self:IsTokenValue("function", 1)) then
		return
	end

	local node = self:StartNode("statement", "local_function")
	node.tokens["local"] = self:ExpectTokenValue("local")
	node.tokens["function"] = self:ExpectTokenValue("function")
	node.tokens["identifier"] = self:ExpectTokenType("letter")
	self:ParseFunctionBody(node)
	node = self:EndNode(node)
	return node
end

function META:ParseLocalAnalyzerFunctionStatement()
	if
		not (
			self:IsTokenValue("local") and
			self:IsTokenValue("analyzer", 1) and
			self:IsTokenValue("function", 2)
		)
	then
		return
	end

	local node = self:StartNode("statement", "local_analyzer_function")
	node.tokens["local"] = self:ExpectTokenValue("local")
	node.tokens["analyzer"] = self:ExpectTokenValue("analyzer")
	node.tokens["function"] = self:ExpectTokenValue("function")
	node.tokens["identifier"] = self:ExpectTokenType("letter")
	self:ParseAnalyzerFunctionBody(node, true)
	node = self:EndNode(node)
	return node
end

function META:ParseLocalTypeFunctionStatement()
	if
		not (
			self:IsTokenValue("local") and
			self:IsTokenValue("function", 1) and
			(
				self:IsTokenValue("<|", 3) or
				self:IsTokenValue("!", 3)
			)
		)
	then
		return
	end

	local node = self:StartNode("statement", "local_type_function")
	node.tokens["local"] = self:ExpectTokenValue("local")
	node.tokens["function"] = self:ExpectTokenValue("function")
	node.tokens["identifier"] = self:ExpectTokenType("letter")
	self:ParseTypeFunctionBody(node)
	node = self:EndNode(node)
	return node
end

function META:ParseBreakStatement()
	if not self:IsTokenValue("break") then return nil end

	local node = self:StartNode("statement", "break")
	node.tokens["break"] = self:ExpectTokenValue("break")
	node = self:EndNode(node)
	return node
end

function META:ParseDoStatement()
	if not self:IsTokenValue("do") then return nil end

	local node = self:StartNode("statement", "do")
	node.tokens["do"] = self:ExpectTokenValue("do")
	node.statements = self:ParseStatements({["end"] = true})
	node.tokens["end"] = self:ExpectTokenValue("end", node.tokens["do"])
	node = self:EndNode(node)
	return node
end

function META:ParseGenericForStatement()
	if not self:IsTokenValue("for") then return nil end

	local node = self:StartNode("statement", "generic_for")
	node.tokens["for"] = self:ExpectTokenValue("for")
	node.identifiers = self:ParseMultipleValues(nil, self.ParseIdentifier)
	node.tokens["in"] = self:ExpectTokenValue("in")
	node.expressions = self:ParseMultipleValues(math_huge, self.ExpectRuntimeExpression, 0)
	node.tokens["do"] = self:ExpectTokenValue("do")
	node.statements = self:ParseStatements({["end"] = true})
	node.tokens["end"] = self:ExpectTokenValue("end", node.tokens["do"])
	node = self:EndNode(node)
	return node
end

function META:ParseGotoLabelStatement()
	if not self:IsTokenValue("::") then return nil end

	local node = self:StartNode("statement", "goto_label")
	node.tokens["::"] = self:ExpectTokenValue("::")
	node.tokens["identifier"] = self:ExpectTokenType("letter")
	node.tokens["::"] = self:ExpectTokenValue("::")
	node = self:EndNode(node)
	return node
end

function META:ParseGotoStatement()
	if not self:IsTokenValue("goto") or not self:IsTokenType("letter", 1) then
		return nil
	end

	local node = self:StartNode("statement", "goto")
	node.tokens["goto"] = self:ExpectTokenValue("goto")
	node.tokens["identifier"] = self:ExpectTokenType("letter")
	node = self:EndNode(node)
	return node
end

function META:ParseIfStatement()
	if not self:IsTokenValue("if") then return nil end

	local node = self:StartNode("statement", "if")
	node.expressions = {}
	node.statements = {}
	node.tokens["if/else/elseif"] = {}
	node.tokens["then"] = {}

	for i = 1, self:GetLength() do
		local token

		if i == 1 then
			token = self:ExpectTokenValue("if")
		else
			token = self:ParseValues({
				["else"] = true,
				["elseif"] = true,
				["end"] = true,
			})
		end

		if not token then return end -- TODO: what happens here? :End is never called
		node.tokens["if/else/elseif"][i] = token

		if token.value ~= "else" then
			node.expressions[i] = self:ExpectRuntimeExpression(0)
			node.tokens["then"][i] = self:ExpectTokenValue("then")
		end

		node.statements[i] = self:ParseStatements({
			["end"] = true,
			["else"] = true,
			["elseif"] = true,
		})

		if self:IsTokenValue("end") then break end
	end

	node.tokens["end"] = self:ExpectTokenValue("end")
	node = self:EndNode(node)
	return node
end

function META:ParseLocalAssignmentStatement()
	if not self:IsTokenValue("local") then return end

	local node = self:StartNode("statement", "local_assignment")
	node.tokens["local"] = self:ExpectTokenValue("local")

	if self.TealCompat and self:IsTokenValue(",", 1) then
		node.left = self:ParseMultipleValues(nil, self.ParseIdentifier, false)

		if self:IsTokenValue(":") then
			self:Advance(1)
			local expressions = self:ParseMultipleValues(nil, self.ParseTealExpression, 0)

			for i, v in ipairs(node.left) do
				v.type_expression = expressions[i]
				v.tokens[":"] = self:NewToken("symbol", ":")
			end
		end
	else
		node.left = self:ParseMultipleValues(nil, self.ParseIdentifier)
	end

	if self:IsTokenValue("=") then
		node.tokens["="] = self:ExpectTokenValue("=")
		node.right = self:ParseMultipleValues(nil, self.ExpectRuntimeExpression, 0)
	end

	node = self:EndNode(node)
	return node
end

function META:ParseNumericForStatement()
	if not (self:IsTokenValue("for") and self:IsTokenValue("=", 2)) then
		return nil
	end

	local node = self:StartNode("statement", "numeric_for")
	node.tokens["for"] = self:ExpectTokenValue("for")
	node.identifiers = self:ParseMultipleValues(1, self.ParseIdentifier)
	node.tokens["="] = self:ExpectTokenValue("=")
	node.expressions = self:ParseMultipleValues(3, self.ExpectRuntimeExpression, 0)
	node.tokens["do"] = self:ExpectTokenValue("do")
	node.statements = self:ParseStatements({["end"] = true})
	node.tokens["end"] = self:ExpectTokenValue("end", node.tokens["do"])
	node = self:EndNode(node)
	return node
end

function META:ParseRepeatStatement()
	if not self:IsTokenValue("repeat") then return nil end

	local node = self:StartNode("statement", "repeat")
	node.tokens["repeat"] = self:ExpectTokenValue("repeat")
	node.statements = self:ParseStatements({["until"] = true})
	node.tokens["until"] = self:ExpectTokenValue("until")
	node.expression = self:ExpectRuntimeExpression()
	node = self:EndNode(node)
	return node
end

function META:ParseSemicolonStatement()
	if not self:IsTokenValue(";") then return nil end

	local node = self:StartNode("statement", "semicolon")
	node.tokens[";"] = self:ExpectTokenValue(";")
	node = self:EndNode(node)
	return node
end

function META:ParseReturnStatement()
	if not self:IsTokenValue("return") then return nil end

	local node = self:StartNode("statement", "return")
	node.tokens["return"] = self:ExpectTokenValue("return")
	node.expressions = self:ParseMultipleValues(nil, self.ParseRuntimeExpression, 0)
	node = self:EndNode(node)
	return node
end

function META:ParseWhileStatement()
	if not self:IsTokenValue("while") then return nil end

	local node = self:StartNode("statement", "while")
	node.tokens["while"] = self:ExpectTokenValue("while")
	node.expression = self:ExpectRuntimeExpression()
	node.tokens["do"] = self:ExpectTokenValue("do")
	node.statements = self:ParseStatements({["end"] = true})
	node.tokens["end"] = self:ExpectTokenValue("end", node.tokens["do"])
	node = self:EndNode(node)
	return node
end

function META:ParseContinueStatement()
	if not self:IsTokenValue("continue") then return nil end

	local node = self:StartNode("statement", "continue")
	node.tokens["continue"] = self:ExpectTokenValue("continue")
	node = self:EndNode(node)
	return node
end

do
	local formating = require("nattlua.other.formating")
	local loadstring = require("nattlua.other.loadstring")
	local locals = ""
	locals = locals .. "local bit=bit32 or _G.bit;"

	if _G.BUNDLE then
		locals = locals .. "local nl=IMPORTS[\"nattlua.init\"]();"
		locals = locals .. "local types=IMPORTS[\"nattlua.types.types\"]();"
		locals = locals .. "local context=IMPORTS[\"nattlua.analyzer.context\"]();"
		locals = locals .. "local cdecl_parser = IMPORTS[\"nattlua.c_declarations.main\"]();"
	else
		locals = locals .. "local nl=require(\"nattlua.init\");"
		locals = locals .. "local types=require(\"nattlua.types.types\");"
		locals = locals .. "local context=require(\"nattlua.analyzer.context\");"
		locals = locals .. "local cdecl_parser=require(\"nattlua.c_declarations.main\");"
	end

	local globals = {
		"loadstring",
		"dofile",
		"gcinfo",
		"collectgarbage",
		"newproxy",
		"print",
		"_VERSION",
		"coroutine",
		"debug",
		"package",
		"os",
		"bit",
		"_G",
		"module",
		"require",
		"assert",
		"string",
		"arg",
		"jit",
		"math",
		"table",
		"io",
		"type",
		"next",
		"pairs",
		"ipairs",
		"getmetatable",
		"setmetatable",
		"getfenv",
		"setfenv",
		"rawget",
		"rawset",
		"rawequal",
		"unpack",
		"select",
		"tonumber",
		"tostring",
		"error",
		"pcall",
		"xpcall",
		"loadfile",
		"load",
	}

	for _, key in ipairs(globals) do
		locals = locals .. "local " .. tostring(key) .. "=_G." .. key .. ";"
	end

	local runtime_injection = {
		[[local analyzer = assert(context:GetCurrentAnalyzer(), "no analyzer in context")]],
		[[local env = analyzer:GetScopeHelper(assert(analyzer.function_scope, "no function scope in context"))]],
	}
	runtime_injection = table.concat(runtime_injection, ";") .. ";"

	function META:CompileLuaAnalyzerDebugCode(code, node)
		local start, stop = code:find("__REPLACE_ME__", nil, true)

		if start and stop then
			local before_function = code:sub(1, start - 1)
			local after_function = code:sub(stop + 1, #code)
			code = before_function .. runtime_injection .. after_function
		else
			code = runtime_injection .. code
		end

		code = locals .. code
		-- append newlines so that potential runtime line errors are correct
		local lua_code = node.Code:GetString()
		local line

		if lua_code then
			local start, stop = node:GetStartStop()
			line = formating.SubPositionToLinePosition(lua_code, start, stop).line_start
			code = ("\n"):rep(line - 1) .. code
		end

		return assert(loadstring(code, node.Code:GetName() .. ":" .. line)), code
	end
end

function META:ParseDebugCodeStatement()
	if self:IsTokenType("analyzer_debug_code") then
		local node = self:StartNode("statement", "analyzer_debug_code")
		node.lua_code = self:ParseValueExpressionType("analyzer_debug_code")
		node.compiled_function = self:CompileLuaAnalyzerDebugCode(node.lua_code.value.value:sub(3), node)
		node = self:EndNode(node)
		return node
	elseif self:IsTokenType("parser_debug_code") then
		local token = self:ExpectTokenType("parser_debug_code")
		assert(loadstring("local parser = ...;" .. token.value:sub(3)))(self)
		local node = self:StartNode("statement", "parser_debug_code")
		local code = self:StartNode("expression", "value")
		code.value = token
		code = self:EndNode(code)
		node.lua_code = code
		node = self:EndNode(node)
		return node
	end
end

function META:ParseLocalTypeAssignmentStatement()
	if
		not (
			self:IsTokenValue("local") and
			self:IsTokenValue("type", 1) and
			runtime_syntax:GetTokenType(self:GetToken(2)) == "letter"
		)
	then
		return
	end

	local node = self:StartNode("statement", "local_assignment")
	node.tokens["local"] = self:ExpectTokenValue("local")
	node.tokens["type"] = self:ExpectTokenValue("type")
	node.left = self:ParseMultipleValues(nil, self.ParseIdentifier)
	node.environment = "typesystem"

	if self:IsTokenValue("=") then
		node.tokens["="] = self:ExpectTokenValue("=")
		self:PushParserEnvironment("typesystem")
		node.right = self:ParseMultipleValues(nil, self.ExpectTypeExpression, 0)
		self:PopParserEnvironment()
	end

	node = self:EndNode(node)
	return node
end

function META:ParseTypeAssignmentStatement()
	if
		not (
			self:IsTokenValue("type") and
			(
				self:IsTokenType("letter", 1) or
				self:IsTokenValue("^", 1)
			)
		)
	then
		return
	end

	local node = self:StartNode("statement", "assignment")
	node.tokens["type"] = self:ExpectTokenValue("type")
	node.left = self:ParseMultipleValues(nil, self.ExpectTypeExpression, 0)
	node.environment = "typesystem"

	if self:IsTokenValue("=") then
		node.tokens["="] = self:ExpectTokenValue("=")
		self:PushParserEnvironment("typesystem")
		node.right = self:ParseMultipleValues(nil, self.ExpectTypeExpression, 0)
		self:PopParserEnvironment()
	end

	node = self:EndNode(node)
	return node
end

function META:ParseCallOrAssignmentStatement()
	local start = self:GetToken()
	self:SuppressOnNode()
	local left = self:ParseMultipleValues(math_huge, self.ExpectRuntimeExpression, 0)

	if
		(
			self:IsTokenValue("+") or
			self:IsTokenValue("-") or
			self:IsTokenValue("*") or
			self:IsTokenValue("/") or
			self:IsTokenValue("%") or
			self:IsTokenValue("^") or
			self:IsTokenValue("..")
		) and
		self:IsTokenValue("=", 1)
	then
		-- roblox compound assignment
		local op_token = self:ParseToken()
		local eq_token = self:ParseToken()
		local bop = self:StartNode("expression", "binary_operator")
		bop.left = left[1]
		bop.value = op_token
		bop.right = self:ExpectRuntimeExpression(0)
		self:EndNode(bop)
		local node = self:StartNode("statement", "assignment", left[1])
		node.tokens["="] = eq_token
		node.left = left

		for i, v in ipairs(node.left) do
			v.is_left_assignment = true
		end

		node.right = {bop}
		self:ReRunOnNode(node.left)
		node = self:EndNode(node)
		return node
	end

	if self:IsTokenValue("=") then
		local node = self:StartNode("statement", "assignment", left[1])
		node.tokens["="] = self:ExpectTokenValue("=")
		node.left = left

		for i, v in ipairs(node.left) do
			v.is_left_assignment = true
		end

		node.right = self:ParseMultipleValues(math_huge, self.ExpectRuntimeExpression, 0)
		self:ReRunOnNode(node.left)
		node = self:EndNode(node)
		return node
	end

	if left[1] and (left[1].kind == "postfix_call") and not left[2] then
		local node = self:StartNode("statement", "call_expression", left[1])
		node.value = left[1]
		node.tokens = left[1].tokens
		self:ReRunOnNode(left)
		node = self:EndNode(node)
		return node
	end

	self:Error(
		"expected assignment or call expression got $1 ($2)",
		start,
		self:GetToken(),
		self:GetToken().type,
		self:GetToken().value
	)
end
