--[[#local type { Token, TokenType } = import_type("nattlua/lexer/token.nlua")]]

--[[#local type NodeType = "expression" | "statement"]]
--[[#local type Node = any]]
local syntax = require("nattlua.syntax.syntax")
local ipairs = _G.ipairs
local pairs = _G.pairs
local setmetatable = _G.setmetatable
local type = _G.type
local table = require("table")
local TEST = false
local META = {}
META.__index = META
--[[# --]]META.Emitter = require("nattlua.transpiler.emitter")
META.syntax = syntax
--[[#type META.@Self = {
		config = any,
		nodes = {[number] = any} | {},
		name = string,
		code = string,
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
			code = string,
			name = string,
			parser = PARSER.@Self,
			statements = {[number] = self} | {},
			tokens = {[string] = Token},
		}]]
--[[#	type PARSER.@Self.nodes = {[number] = META.@Self} | {}]]

	function META:__tostring()
		if self.type == "statement" then
			local str = "[" .. self.type .. " - " .. self.kind .. "]"

			if self.code and self.name and self.name:sub(1, 1) == "@" then
				local helpers = require("nattlua.other.helpers")
				local data = helpers.SubPositionToLinePosition(self.code, helpers.LazyFindStartStop(self))

				if data and data.line_start then
					str = str .. " @ " .. self.name:sub(2) .. ":" .. data.line_start
				else
					str = str .. " @ " .. self.name:sub(2) .. ":" .. "?"
				end
			else
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
				code = self.code,
				name = self.name,
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
		self.code,
		self.name,
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
	local ReadBreak = require("nattlua.parser.statements.break").ReadBreak
	local ReadDo = require("nattlua.parser.statements.do").ReadDo
	local ReadGenericFor = require("nattlua.parser.statements.generic_for").ReadGenericFor
	local ReadGotoLabel = require("nattlua.parser.statements.goto_label").ReadGotoLabel
	local ReadGoto = require("nattlua.parser.statements.goto").ReadGoto
	local ReadIf = require("nattlua.parser.statements.if").ReadIf
	local ReadLocalAssignment = require("nattlua.parser.statements.local_assignment").ReadLocalAssignment
	local ReadNumericFor = require("nattlua.parser.statements.numeric_for").ReadNumericFor
	local ReadRepeat = require("nattlua.parser.statements.repeat").ReadRepeat
	local ReadSemicolon = require("nattlua.parser.statements.semicolon").ReadSemicolon
	local ReadReturn = require("nattlua.parser.statements.return").ReadReturn
	local ReadWhile = require("nattlua.parser.statements.while").ReadWhile
	local ReadFunction = require("nattlua.parser.statements.function").ReadFunction
	local ReadLocalFunction = require("nattlua.parser.statements.local_function").ReadLocalFunction
	local ReadContinue = require("nattlua.parser.statements.extra.continue").ReadContinue
	local ReadDestructureAssignment = require("nattlua.parser.statements.extra.destructure_assignment").ReadDestructureAssignment
	local ReadLocalDestructureAssignment = require("nattlua.parser.statements.extra.local_destructure_assignment")
		.ReadLocalDestructureAssignment
	local ReadAnalyzerFunction = require("nattlua.parser.statements.typesystem.analyzer_function").ReadAnalyzerFunction
	local ReadLocalAnalyzerFunction = require("nattlua.parser.statements.typesystem.local_analyzer_function").ReadLocalAnalyzerFunction
	local ReadLocalTypeFunction = require("nattlua.parser.statements.typesystem.local_type_function").ReadLocalTypeFunction
	local ReadDebugCode = require("nattlua.parser.statements.typesystem.debug_code").ReadDebugCode
	local ReadLocalTypeAssignment = require("nattlua.parser.statements.typesystem.local_assignment").ReadLocalAssignment
	local ReadTypeAssignment = require("nattlua.parser.statements.typesystem.assignment").ReadAssignment
	local ReadCallOrAssignment = require("nattlua.parser.statements.call_or_assignment").ReadCallOrAssignment
	local ReadRoot = require("nattlua.parser.statements.root").ReadRoot

	function META:ReadRootNode()
		return ReadRoot(self)
	end

	function META:ReadNode()
		if self:IsType("end_of_file") then return end
		return
			ReadDebugCode(self) or
			ReadReturn(self) or
			ReadBreak(self) or
			ReadContinue(self) or
			ReadSemicolon(self) or
			ReadGoto(self) or
			ReadGotoLabel(self) or
			ReadRepeat(self) or
			ReadAnalyzerFunction(self) or
			ReadFunction(self) or
			ReadLocalTypeFunction(self) or
			ReadLocalFunction(self) or
			ReadLocalAnalyzerFunction(self) or
			ReadLocalTypeAssignment(self) or
			ReadLocalDestructureAssignment(self) or
			ReadLocalAssignment(self) or
			ReadTypeAssignment(self) or
			ReadDo(self) or
			ReadIf(self) or
			ReadWhile(self) or
			ReadNumericFor(self) or
			ReadGenericFor(self) or
			ReadDestructureAssignment(self) or
			ReadCallOrAssignment(self)
	end
end

return function(tokens--[[#: {[1 .. inf] = Token}]], config--[[#: any]])
	return setmetatable(
		{
			config = config,
			nodes = {},
			name = "",
			code = "",
			current_statement = false,
			current_expression = false,
			root = false,
			i = 1,
			tokens = tokens,
		},
		META
	)
end
