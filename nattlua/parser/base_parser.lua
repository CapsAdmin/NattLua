local ipairs = _G.ipairs
local pairs = _G.pairs
local setmetatable = _G.setmetatable
local type = _G.type
local table = require("table")
return function(META)
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

		function META:GetStatements()
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

		function META:HasStatements()
			return self.statements ~= nil
		end

		function META:FindStatementsByType(what, out)
			out = out or {}

			for _, child in ipairs(self:GetStatements()) do
				if child.kind == what then
					table.insert(out, child)
				elseif child:GetStatements() then
					child:FindStatementsByType(what, out)
				end
			end

			return out
		end

		function META:ExpectExpressionList(length)
			self.expressions = self.parser:ReadExpressionList(length)
			return self
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

		function META:ExpectExpression()
			if self.expressions then
				table.insert(self.expressions, self.parser:ReadExpectExpression(0))
			elseif self.expression then
				self.expressions = {self.expression}
				self.expression = nil
				table.insert(self.expressions, self.parser:ReadExpectExpression(0))
			else
				self.expression = self.parser:ReadExpectExpression(0)
			end

			return self
		end

		function META:ExpectStatementsUntil(what)
			self.statements = self.parser:ReadStatements(type(what) == "table" and what or {[what] = true})
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

		function META:GetLength()
			local helpers = require("nattlua.other.helpers")
			local start, stop = helpers.LazyFindStartStop(self, true)
			return stop - start
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

		node.statements = self:ReadStatements()

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

	function META:ReadStatements(stop_token)
		local out = {}

		for i = 1, self:GetLength() do
			if
				not self:GetCurrentToken() or
				stop_token and
				stop_token[self:GetCurrentToken().value]
			then
				break
			end

			out[i] = self:ReadStatement()
			if not out[i] then break end

			if self.config and self.config.on_statement then
				out[i] = self.config.on_statement(self, out[i]) or out[i]
			end
		end

		return out
	end
end
