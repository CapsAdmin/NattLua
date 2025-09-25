local runtime_syntax = require("nattlua.syntax.runtime")
local typesystem_syntax = require("nattlua.syntax.typesystem")
local loadstring = require("nattlua.other.loadstring")
local math_huge = _G.math.huge
local ipairs = _G.ipairs
local assert = _G.assert
local tostring = _G.tostring
return function(META)
	do -- destructure statement
		function META:IsDestructureStatement(offset--[[#: number]])
			offset = offset or 0
			return (
					self:IsTokenOffset("{", offset + 0) and
					self:IsTokenTypeOffset("letter", offset + 1)
				) or
				(
					self:IsTokenTypeOffset("letter", offset + 0) and
					self:IsTokenOffset(",", offset + 1) and
					self:IsTokenOffset("{", offset + 2)
				)
		end

		function META:IsLocalDestructureAssignmentStatement()
			if self:IsToken("local") then
				if self:IsTokenOffset("type", 1) then
					return self:IsDestructureStatement(2)
				end

				return self:IsDestructureStatement(1)
			end
		end

		function META:ParseDestructureAssignmentStatement()
			if not self:IsDestructureStatement() then return false end

			local node = self:StartNode("statement_destructure_assignment")

			do
				if self:IsTokenType("letter") then
					node.default = self:ParseValueExpressionToken()
					node.default_comma = self:ExpectToken(",")
				end

				node.tokens["{"] = self:ExpectToken("{")
				node.left = self:ParseMultipleValues(self.ParseIdentifier)
				node.tokens["}"] = self:ExpectToken("}")
				node.tokens["="] = self:ExpectToken("=")
				node.right = self:ExpectRuntimeExpression(0)
			end

			node = self:EndNode(node)
			return node
		end

		function META:ParseLocalDestructureAssignmentStatement()
			if not self:IsLocalDestructureAssignmentStatement() then return false end

			local node = self:StartNode("statement_local_destructure_assignment")
			node.tokens["local"] = self:ExpectToken("local")

			if self:IsToken("type") then
				node.tokens["type"] = self:ExpectToken("type")
				node.environment = "typesystem"
			end

			do -- remaining
				if self:IsTokenType("letter") then
					node.default = self:ParseValueExpressionToken()
					node.default_comma = self:ExpectToken(",")
				end

				node.tokens["{"] = self:ExpectToken("{")
				node.left = self:ParseMultipleValues(self.ParseIdentifier)
				node.tokens["}"] = self:ExpectToken("}")
				node.tokens["="] = self:ExpectToken("=")
				node.right = self:ExpectRuntimeExpression(0)
			end

			node = self:EndNode(node)
			return node
		end
	end

	do
		function META:ParseFunctionNameIndex()
			if not runtime_syntax:IsValue(self:GetToken()) then return false end

			local node = self:ParseValueExpressionToken()
			local first = node
			first.standalone_letter = node

			for _ = self:GetPosition(), self:GetLength() do
				if not (self:IsToken(".") or self:IsToken(":")) then break end

				local left = node
				local self_call = self:IsToken(":")
				node = self:StartNode("expression_binary_operator")
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
			if not self:IsToken("function") then return false end

			local node = self:StartNode("statement_function")
			node.tokens["function"] = self:ExpectToken("function")
			node.expression = self:ParseFunctionNameIndex()

			if node.expression and node.expression.Type == "expression_binary_operator" then
				node.self_call = node.expression.right.self_call or false
			end

			if self:IsToken("<|") then
				node.Type = "statement_type_function"
				self:ParseTypeFunctionBody(node)
			else
				self:ParseFunctionBody(node)
			end

			node = self:EndNode(node)
			return node
		end

		function META:ParseAnalyzerFunctionStatement()
			if
				not (
					self:IsToken("analyzer") and
					self:IsTokenOffset("function", 1)
				)
			then
				return false
			end

			local node = self:StartNode("statement_analyzer_function")
			node.tokens["analyzer"] = self:ExpectToken("analyzer")
			node.tokens["function"] = self:ExpectToken("function")
			local force_upvalue = false

			if self:IsToken("^") then
				force_upvalue = true
				node.tokens["^"] = self:ParseToken()
			end

			node.expression = self:ParseFunctionNameIndex()

			do -- hacky
				if node.expression.Type == "expression_binary_operator" and node.expression.left then
					node.expression.left.standalone_letter = node
					node.expression.left.force_upvalue = force_upvalue
				else
					node.expression.standalone_letter = node
					node.expression.force_upvalue = force_upvalue
				end

				if node.expression.value:ValueEquals(":") then node.self_call = true end
			end

			self:ParseAnalyzerFunctionBody(node, true)
			node = self:EndNode(node)
			return node
		end
	end

	function META:ParseLocalFunctionStatement()
		if not (self:IsToken("local") and self:IsTokenOffset("function", 1)) then
			return false
		end

		local node = self:StartNode("statement_local_function")
		node.tokens["local"] = self:ExpectToken("local")
		node.tokens["function"] = self:ExpectToken("function")
		node.tokens["identifier"] = self:ExpectTokenType("letter")
		self:ParseFunctionBody(node)
		node = self:EndNode(node)
		return node
	end

	function META:ParseLocalAnalyzerFunctionStatement()
		if
			not (
				self:IsToken("local") and
				self:IsTokenOffset("analyzer", 1) and
				self:IsTokenOffset("function", 2)
			)
		then
			return false
		end

		local node = self:StartNode("statement_local_analyzer_function")
		node.tokens["local"] = self:ExpectToken("local")
		node.tokens["analyzer"] = self:ExpectToken("analyzer")
		node.tokens["function"] = self:ExpectToken("function")
		node.tokens["identifier"] = self:ExpectTokenType("letter")
		self:ParseAnalyzerFunctionBody(node, true)
		node = self:EndNode(node)
		return node
	end

	function META:ParseLocalTypeFunctionStatement()
		if
			not (
				self:IsToken("local") and
				self:IsTokenOffset("function", 1) and
				(
					self:IsTokenOffset("<|", 3) or
					self:IsTokenOffset("!", 3)
				)
			)
		then
			return false
		end

		local node = self:StartNode("statement_local_type_function")
		node.tokens["local"] = self:ExpectToken("local")
		node.tokens["function"] = self:ExpectToken("function")
		node.tokens["identifier"] = self:ExpectTokenType("letter")
		self:ParseTypeFunctionBody(node)
		node = self:EndNode(node)
		return node
	end

	function META:ParseBreakStatement()
		if not self:IsToken("break") then return false end

		local node = self:StartNode("statement_break")
		node.tokens["break"] = self:ExpectToken("break")
		node = self:EndNode(node)
		return node
	end

	function META:ParseDoStatement()
		if not self:IsToken("do") then return false end

		local node = self:StartNode("statement_do")
		node.tokens["do"] = self:ExpectToken("do")
		node.statements = self:ParseStatementsUntilEnd()
		node.tokens["end"] = self:ExpectToken("end", node.tokens["do"])
		node = self:EndNode(node)
		return node
	end

	function META:ParseGenericForStatement()
		if not self:IsToken("for") then return false end

		local node = self:StartNode("statement_generic_for")
		node.tokens["for"] = self:ExpectToken("for")
		node.identifiers = self:ParseMultipleValues(self.ParseIdentifier)
		node.tokens["in"] = self:ExpectToken("in")
		node.expressions = self:ParseMultipleValues(self.ExpectRuntimeExpression, 0)
		node.tokens["do"] = self:ExpectToken("do")
		node.statements = self:ParseStatementsUntilEnd()
		node.tokens["end"] = self:ExpectToken("end", node.tokens["do"])
		node = self:EndNode(node)
		return node
	end

	function META:ParseGotoLabelStatement()
		if not self:IsToken("::") then return false end

		local node = self:StartNode("statement_goto_label")
		node.tokens["::"] = self:ExpectToken("::")
		node.tokens["identifier"] = self:ExpectTokenType("letter")
		node.tokens["::"] = self:ExpectToken("::")
		node = self:EndNode(node)
		return node
	end

	function META:ParseGotoStatement()
		if not self:IsToken("goto") or not self:IsTokenTypeOffset("letter", 1) then
			return false
		end

		local node = self:StartNode("statement_goto")
		node.tokens["goto"] = self:ExpectToken("goto")
		node.tokens["identifier"] = self:ExpectTokenType("letter")
		node = self:EndNode(node)
		return node
	end

	do
		local function condition(token)
			return token.type == "letter" and
				(
					token:ValueEquals("end") or
					token:ValueEquals("else") or
					token:ValueEquals("elseif")
				)
		end

		function META:ParseIfStatement()
			if not self:IsToken("if") then return false end

			local node = self:StartNode("statement_if")
			node.expressions = {}
			node.statements = {}
			node.tokens["if/else/elseif"] = {}
			node.tokens["then"] = {}
			local i = 1

			for _ = self:GetPosition(), self:GetLength() do
				local token

				if i == 1 then
					token = self:ExpectToken("if")
				elseif self:IsToken("elseif") or self:IsToken("else") or self:IsToken("end") then
					token = self:GetToken()
					self:Advance(1)
				else
					self:Error("expected elseif, else or end got $2", nil, nil, self:GetToken().type)
				end

				if not token then return false end -- TODO: what happens here? :End is never called
				node.tokens["if/else/elseif"][i] = token

				if not token:ValueEquals("else") then
					node.expressions[i] = self:ExpectRuntimeExpression(0)
					node.tokens["then"][i] = self:ExpectToken("then")
				end

				node.statements[i] = self:ParseStatementsUntilCondition(condition)

				if self:IsToken("end") then break end

				i = i + 1
			end

			node.tokens["end"] = self:ExpectToken("end")
			node = self:EndNode(node)
			return node
		end
	end

	function META:ParseLocalAssignmentStatement()
		if not self:IsToken("local") then return false end

		local node = self:StartNode("statement_local_assignment")
		node.tokens["local"] = self:ExpectToken("local")

		if self.TealCompat and self:IsTokenOffset(",", 1) then
			node.left = self:ParseMultipleValues(self.ParseIdentifier, false)

			if self:IsToken(":") then
				self:Advance(1)
				local expressions = self:ParseMultipleValues(self.ParseTealExpression, 0)

				for i, v in ipairs(node.left) do
					v.type_expression = expressions[i]
					v.tokens[":"] = self:NewToken("symbol", ":")
				end
			end
		else
			node.left = self:ParseMultipleValues(self.ParseIdentifier)
		end

		if self:IsToken("=") then
			node.tokens["="] = self:ExpectToken("=")
			node.right = self:ParseMultipleValues(self.ExpectRuntimeExpression, 0)
		end

		node = self:EndNode(node)
		return node
	end

	function META:ParseNumericForStatement()
		if not (self:IsToken("for") and self:IsTokenOffset("=", 2)) then
			return false
		end

		local node = self:StartNode("statement_numeric_for")
		node.tokens["for"] = self:ExpectToken("for")
		node.identifiers = self:ParseFixedMultipleValues(1, self.ParseIdentifier)
		node.tokens["="] = self:ExpectToken("=")
		node.expressions = self:ParseFixedMultipleValues(3, self.ExpectRuntimeExpression, 0)
		node.tokens["do"] = self:ExpectToken("do")
		node.statements = self:ParseStatementsUntilEnd()
		node.tokens["end"] = self:ExpectToken("end", node.tokens["do"])
		node = self:EndNode(node)
		return node
	end

	do
		local function condition(token)
			return token:ValueEquals("until")
		end

		function META:ParseRepeatStatement()
			if not self:IsToken("repeat") then return false end

			local node = self:StartNode("statement_repeat")
			node.tokens["repeat"] = self:ExpectToken("repeat")
			node.statements = self:ParseStatementsUntilCondition(condition)
			node.tokens["until"] = self:ExpectToken("until")
			node.expression = self:ExpectRuntimeExpression()
			node = self:EndNode(node)
			return node
		end
	end

	function META:ParseSemicolonStatement()
		if not self:IsToken(";") then return false end

		local node = self:StartNode("statement_semicolon")
		node.tokens[";"] = self:ExpectToken(";")
		node = self:EndNode(node)
		return node
	end

	function META:ParseReturnStatement()
		if not self:IsToken("return") then return false end

		local node = self:StartNode("statement_return")
		node.tokens["return"] = self:ExpectToken("return")
		node.expressions = self:ParseMultipleValues(self.ParseRuntimeExpression, 0)
		node = self:EndNode(node)
		return node
	end

	function META:ParseWhileStatement()
		if not self:IsToken("while") then return false end

		local node = self:StartNode("statement_while")
		node.tokens["while"] = self:ExpectToken("while")
		node.expression = self:ExpectRuntimeExpression()
		node.tokens["do"] = self:ExpectToken("do")
		node.statements = self:ParseStatementsUntilEnd()
		node.tokens["end"] = self:ExpectToken("end", node.tokens["do"])
		node = self:EndNode(node)
		return node
	end

	function META:ParseContinueStatement()
		if not self:IsToken("continue") then return false end

		local node = self:StartNode("statement_continue")
		node.tokens["continue"] = self:ExpectToken("continue")
		node = self:EndNode(node)
		return node
	end

	do
		local needed = {
			{key = "bit", path = "nattlua.other.bit"},
			{key = "nl", path = "nattlua.init"},
			{key = "types", path = "nattlua.types.types"},
			{key = "context", path = "nattlua.analyzer.context"},
			{
				key = "error_messages",
				path = "nattlua.error_messages",
			},
		}
		local locals = ""

		for _, mod in ipairs(needed) do
			if _G.BUNDLE then
				locals = locals .. "local " .. mod.key .. "=IMPORTS[\"" .. mod.path .. "\"](\"" .. mod.path .. "\");"
			else
				locals = locals .. "local " .. mod.key .. "=require(\"" .. mod.path .. "\");"
			end
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

		local function invalid_function()
			error("invalid function")
		end

		function META:CompileLuaAnalyzerDebugCode(code, node, start_token, stop_token)
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
			local line

			if node.Code:GetString() then
				line = node.Code:SubPosToLineChar(node.code_start, node.code_stop).line_start
				code = ("\n"):rep(line - 1) .. code
			end

			local func, err = loadstring(code, node.Code:GetName() .. ":" .. line)

			if not func then
				self:Error("error compiling debug code: $1", start_token, stop_token, err)
				return invalid_function, code
			end

			return func, code
		end
	end

	function META:ParseDebugCodeStatement()
		if self:IsTokenType("analyzer_debug_code") then
			local node = self:StartNode("statement_analyzer_debug_code")
			node.lua_code = self:ParseValueExpressionType("analyzer_debug_code")
			node.compiled_function = self:CompileLuaAnalyzerDebugCode(node.lua_code.value:GetValueString():sub(3), node, node.lua_code.value, node.lua_code.value)
			node = self:EndNode(node)
			return node
		elseif self:IsTokenType("parser_debug_code") then
			local token = self:ExpectTokenType("parser_debug_code")
			assert(loadstring("local parser = ...;" .. token:GetValueString():sub(3)))(self)
			local node = self:StartNode("statement_parser_debug_code")
			local code = self:StartNode("expression_value")
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
				self:IsToken("local") and
				self:IsTokenOffset("type", 1) and
				runtime_syntax:GetTokenType(self:GetTokenOffset(2)) == "letter"
			)
		then
			return
		end

		local node = self:StartNode("statement_local_assignment")
		node.tokens["local"] = self:ExpectToken("local")
		node.tokens["type"] = self:ExpectToken("type")
		node.left = self:ParseMultipleValues(self.ParseIdentifier)
		node.environment = "typesystem"

		if self:IsToken("=") then
			node.tokens["="] = self:ExpectToken("=")
			self:PushParserEnvironment("typesystem")
			node.right = self:ParseMultipleValues(self.ExpectTypeExpression, 0)
			self:PopParserEnvironment()
		end

		node = self:EndNode(node)
		return node
	end

	function META:ParseTypeAssignmentStatement()
		if
			not (
				self:IsToken("type") and
				(
					self:IsTokenTypeOffset("letter", 1) or
					self:IsTokenOffset("^", 1)
				)
			)
		then
			return
		end

		local node = self:StartNode("statement_assignment")
		node.tokens["type"] = self:ExpectToken("type")
		node.left = self:ParseMultipleValues(self.ExpectTypeExpression, 0)
		node.environment = "typesystem"

		if self:IsToken("=") then
			node.tokens["="] = self:ExpectToken("=")
			self:PushParserEnvironment("typesystem")
			node.right = self:ParseMultipleValues(self.ExpectTypeExpression, 0)
			self:PopParserEnvironment()
		end

		node = self:EndNode(node)
		return node
	end

	function META:ParseCallOrAssignmentStatement()
		local start = self:GetToken()
		self:SuppressOnNode()
		local left = self:ParseMultipleValues(self.ExpectRuntimeExpression, 0)

		if
			(
				self:IsToken("+") or
				self:IsToken("-") or
				self:IsToken("*") or
				self:IsToken("/") or
				self:IsToken("%") or
				self:IsToken("^") or
				self:IsToken("..")
			) and
			self:IsTokenOffset("=", 1)
		then
			-- roblox compound assignment
			local op_token = self:ParseToken()
			local eq_token = self:ParseToken()
			local bop = self:StartNode("expression_binary_operator")
			bop.left = left[1]
			bop.value = op_token
			bop.right = self:ExpectRuntimeExpression(0)
			self:EndNode(bop)
			local node = self:StartNode("statement_assignment", left[1])
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

		if self:IsToken("=") then
			local node = self:StartNode("statement_assignment", left[1])
			node.tokens["="] = self:ExpectToken("=")
			node.left = left

			for i, v in ipairs(node.left) do
				v.is_left_assignment = true
			end

			node.right = self:ParseMultipleValues(self.ExpectRuntimeExpression, 0)
			self:ReRunOnNode(node.left)
			node = self:EndNode(node)
			return node
		end

		if left[1] and (left[1].Type == "expression_postfix_call") and not left[2] then
			local node = self:StartNode("statement_call_expression", left[1])
			node.value = left[1]
			node.tokens = left[1].tokens
			self:ReRunOnNode(left)
			node = self:EndNode(node)
			return node
		end

		self:Error(
			"expected assignment or call expression got $1",
			start,
			self:GetToken(),
			self:GetToken().type
		)

		if left and left[1] and left[1].Type ~= "expression_postfix_call" then
			local node = self:StartNode("statement_call_expression", left[1])
			node.value = left[1]
			node = self:EndNode(node)
			return node
		end

		return self:ErrorStatement()
	end
end
