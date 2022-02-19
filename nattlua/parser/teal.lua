local META = ...
local runtime_syntax = require("nattlua.syntax.runtime")
local typesystem_syntax = require("nattlua.syntax.typesystem")

local function Value(self, symbol, value)
	local node = self:StartNode("expression", "value")
	node.value = self:NewToken(symbol, value)
	self:EndNode(node)
	return node
end

local function Parse(code)
	local compiler = require("nattlua").Compiler(code, "temp")
	assert(compiler:Lex())
	assert(compiler:Parse())
	return compiler.SyntaxTree
end

local function fix(tk, new_value)
	tk.value = new_value
	return tk
end

function META:NewToken(type, value)
	local tk = {}
	tk.type = type
	tk.is_whitespace = false
	tk.start = start
	tk.stop = stop
	tk.value = value
	return tk
end

function META:ReadTealFunctionArgument(expect_type--[[#: nil | boolean]])
	if
		expect_type or
		(
			self:IsType("letter") or
			self:IsValue("...")
		) and
		self:IsValue(":", 1)
	then
		local identifier = self:ReadToken()
		local token = self:ExpectValue(":")
		local exp = self:ReadTealExpression(0)
		exp.tokens[":"] = token
		exp.identifier = identifier
		return exp
	end

	return self:ReadTealExpression(0)
end

function META:ReadTealFunctionSignature()
	if not self:IsValue("function") then return nil end

	local node = self:StartNode("expression", "function_signature")
	node.tokens["function"] = self:ExpectValue("function")

	if self:IsValue("<") then
		node.tokens["<"] = self:ExpectValue("<")
		node.identifiers_typesystem = self:ReadMultipleValues(math_huge, self.ReadTealFunctionArgument, false)
		node.tokens[">"] = self:ExpectValue(">")
	end

	node.tokens["="] = self:NewToken("symbol", "=")
	node.tokens["arguments("] = self:ExpectValue("(")
	node.identifiers = self:ReadMultipleValues(nil, self.ReadTealFunctionArgument)
	node.tokens["arguments)"] = self:ExpectValue(")")
	node.tokens[">"] = self:NewToken("symbol", ">")

	if self:IsValue(":") then
		node.tokens[":"] = self:ExpectValue(":")
		node.tokens["return("] = self:NewToken("symbol", "(")
		node.return_types = self:ReadMultipleValues(nil, self.ReadTealFunctionArgument)
		node.tokens["return)"] = self:NewToken("symbol", ")")
	end

	self:EndNode(node)
	return node
end

function META:ReadTealKeywordValueExpression()
	if not typesystem_syntax:IsValue(self:GetToken()) then return end

	local node = self:StartNode("expression", "value")
	node.value = self:ReadToken()
	self:EndNode(node)
	return node
end

function META:ReadTealVarargExpression()
	if not self:IsType("letter") or not self:IsValue("...", 1) then return end

	local node = self:StartNode("expression", "value")
	node.type_expression = self:ReadValueExpressionType("letter")
	node.value = self:ExpectValue("...")
	self:EndNode(node)
	return node
end

function META:ReadTealTable()
	if not self:IsValue("{") then return nil end

	local node = self:StartNode("expression", "type_table")
	node.tokens["{"] = self:ExpectValue("{")
	node.tokens["separators"] = {}
	node.children = {}

	if self:IsValue(":", 1) or self:IsValue("(") then
		local kv = self:StartNode("expression", "table_expression_value")
		kv.expression_key = true

		if self:IsValue("(") then
			kv.tokens["["] = fix(self:ExpectValue("("), "[")
			kv.key_expression = self:ReadTealExpression(0)
			kv.tokens["]"] = fix(self:ExpectValue(")"), "]")
		else
			kv.tokens["["] = self:NewToken("symbol", "[")
			kv.key_expression = self:ReadValueExpressionType("letter")
			kv.tokens["]"] = self:NewToken("symbol", "]")
		end

		kv.tokens["="] = fix(self:ExpectValue(":"), "=")
		kv.value_expression = self:ReadTealExpression(0)
		self:EndNode(kv)
		node.children = {kv}
	else
		local i = 1

		while true do
			local kv = self:StartNode("expression", "table_expression_value")
			kv.expression_key = true
			kv.tokens["["] = self:NewToken("symbol", "[")
			local key = self:StartNode("expression", "value")
			key.value = self:NewToken("letter", "number")
			key.standalone_letter = key
			self:EndNode(key)
			kv.key_expression = key
			kv.tokens["]"] = self:NewToken("symbol", "]")
			kv.tokens["="] = self:NewToken("symbol", "=")
			kv.value_expression = self:ReadTealExpression(0)
			self:EndNode(kv)
			table.insert(node.children, kv)

			if not self:IsValue(",") then
				if i > 1 then
					key.value = self:NewToken("number", tostring(i))
				end

				break
			end

			key.value = self:NewToken("number", tostring(i))
			i = i + 1
			table.insert(node.tokens["separators"], self:ExpectValue(","))
		end
	end

	node.tokens["}"] = self:ExpectValue("}")
	self:EndNode(node)
	return node
end

function META:ReadTealTuple()
	if not self:IsValue("(") then return nil end

	local node = self:StartNode("expression", "tuple")
	node.tokens["("] = self:ExpectValue("(")
	node.expressions = self:ReadMultipleValues(nil, self.ReadTealExpression, 0)
	node.tokens[")"] = self:ExpectValue(")")
	self:EndNode(node)
	return node
end

function META:ReadTealCallSubExpression()
	if not self:IsValue("<") then return end

	local node = self:StartNode("expression", "postfix_call")
	node.tokens["call("] = fix(self:ExpectValue("<"), "<|")
	node.expressions = self:ReadMultipleValues(nil, self.ReadTealExpression, 0)
	node.tokens["call)"] = fix(self:ExpectValue(">"), "|>")
	node.type_call = true
	self:EndNode(node)
	return node
end

function META:ReadTealSubExpression(node)
	for _ = 1, self:GetLength() do
		local left_node = node
		local found = self:ReadIndexSubExpression() or
			--self:ReadSelfCallSubExpression() or
			--self:ReadPostfixTypeOperatorSubExpression() or
			self:ReadTealCallSubExpression() --or
		--self:ReadPostfixTypeIndexExpressionSubExpression() or
		--self:ReadAsSubExpression(left_node)
		if not found then break end

		found.left = left_node

		if left_node.value and left_node.value.value == ":" then
			found.parser_call = true
		end

		node = found
	end

	return node
end

function META:ReadTealExpression(priority)
	local node = self:ReadTealFunctionSignature() or
		self:ReadTealVarargExpression() or
		self:ReadTealKeywordValueExpression() or
		self:ReadTealTable() or
		self:ReadTealTuple()
	local first = node

	if node then
		node = self:ReadTealSubExpression(node)

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

	if self.TealCompat and self:IsValue(">") then return node end

	while
		typesystem_syntax:GetBinaryOperatorInfo(self:GetToken()) and
		typesystem_syntax:GetBinaryOperatorInfo(self:GetToken()).left_priority > priority
	do
		local left_node = node
		node = self:StartNode("expression", "binary_operator")
		node.value = self:ReadToken()
		node.left = left_node
		node.right = self:ReadTealExpression(typesystem_syntax:GetBinaryOperatorInfo(node.value).right_priority)
		self:EndNode(node)
	end

	return node
end

function META:ReadTealAssignment()
	if not self:IsValue("type") or not self:IsType("letter", 1) then return nil end

	local kv = self:StartNode("statement", "assignment")
	kv.tokens["type"] = self:ExpectValue("type")
	kv.left = {self:ReadValueExpressionToken()}
	kv.tokens["="] = self:ExpectValue("=")
	kv.right = {self:ReadTealExpression(0)}
	return kv
end

function META:ReadTealRecordKeyVal()
	if not self:IsType("letter") or not self:IsValue(":", 1) then return nil end

	local kv = self:StartNode("statement", "assignment")
	kv.tokens["type"] = self:NewToken("letter", "type")
	kv.left = {self:ReadValueExpressionToken()}
	kv.tokens["="] = fix(self:ExpectValue(":"), "=")
	kv.right = {self:ReadTealExpression(0)}
	return kv
end

function META:ReadTealRecordArray()
	if not self:IsValue("{") then return nil end

	local kv = self:StartNode("statement", "assignment")
	kv.tokens["type"] = fix(self:ExpectValue("{"), "type")
	kv.left = {Parse("_G[number] = 1").statements[1].left[1]}
	kv.tokens["="] = self:NewToken("symbol", "=")
	kv.right = {self:ReadTealExpression(0)}
	self:Advance(1) -- }
	return kv
end

function META:ReadTealRecordMetamethod()
	if
		not self:IsValue("metamethod") or
		not self:IsType("letter", 1)
		or
		not self:IsValue(":", 2)
	then
		return nil
	end

	local kv = self:StartNode("statement", "assignment")
	kv.tokens["type"] = fix(self:ExpectValue("metamethod"), "type")
	kv.left = {self:ReadValueExpressionToken()}
	kv.tokens["="] = fix(self:ExpectValue(":"), "=")
	kv.right = {self:ReadTealExpression(0)}
	return kv
end

local function ReadRecordBody(self, assignment)
	local func

	if self:IsValue("<") then
		func = self:StartNode("statement", "local_type_function")
		func.tokens["local"] = self:NewToken("letter", "local")
		func.tokens["identifier"] = assignment.left[1].value
		func.tokens["function"] = self:NewToken("letter", "function")
		func.tokens["arguments("] = fix(self:ExpectValue("<"), "<|")
		func.identifiers = self:ReadMultipleValues(nil, self.ReadValueExpressionToken)
		func.tokens["arguments)"] = fix(self:ExpectValue(">"), "|>")
		func.statements = {}
	end

	local name = func and "__env" or assignment.left[1].value.value
	assignment.left[1].value = self:NewToken("letter", name)
	local tbl = self:StartNode("expression", "type_table")
	tbl.tokens["{"] = self:NewToken("symbol", "{")
	tbl.tokens["}"] = self:NewToken("symbol", "}")
	tbl.children = {}
	self:EndNode(tbl)
	assignment.right = {tbl}
	self:EndNode(assignment)
	local block = self:StartNode("statement", "do")
	block.tokens["do"] = self:NewToken("letter", "do")
	block.statements = {}
	table.insert(block.statements, Parse("PushTypeEnvironment<|" .. name .. "|>").statements[1])

	while true do
		local node = self:ReadTealEnumStatement() or
			self:ReadTealAssignment() or
			self:ReadTealRecord() or
			self:ReadTealRecordMetamethod() or
			self:ReadTealRecordKeyVal() or
			self:ReadTealRecordArray()

		if not node then break end

		if node[1] then
			for _, node in ipairs(node) do
				table.insert(block.statements, node)
			end
		else
			table.insert(block.statements, node)
		end
	end

	table.insert(block.statements, Parse("PopTypeEnvironment<||>").statements[1])
	block.tokens["end"] = self:ExpectValue("end")
	self:EndNode(block)
	self:PopParserEnvironment("typesystem")

	if func then
		table.insert(func.statements, assignment)
		table.insert(func.statements, block)
		table.insert(func.statements, Parse("return " .. name).statements[1])
		func.tokens["end"] = self:NewToken("letter", "end")
		self:EndNode(func)
		return func
	end

	return {assignment, block}
end

function META:ReadTealRecord()
	if not self:IsValue("record") or not self:IsType("letter", 1) then return nil end

	self:PushParserEnvironment("typesystem")
	local assignment = self:StartNode("statement", "assignment")
	assignment.tokens["type"] = fix(self:ExpectValue("record"), "type")
	assignment.tokens["="] = self:NewToken("symbol", "=")
	assignment.left = {self:ReadValueExpressionToken()}
	return ReadRecordBody(self, assignment)
end

function META:ReadLocalTealRecord()
	if
		not self:IsValue("local") or
		not self:IsValue("record", 1)
		or
		not self:IsType("letter", 2)
	then
		return nil
	end

	self:PushParserEnvironment("typesystem")
	local assignment = self:StartNode("statement", "local_assignment")
	assignment.tokens["local"] = self:ExpectValue("local")
	assignment.tokens["type"] = fix(self:ExpectValue("record"), "type")
	assignment.tokens["="] = self:NewToken("symbol", "=")
	assignment.left = {self:ReadValueExpressionToken()}
	return ReadRecordBody(self, assignment)
end

do
	local function ReadBody(self, assignment)
		self:PushParserEnvironment("typesystem")
		assignment.tokens["type"] = fix(self:ExpectValue("enum"), "type")
		assignment.left = {self:ReadValueExpressionToken()}
		assignment.tokens["="] = self:NewToken("symbol", "=")
		local bnode = self:ReadValueExpressionType("string")

		while not self:IsValue("end") do
			local left = bnode
			bnode = self:StartNode("expression", "binary_operator")
			bnode.value = self:NewToken("symbol", "|")
			bnode.right = self:ReadValueExpressionType("string")
			bnode.left = left
			self:EndNode(bnode)
		end

		assignment.right = {bnode}
		self:ExpectValue("end")
		self:EndNode(assignment)
		self:PopParserEnvironment("typesystem")
		return assignment
	end

	function META:ReadTealEnumStatement()
		if not self:IsValue("enum") or not self:IsType("letter", 1) then return nil end

		local assignment = self:StartNode("statement", "assignment")
		return ReadBody(self, assignment)
	end

	function META:ReadLocalTealEnumStatement()
		if
			not self:IsValue("local") or
			not self:IsValue("enum", 1)
			or
			not self:IsType("letter", 2)
		then
			return nil
		end

		local assignment = self:StartNode("statement", "local_assignment")
		assignment.tokens["local"] = self:ExpectValue("local")
		return ReadBody(self, assignment)
	end
end
