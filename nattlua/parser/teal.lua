--[[#local type { Node, statement } = import("~/nattlua/parser/node.lua")]]

--[[#local type { Token, TokenType } = import("~/nattlua/lexer/token.lua")]]

local runtime_syntax = require("nattlua.syntax.runtime")
local typesystem_syntax = require("nattlua.syntax.typesystem")
local math_huge = math.huge
local table_insert = table.insert
local tostring = tostring
return function(META--[[#: any]])
	function META:ParseTealFunctionArgument(expect_type--[[#: nil | boolean]])
		if
			expect_type or
			(
				self:IsTokenType("letter") or
				self:IsToken("...")
			) and
			self:IsTokenOffset(":", 1)
		then
			if self:IsToken("...") then
				local node = self:StartNode("expression_vararg")
				node.tokens["..."] = self:ExpectToken("...")
				node.tokens[":"] = self:ExpectToken(":")
				node.value = self:ParseValueExpressionType("letter")
				node = self:EndNode(node)
				return node
			end

			local identifier = self:ParseToken()
			local token = self:ExpectToken(":")
			local exp = self:ParseTealExpression(0)
			exp.tokens[":"] = token
			exp.identifier = identifier
			return exp
		end

		return self:ParseTealExpression(0)
	end

	function META:ParseTealFunctionSignature()
		if not self:IsToken("function") then return nil end

		local node = self:StartNode("expression_function_signature")
		node.tokens["function"] = self:ExpectToken("function")

		if self:IsToken("<") then
			node.tokens["<"] = self:ExpectToken("<")
			node.identifiers_typesystem = self:ParseMultipleValues(self.ParseTealFunctionArgument, false) or false
			node.tokens[">"] = self:ExpectToken(">")
		end

		node.tokens["="] = self:NewToken("symbol", "=")
		node.tokens["arguments("] = self:ExpectToken("(")
		node.identifiers = self:ParseMultipleValues(self.ParseTealFunctionArgument)
		node.tokens["arguments)"] = self:ExpectToken(")")
		node.tokens[">"] = self:NewToken("symbol", ">")
		node.tokens["return("] = self:NewToken("symbol", "(")

		if self:IsToken(":") then
			node.tokens[":"] = self:ExpectToken(":")
			node.return_types = self:ParseMultipleValues(self.ParseTealExpression, 0)
		else
			node.tokens[":"] = self:NewToken("symbol", ":")
			node.return_types = {}
		end

		node.tokens["return)"] = self:NewToken("symbol", ")")
		node = self:EndNode(node)
		return node
	end

	function META:ParseTealKeywordValueExpression()
		local token = self:GetToken()

		if not token then return end

		if not typesystem_syntax:IsValue(token) then return end

		local node = self:StartNode("expression_value")
		node.value = self:ParseToken()
		node = self:EndNode(node)
		return node
	end

	function META:ParseTealVarargExpression()
		if not self:IsTokenOffset("...", 1) then return end

		local node = self:StartNode("expression_vararg")
		node.value = self:ParseValueExpressionType("letter")
		node.tokens["..."] = self:ExpectToken("...")
		node = self:EndNode(node)
		return node
	end

	function META:ParseTealTable()
		if not self:IsToken("{") then return nil end

		local node = self:StartNode("expression_type_table")
		node.tokens["{"] = self:ExpectToken("{")
		node.tokens["separators"] = {}
		node.children = {}

		if
			self:IsTokenOffset(":", 1) or
			self:IsToken("(") or
			(
				self:IsToken("{") and
				self:IsTokenOffset(":", 2) and
				self:IsTokenOffset(":", 5)
			)
		then
			local kv = self:StartNode("sub_statement_table_expression_value")

			if self:IsToken("(") then
				kv.tokens["["] = self:ExpectValueTranslate("(", "[")
				kv.key_expression = self:ParseTealExpression(0)
				kv.tokens["]"] = self:ExpectValueTranslate(")", "]")
			elseif self:IsToken("{") then
				kv.tokens["["] = self:NewToken("symbol", "[")
				kv.key_expression = self:ParseTealTable()

				if self:IsToken("}") then
					kv = self:EndNode(kv)
					node.children = {kv}
					node.tokens["}"] = self:ExpectToken("}")
					node = self:EndNode(node)
					return node
				end

				kv.tokens["]"] = self:NewToken("symbol", "]")
			else
				kv.tokens["["] = self:NewToken("symbol", "[")
				kv.key_expression = self:ParseValueExpressionType("letter")
				kv.key_expression.standalone_letter = true
				kv.tokens["]"] = self:NewToken("symbol", "]")
			end

			kv.tokens["="] = self:ExpectValueTranslate(":", "=")
			kv.value_expression = self:ParseTealExpression(0)
			kv = self:EndNode(kv)
			node.children = {kv}
		else
			local i = 1

			for _ = self:GetPosition(), self:GetLength() do
				local kv = self:StartNode("sub_statement_table_expression_value")
				kv.tokens["["] = self:NewToken("symbol", "[")
				local key = self:StartNode("expression_value")
				key.value = self:NewToken("letter", "number")
				key.standalone_letter = key
				key = self:EndNode(key)
				kv.key_expression = key
				kv.tokens["]"] = self:NewToken("symbol", "]")
				kv.tokens["="] = self:NewToken("symbol", "=")
				kv.value_expression = self:ParseTealExpression(0)
				kv = self:EndNode(kv)
				table_insert(node.children, kv)

				if not self:IsToken(",") then
					if i > 1 then key.value = self:NewToken("number", tostring(i)) end

					break
				end

				key.value = self:NewToken("number", tostring(i))
				i = i + 1
				table_insert(node.tokens["separators"], self:ExpectToken(","))
			end
		end

		node.tokens["}"] = self:ExpectToken("}")
		node = self:EndNode(node)
		return node
	end

	function META:ParseTealTuple()
		if not self:IsToken("(") then return nil end

		local node = self:StartNode("expression_tuple")
		node.tokens["("] = self:ExpectToken("(")
		node.expressions = self:ParseMultipleValues(self.ParseTealExpression, 0)
		node.tokens[")"] = self:ExpectToken(")")
		node = self:EndNode(node)
		return node
	end

	function META:ParseTealCallSubExpression()
		if not self:IsToken("<") then return end

		local node = self:StartNode("expression_postfix_call")
		node.tokens["call("] = self:ExpectValueTranslate("<", "<|")
		node.expressions = self:ParseMultipleValues(self.ParseTealExpression, 0)
		node.tokens["call)"] = self:ExpectValueTranslate(">", "|>")
		node.type_call = true
		node = self:EndNode(node)
		return node
	end

	function META:ParseTealSubExpression(node--[[#: Node]])
		for _ = self:GetPosition(), self:GetLength() do
			local left_node = node
			local found = self:ParseIndexSubExpression() or
				--self:ParseSelfCallSubExpression() or
				--self:ParsePostfixTypeOperatorSubExpression() or
				self:ParseTealCallSubExpression() --or
			--self:ParsePostfixTypeIndexExpressionSubExpression() or
			--self:ParseAsSubExpression(left_node)
			if not found then break end

			found.left = left_node

			if left_node.value and left_node.value.sub_type == ":" then
				found.parser_call = true
			end

			node = found
		end

		return node
	end

	function META:ParseTealExpression(priority--[[#: number]])
		self:PushParserEnvironment("typesystem")
		local node = self:ParseTealFunctionSignature() or
			self:ParseTealVarargExpression() or
			self:ParseTealKeywordValueExpression() or
			self:ParseTealTable() or
			self:ParseTealTuple()
		local first = node

		if node then
			node = self:ParseTealSubExpression(node)

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

		if self.TealCompat and self:IsToken(">") then
			self:PopParserEnvironment()
			return node
		end

		for _ = self:GetPosition(), self:GetLength() do
			local info = typesystem_syntax:GetBinaryOperatorInfo(self:GetToken())

			if not info or info.left_priority <= priority then break end

			local left_node = node
			node = self:StartNode("expression_binary_operator")
			node.value = self:ParseToken()
			node.left = left_node
			node.right = self:ParseTealExpression(info.right_priority)
			node = self:EndNode(node)
		end

		self:PopParserEnvironment()
		return node
	end

	function META:ParseTealAssignment()
		if not self:IsToken("type") or not self:IsTokenTypeOffset("letter", 1) then
			return nil
		end

		local kv = self:StartNode("statement_assignment")
		kv.tokens["type"] = self:ExpectToken("type")
		kv.left = {self:ParseValueExpressionToken()}
		kv.tokens["="] = self:ExpectToken("=")
		kv.right = {self:ParseTealExpression(0)}
		kv = self:EndNode(kv)
		return kv
	end

	function META:ParseTealRecordKeyVal()
		if not self:IsTokenType("letter") or not self:IsTokenOffset(":", 1) then
			return nil
		end

		local kv = self:StartNode("statement_assignment")
		kv.tokens["type"] = self:NewToken("letter", "type")
		kv.left = {self:ParseValueExpressionToken()}
		kv.tokens["="] = self:ExpectValueTranslate(":", "=")
		kv.right = {self:ParseTealExpression(0)}
		return kv
	end

	function META:ParseTealRecordArray()
		if not self:IsToken("{") then return nil end

		local kv = self:StartNode("statement_assignment")
		kv.tokens["type"] = self:ExpectValueTranslate("{", "type")
		kv.left = {self:ParseString("_G[number] = 1").statements[1].left[1]}
		kv.tokens["="] = self:NewToken("symbol", "=")
		kv.right = {self:ParseTealExpression(0)}
		self:Advance(1) -- }
		kv = self:EndNode(kv)
		return kv
	end

	function META:ParseTealRecordMetamethod()
		if
			not self:IsTokenValue("metamethod") or
			not self:IsTokenTypeOffset("letter", 1)
			or
			not self:IsTokenOffset(":", 2)
		then
			return nil
		end

		local kv = self:StartNode("statement_assignment")
		kv.tokens["type"] = self:ExpectValueTranslate("metamethod", "type")
		kv.left = {self:ParseValueExpressionToken()}
		kv.tokens["="] = self:ExpectValueTranslate(":", "=")
		kv.right = {self:ParseTealExpression(0)}
		return kv
	end

	local function ParseRecordBody(
		self--[[#: META.@Self]],
		assignment--[[#: statement.assignment | statement.local_assignment]]
	)
		local func

		if self:IsToken("<") then
			func = self:StartNode("statement_local_type_function")
			func.tokens["local"] = self:NewToken("letter", "local")
			func.tokens["identifier"] = assignment.left[1].value
			func.tokens["function"] = self:NewToken("letter", "function")
			func.tokens["arguments("] = self:ExpectValueTranslate("<", "<|")
			func.identifiers = self:ParseMultipleValues(self.ParseValueExpressionToken)
			func.tokens["arguments)"] = self:ExpectValueTranslate(">", "|>")
			func.statements = {}
		end

		local name = func and "__env" or assignment.left[1].value:GetValueString()
		assignment.left[1].value = self:NewToken("letter", name)
		local tbl = self:StartNode("expression_type_table")
		tbl.tokens["{"] = self:NewToken("symbol", "{")
		tbl.tokens["}"] = self:NewToken("symbol", "}")
		tbl.children = {}
		tbl = self:EndNode(tbl)
		assignment.right = {tbl}
		assignment = self:EndNode(assignment)
		local block = self:StartNode("statement_do")
		block.tokens["do"] = self:NewToken("letter", "do")
		block.statements = {}
		table_insert(
			block.statements,
			self:ParseString("PushTypeEnvironment<|" .. name .. "|>").statements[1]
		)

		for _ = self:GetPosition(), self:GetLength() do
			local node = self:ParseTealEnumStatement() or
				self:ParseTealAssignment() or
				self:ParseTealRecord() or
				self:ParseTealRecordMetamethod() or
				self:ParseTealRecordKeyVal() or
				self:ParseTealRecordArray()

			if not node then break end

			if #node > 0 then
				for _, node in ipairs(node) do
					table_insert(block.statements, node)
				end
			else
				table_insert(block.statements, node)
			end
		end

		table_insert(block.statements, self:ParseString("PopTypeEnvironment<||>").statements[1])
		block.tokens["end"] = self:ExpectToken("end")
		block = self:EndNode(block)
		self:PopParserEnvironment()

		if func then
			table_insert(func.statements, assignment)
			table_insert(func.statements, block)
			table_insert(func.statements, self:ParseString("return " .. name).statements[1])
			func.tokens["end"] = self:NewToken("letter", "end")
			func = self:EndNode(func)
			return func
		end

		return {assignment, block}
	end

	function META:ParseTealRecord()
		if not self:IsTokenValue("record") or not self:IsTokenTypeOffset("letter", 1) then
			return nil
		end

		self:PushParserEnvironment("typesystem")
		local assignment = self:StartNode("statement_assignment")
		assignment.tokens["type"] = self:ExpectValueTranslate("record", "type")
		assignment.tokens["="] = self:NewToken("symbol", "=")
		assignment.left = {self:ParseValueExpressionToken()}
		return ParseRecordBody(self, assignment)
	end

	function META:ParseLocalTealRecord()
		if
			not self:IsToken("local") or
			not self:IsTokenValueOffset("record", 1)
			or
			not self:IsTokenTypeOffset("letter", 2)
		then
			return nil
		end

		self:PushParserEnvironment("typesystem")
		local assignment = self:StartNode("statement_local_assignment")
		assignment.tokens["local"] = self:ExpectToken("local")
		assignment.tokens["type"] = self:ExpectValueTranslate("record", "type")
		assignment.tokens["="] = self:NewToken("symbol", "=")
		assignment.left = {self:ParseValueExpressionToken()}
		return ParseRecordBody(self, assignment)
	end

	do
		local function ParseBody(
			self--[[#: META.@Self]],
			assignment--[[#: statement.assignment | statement.local_assignment]]
		)
			assignment.tokens["type"] = self:ExpectValueTranslate("enum", "type")
			assignment.left = {self:ParseValueExpressionToken()}
			assignment.tokens["="] = self:NewToken("symbol", "=")
			local bnode = self:ParseValueExpressionType("string")

			for _ = self:GetPosition(), self:GetLength() do
				if self:IsTokenType("letter") and self:IsToken("end") then break end

				local left = bnode
				bnode = self:StartNode("expression_binary_operator")
				bnode.value = self:NewToken("symbol", "|")
				bnode.right = self:ParseValueExpressionType("string")
				bnode.left = left
				bnode = self:EndNode(bnode)
			end

			assignment.right = {bnode}
			self:ExpectToken("end")
		end

		function META:ParseTealEnumStatement()
			if not self:IsTokenValue("enum") or not self:IsTokenTypeOffset("letter", 1) then
				return nil
			end

			self:PushParserEnvironment("typesystem")
			local assignment = self:StartNode("statement_assignment")
			ParseBody(self, assignment)
			assignment = self:EndNode(assignment)
			self:PopParserEnvironment()
			return assignment
		end

		function META:ParseLocalTealEnumStatement()
			if
				not self:IsToken("local") or
				not self:IsTokenValueOffset("enum", 1)
				or
				not self:IsTokenTypeOffset("letter", 2)
			then
				return nil
			end

			self:PushParserEnvironment("typesystem")
			local assignment = self:StartNode("statement_local_assignment")
			assignment.tokens["local"] = self:ExpectToken("local")
			ParseBody(self, assignment)
			assignment = self:EndNode(assignment)
			self:PopParserEnvironment()
			return assignment
		end
	end
end
