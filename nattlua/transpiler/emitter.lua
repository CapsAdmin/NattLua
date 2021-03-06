local syntax = require("nattlua.syntax.syntax")
local tostring = _G.tostring
local error = _G.error
local pairs = _G.pairs
local print = _G.print
local ipairs = _G.ipairs
local assert = _G.assert
local table = require("table")
local setmetatable = _G.setmetatable
local B = string.byte
local META = {}
META.__index = META
require("nattlua.transpiler.base_emitter")(META)

function META:OptionalWhitespace()
	if self.config.preserve_whitespace == nil then return end

	if syntax.IsLetter(self:GetPrevChar()) or syntax.IsNumber(self:GetPrevChar()) then
		self:EmitSpace(" ")
	end
end

function META:EmitStringToken(token)
	if self.config.string_quote then
		local current = token.value:sub(1, 1)
		local target = self.config.string_quote

		if current == "\"" or current == "\'" then
			local contents = token.value:sub(2, -2)
			contents = contents:gsub("([\\])" .. current, current)
			contents = contents:gsub("([\\])" .. target, target)
			contents = contents:gsub(target, "\\" .. target)
			self:EmitToken(token, target .. contents .. target)
		else
			self:EmitToken(token)
		end
	else
		self:EmitToken(token)
	end
end

function META:EmitNumberToken(token)
	self:EmitToken(token)
end

function META:EmitExpression(node, from_assignment)
	if not node then
		print(debug.traceback())
	end

	local pushed = false

	if node.tokens["("] then
		for _, node in ipairs(node.tokens["("]) do
			self:EmitToken(node)
		end

		if node.tokens["("] then
			if node:GetLength() < 100 then
				self:PushForceNewlines(false)
				pushed = true
			else
				self:Indent()
				self:Whitespace("\n")
				self:Whitespace("\t")
			end
		end
	end

	if node.kind == "binary_operator" then
		self:EmitBinaryOperator(node)
	elseif node.kind == "function" then
		self:EmitAnonymousFunction(node)
	elseif node.kind == "type_function" then
		self:EmitInvalidLuaCode("EmitTypeFunction", node)
	elseif node.kind == "table" then
		self:EmitTable(node)
	elseif node.kind == "prefix_operator" then
		self:EmitPrefixOperator(node)
	elseif node.kind == "postfix_operator" then
		self:EmitPostfixOperator(node)
	elseif node.kind == "postfix_call" then
		if node.type_call then
			self:EmitInvalidLuaCode("EmitCall", node)
		else
			self:EmitCall(node)
		end
	elseif node.kind == "postfix_expression_index" then
		self:EmitExpressionIndex(node)
	elseif node.kind == "value" then
		if node.tokens["is"] then
			self:EmitToken(node.value, tostring(node.result_is))
		else
			if node.value.type == "string" then
				self:EmitStringToken(node.value)
			elseif node.value.type == "number" then
				self:EmitNumberToken(node.value)
			else
				self:EmitToken(node.value)
			end
		end
	elseif node.kind == "import" then
		self:EmitImportExpression(node)
	elseif node.kind == "type_table" then
		self:EmitTableType(node)
	elseif node.kind == "table_expression_value" then
		self:EmitTableExpressionValue(node)
	elseif node.kind == "table_key_value" then
		self:EmitTableKeyValue(node)
	else
		error("unhandled token type " .. node.kind)
	end

	if pushed then
		self:PopForceNewlines()
	elseif node.tokens[")"] then
		self:Outdent()
		self:Whitespace("\n")
		self:Whitespace("\t")
	end

	if node.tokens[")"] then
		for _, node in ipairs(node.tokens[")"]) do
			self:EmitToken(node)
		end
	end

	if self.config.annotate and node.tokens["as"] then
		self:EmitInvalidLuaCode("EmitAsAnnotationExpression", node)
	end
end

function META:EmitVarargTuple(node)
	self:Emit(tostring(node.inferred_type))
end

function META:EmitExpressionIndex(node)
	self:EmitExpression(node.left)
	self:EmitToken(node.tokens["["])
	self:EmitExpression(node.expression)
	self:EmitToken(node.tokens["]"])
end

function META:PushForceNewlines(b)
	self.force_newlines = self.force_newlines or {}
	table.insert(self.force_newlines, b)
end

function META:PopForceNewlines()
	table.remove(self.force_newlines)
end

function META:IsForcingNewlines()
	return self.force_newlines and self.force_newlines[#self.force_newlines]
end

function META:EmitBreakableExpressionList(list, first_newline)
	local newlines = self:ShouldBreakExpressionList(list)

	if newlines then
		self:Indent()
		self:PushForceNewlines(true)

		if first_newline then
			self:Whitespace("\n")
			self:Whitespace("\t")
		end
	end

	self:EmitExpressionList(list)

	if newlines then
		self:Outdent()
        --self:Whitespace("\n")
--        self:Whitespace("\t")
        self:PopForceNewlines()
	end

	return newlines
end

function META:EmitCall(node)
    -- this will not work for calls with functions that contain statements
    self.inside_call_expression = true
	self:EmitExpression(node.left)

	if node.tokens["call("] then
		self:EmitToken(node.tokens["call("])
	else
		if self.config.force_parenthesis then
			self:EmitNonSpace("(")
		end
	end

	local newlines = self:ShouldBreakExpressionList(node.expressions)

	if not newlines then
		self:PushForceNewlines(false)
	end

	self:EmitBreakableExpressionList(node.expressions, true)

	if not newlines then
		self:PopForceNewlines()
	end

	if node.tokens["call)"] then
		if newlines then
			self:Whitespace("\n")
			self:Whitespace("\t")
		end

		self:EmitToken(node.tokens["call)"])
	else
		if self.config.force_parenthesis then
			if newlines then
				self:Whitespace("\n")
				self:Whitespace("\t")
			end

			self:EmitNonSpace(")")
		end
	end

	self.inside_call_expression = false
end

function META:EmitBinaryOperator(node)
	local func_chunks = node.environment == "runtime" and syntax.GetFunctionForBinaryOperator(node.value)

	if func_chunks then
		self:Emit(func_chunks[1])

		if node.left then
			self:EmitExpression(node.left)
		end

		self:Emit(func_chunks[2])

		if node.right then
			self:EmitExpression(node.right)
		end

		self:Emit(func_chunks[3])
		self.operator_transformed = true
	else
		if node.left then
			self:EmitExpression(node.left)
		end

		if node.value.value == "." or node.value.value == ":" then
			if node:GetLength() > 100 then
				self:Whitespace("\n")
				self:Whitespace("\t")
			end

			self:EmitToken(node.value)
		elseif node.value.value == "and" or node.value.value == "or" then
			self:Whitespace(" ")
			self:EmitToken(node.value)

			if node.right then
				if self:IsForcingNewlines() or node:GetLength() > 100 then
					self:Whitespace("\n")
					self:Whitespace("\t")
				else
					self:Whitespace(" ")
				end
			end
		else
			self:Whitespace(" ")
			self:EmitToken(node.value)
			self:Whitespace(" ")
		end

		if node.right then
			self:EmitExpression(node.right)
		end
	end
end

do
	local function emit_function_body(self, node, type_function)
		self:EmitToken(node.tokens["arguments("])
		self:EmitIdentifierList(node.identifiers)
		self:EmitToken(node.tokens["arguments)"])
		self:EmitFunctionReturnAnnotation(node)

		if node.statements then
			self:PushForceNewlines(false)

			if #node.statements > 0 then
				self:Whitespace("\n")
			end

			if #node.statements == 0 then
				self:Whitespace(" ")
			end

			self:EmitBlock(node.statements)
			self:PopForceNewlines()
			self:Whitespace("\n")
			self:Whitespace("\t")
			self:EmitToken(node.tokens["end"])
		end
	end

	function META:EmitAnonymousFunction(node)
		self:EmitToken(node.tokens["function"])
		emit_function_body(self, node)
	end

	function META:EmitLocalFunction(node)
		self:Whitespace("\t")
		self:EmitToken(node.tokens["local"])
		self:Whitespace(" ")
		self:EmitToken(node.tokens["function"])
		self:Whitespace(" ")
		self:EmitToken(node.tokens["identifier"])
		emit_function_body(self, node)
	end

	function META:EmitLocalTypeFunction(node)
		self:Whitespace("\t")
		self:EmitToken(node.tokens["local"])
		self:Whitespace(" ")
		self:EmitToken(node.tokens["type"])
		self:Whitespace(" ")
		self:EmitToken(node.tokens["function"])
		self:Whitespace(" ")
		self:EmitToken(node.tokens["identifier"])
		emit_function_body(self, node)
	end

	function META:EmitLocalGenericsTypeFunction(node)
		self:Whitespace("\t")
		self:EmitToken(node.tokens["local"])
		self:Whitespace(" ")
		self:EmitToken(node.tokens["function"])
		self:Whitespace(" ")
		self:EmitToken(node.tokens["identifier"])
		emit_function_body(self, node, true)
	end

	function META:EmitGenericsTypeFunction(node)
		self:Whitespace("\t")
		self:EmitToken(node.tokens["function"])
		self:Whitespace(" ")
		self:EmitExpression(node.expression or node.identifier)
		emit_function_body(self, node, true)
	end

	function META:EmitFunction(node)
		self:Whitespace("\t")

		if node.tokens["local"] then
			self:EmitToken(node.tokens["local"])
			self:Whitespace(" ")
		end

		self:EmitToken(node.tokens["function"])
		self:Whitespace(" ")
		self:EmitExpression(node.expression or node.identifier)
		emit_function_body(self, node)
	end

	function META:EmitTypeFunctionStatement(node)
		self:Whitespace("\t")

		if node.tokens["local"] then
			self:EmitToken(node.tokens["local"])
			self:Whitespace(" ")
		end

		if node.tokens["type"] then
			self:EmitToken(node.tokens["type"])
			self:Whitespace(" ")
		end

		self:EmitToken(node.tokens["function"])
		self:Whitespace(" ")

		if node.tokens["^"] then
			self:EmitToken(node.tokens["^"])
		end

		if node.expression or node.identifier then
			self:EmitExpression(node.expression or node.identifier)
		end

		emit_function_body(self, node)
	end
end

function META:EmitTableExpressionValue(node)
	self:EmitToken(node.tokens["["])
	self:EmitExpression(node.key_expression)
	self:EmitToken(node.tokens["]"])
	self:Whitespace(" ")
	self:EmitToken(node.tokens["="])
	self:Whitespace(" ")
	self:EmitExpression(node.value_expression)
end

function META:EmitTableKeyValue(node)
	self:EmitToken(node.tokens["identifier"])
	self:Whitespace(" ")
	self:EmitToken(node.tokens["="])
	self:Whitespace(" ")
	self:EmitExpression(node.value_expression)
end

local function has_function_value(tree)
	for _, exp in ipairs(tree.children) do
		if exp.expression and exp.expression.kind == "function" then return true end
	end

	return false
end

function META:EmitTable(tree)
	if tree.spread then
		self:EmitNonSpace("table.mergetables")
	end

	local during_spread = false
	self:EmitToken(tree.tokens["{"])
	local newline = tree:GetLength() > 50 or has_function_value(tree)

	if newline then
		self:Indent()
		self:Whitespace("\n")
	end

	if tree.children[1] then
		for i, node in ipairs(tree.children) do
			if newline then
				self:Whitespace("\t")
			end

			if node.kind == "table_index_value" then
				if node.spread then
					if during_spread then
						self:EmitNonSpace("},")
						during_spread = false
					end

					self:EmitExpression(node.spread.expression)
				else
					self:EmitExpression(node.value_expression)
				end
			elseif node.kind == "table_key_value" then
				if tree.spread and not during_spread then
					during_spread = true
					self:EmitNonSpace("{")
				end

				self:EmitTableKeyValue(node)
			elseif node.kind == "table_expression_value" then
				self:EmitTableExpressionValue(node)
			end

			if tree.tokens["separators"][i] then
				self:EmitToken(tree.tokens["separators"][i])
			else
				if newline then
					self:EmitNonSpace(",")
				end
			end

			if newline then
				self:Whitespace("\n")
			else
				if i ~= #tree.children then
					self:Whitespace(" ")
				end
			end
		end
	end

	if during_spread then
		self:EmitNonSpace("}")
	end

	if newline then
		self:Outdent()
		self:Whitespace("\t")
	end

	self:EmitToken(tree.tokens["}"])
end

function META:EmitPrefixOperator(node)
	local func_chunks = node.environment == "runtime" and syntax.GetFunctionForPrefixOperator(node.value)

	if self.TranslatePrefixOperator then
		func_chunks = self:TranslatePrefixOperator(node) or func_chunks
	end

	if func_chunks then
		self:Emit(func_chunks[1])
		self:EmitExpression(node.right)
		self:Emit(func_chunks[2])
		self.operator_transformed = true
	else
		if syntax.IsKeyword(node.value) or syntax.IsNonStandardKeyword(node.value) then
			self:OptionalWhitespace()
			self:EmitToken(node.value)
			self:OptionalWhitespace()
			self:EmitExpression(node.right)
		else
			self:EmitToken(node.value)
			self:OptionalWhitespace()
			self:EmitExpression(node.right)
		end
	end
end

function META:EmitPostfixOperator(node)
	local func_chunks = node.environment == "runtime" and syntax.GetFunctionForPostfixOperator(node.value)

    -- no such thing as postfix operator in lua,
    -- so we have to assume that there's a translation
    assert(func_chunks)
	self:Emit(func_chunks[1])
	self:EmitExpression(node.left)
	self:Emit(func_chunks[2])
	self.operator_transformed = true
end

function META:EmitBlock(statements)
	self:Whitespace("\t+")
	self:EmitStatements(statements)
	self:Whitespace("\t-")
end

local function is_short_statement(kind)
	return kind == "return" or kind == "break" or kind == "continue"
end

function META:IsShortIfStatement(node)
	return
		#node.statements == 1 and
		node.statements[1][1] and
		is_short_statement(node.statements[1][1].kind) and
		not self:ShouldBreakExpressionList({node.expressions[1]})
end

function META:EmitIfStatement(node)
	if self:IsShortIfStatement(node) then
		self:Whitespace("\t")
		self:EmitToken(node.tokens["if/else/elseif"][1])
		self:Whitespace(" ")
		self:EmitExpression(node.expressions[1], true)
		self:Whitespace(" ")
		self:EmitToken(node.tokens["then"][1])
		self:Whitespace(" ")

		if node.statements[1][1].kind == "return" then
			self:EmitReturnStatement(node.statements[1][1], true)
		elseif node.statements[1][1].kind == "break" then
			self:EmitBreakStatement(node.statements[1][1], true)
		elseif node.statements[1][1].kind == "continue" then
			self:EmitContinueStatement(node.statements[1][1], true)
		end

		self:Whitespace(" ")
		self:EmitToken(node.tokens["end"])
		return
	end

	for i = 1, #node.statements do
		if i == 1 then
			self:Whitespace("\t")
		end

		if node.expressions[i] then
			if i > 1 then
				self:Whitespace("\n")
				self:Whitespace("\t")
			end

			self:EmitToken(node.tokens["if/else/elseif"][i])
			local newlines = self:ShouldBreakExpressionList({node.expressions[i]})

			if newlines then
				self:Indent()
				self:PushForceNewlines(true)
				self:Whitespace("\n")
				self:Whitespace("\t")
			else
				self:Whitespace(" ")
			end

			self:EmitExpression(node.expressions[i], true)

			if newlines then
				self:Outdent()
				self:Whitespace("\n")
				self:Whitespace("\t")
				self:PopForceNewlines()
			else
				self:Whitespace(" ")
			end

			self:EmitToken(node.tokens["then"][i])
		elseif node.tokens["if/else/elseif"][i] then
			self:Whitespace("\n")
			self:Whitespace("\t")
			self:EmitToken(node.tokens["if/else/elseif"][i])
		end

		self:Whitespace("\n")
		self:EmitBlock(node.statements[i])
	end

	self:Whitespace("\n")
	self:Whitespace("\t")
	self:EmitToken(node.tokens["end"])
end

function META:EmitGenericForStatement(node)
	self:Whitespace("\t")
	self:EmitToken(node.tokens["for"])
	self:Whitespace(" ")
	self:EmitIdentifierList(node.identifiers)
	self:Whitespace(" ")
	self:EmitToken(node.tokens["in"])
	self:Whitespace(" ")
	self:EmitExpressionList(node.expressions)
	self:Whitespace(" ")
	self:EmitToken(node.tokens["do"])
	self:Whitespace("\n")
	self:EmitBlock(node.statements)
	self:Whitespace("\n")
	self:Whitespace("\t")
	self:EmitToken(node.tokens["end"])
end

function META:EmitNumericForStatement(node)
	self:Whitespace("\t")
	self:EmitToken(node.tokens["for"])
	self:Whitespace(" ")
	self:EmitIdentifierList(node.identifiers)
	self:Whitespace(" ")
	self:EmitToken(node.tokens["="])
	self:Whitespace(" ")
	self:EmitExpressionList(node.expressions)
	self:Whitespace(" ")
	self:EmitToken(node.tokens["do"])
	self:Whitespace("\n")
	self:EmitBlock(node.statements)
	self:Whitespace("\n")
	self:Whitespace("\t")
	self:EmitToken(node.tokens["end"])
end

function META:EmitWhileStatement(node)
	self:Whitespace("\t")
	self:EmitToken(node.tokens["while"])
	self:Whitespace(" ")
	self:EmitExpression(node.expression)
	self:Whitespace(" ")
	self:EmitToken(node.tokens["do"])
	self:Whitespace("\n")
	self:EmitBlock(node.statements)
	self:Whitespace("\n")
	self:Whitespace("\t")
	self:EmitToken(node.tokens["end"])
end

function META:EmitRepeatStatement(node)
	self:Whitespace("\t")
	self:EmitToken(node.tokens["repeat"])
	self:Whitespace("\n")
	self:EmitBlock(node.statements)
	self:Whitespace("\t")
	self:EmitToken(node.tokens["until"])
	self:Whitespace(" ")
	self:EmitExpression(node.expression)
end

function META:EmitLabelStatement(node)
	self:Whitespace("\t")
	self:EmitToken(node.tokens["::"][1])
	self:EmitToken(node.tokens["identifier"])
	self:EmitToken(node.tokens["::"][2])
end

function META:EmitGotoStatement(node)
	self:Whitespace("\t")
	self:EmitToken(node.tokens["goto"])
	self:Whitespace(" ")
	self:EmitToken(node.tokens["identifier"])
end

function META:EmitBreakStatement(node, no_tab)
	if not no_tab then
		self:Whitespace("\t")
	end

	self:EmitToken(node.tokens["break"])
end

function META:EmitContinueStatement(node, no_tab)
	if not no_tab then
		self:Whitespace("\t")
	end

	self:EmitToken(node.tokens["continue"])
end

function META:EmitDoStatement(node)
	self:Whitespace("\t")
	self:EmitToken(node.tokens["do"])
	self:Whitespace("\n")
	self:EmitBlock(node.statements)
	self:Whitespace("\n")
	self:Whitespace("\t")
	self:EmitToken(node.tokens["end"])
end

function META:EmitReturnStatement(node, no_tab)
	if not no_tab then
		self:Whitespace("\t")
	end

	self:EmitToken(node.tokens["return"])

	if node.expressions[1] then
		if not self:ShouldBreakExpressionList(node.expressions) then
			self:Whitespace(" ")
		end

		self:EmitBreakableExpressionList(node.expressions, true)
	end
end

function META:EmitSemicolonStatement(node)
	if self.config.no_semicolon then
		self:EmitToken(node.tokens[";"], "")
	else
		self:EmitToken(node.tokens[";"])
	end
end

function META:EmitLocalAssignment(node)
	self:Whitespace("\t")
	self:EmitToken(node.tokens["local"])

	if node.environment == "typesystem" then
		self:Whitespace(" ")
		self:EmitToken(node.tokens["type"])
	end

	self:Whitespace(" ")
	self:EmitIdentifierList(node.left)

	if node.tokens["="] then
		self:Whitespace(" ")
		self:EmitToken(node.tokens["="])
		self:Whitespace(" ")
		self:EmitBreakableExpressionList(node.right)
	end
end

function META:EmitAssignment(node)
	self:Whitespace("\t")

	if node.environment == "typesystem" then
		self:EmitToken(node.tokens["type"])
		self:Whitespace(" ")
	end

	self:EmitExpressionList(node.left, nil, true)

	if node.tokens["="] then
		self:Whitespace(" ")
		self:EmitToken(node.tokens["="])
		self:Whitespace(" ")
		self:EmitBreakableExpressionList(node.right)
	end
end

function META:EmitStatement(node)
	if node.kind == "if" then
		self:EmitIfStatement(node)
	elseif node.kind == "goto" then
		self:EmitGotoStatement(node)
	elseif node.kind == "goto_label" then
		self:EmitLabelStatement(node)
	elseif node.kind == "while" then
		self:EmitWhileStatement(node)
	elseif node.kind == "repeat" then
		self:EmitRepeatStatement(node)
	elseif node.kind == "break" then
		self:EmitBreakStatement(node)
	elseif node.kind == "return" then
		self:EmitReturnStatement(node)
	elseif node.kind == "numeric_for" then
		self:EmitNumericForStatement(node)
	elseif node.kind == "generic_for" then
		self:EmitGenericForStatement(node)
	elseif node.kind == "do" then
		self:EmitDoStatement(node)
	elseif node.kind == "type_function" then
		self:EmitInvalidLuaCode("EmitTypeFunctionStatement", node)
	elseif node.kind == "function" then
		self:EmitFunction(node)
	elseif node.kind == "local_function" then
		self:EmitLocalFunction(node)
	elseif node.kind == "local_type_function" then
		self:EmitLocalTypeFunction(node)
	elseif node.kind == "local_generics_type_function" then
		self:EmitInvalidLuaCode("EmitLocalGenericsTypeFunction", node)
	elseif node.kind == "generics_type_function" then
		self:EmitInvalidLuaCode("EmitGenericsTypeFunction", node)
	elseif
		node.kind == "destructure_assignment" or
		node.kind == "local_destructure_assignment"
	then
		if self.config.use_comment_types then
			self:EmitInvalidLuaCode("EmitDestructureAssignment", node)
		else
			self:EmitTranspiledDestructureAssignment(node)
		end
	elseif node.kind == "assignment" then
		if node.environment == "typesystem" and self.config.use_comment_types then
			self:EmitInvalidLuaCode("EmitAssignment", node)
		else
			self:EmitAssignment(node)
		end

		self:Emit_ENVFromAssignment(node)
	elseif node.kind == "local_assignment" then
		if node.environment == "typesystem" then
			self:EmitInvalidLuaCode("EmitLocalAssignment", node)
		else
			self:EmitLocalAssignment(node)
		end
	elseif node.kind == "import" then
		self:EmitNonSpace("local")
		self:EmitSpace(" ")
		self:EmitIdentifierList(node.left)
		self:EmitSpace(" ")
		self:EmitNonSpace("=")
		self:EmitSpace(" ")
		self:EmitImportExpression(node)
	elseif node.kind == "call_expression" then
		self:Whitespace("\t")
		self:EmitExpression(node.value)
	elseif node.kind == "shebang" then
		self:EmitToken(node.tokens["shebang"])
	elseif node.kind == "continue" then
		self:EmitContinueStatement(node)
	elseif node.kind == "semicolon" then
		self:EmitSemicolonStatement(node)

		if self.config.preserve_whitespace == false then
			if self.out[self.i - 2] and self.out[self.i - 2] == "\n" then
				self.out[self.i - 2] = ""
			end
		end
	elseif node.kind == "end_of_file" then
		self:EmitToken(node.tokens["end_of_file"])
	elseif node.kind == "root" then
		self:EmitStatements(node.statements)
	elseif node.kind == "type_code" then
		self:EmitNonSpace("--" .. node.lua_code.value.value)
	elseif node.kind == "parser_code" then
		self:EmitNonSpace("--" .. node.lua_code.value.value)
	elseif node.kind then
		error("unhandled statement: " .. node.kind)
	else
		for k, v in pairs(node) do
			print(k, v)
		end

		error("invalid statement: " .. tostring(node))
	end

	if self.OnEmitStatement then
		if node.kind ~= "end_of_file" then
			self:OnEmitStatement()
		end
	end
end

local function general_kind(self, node)
	if node.kind == "call_expression" then
		for i, v in ipairs(node.value.expressions) do
			if v.kind == "function" then return "other" end
		end
	end

	if node.kind == "if" then
		if self:IsShortIfStatement(node) then return "expression_statement" end
	end

	if
		node.kind == "call_expression" or
		node.kind == "local_assignment" or
		node.kind == "assignment" or
		node.kind == "return"
	then
		return "expression_statement"
	end

	return "other"
end

local function find_previous(statements, i)
	while true do
		if not statements[i] then return end
		if statements[i].kind ~= "semicolon" then return statements[i] end
		i = i - 1
	end
end

function META:EmitStatements(tbl)
	for i, node in ipairs(tbl) do
		if i > 1 and general_kind(self, node) == "other" and node.kind ~= "end_of_file" then
			self:Whitespace("\n")
		end

		self:EmitStatement(node)

		if
			node.kind ~= "semicolon" and
			node.kind ~= "end_of_file" and
			tbl[i + 1] and
			tbl[i + 1].kind ~= "end_of_file"
		then
			self:Whitespace("\n")
		end

		if general_kind(self, node) == "other" then
			if tbl[i + 1] and general_kind(self, tbl[i + 1]) == "expression_statement" then
				self:Whitespace("\n")
			end
		end
	end
end

function META:ShouldBreakExpressionList(tbl)
	if self.config.preserve_whitespace == false then
        -- more than 5 arguments, always break everything into newline call
        if #tbl > 5 then
			return true
		else
			local total_length = 0

			for _, exp in ipairs(tbl) do
				local length = exp:GetLength()
				total_length = total_length + length
				if total_length > 75 then return true end
			end
		end
	end

	return false
end

function META:EmitExpressionList(tbl, delimiter, from_assignment)
	for i = 1, #tbl do
		if i > 1 and self:IsForcingNewlines() then
			self:Whitespace("\n")
			self:Whitespace("\t")
		end

		local pushed = false

		if self:IsForcingNewlines() then
			if tbl[i]:GetLength() < 50 then
				self:PushForceNewlines(false)
				pushed = true
			end
		end

		self:EmitExpression(tbl[i], from_assignment)

		if pushed then
			self:PopForceNewlines()
		end

		if i ~= #tbl then
			self:EmitToken(tbl[i].tokens[","], delimiter)

			if not self:IsForcingNewlines() then
				self:Whitespace(" ")
			end
		end
	end
end

function META:HasTypeNotation(node)
	return node.as_expression or node.inferred_type or node.return_types
end

function META:EmitFunctionReturnAnnotationExpression(node, type_function)
	if node.tokens[":"] then
		self:EmitToken(node.tokens[":"])
	else
		self:EmitNonSpace(":")
	end

	self:Whitespace(" ")

	if node.return_types then
		for i, exp in ipairs(node.return_types) do
			self:EmitTypeExpression(exp)

			if i ~= #node.return_types then
				self:EmitToken(exp.tokens[","])
			end
		end
	elseif node.inferred_type and self.config.annotate ~= "explicit" then
		local str = {}

        -- this iterates the first return tuple
        local obj = node.inferred_type:GetContract() or node.inferred_type

		if obj.Type == "function" then
			for i, v in ipairs(obj:GetReturnTypes():GetData()) do
				str[i] = tostring(v)
			end
		else
			str[1] = tostring(obj)
		end

		if str[1] then
			self:EmitNonSpace(table.concat(str, ", "))
		end
	end
end

function META:EmitFunctionReturnAnnotation(node, type_function)
	if not self.config.annotate then return end

	if self:HasTypeNotation(node) then
		self:EmitInvalidLuaCode("EmitFunctionReturnAnnotationExpression", node, type_function)
	end
end

function META:EmitAnnotationExpression(node)
	if node.as_expression then
		self:EmitTypeExpression(node.as_expression)
	elseif node.inferred_type and self.config.annotate ~= "explicit" then
		self:Emit(tostring(node.inferred_type:GetContract() or node.inferred_type))
	end
end

function META:EmitAsAnnotationExpression(node)
	self:OptionalWhitespace()
	self:Whitespace(" ")
	self:EmitToken(node.tokens["as"])
	self:Whitespace(" ")
	self:EmitAnnotationExpression(node)
end

function META:EmitColonAnnotationExpression(node)
	if node.tokens[":"] then
		self:EmitToken(node.tokens[":"])
	else
		self:EmitNonSpace(":")
	end

	self:Whitespace(" ")
	self:EmitAnnotationExpression(node)
end

function META:EmitAnnotation(node)
	if not self.config.annotate then return end

	if self:HasTypeNotation(node) and not node.tokens["as"] then
		self:EmitInvalidLuaCode("EmitColonAnnotationExpression", node)
	end
end

function META:EmitIdentifier(node)
	self:EmitToken(node.value)
	self:EmitAnnotation(node)
end

function META:EmitIdentifierList(tbl)
	for i = 1, #tbl do
		self:EmitIdentifier(tbl[i])

		if i ~= #tbl then
			self:EmitToken(tbl[i].tokens[","])
			self:Whitespace(" ")
		end
	end
end

do -- types
    function META:EmitTypeBinaryOperator(node)
		if node.left then
			self:EmitTypeExpression(node.left)
		end

		if node.value.value == "." or node.value.value == ":" then
			self:EmitToken(node.value)
		else
			self:Whitespace(" ")
			self:EmitToken(node.value)
			self:Whitespace(" ")
		end

		if node.right then
			self:EmitTypeExpression(node.right)
		end
	end

	function META:EmitType(node)
		self:EmitToken(node.value)
		self:EmitAnnotation(node)
	end

	function META:EmitTableType(node)
		local tree = node
		self:EmitToken(tree.tokens["{"])
		local newline = tree:GetLength() > 50 or has_function_value(tree)

		if newline then
			self:Indent()
			self:Whitespace("\n")
		end

		if tree.children[1] then
			for i, node in ipairs(tree.children) do
				if newline then
					self:Whitespace("\t")
				end

				if node.kind == "table_index_value" then
					self:EmitTypeExpression(node.value_expression)
				elseif node.kind == "table_key_value" then
					self:EmitToken(node.tokens["identifier"])
					self:Whitespace(" ")
					self:EmitToken(node.tokens["="])
					self:Whitespace(" ")
					self:EmitTypeExpression(node.value_expression)
				elseif node.kind == "table_expression_value" then
					self:EmitToken(node.tokens["["])
					self:EmitTypeExpression(node.key_expression)
					self:EmitToken(node.tokens["]"])
					self:Whitespace(" ")
					self:EmitToken(node.tokens["="])
					self:Whitespace(" ")
					self:EmitTypeExpression(node.value_expression)
				end

				if tree.tokens["separators"][i] then
					self:EmitToken(tree.tokens["separators"][i])
				else
					if newline then
						self:EmitNonSpace(",")
					end
				end

				if newline then
					self:Whitespace("\n")
				else
					if i ~= #tree.children then
						self:Whitespace(" ")
					end
				end
			end
		end

		if newline then
			self:Outdent()
			self:Whitespace("\t")
		end

		self:EmitToken(tree.tokens["}"])
	end

	function META:EmitTypeFunction(node)
		if not self.config.lua_type_function then
			if node.tokens["type"] then
				self:Whitespace(" ")
				self:EmitToken(node.tokens["type"])
			end
		end

		self:EmitToken(node.tokens["function"])

		if not self.config.lua_type_function then
			if node.tokens["^"] then
				self:EmitToken(node.tokens["^"])
			end
		end

		self:EmitToken(node.tokens["arguments("])

		for i, exp in ipairs(node.identifiers) do
			if not self.config.annotate and node.statements then
				if exp.identifier then
					self:EmitToken(exp.identifier)
				else
					self:EmitTypeExpression(exp)
				end
			else
				if exp.identifier then
					self:EmitToken(exp.identifier)
					self:EmitToken(exp.tokens[":"])
					self:Whitespace(" ")
				end

				self:EmitTypeExpression(exp)
			end

			if i ~= #node.identifiers then
				if exp.tokens[","] then
					self:EmitToken(exp.tokens[","])
					self:Whitespace(" ")
				end
			end
		end

		self:EmitToken(node.tokens["arguments)"])

		if node.tokens[":"] then
			self:EmitToken(node.tokens[":"])
			self:Whitespace(" ")

			for i, exp in ipairs(node.return_types) do
				self:EmitTypeExpression(exp)

				if i ~= #node.return_types then
					self:EmitToken(exp.tokens[","])
					self:Whitespace(" ")
				end
			end
		else
			if node.statements then
				self:Whitespace("\n")
				self:EmitBlock(node.statements)
				self:Whitespace("\n")
				self:Whitespace("\t")
				self:EmitToken(node.tokens["end"])
			end
		end
	end

	function META:EmitTypeExpression(node)
		if node.tokens["("] then
			for _, node in ipairs(node.tokens["("]) do
				self:EmitToken(node)
			end
		end

		if node.kind == "binary_operator" then
			self:EmitTypeBinaryOperator(node)
		elseif node.kind == "type_function" then
			self:EmitInvalidLuaCode("EmitTypeFunction", node)
		elseif node.kind == "table" then
			self:EmitTable(node)
		elseif node.kind == "prefix_operator" then
			self:EmitPrefixOperator(node)
		elseif node.kind == "postfix_operator" then
			self:EmitPostfixOperator(node)
		elseif node.kind == "postfix_call" then
			if node.type_call then
				self:EmitInvalidLuaCode("EmitCall", node)
			else
				self:EmitCall(node)
			end
		elseif node.kind == "postfix_expression_index" then
			self:EmitExpressionIndex(node)
		elseif node.kind == "value" then
			self:EmitToken(node.value)
		elseif node.kind == "type_table" then
			self:EmitTableType(node)
		elseif node.kind == "table_expression_value" then
			self:EmitTableExpressionValue(node)
		elseif node.kind == "table_key_value" then
			self:EmitTableKeyValue(node)
		else
			error("unhandled token type " .. node.kind)
		end

		if not self.config.lua_type_function then
			if node.as_expression then
				self:EmitTypeExpression(node.as_expression)
			end
		end

		if node.tokens[")"] then
			for _, node in ipairs(node.tokens[")"]) do
				self:EmitToken(node)
			end
		end
	end

	function META:EmitInvalidLuaCode(func, ...)
		local emitted = false

		if not self.config.uncomment_types then
			if not self.during_comment_type or self.during_comment_type == 0 then
				self:EmitNonSpace("--[[#")
				emitted = true
			end

			self.during_comment_type = self.during_comment_type or 0
			self.during_comment_type = self.during_comment_type + 1
		end

		self[func](self, ...)

		if emitted then
			if self:GetPrevChar() == B("]") then
				self:Whitespace(" ")
			end

			self:EmitNonSpace("]]")
		end

		if not self.config.uncomment_types then
			self.during_comment_type = self.during_comment_type - 1
		end
	end
end

do -- extra
    function META:EmitTranspiledDestructureAssignment(node)
		self:Whitespace("\t")
		self:EmitToken(node.tokens["{"], "")

		if node.default then
			self:EmitToken(node.default.value)
			self:EmitToken(node.default_comma)
		end

		self:EmitToken(node.tokens["{"], "")
		self:Whitespace(" ")
		self:EmitIdentifierList(node.left)
		self:EmitToken(node.tokens["}"], "")
		self:Whitespace(" ")
		self:EmitToken(node.tokens["="])
		self:Whitespace(" ")
		self:EmitNonSpace("table.destructure(")
		self:EmitExpression(node.right)
		self:EmitNonSpace(",")
		self:EmitSpace(" ")
		self:EmitNonSpace("{")

		for i, v in ipairs(node.left) do
			self:EmitNonSpace("\"")
			self:Emit(v.value.value)
			self:EmitNonSpace("\"")

			if i ~= #node.left then
				self:EmitNonSpace(",")
				self:EmitSpace(" ")
			end
		end

		self:EmitNonSpace("}")

		if node.default then
			self:EmitNonSpace(",")
			self:EmitSpace(" ")
			self:EmitNonSpace("true")
		end

		self:EmitNonSpace(")")
	end

	function META:EmitDestructureAssignment(node)
		self:Whitespace("\t")

		if node.tokens["local"] then
			self:EmitToken(node.tokens["local"])
		end

		if node.tokens["type"] then
			self:Whitespace(" ")
			self:EmitToken(node.tokens["type"])
		end

		self:Whitespace(" ")
		self:EmitToken(node.tokens["{"])
		self:Whitespace(" ")
		self:EmitIdentifierList(node.left)
		self:Whitespace(" ")
		self:EmitToken(node.tokens["}"])
		self:Whitespace(" ")
		self:EmitToken(node.tokens["="])
		self:Whitespace(" ")
		self:EmitExpression(node.right)
	end

	function META:Emit_ENVFromAssignment(node)
		for i, v in ipairs(node.left) do
			if v.kind == "value" and v.value.value == "_ENV" then
				if node.right[i] then
					local key = node.left[i]
					local val = node.right[i]
					self:EmitNonSpace(";setfenv(1, _ENV);")
				end
			end
		end
	end

	function META:EmitImportExpression(node)
		self:EmitSpace(" ")
		self:EmitNonSpace("IMPORTS['" .. node.path .. "'](")
		self:EmitExpressionList(node.expressions)
		self:EmitNonSpace(")")
	end
end

return function(config)
	local self = setmetatable({}, META)
	self.config = config or {}
	self:Initialize()
	return self
end
