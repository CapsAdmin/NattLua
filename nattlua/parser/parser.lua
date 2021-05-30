local syntax = require("nattlua.syntax.syntax")
local ipairs = _G.ipairs
local pairs = _G.pairs
local setmetatable = _G.setmetatable
local type = _G.type
local table = require("table")
local META = {}
META.__index = META
META.Emitter = require("nattlua.transpiler.emitter")
META.syntax = syntax

do
	local PARSER = META
	local META = {}
	META.__index = META
	META.Type = "node"

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

	function META:Render(op)
		local em = PARSER.Emitter(op or {preserve_whitespace = false, no_newlines = true})

		if self.type == "expression" then
			em:EmitExpression(self)
		else
			em:EmitStatement(self)
		end

		return em:Concat()
	end

	function META:IsWrappedInParenthesis()
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

	function META:FindNodesByType(what, out)
		out = out or {}

		for _, child in ipairs(self:GetNodes()) do
			if child.kind == what then
				table.insert(out, child)
			elseif child:GetNodes() then
				child:FindNodesByType(what, out)
			end
		end

		return out
	end

	do
		local function expect(node, parser, func, what, start, stop, alias)
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

		function META:ExpectAliasedKeyword(what, alias, start, stop)
			expect(
				self,
				self.parser,
				self.parser.ReadValue,
				what,
				start,
				stop,
				alias
			)
			return self
		end

		function META:ExpectKeyword(what, start, stop)
			expect(
				self,
				self.parser,
				self.parser.ReadValue,
				what,
				start,
				stop
			)
			return self
		end
	end

	function META:ExpectNodesUntil(what)
		self.statements = self.parser:ReadNodes(type(what) == "table" and what or {[what] = true})
		return self
	end

	function META:ExpectSimpleIdentifier()
		self.tokens["identifier"] = self.parser:ReadType("letter")
		return self
	end

	function META:Store(key, val)
		self[key] = val
		return self
	end

	function META:End()
		table.remove(self.parser.nodes, 1)
		return self
	end

	local id = 0

	function PARSER:Node(type, kind)
		local node = {}
		node.type = type
		node.tokens = {}
		node.kind = kind
		node.id = id
		node.code = self.code
		node.name = self.name
		node.parser = self
		id = id + 1
		setmetatable(node, META)

		if type == "expression" then
			self.current_expression = node
		else
			self.current_statement = node
		end

		if self.OnNode then
			self:OnNode(node)
		end

		node.parent = self.nodes[#self.nodes]
		table.insert(self.nodes, node)
		return node
	end
end

function META:Error(msg, start, stop, ...)
	if type(start) == "table" then
		start = start.start
	end

	if type(stop) == "table" then
		stop = stop.stop
	end

	local tk = self:GetCurrentToken()
	start = start or tk and tk.start or 0
	stop = stop or tk and tk.stop or 0
	self:OnError(
		self.code,
		self.name,
		msg,
		start,
		stop,
		...
	)
end

function META:OnError() 
end

function META:GetCurrentToken()
	return self.tokens[self.i]
end

function META:GetToken(offset)
	return self.tokens[self.i + offset]
end

function META:ReadTokenLoose()
	self:Advance(1)
	local tk = self:GetToken(-1)
	tk.parent = self.nodes[#self.nodes]
	return tk
end

function META:RemoveToken(i)
	local t = self.tokens[i]
	table.remove(self.tokens, i)
	return t
end

function META:AddTokens(tokens)
	local eof = table.remove(self.tokens)

	for i, token in ipairs(tokens) do
		if token.type == "end_of_file" then break end
		table.insert(self.tokens, self.i + i - 1, token)
	end

	table.insert(self.tokens, eof)
end

function META:IsValue(str, offset)
	return self:GetToken(offset).value == str
end

function META:IsType(str, offset)
	return self:GetToken(offset).type == str
end

function META:IsCurrentValue(str)
	return self:GetCurrentToken().value == str
end

function META:IsCurrentType(str)
	return self:GetCurrentToken().type == str
end

do
	local function error_expect(self, str, what, start, stop)
		if not self:GetCurrentToken() then
			self:Error("expected $1 $2: reached end of code", start, stop, what, str)
		else
			self:Error(
				"expected $1 $2: got $3",
				start,
				stop,
				what,
				str,
				self:GetCurrentToken()[what]
			)
		end
	end

	function META:ReadValue(str, start, stop)
		if not self:IsCurrentValue(str) then
			error_expect(self, str, "value", start, stop)
		end

		return self:ReadTokenLoose()
	end

	function META:ReadType(str, start, stop)
		if not self:IsCurrentType(str) then
			error_expect(self, str, "type", start, stop)
		end

		return self:ReadTokenLoose()
	end
end

function META:ReadValues(values, start, stop)
	if not self:GetCurrentToken() or not values[self:GetCurrentToken().value] then
		local tk = self:GetCurrentToken()

		if not tk then
			self:Error("expected $1: reached end of code", start, stop, values)
		end

		local array = {}

		for k in pairs(values) do
			table.insert(array, k)
		end

		self:Error("expected $1 got $2", start, stop, array, tk.type)
	end

	return self:ReadTokenLoose()
end

function META:GetLength()
	return #self.tokens
end

function META:Advance(offset)
	self.i = self.i + offset
end

function META:BuildAST(tokens)
	self.tokens = tokens
	self.i = 1
	return self:Root(self.config and self.config.root)
end

function META:Root(root)
	local node = self:Node("statement", "root")
	self.root = root or node
	local shebang

	if self:IsCurrentType("shebang") then
		shebang = self:Node("statement", "shebang")
		shebang.tokens["shebang"] = self:ReadType("shebang")
	end

	node.statements = self:ReadNodes()

	if shebang then
		table.insert(node.statements, 1, shebang)
	end

	if self:IsCurrentType("end_of_file") then
		local eof = self:Node("statement", "end_of_file")
		eof.tokens["end_of_file"] = self.tokens[#self.tokens]
		table.insert(node.statements, eof)
	end

	return node:End()
end

function META:ReadNodes(stop_token)
	local out = {}

	for i = 1, self:GetLength() do
		if
			not self:GetCurrentToken() or
			stop_token and
			stop_token[self:GetCurrentToken().value]
		then
			break
		end

		out[i] = self:ReadNode()
		if not out[i] then break end

		if self.config and self.config.on_statement then
			out[i] = self.config.on_statement(self, out[i]) or out[i]
		end
	end

	return out
end

function META:ResolvePath(path)
	return path
end

do -- statements
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
	local ReadTypeFunction = require("nattlua.parser.statements.typesystem.function").ReadFunction
	local ReadLocalTypeFunction = require("nattlua.parser.statements.typesystem.local_function").ReadLocalFunction
	local ReadLocalGenericsFunction = require("nattlua.parser.statements.typesystem.local_generics_function").ReadLocalGenericsFunction
	local ReadDebugCode = require("nattlua.parser.statements.typesystem.debug_code").ReadDebugCode
	local ReadLocalTypeAssignment = require("nattlua.parser.statements.typesystem.local_assignment").ReadLocalAssignment
	local ReadTypeAssignment = require("nattlua.parser.statements.typesystem.assignment").ReadAssignment
	local ReadCallOrAssignment = require("nattlua.parser.statements.call_or_assignment").ReadCallOrAssignment

	function META:ReadNode()
		if self:IsCurrentType("end_of_file") then return end
		return
			ReadDebugCode(self) or
			ReadReturn(self) or
			ReadBreak(self) or
			ReadContinue(self) or
			ReadSemicolon(self) or
			ReadGoto(self) or
			ReadGotoLabel(self) or
			ReadRepeat(self) or
			ReadTypeFunction(self) or
			ReadFunction(self) or
			ReadLocalGenericsFunction(self) or
			ReadLocalFunction(self) or
			ReadLocalTypeFunction(self) or
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

return function(config)
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
			tokens = {},
			OnError = function() 
			end,
		},
		META
	)
end
