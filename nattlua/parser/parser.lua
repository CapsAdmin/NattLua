--[[#local type { Token, TokenType } = import_type("nattlua/lexer/token.nlua")]]
--[[#import_type("nattlua/code/code.lua")]]

--[[#local type NodeType = "expression" | "statement"]]
--[[#local type Node = any]]
local ipairs = _G.ipairs
local pairs = _G.pairs
local setmetatable = _G.setmetatable
local type = _G.type
local table = require("table")
local TEST = false
local META = {}
META.__index = META
--[[# --]]META.Emitter = require("nattlua.transpiler.emitter")
--[[#type META.@Self = {
		config = any,
		nodes = {[number] = any} | {},
		Code = Code,
		current_statement = false | any,
		current_expression = false | any,
		root = false | any,
		i = number,
		tokens = {[number] = Token},
	}]]

do
	local PARSER = META
	local META = {}
	META.__index = META
	META.Type = "node"
--[[#	type META.@Self = {
			type = TokenType,
			kind = string,
			id = number,
			Code = Code,
			parser = PARSER.@Self,
			statements = {[number] = self} | {},
			tokens = {[string] = Token},
		}]]
--[[#	type PARSER.@Self.nodes = {[number] = META.@Self} | {}]]

	function META:__tostring()
		if self.type == "statement" then
			local str = "[" .. self.type .. " - " .. self.kind .. "]"


			local ok = false
			if self.Code then
				local lua_code = self.Code:GetString()
				local name = self.Code:GetName()
				if name:sub(1, 1) == "@" then
					ok = true
					local helpers = require("nattlua.other.helpers")
					local data = helpers.SubPositionToLinePosition(lua_code, helpers.LazyFindStartStop(self))

					if data and data.line_start then
						str = str .. " @ " .. name:sub(2) .. ":" .. data.line_start
					else
						str = str .. " @ " .. name:sub(2) .. ":" .. "?"
					end
				end
			end

			if not ok then
				str = str .. " " .. ("%s"):format(self.id)
			end

			return str
		elseif self.type == "expression" then
			local str = "[" .. self.type .. " - " .. self.kind .. " - " .. ("%s"):format(self.id) .. "]"

			if self.value and type(self.value.value) == "string" then
				str = str .. ": " .. require("nattlua.other.quote").QuoteToken(self.value.value)
			end

			return str
		end
	end

	function META:Dump()
		local table_print = require("nattlua.other.table_print")
		table_print(self)
	end

	function META:Render(config)
		local em = PARSER.Emitter(config or {preserve_whitespace = false, no_newlines = true})

		if self.type == "expression" then
			em:EmitExpression(self)
		else
			em:EmitStatement(self)
		end

		return em:Concat()
	end

	function META:IsWrappedInParenthesis()--[[#: boolean]]
		return self.tokens["("] and self.tokens[")"]
	end

	function META:GetLength()
		local helpers = require("nattlua.other.helpers")
		local start, stop = helpers.LazyFindStartStop(self, true)
		return stop - start
	end

	function META:GetNodes()
		if self.kind == "if" then
			local flat = {}

			for _, statements in ipairs(self.statements) do
				for _, v in ipairs(statements) do
					table.insert(flat, v)
				end
			end

			return flat
		end

		return self.statements
	end

	function META:HasNodes()
		return self.statements ~= nil
	end

	local function find_by_type(node--[[#: META.@Self]], what--[[#: TokenType]], out--[[#: {[1 .. inf] = Node}]])
		out = out or {}

		for _, child in ipairs(node:GetNodes()) do
			if child.kind == what then
				table.insert(out, child)
			elseif child:GetNodes() then
				find_by_type(child, what, out)
			end
		end

		return out
	end

	function META:FindNodesByType(what--[[#: TokenType]])
		return find_by_type(self, what, {})
	end

	do
		-- META.@Self.ExpectValue | META.@Self.ExpectType
		local function expect(node--[[#: Node]], parser--[[#: META.@Self]], func--[[#: any]], what--[[#: string]], start--[[#: number | nil]], stop--[[#: number | nil]], alias--[[#: string | nil]])
			local tokens = node.tokens

			if start then
				start = tokens[start]
			end

			if stop then
				stop = tokens[stop]
			end

			if start and not stop then
				stop = tokens[start]
			end

			local token = func(parser, what, start, stop)
			local what = alias or what

			if tokens[what] then
				if not tokens[what][1] then
					tokens[what] = {tokens[what]}
				end

				table.insert(tokens[what], token)
			else
				tokens[what] = token
			end

			token.parent = node
		end

		function META:ExpectAliasedKeyword(what--[[#: string]], alias--[[#: string | nil]], start--[[#: number | nil]], stop--[[#: number | nil]])
			expect(
				self,
				self.parser,
				self.parser.ExpectValue,
				what,
				start,
				stop,
				alias
			)
			return self
		end

		function META:ExpectKeyword(what--[[#: string]], start--[[#: number | nil]], stop--[[#: number | nil]])
			expect(
				self,
				self.parser,
				self.parser.ExpectValue,
				what,
				start,
				stop
			)
			return self
		end
	end

	function META:ExpectNodesUntil(what--[[#: string]])
		self.statements = self.parser:ReadNodes({[what] = true})
		return self
	end

	function META:ExpectSimpleIdentifier()
		self.tokens["identifier"] = self.parser:ExpectType("letter")
		return self
	end

	function META:Store(key--[[#: keysof<|META.@Self|>]], val--[[#: literal any]])
		self[key] = val
		return self
	end

	local id = 0

	function PARSER:Node(type--[[#: NodeType]], kind--[[#: string]])
		id = id + 1
		local node = setmetatable(
			{
				type = type,
				kind = kind,
				tokens = {},
				id = id,
				Code = self.Code,
				parser = self,
			},
			META
		)

		if type == "expression" then
			self.current_expression = node
		else
			self.current_statement = node
		end

		if self.OnNode then
			self:OnNode(node)
		end

		node.parent = self.nodes[1]
		table.insert(self.nodes, 1, node)

		if TEST then
			node.traceback = debug.getinfo(2).source:sub(2) .. ":" .. debug.getinfo(2).currentline
			node.ref = newproxy(true)
			getmetatable(node.ref).__gc = function()
				if not node.end_called then
					print("node:End() was never called before gc: ", node.traceback)
				end
			end
		end

		return node
	end

	function META:End()
		if TEST then
			self.end_called = true
		end

		table.remove(self.parser.nodes, 1)
		return self
	end
end

function META:Error(msg--[[#: string]], start_token--[[#: Token | nil]], stop_token--[[#: Token | nil]], ...--[[#: ...any]])
	local tk = self:GetToken()
	local start = start_token and
		(start_token)--[[# as Token]].start or
		tk and
		(tk)--[[# as Token]].start or
		0
	local stop = stop_token and
		(stop_token)--[[# as Token]].stop or
		tk and
		(tk)--[[# as Token]].stop or
		0
	self:OnError(
		self.Code,
		msg,
		start,
		stop,
		...
	)
end

function META:OnNode(node--[[#: any]]) 
end

function META:OnError(code--[[#: string]], name--[[#: string]], message--[[#: string]], start--[[#: number]], stop--[[#: number]], ...--[[#: ...any]]) 
end

function META:GetToken(offset--[[#: number | nil]])
	return self.tokens[self.i + (offset or 0)]
end

function META:GetLength()
	return #self.tokens
end

function META:Advance(offset--[[#: number]])
	self.i = self.i + offset
end

function META:IsValue(str--[[#: string]], offset--[[#: number | nil]])
	local tk = self:GetToken(offset)
	if tk then return tk.value == str end
end

function META:IsType(token_type--[[#: TokenType]], offset--[[#: number | nil]])
	local tk = self:GetToken(offset)
	if tk then return tk.type == token_type end
end

function META:ReadToken()
	local tk = self:GetToken()
	if not tk then return end
	self:Advance(1)
	tk.parent = self.nodes[1]
	return tk
end

function META:RemoveToken(i)
	local t = self.tokens[i]
	table.remove(self.tokens, i)
	return t
end

function META:AddTokens(tokens--[[#: {[1 .. inf] = Token}]])
	local eof = table.remove(self.tokens)

	for i, token in ipairs(tokens) do
		if token.type == "end_of_file" then break end
		table.insert(self.tokens, self.i + i - 1, token)
	end

	table.insert(self.tokens, eof)
end

do
	local function error_expect(self--[[#: META.@Self]], str--[[#: string]], what--[[#: string]], start--[[#: Token | nil]], stop--[[#: Token | nil]])
		if not self:GetToken() then
			self:Error("expected $1 $2: reached end of code", start, stop, what, str)
		else
			self:Error(
				"expected $1 $2: got $3",
				start,
				stop,
				what,
				str,
				self:GetToken()[what]
			)
		end
	end

	function META:ExpectValue(str--[[#: string]], error_start--[[#: Token | nil]], error_stop--[[#: Token | nil]])
		if not self:IsValue(str) then
			error_expect(self, str, "value", error_start, error_stop)
		end

		return self:ReadToken()
	end

	function META:ExpectType(str--[[#: TokenType]], error_start--[[#: Token | nil]], error_stop--[[#: Token | nil]])
		if not self:IsType(str) then
			error_expect(self, str, "type", error_start, error_stop)
		end

		return self:ReadToken()
	end
end

function META:ReadValues(values--[[#: {[string] = true}]], start--[[#: Token | nil]], stop--[[#: Token | nil]])
	local tk = self:GetToken()

	if not tk then
		self:Error("expected $1: reached end of code", start, stop, values)
		return
	end

	if not values[tk.value] then
		local array = {}

		for k in pairs(values) do
			table.insert(array, k)
		end

		self:Error("expected $1 got $2", start, stop, array, tk.type)
	end

	return self:ReadToken()
end

function META:ReadNodes(stop_token--[[#: {[string] = true} | nil]])
	local out = {}

	for i = 1, self:GetLength() do
		local tk = self:GetToken()
		if not tk then break end
		if stop_token and stop_token[tk.value] then break end
		out[i] = self:ReadNode()
		if not out[i] then break end

		if self.config and self.config.on_statement then
			out[i] = self.config.on_statement(self, out[i]) or out[i]
		end
	end

	return out
end


do
	function META:GetPreferTypesystem()
		return self.prefer_typesystem_stack and self.prefer_typesystem_stack[1]
	end

	function META:PushPreferTypesystem(b)
		self.prefer_typesystem_stack = self.prefer_typesystem_stack or {}
		table.insert(self.prefer_typesystem_stack, 1, b)
	end

	function META:PopPreferTypesystem()
		table.remove(self.prefer_typesystem_stack, 1)
	end
end

function META:ResolvePath(path)
	return path
end

--[[# if false then --]]do -- statements
	local ExpectTypeExpression
	local ReadTypeExpression

	local ReadRuntimeExpression
	local ExpectRuntimeExpression

	local typesystem_syntax = require("nattlua.syntax.typesystem")
	local runtime_syntax = require("nattlua.syntax.runtime")
	local math_huge = math.huge

	local math = require("math")
	local table_insert = require("table").insert
	local table_remove = require("table").remove
	local ipairs = _G.ipairs

	local function ReadMultipleValues(parser, max, reader, a, b, c)
		if not reader then print(debug.traceback()) end
		local out = {}

		for i = 1, max or parser:GetLength() do
			local node = reader(parser, a, b, c)
			if not node then break end
			out[i] = node
			if not parser:IsValue(",") then break end
			node.tokens[","] = parser:ExpectValue(",")
		end

		return out
	end

	local function ReadIdentifier(parser, expect_type)
		if not parser:IsType("letter") and not parser:IsValue("...") then return end
		local node = parser:Node("expression", "value")

		if parser:IsValue("...") then
			node.value = parser:ExpectValue("...")
		else
			node.value = parser:ExpectType("letter")
		end

		if parser:IsValue(":") or expect_type then
			node:ExpectKeyword(":")
			node.type_expression = ExpectTypeExpression(parser, 0)
		end

		return node:End()
	end

	local function IsDestructureStatement(parser, offset)
		offset = offset or 0
		return
			(parser:IsValue("{", offset + 0) and parser:IsType("letter", offset + 1)) or
			(parser:IsType("letter", offset + 0) and parser:IsValue(",", offset + 1) and parser:IsValue("{", offset + 2))
	end

	local function IsLocalDestructureAssignmentStatement(parser)
		if parser:IsValue("local") then
			if parser:IsValue("type", 1) then return IsDestructureStatement(parser, 2) end
			return IsDestructureStatement(parser, 1)
		end
	end

	local function ReadFunctionBody(parser, node)
		node:ExpectAliasedKeyword("(", "arguments(")
		node.identifiers = ReadMultipleValues(parser, nil, ReadIdentifier)
		node:ExpectAliasedKeyword(")", "arguments)", "arguments)")

		if parser:IsValue(":") then
			node.tokens[":"] = parser:ExpectValue(":")
			node.return_types = ReadMultipleValues(parser, nil, ReadTypeExpression)
		end

		node:ExpectNodesUntil("end")
		node:ExpectKeyword("end", "function")
		return node
	end

	local function ReadIndexExpression(parser)
		if not runtime_syntax:IsValue(parser:GetToken()) then return end
		local node = parser:Node("expression", "value"):Store("value", parser:ReadToken()):End()
		local first = node

		while parser:IsValue(".") or parser:IsValue(":") do
			local left = node
			local self_call = parser:IsValue(":")
			node = parser:Node("expression", "binary_operator")
			node.value = parser:ReadToken()
			node.right = parser:Node("expression", "value"):Store("value", parser:ExpectType("letter")):End()
			node.left = left
			node.right.self_call = self_call
			node:End()
		end

		first.standalone_letter = node
		return node
	end

	local function ReadTypeFunctionBody(parser, node)
		if parser:IsValue("!") then
			node.tokens["!"] = parser:ExpectValue("!")	
			node.tokens["arguments("] = parser:ExpectValue("(")				
			node.identifiers = ReadMultipleValues(parser, nil, ReadIdentifier, true)

			if parser:IsValue("...") then
				local vararg = parser:Node("expression", "value")
				vararg.value = parser:ExpectValue("...")
				vararg:End()
				table_insert(node.identifiers, vararg)
			end
			node.tokens["arguments)"] = parser:ExpectValue(")")
		else
			node.tokens["arguments("] = parser:ExpectValue("<|")
			node.identifiers = ReadMultipleValues(parser, nil, ReadIdentifier, true)

			if parser:IsValue("...") then
				local vararg = parser:Node("expression", "value")
				vararg.value = parser:ExpectValue("...")
				vararg:End()
				table_insert(node.identifiers, vararg)
			end

			node.tokens["arguments)"] = parser:ExpectValue("|>", node.tokens["arguments("])
		end

		if parser:IsValue(":") then
			node.tokens[":"] = parser:ExpectValue(":")
			node.return_types = ReadMultipleValues(parser, math.huge, ExpectTypeExpression)
		end

		parser:PushPreferTypesystem(true)

		local start = parser:GetToken()
		node.statements = parser:ReadNodes({["end"] = true})
		node.tokens["end"] = parser:ExpectValue("end", start, start)

		parser:PopPreferTypesystem()

		return node
	end

	local function ReadTypeFunctionArgument(parser, expect_type)
		if parser:IsValue(")") then return end
		if parser:IsValue("...") then return end

		if expect_type or parser:IsType("letter") and parser:IsValue(":", 1) then
			local identifier = parser:ReadToken()
			local token = parser:ExpectValue(":")
			local exp = ExpectTypeExpression(parser)
			exp.tokens[":"] = token
			exp.identifier = identifier
			return exp
		end

		return ExpectTypeExpression(parser)
	end

	local function ReadAnalyzerFunctionBody(parser, node, type_args)
		node.tokens["arguments("] = parser:ExpectValue("(")

		node.identifiers = ReadMultipleValues(parser, math_huge, ReadTypeFunctionArgument, type_args)

		if parser:IsValue("...") then
			local vararg = parser:Node("expression", "value")
			vararg.value = parser:ExpectValue("...")

			if parser:IsValue(":") or type_args then
				vararg.tokens[":"] = parser:ExpectValue(":")
				vararg.type_expression = ExpectTypeExpression(parser)
			else
				if parser:IsType("letter") then
					vararg.type_expression = ExpectTypeExpression(parser)
				end
			end

			vararg:End()
			table_insert(node.identifiers, vararg)
		end

		node.tokens["arguments)"] = parser:ExpectValue(")", node.tokens["arguments("])

		if parser:IsValue(":") then
			node.tokens[":"] = parser:ExpectValue(":")
			node.return_types = ReadMultipleValues(parser, math.huge, ReadTypeExpression)
		elseif not parser:IsValue(",") then
			local start = parser:GetToken()
			node.statements = parser:ReadNodes({["end"] = true})
			node.tokens["end"] = parser:ExpectValue("end", start, start)
		end

		return node
	end

	local function ReadFunctionExpression(parser)
		if not parser:IsValue("function") then return end
		local node = parser:Node("expression", "function"):ExpectKeyword("function")
		ReadFunctionBody(parser, node)
		return node:End()
	end
	
	do
		function ExpectTypeExpression(parser, priority)
			local token = parser:GetToken()
		
			if
				not token or
				token.type == "end_of_file" or
				token.value == "}" or
				token.value == "," or
				token.value == "]" or
				(
					typesystem_syntax:IsKeyword(token) and
					not typesystem_syntax:IsPrefixOperator(token) and
					not typesystem_syntax:IsValue(token) and
					token.value ~= "function"
				)
			then
				parser:Error(
					"expected beginning of expression, got $1",
					nil,
					nil,
					token and
					token.value ~= "" and
					token.value or
					token.type
				)
				return
			end
		
			return ReadTypeExpression(parser, priority)
		end
		
		local function ReadParenthesisExpression(parser)
			if not parser:IsValue("(") then return end
			local pleft = parser:ExpectValue("(")
			local node = ReadTypeExpression(parser, 0)
		
			if not node or parser:IsValue(",") then
				local first_expression = node
				local node = parser:Node("expression", "tuple")
				
				if parser:IsValue(",") then
					first_expression.tokens[","] = parser:ExpectValue(",")
					node.expressions = ReadMultipleValues(parser, nil, ReadTypeExpression, 0)
				else
					node.expressions = {}
				end
		
				if first_expression then
					table.insert(node.expressions, 1, first_expression)
				end
				node.tokens["("] = pleft
				node:ExpectKeyword(")")
				return node:End()
			end
		
			node.tokens["("] = node.tokens["("] or {}
			table_insert(node.tokens["("], 1, pleft)
			node.tokens[")"] = node.tokens[")"] or {}
			table_insert(node.tokens[")"], parser:ExpectValue(")"))
			return node:End()
		end
		
		local function ReadPrefixOperatorExpression(parser)
			if not typesystem_syntax:IsPrefixOperator(parser:GetToken()) then return end
			local node = parser:Node("expression", "prefix_operator")
			node.value = parser:ReadToken()
			node.tokens[1] = node.value
			node.right = ReadTypeExpression(parser, math_huge)
			return node:End()
		end
		
		local function ReadValueExpression(parser)
			if not (parser:IsValue("...") and parser:IsType("letter", 1)) then return end
			local node = parser:Node("expression", "value")
			node.value = parser:ExpectValue("...")
			node.type_expression = ReadTypeExpression(parser)
			return node:End()
		end

		local function ReadTypeFunctionArgument(parser, expect_type)
			if parser:IsValue(")") then return end
		
			if expect_type or parser:IsType("letter") and parser:IsValue(":", 1) then
				local identifier = parser:ReadToken()
				local token = parser:ExpectValue(":")
				local exp = ExpectTypeExpression(parser)
				exp.tokens[":"] = token
				exp.identifier = identifier
				return exp
			end
		
			return ExpectTypeExpression(parser)
		end
		
		local function ReadFunctionSignatureExpression(parser)
			if not (parser:IsValue("function") and parser:IsValue("=", 1)) then return end
		
			local node = parser:Node("expression", "function_signature")
			node.stmnt = false
			node.tokens["function"] = parser:ExpectValue("function")
			node.tokens["="] = parser:ExpectValue("=")
		
			node.tokens["arguments("] = parser:ExpectValue("(")
			node.identifiers = ReadMultipleValues(parser, nil, ReadTypeFunctionArgument)
			node.tokens["arguments)"] = parser:ExpectValue(")")
		
			node.tokens[">"] = parser:ExpectValue(">")
		
			node.tokens["return("] = parser:ExpectValue("(")
			node.return_types = ReadMultipleValues(parser, nil, ReadTypeFunctionArgument)
			node.tokens["return)"] = parser:ExpectValue(")")
			
			return node
		end
		
		local function ReadTypeFunctionExpression(parser)
			if not (parser:IsValue("function") and parser:IsValue("<|", 1)) then return end
			local node = parser:Node("expression", "type_function")
			node.stmnt = false
			node.tokens["function"] = parser:ExpectValue("function")
			return ReadTypeFunctionBody(parser, node):End()
		end
		
		
		local function ReadAnalyzerFunctionExpression(parser)
			if not (parser:IsValue("analyzer") and parser:IsValue("function", 1)) then return end
			local node = parser:Node("expression", "analyzer_function")
			node.stmnt = false
			node.tokens["analyzer"] = parser:ExpectValue("analyzer")
			node.tokens["function"] = parser:ExpectValue("function")
			return ReadAnalyzerFunctionBody(parser, node):End()
		end
		
		local function ReadKeywordValueExpression(parser)
			if not typesystem_syntax:IsValue(parser:GetToken()) then return end
			local node = parser:Node("expression", "value")
			node.value = parser:ReadToken()
			return node:End()
		end
		
		local function read_table_entry(parser, i)
			if parser:IsValue("[") then
				local node = parser:Node("expression", "table_expression_value"):Store("expression_key", true):ExpectKeyword("[")
				node.key_expression = ReadTypeExpression(parser, 0)
				node:ExpectKeyword("]"):ExpectKeyword("=")
				node.value_expression = ReadTypeExpression(parser, 0)
				return node:End()
			elseif parser:IsType("letter") and parser:IsValue("=", 1) then
				local node = parser:Node("expression", "table_key_value"):ExpectSimpleIdentifier():ExpectKeyword("="):End()
				node.value_expression = ReadTypeExpression(parser, 0)
				return node:End()
			end
		
			local node = parser:Node("expression", "table_index_value"):Store("key", i)
			node.value_expression = ReadTypeExpression(parser, 0)
			return node:End()
		end
		
		local function ReadTypeTableExpression(parser)
			if not parser:IsValue("{") then return end
			local tree = parser:Node("expression", "type_table")
			tree:ExpectKeyword("{")
			tree.children = {}
			tree.tokens["separators"] = {}
		
			for i = 1, math_huge do
				if parser:IsValue("}") then break end
				local entry = read_table_entry(parser, i)
		
				if entry.spread then
					tree.spread = true
				end
		
				tree.children[i] = entry
		
				if not parser:IsValue(",") and not parser:IsValue(";") and not parser:IsValue("}") then
					parser:Error(
						"expected $1 got $2",
						nil,
						nil,
						{",", ";", "}"},
						(parser:GetToken() and parser:GetToken().value) or
						"no token"
					)
		
					break
				end
		
				if not parser:IsValue("}") then
					tree.tokens["separators"][i] = parser:ReadToken()
				end
			end
		
			tree:ExpectKeyword("}")
			return tree:End()
		end
		
		local function ReadStringExpression(parser)
			if not (parser:IsType("$") and parser:IsType("string", 1)) then return end
			local node = parser:Node("expression", "type_string")
			node.tokens["$"] = parser:ReadToken("...")
			node.value = parser:ExpectType("string")
			return node
		end
		
		local function ReadEmptyUnionExpression(parser)
			if not parser:IsValue("|") then return end
			local node = parser:Node("expression", "empty_union")
			node.tokens["|"] = parser:ReadToken("|")
			return node
		end
		

		local function is_call_expression(parser, offset)
			return
				parser:IsValue("(", offset) or
				parser:IsValue("<|", offset) or
				parser:IsValue("{", offset) or
				parser:IsType("string", offset) or
				(parser:IsValue("!", offset) and parser:IsValue("(", offset + 1))
		end
	
		local function ReadAsSubExpression(parser, node)
			if not parser:IsValue("as") then return end
			node.tokens["as"] = parser:ExpectValue("as")
			node.type_expression = ReadTypeExpression(parser)
		end
	
		local function ReadIndexSubExpression(parser)
			if not (parser:IsValue(".") and parser:IsType("letter", 1)) then return end
			local node = parser:Node("expression", "binary_operator")
			node.value = parser:ReadToken()
			node.right = parser:Node("expression", "value"):Store("value", parser:ExpectType("letter")):End()
			return node:End()
		end
	
		local function ReadSelfCallSubExpression(parser)
			if not (parser:IsValue(":") and parser:IsType("letter", 1) and is_call_expression(parser, 2)) then return end
			local node = parser:Node("expression", "binary_operator")
			node.value = parser:ReadToken()
			node.right = parser:Node("expression", "value"):Store("value", parser:ExpectType("letter")):End()
			return node:End()
		end
	
		local function ReadPostfixOperatorSubExpression(parser)
			if not typesystem_syntax:IsPostfixOperator(parser:GetToken()) then return end
			return
				parser:Node("expression", "postfix_operator"):Store("value", parser:ReadToken()):End()
		end
	
		local function ReadCallSubExpression(parser)
			if not is_call_expression(parser, 0) then return end
			local node = parser:Node("expression", "postfix_call")
	
			if parser:IsValue("{") then
				node.expressions = {ReadTypeTableExpression(parser)}
			elseif parser:IsType("string") then
				node.expressions = {
						parser:Node("expression", "value"):Store("value", parser:ReadToken()):End(),
					}
			elseif parser:IsValue("<|") then
				node.tokens["call("] = parser:ExpectValue("<|")
				node.expressions = ReadMultipleValues(parser, nil, ReadTypeExpression, 0)
				node.tokens["call)"] = parser:ExpectValue("|>")
			else
				node.tokens["call("] = parser:ExpectValue("(")
				node.expressions = ReadMultipleValues(parser, nil, ReadTypeExpression, 0)
				node.tokens["call)"] = parser:ExpectValue(")")
			end
	
			node.type_call = true
			return node:End()
		end
	
		local function ReadPostfixIndexExpressionSubExpression(parser)
			if not parser:IsValue("[") then return end
			local node = parser:Node("expression", "postfix_expression_index"):ExpectKeyword("[")
			node.expression = ExpectTypeExpression(parser)
			return node:ExpectKeyword("]"):End()
		end
	
		local function ReadSubExpression(parser, node)
			for _ = 1, parser:GetLength() do
				local left_node = node
				local found = ReadIndexSubExpression(parser) or
					ReadSelfCallSubExpression(parser) or
					ReadPostfixOperatorSubExpression(parser) or
					ReadCallSubExpression(parser) or
					ReadPostfixIndexExpressionSubExpression(parser) or
					ReadAsSubExpression(parser, left_node)
				if not found then break end
				found.left = left_node
	
				if left_node.value and left_node.value.value == ":" then
					found.parser_call = true
				end
	
				node = found
			end
	
			return node
		end
	
		function ReadTypeExpression(parser, priority)
			priority = priority or 0
			local node
			local force_upvalue
		
			if parser:IsValue("^") then
				force_upvalue = true
				parser:Advance(1)
			end
		
			node = ReadParenthesisExpression(parser) or
				ReadEmptyUnionExpression(parser) or
				ReadPrefixOperatorExpression(parser) or
				ReadAnalyzerFunctionExpression(parser) or
				ReadFunctionSignatureExpression(parser) or
				ReadTypeFunctionExpression(parser) or
				ReadFunctionExpression(parser) or
				ReadValueExpression(parser) or
				ReadKeywordValueExpression(parser) or
				ReadTypeTableExpression(parser) or
				ReadStringExpression(parser)
			local first = node
		
			if node then
				node = ReadSubExpression(parser, node)
		
				if
					first.kind == "value" and
					(first.value.type == "letter" or first.value.value == "...")
				then
					first.standalone_letter = node
					first.force_upvalue = force_upvalue
				end
			end
		
			while typesystem_syntax:GetBinaryOperatorInfo(parser:GetToken()) and
			typesystem_syntax:GetBinaryOperatorInfo(parser:GetToken()).left_priority > priority do
				local left_node = node
				node = parser:Node("expression", "binary_operator")
				node.value = parser:ReadToken()
				node.left = left_node
				node.right = ReadTypeExpression(parser, typesystem_syntax:GetBinaryOperatorInfo(node.value).right_priority)
				node:End()
			end
		
			return node
		end
	end
	do

		local function read_table_spread(parser)
			if not (parser:IsValue("...") and (parser:IsType("letter", 1) or parser:IsValue("{", 1) or parser:IsValue("(", 1))) then return end
			local node = parser:Node("expression", "table_spread"):ExpectKeyword("...")
			node.expression = ExpectRuntimeExpression(parser)
			return node:End()
		end
		
		local function read_table_entry(parser, i)
			if parser:IsValue("[") then
				local node = parser:Node("expression", "table_expression_value"):Store("expression_key", true):ExpectKeyword("[")
				node.key_expression = ExpectRuntimeExpression(parser, 0)
				node:ExpectKeyword("]"):ExpectKeyword("=")
				node.value_expression = ExpectRuntimeExpression(parser, 0)
				return node:End()
			elseif parser:IsType("letter") and parser:IsValue("=", 1) then
				local node = parser:Node("expression", "table_key_value"):ExpectSimpleIdentifier():ExpectKeyword("=")
				local spread = read_table_spread(parser)
		
				if spread then
					node.spread = spread
				else
					node.value_expression = ExpectRuntimeExpression(parser)
				end
		
				return node:End()
			end
		
			local node = parser:Node("expression", "table_index_value")
			local spread = read_table_spread(parser)
		
			if spread then
				node.spread = spread
			else
				node.value_expression = ExpectRuntimeExpression(parser)
			end
		
			node.key = i
			return node:End()
		end
		
		local function ReadTableExpression(parser)
			if not parser:IsValue("{") then return end
			local tree = parser:Node("expression", "table")
			tree:ExpectKeyword("{")
			tree.children = {}
			tree.tokens["separators"] = {}
		
			for i = 1, parser:GetLength() do
				if parser:IsValue("}") then break end
				local entry = read_table_entry(parser, i)
		
				if entry.kind == "table_index_value" then
					tree.is_array = true
				else
					tree.is_dictionary = true
				end
		
				if entry.spread then
					tree.spread = true
				end
		
				tree.children[i] = entry
		
				if not parser:IsValue(",") and not parser:IsValue(";") and not parser:IsValue("}") then
					parser:Error(
						"expected $1 got $2",
						nil,
						nil,
						{",", ";", "}"},
						(parser:GetToken() and parser:GetToken().value) or
						"no token"
					)
		
					break
				end
		
				if not parser:IsValue("}") then
					tree.tokens["separators"][i] = parser:ReadToken()
				end
			end
		
			tree:ExpectKeyword("}")
			return tree:End()
		end
		

		local function is_call_expression(parser, offset)
			return
				parser:IsValue("(", offset) or
				parser:IsValue("<|", offset) or
				parser:IsValue("{", offset) or
				parser:IsType("string", offset) or
				(parser:IsValue("!", offset) and parser:IsValue("(", offset + 1))
		end

		local function read_call_expression(parser)
			local node = parser:Node("expression", "postfix_call")

			if parser:IsValue("{") then
				node.expressions = {ReadTableExpression(parser)}
			elseif parser:IsType("string") then
				node.expressions = {
						parser:Node("expression", "value"):Store("value", parser:ReadToken()):End(),
					}
			elseif parser:IsValue("<|") then
				node.tokens["call("] = parser:ExpectValue("<|")
				node.expressions = ReadMultipleValues(parser, nil, ReadTypeExpression, 0)
				node.tokens["call)"] = parser:ExpectValue("|>")
				node.type_call = true
			elseif parser:IsValue("!") then
				node.tokens["!"] = parser:ExpectValue("!")
				node.tokens["call("] = parser:ExpectValue("(")
				node.expressions = ReadMultipleValues(parser, nil, ReadTypeExpression, 0)
				node.tokens["call)"] = parser:ExpectValue(")")
				node.type_call = true
			else
				node.tokens["call("] = parser:ExpectValue("(")
				node.expressions = ReadMultipleValues(parser, nil, ReadRuntimeExpression, 0)
				node.tokens["call)"] = parser:ExpectValue(")")
			end

			return node:End()
		end

		local function ReadIndexSubExpression(parser)
			if not (parser:IsValue(".") and parser:IsType("letter", 1)) then return end
			local node = parser:Node("expression", "binary_operator")
			node.value = parser:ReadToken()
			node.right = parser:Node("expression", "value"):Store("value", parser:ExpectType("letter")):End()
			return node:End()
		end

		local function ReadSelfCallSubExpression(parser)
			if not (parser:IsValue(":") and parser:IsType("letter", 1) and is_call_expression(parser, 2)) then return end
			local node = parser:Node("expression", "binary_operator")
			node.value = parser:ReadToken()
			node.right = parser:Node("expression", "value"):Store("value", parser:ExpectType("letter")):End()
			return node:End()
		end

		local function ReadPostfixOperatorSubExpression(parser)
			if not runtime_syntax:IsPostfixOperator(parser:GetToken()) then return end
			return
				parser:Node("expression", "postfix_operator"):Store("value", parser:ReadToken()):End()
		end

		local function ReadCallSubExpression(parser)
			if not is_call_expression(parser, 0) then return end
			return read_call_expression(parser)
		end

		local function ReadPostfixIndexExpressionSubExpression(parser)
			if not parser:IsValue("[") then return end
			local node = parser:Node("expression", "postfix_expression_index"):ExpectKeyword("[")
			node.expression = ExpectRuntimeExpression(parser)
			return node:ExpectKeyword("]"):End()
		end

		local function read_and_add_explicit_type(parser, node)
			if parser:IsValue(":") and (not parser:IsType("letter", 1) or not is_call_expression(parser, 2)) then
				node.tokens[":"] = parser:ExpectValue(":")
				node.type_expression = ExpectTypeExpression(parser, 0)
			elseif parser:IsValue("as") then
				node.tokens["as"] = parser:ExpectValue("as")
				node.type_expression = ExpectTypeExpression(parser, 0)
			elseif parser:IsValue("is") then
				node.tokens["is"] = parser:ExpectValue("is")
				node.type_expression = ExpectTypeExpression(parser, 0)
			end
		end

		local function ReadSubExpression(parser, node)
			for _ = 1, parser:GetLength() do
				local left_node = node
				read_and_add_explicit_type(parser, node)
				
				local found = ReadIndexSubExpression(parser) or
					ReadSelfCallSubExpression(parser) or
					ReadCallSubExpression(parser) or
					ReadPostfixOperatorSubExpression(parser) or
					ReadPostfixIndexExpressionSubExpression(parser)
					
				if not found then break end
				found.left = left_node

				if left_node.value and left_node.value.value == ":" then
					found.parser_call = true
				end

				node = found
			end

			return node
		end

		local function ReadPrefixOperatorExpression(parser)
			if not runtime_syntax:IsPrefixOperator(parser:GetToken()) then return end
			local node = parser:Node("expression", "prefix_operator")
			node.value = parser:ReadToken()
			node.tokens[1] = node.value
			node.right = ExpectRuntimeExpression(parser, math.huge)
			return node:End()
		end

		local function ReadParenthesisExpression(parser)
			if not parser:IsValue("(") then return end
			local pleft = parser:ExpectValue("(")
			local node = ReadRuntimeExpression(parser, 0)

			if not node then
				parser:Error("empty parentheses group", pleft)
				return
			end

			node.tokens["("] = node.tokens["("] or {}
			table_insert(node.tokens["("], 1, pleft)
			node.tokens[")"] = node.tokens[")"] or {}
			table_insert(node.tokens[")"], parser:ExpectValue(")"))
			return node
		end

		local function ReadValueExpression(parser)
			if not runtime_syntax:IsValue(parser:GetToken()) then return end
			return parser:Node("expression", "value"):Store("value", parser:ReadToken()):End()
		end

		local function check_integer_division_operator(parser, node)
			if node and not node.idiv_resolved then
				for i, token in ipairs(node.whitespace) do
					if token.value:find("\n", nil, true) then break end
					if token.type == "line_comment" and token.value:sub(1, 2) == "//" then
						table_remove(node.whitespace, i)
						local Code = require("nattlua.code.code")
						local tokens = require("nattlua.lexer.lexer")(Code("/idiv" .. token.value:sub(2), "")):GetTokens()

						for _, token in ipairs(tokens) do
							check_integer_division_operator(parser, token)
						end

						parser:AddTokens(tokens)
						node.idiv_resolved = true

						break
					end
				end
			end
		end

		local function ReadAnalyzerFunctionExpression(parser)
			if not parser:IsValue("analyzer") or not parser:IsValue("function", 1) then return end
			local node = parser:Node("expression", "analyzer_function"):ExpectKeyword("analyzer"):ExpectKeyword("function")
			ReadAnalyzerFunctionBody(parser, node)
			return node:End()
		end


		function ExpectRuntimeExpression(parser, priority)
			local token = parser:GetToken()
			if
				not token or
				token.type == "end_of_file" or
				token.value == "}" or
				token.value == "," or
				token.value == "]" or
				(
					runtime_syntax:IsKeyword(token) and
					not runtime_syntax:IsPrefixOperator(token) and
					not runtime_syntax:IsValue(token) and
					token.value ~= "function"
				)
			then
				parser:Error(
					"expected beginning of expression, got $1",
					nil,
					nil,
					token and
					token.value ~= "" and
					token.value or
					token.type
				)
				return
			end

			return ReadRuntimeExpression(parser, priority)
		end
		
		local function ReadImportExpression(parser)
			if not (parser:IsValue("import") and parser:IsValue("(", 1)) then return end
			local node = parser:Node("expression", "import")
			node.tokens["import"] = parser:ExpectValue("import")
			node.tokens["("] = {parser:ExpectValue("(")}
			local start = parser:GetToken()
			node.expressions = ReadMultipleValues(parser, nil, ReadRuntimeExpression, 0)
			local root = parser.config.path and parser.config.path:match("(.+/)") or ""
			node.path = root .. node.expressions[1].value.value:sub(2, -2)
			local nl = require("nattlua")
			local root, err = nl.ParseFile(parser:ResolvePath(node.path), parser.root)

			if not root then
				parser:Error("error importing file: $1", start, start, err)
			end

			node.root = root.SyntaxTree
			node.analyzer = root
			node.tokens[")"] = {parser:ExpectValue(")")}
			parser.root.imports = parser.root.imports or {}
			table.insert(parser.root.imports, node)
			return node
		end
	

		function ReadRuntimeExpression(parser, priority)
			if parser:GetPreferTypesystem() then
				return ReadTypeExpression(parser, priority)
			end

			priority = priority or 0
			local node = ReadParenthesisExpression(parser) or
				ReadPrefixOperatorExpression(parser) or
				ReadAnalyzerFunctionExpression(parser) or
				ReadFunctionExpression(parser) or
				ReadImportExpression(parser) or
				ReadValueExpression(parser) or
				ReadTableExpression(parser)
			local first = node

			if node then
				node = ReadSubExpression(parser, node)

				if
					first.kind == "value" and
					(first.value.type == "letter" or first.value.value == "...")
				then
					first.standalone_letter = node
				end
			end

			check_integer_division_operator(parser, parser:GetToken())

			while runtime_syntax:GetBinaryOperatorInfo(parser:GetToken()) and
			runtime_syntax:GetBinaryOperatorInfo(parser:GetToken()).left_priority > priority do
				local left_node = node
				node = parser:Node("expression", "binary_operator")
				node.value = parser:ReadToken()
				node.left = left_node

				if node.left then
					node.left.parent = node
				end

				node.right = ExpectRuntimeExpression(parser, runtime_syntax:GetBinaryOperatorInfo(node.value).right_priority)

				if not node.right then
					local token = parser:GetToken()
					parser:Error(
						"expected right side to be an expression, got $1",
						nil,
						nil,
						token and
						token.value ~= "" and
						token.value or
						token.type
					)
					return
				end

				node:End()
			end

			return node
		end
	end



	
			
	local function ReadDestructureAssignmentStatement(parser)
		if not IsDestructureStatement(parser) then return end
		local node = parser:Node("statement", "destructure_assignment")
		do
			if parser:IsType("letter") then
				local val = parser:Node("expression", "value")
				val.value = parser:ReadToken()
				node.default = val:End()
				node.default_comma = parser:ExpectValue(",")
			end
		
			node.tokens["{"] = parser:ExpectValue("{")
			node.left = ReadMultipleValues(parser, nil, ReadIdentifier)
			node.tokens["}"] = parser:ExpectValue("}")
			node.tokens["="] = parser:ExpectValue("=")
			node.right = ReadRuntimeExpression(parser, 0)
		end
		return node:End()
	end
	local function ReadLocalDestructureAssignmentStatement(parser)
		if not IsLocalDestructureAssignmentStatement(parser) then return end
		local node = parser:Node("statement", "local_destructure_assignment")
		node.tokens["local"] = parser:ExpectValue("local")
	
		if parser:IsValue("type") then
			node.tokens["type"] = parser:ExpectValue("type")
			node.environment = "typesystem"
		end
	
		do -- remaining
			if parser:IsType("letter") then
				local val = parser:Node("expression", "value")
				val.value = parser:ReadToken()
				node.default = val:End()
				node.default_comma = parser:ExpectValue(",")
			end
		
			node.tokens["{"] = parser:ExpectValue("{")
			node.left = ReadMultipleValues(parser, nil, ReadIdentifier)
			node.tokens["}"] = parser:ExpectValue("}")
			node.tokens["="] = parser:ExpectValue("=")
			node.right = ReadRuntimeExpression(parser, 0)
		end

		return node:End()
	end
	local function ReadFunctionStatement(self)
		if not self:IsValue("function") then return end
		local node = self:Node("statement", "function")
		node.tokens["function"] = self:ExpectValue("function")
		node.expression = ReadIndexExpression(self)

		if node.expression and node.expression.kind == "binary_operator" then
			node.self_call = node.expression.right.self_call
		end

		if self:IsValue("<|") then
			node.kind = "type_function"
			ReadTypeFunctionBody(self, node)
		else
			ReadFunctionBody(self, node)
		end

		return node:End()
	end
	local function ReadLocalFunctionStatement(parser)
		if not (parser:IsValue("local") and parser:IsValue("function", 1)) then return end
		local node = parser:Node("statement", "local_function"):ExpectKeyword("local"):ExpectKeyword("function")
			:ExpectSimpleIdentifier()
			ReadFunctionBody(parser, node)
		return node:End()
	end
	local function ReadAnalyzerFunctionStatement(parser)
		if not (parser:IsValue("analyzer") and parser:IsValue("function", 1)) then return end
		local node = parser:Node("statement", "analyzer_function")
		node.tokens["analyzer"] = parser:ExpectValue("analyzer")
		node.tokens["function"] = parser:ExpectValue("function")
		local force_upvalue

		if parser:IsValue("^") then
			force_upvalue = true
			node.tokens["^"] = parser:ReadToken()
		end

		node.expression = ReadIndexExpression(parser)

		do -- hacky
			if node.expression.left then
				node.expression.left.standalone_letter = node
				node.expression.left.force_upvalue = force_upvalue
			else
				node.expression.standalone_letter = node
				node.expression.force_upvalue = force_upvalue
			end

			if node.expression.value.value == ":" then
				node.self_call = true
			end
		end

		ReadAnalyzerFunctionBody(parser, node, true)
		return node:End()
	end
	local function ReadLocalAnalyzerFunctionStatement(parser)
		if not (parser:IsValue("local") and parser:IsValue("analyzer", 1) and parser:IsValue("function", 2)) then return end
		local node = parser:Node("statement", "local_analyzer_function"):ExpectKeyword("local"):ExpectKeyword("analyzer")
			:ExpectKeyword("function")
			:ExpectSimpleIdentifier()
		ReadAnalyzerFunctionBody(parser, node, true)
		return node:End()
	end
	local function ReadLocalTypeFunctionStatement(parser)
		if not (parser:IsValue("local") and parser:IsValue("function", 1) and (parser:IsValue("<|", 3) or parser:IsValue("!", 3))) then return end
		local node = parser:Node("statement", "local_type_function"):ExpectKeyword("local"):ExpectKeyword("function")
			:ExpectSimpleIdentifier()
		ReadTypeFunctionBody(parser, node)
		return node:End()
	end
	local function ReadBreakStatement(parser)
		if not parser:IsValue("break") then return nil end
		return parser:Node("statement", "break"):ExpectKeyword("break"):End()
	end
	local function ReadDoStatement(parser)
		if not parser:IsValue("do") then return nil end
		return
			parser:Node("statement", "do"):ExpectKeyword("do"):ExpectNodesUntil("end"):ExpectKeyword("end", "do")
			:End()
	end
	local function ReadGenericForStatement(parser)
		if not parser:IsValue("for") then return nil end
		local node = parser:Node("statement", "generic_for")
		node:ExpectKeyword("for")
		node.identifiers = ReadMultipleValues(parser, nil, ReadIdentifier)
		node:ExpectKeyword("in")
		node.expressions = ReadMultipleValues(parser, math.huge, ExpectRuntimeExpression, 0)
		return
			node:ExpectKeyword("do"):ExpectNodesUntil("end"):ExpectKeyword("end", "do"):End()
	end
	local function ReadGotoLabelStatement(parser)
		if not parser:IsValue("::") then return nil end
		return
			parser:Node("statement", "goto_label"):ExpectKeyword("::"):ExpectSimpleIdentifier():ExpectKeyword("::")
			:End()
	end
	local function ReadGotoStatement(parser)
		if not parser:IsValue("goto") then return nil end
		return
			parser:IsType("letter", 1) and
			parser:Node("statement", "goto"):ExpectKeyword("goto"):ExpectSimpleIdentifier():End()
	end
	local function ReadIfStatement(parser)
		if not parser:IsValue("if") then return nil end
		local node = parser:Node("statement", "if")
		node.expressions = {}
		node.statements = {}
		node.tokens["if/else/elseif"] = {}
		node.tokens["then"] = {}

		for i = 1, parser:GetLength() do
			local token

			if i == 1 then
				token = parser:ExpectValue("if")
			else
				token = parser:ReadValues(
					{
						["else"] = true,
						["elseif"] = true,
						["end"] = true,
					}
				)
			end

			if not token then return end -- TODO: what happens here? :End is never called
			node.tokens["if/else/elseif"][i] = token

			if token.value ~= "else" then
				node.expressions[i] = ExpectRuntimeExpression(parser, 0)
				node.tokens["then"][i] = parser:ExpectValue("then")
			end

			node.statements[i] = parser:ReadNodes({
				["end"] = true,
				["else"] = true,
				["elseif"] = true,
			})
			if parser:IsValue("end") then break end
		end

		node:ExpectKeyword("end")
		return node:End()
	end
	local function ReadLocalAssignmentStatement(parser)
		if not parser:IsValue("local") then return end
		local node = parser:Node("statement", "local_assignment")
		node:ExpectKeyword("local")
		node.left = ReadMultipleValues(parser, nil, ReadIdentifier)

		if parser:IsValue("=") then
			node:ExpectKeyword("=")
			node.right = ReadMultipleValues(parser, nil, ReadRuntimeExpression, 0)
		end

		return node:End()
	end
	local function ReadNumericForStatement(parser)
		if not (parser:IsValue("for") and parser:IsValue("=", 2)) then return nil end
		local node = parser:Node("statement", "numeric_for")
		node:ExpectKeyword("for")
		node.identifiers = ReadMultipleValues(parser, 1, ReadIdentifier)
		node:ExpectKeyword("=")
		node.expressions = ReadMultipleValues(parser, 3, ExpectRuntimeExpression, 0)
		return
			node:ExpectKeyword("do"):ExpectNodesUntil("end"):ExpectKeyword("end", "do"):End()
	end
	local function ReadRepeatStatement(parser)
		if not parser:IsValue("repeat") then return nil end
		local node = parser:Node("statement", "repeat"):ExpectKeyword("repeat"):ExpectNodesUntil("until"):ExpectKeyword("until")
		node.expression = ExpectRuntimeExpression(parser)
		return node:End()
	end
	local function ReadSemicolonStatement(parser)
		if not parser:IsValue(";") then return nil end
		local node = parser:Node("statement", "semicolon")
		node.tokens[";"] = parser:ExpectValue(";")
		return node:End()
	end
	local function ReadReturnStatement(parser)
		if not parser:IsValue("return") then return nil end
		local node = parser:Node("statement", "return"):ExpectKeyword("return")
		node.expressions = ReadMultipleValues(parser, nil, ReadRuntimeExpression, 0)
		return node:End()
	end
	local function ReadWhileStatement(parser)
		if not parser:IsValue("while") then return nil end
		local node = parser:Node("statement", "while"):ExpectKeyword("while")
		node.expression = ExpectRuntimeExpression(parser)
		return
			node:ExpectKeyword("do"):ExpectNodesUntil("end"):ExpectKeyword("end", "do"):End()
	end
	local function ReadContinueStatement(parser)
		return
			parser:IsValue("continue") and
			parser:Node("statement", "continue"):ExpectKeyword("continue"):End()
	end
	local function ReadDebugCodeStatement(parser)
		if parser:IsType("type_code") then
			local node = parser:Node("statement", "type_code")
			local code = parser:Node("expression", "value")
			code.value = parser:ExpectType("type_code")
			code:End()
			node.lua_code = code
			return node:End()
		elseif parser:IsType("parser_code") then
			local token = parser:ExpectType("parser_code")
			assert(loadstring("local parser = ...;" .. token.value:sub(3)))(parser)
			local node = parser:Node("statement", "parser_code")
			local code = parser:Node("expression", "value")
			code.value = token
			node.lua_code = code:End()
			return node:End()
		end
	end
	local function ReadLocalTypeAssignmentStatement(parser)
		if not (
			parser:IsValue("local") and parser:IsValue("type", 1) and
			runtime_syntax:GetTokenType(parser:GetToken(2)) == "letter"
		) then return end
		local node = parser:Node("statement", "local_assignment")
		node.tokens["local"] = parser:ExpectValue("local")
		node.tokens["type"] = parser:ExpectValue("type")
		node.left = ReadMultipleValues(parser, nil, ReadIdentifier)
		node.environment = "typesystem"

		if parser:IsValue("=") then
			node.tokens["="] = parser:ExpectValue("=")
			node.right = ReadMultipleValues(parser, nil, ReadTypeExpression)
		end

		return node:End()
	end
	local function ReadTypeAssignmentStatement(parser)
		if not (parser:IsValue("type") and (parser:IsType("letter", 1) or parser:IsValue("^", 1))) then return end
		local node = parser:Node("statement", "assignment")
		node.tokens["type"] = parser:ExpectValue("type")
		node.left = ReadMultipleValues(parser, nil, ReadTypeExpression, 0)
		node.environment = "typesystem"

		if parser:IsValue("=") then
			node.tokens["="] = parser:ExpectValue("=")
			node.right = ReadMultipleValues(parser, nil, ReadTypeExpression, 0)
		end

		return node:End()
	end

	local function ReadCallOrAssignmentStatement(parser)
		local start = parser:GetToken()
		local left = ReadMultipleValues(parser, math.huge, ExpectRuntimeExpression, 0)

		if parser:IsValue("=") then
			local node = parser:Node("statement", "assignment")
			node:ExpectKeyword("=")
			node.left = left
			node.right = ReadMultipleValues(parser, math.huge, ExpectRuntimeExpression, 0)
			return node:End()
		end

		if left[1] and (left[1].kind == "postfix_call" or left[1].kind == "import") and not left[2] then
			local node = parser:Node("statement", "call_expression")
			node.value = left[1]
			node.tokens = left[1].tokens
			return node:End()
		end

		parser:Error(
			"expected assignment or call expression got $1 ($2)",
			start,
			parser:GetToken(),
			parser:GetToken().type,
			parser:GetToken().value
		)
	end

	function META:ReadRootNode()
		local node = self:Node("statement", "root")
		self.root = self.config and self.config.root or node
		local shebang

		if self:IsType("shebang") then
			shebang = self:Node("statement", "shebang")
			shebang.tokens["shebang"] = self:ExpectType("shebang")
			shebang:End()
			node.tokens["shebang"] = shebang.tokens["shebang"]
		end

		node.statements = self:ReadNodes()

		if shebang then
			table.insert(node.statements, 1, shebang)
		end

		if self:IsType("end_of_file") then
			local eof = self:Node("statement", "end_of_file")
			eof.tokens["end_of_file"] = self.tokens[#self.tokens]
			eof:End()
			table.insert(node.statements, eof)
			node.tokens["eof"] = eof.tokens["end_of_file"]
		end

		return node:End()
	end

	function META:ReadNode()
		if self:IsType("end_of_file") then return end
		return
			ReadDebugCodeStatement(self) or
			ReadReturnStatement(self) or
			ReadBreakStatement(self) or
			ReadContinueStatement(self) or
			ReadSemicolonStatement(self) or
			ReadGotoStatement(self) or
			ReadGotoLabelStatement(self) or
			ReadRepeatStatement(self) or
			ReadAnalyzerFunctionStatement(self) or
			ReadFunctionStatement(self) or
			ReadLocalTypeFunctionStatement(self) or
			ReadLocalFunctionStatement(self) or
			ReadLocalAnalyzerFunctionStatement(self) or
			ReadLocalTypeAssignmentStatement(self) or
			ReadLocalDestructureAssignmentStatement(self) or
			ReadLocalAssignmentStatement(self) or
			ReadTypeAssignmentStatement(self) or
			ReadDoStatement(self) or
			ReadIfStatement(self) or
			ReadWhileStatement(self) or
			ReadNumericForStatement(self) or
			ReadGenericForStatement(self) or
			ReadDestructureAssignmentStatement(self) or
			ReadCallOrAssignmentStatement(self)
	end
end

return function(tokens--[[#: {[1 .. inf] = Token}]], code --[[#: Code]], config--[[#: any]])
	return setmetatable(
		{
			config = config,
			Code = code,
			nodes = {},
			current_statement = false,
			current_expression = false,
			root = false,
			i = 1,
			tokens = tokens,
		},
		META
	)
end
