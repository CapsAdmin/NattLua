--[[#local type { Token, TokenType } = import_type<|"nattlua/lexer/token.nlua"|>]]
--[[#local type { ExpressionKind, StatementKind, FunctionAnalyzerStatement,
FunctionTypeStatement,
FunctionAnalyzerExpression,
FunctionTypeExpression,
FunctionExpression,
FunctionLocalStatement,
FunctionLocalTypeStatement,
FunctionStatement,
FunctionLocalAnalyzerStatement,
ValueExpression
  } = import_type<|"nattlua/parser/nodes.nlua"|>]]
--[[#import_type<|"nattlua/code/code.lua"|>]]

--[[#local type NodeType = "expression" | "statement"]]

local Node = require("nattlua.parser.node")
local ipairs = _G.ipairs
local pairs = _G.pairs
local setmetatable = _G.setmetatable
local type = _G.type
local table = require("table")
local helpers = require("nattlua.other.helpers")
local quote_helper = require("nattlua.other.quote")
local META = {}
META.__index = META

--[[#local type Node = Node.@Self]]

--[[#
type META.@Self = {
		config = any,
		nodes = List<|any|>,
		Code = Code,
		current_statement = false | any,
		current_expression = false | any,
		root = false | any,
		i = number,
		tokens = List<|Token|>,
		environment_stack = List<|"typesystem" | "runtime"|>,
		OnNode = nil | function=(self, any)>(nil)
	}
]]
--[[#type META.@Name = "Parser"]]
--[[#local type Parser = META.@Self]]

function META.New(tokens--[[#: List<|Token|>]], code --[[#: Code]], config--[[#: nil | {
	root = nil | Node,
	on_statement = nil | function=(Parser, Node)>(Node),
	path = nil | string,
}]])
	return setmetatable(
		{
			config = config or {},
			Code = code,
			nodes = {},
			current_statement = false,
			current_expression = false,
			environment_stack = {},
			root = false,
			i = 1,
			tokens = tokens,
		},
		META
	)
end

do
	function META:GetCurrentParserEnvironment()
		return self.environment_stack[1] or "runtime"
	end

	function META:PushParserEnvironment(env--[[#: "runtime" | "typesystem" ]])
		table.insert(self.environment_stack, 1, env)
	end

	function META:PopParserEnvironment()
		table.remove(self.environment_stack, 1)
	end
end

function META:StartNode(type--[[#: "statement" | "expression"]], kind--[[#: StatementKind | ExpressionKind]])
	local code_start = assert(self:GetToken()).start

	local node = Node.New({
		type = type, 
		kind = kind, 
		Code = self.Code,
		code_start = code_start,
		code_stop = code_start,
		environment = self:GetCurrentParserEnvironment(),
		parent = self.nodes[1],
	})

	if type == "expression" then
		self.current_expression = node
	else
		self.current_statement = node
	end

	if self.OnNode then
		self:OnNode(node)
	end

	table.insert(self.nodes, 1, node)

	return node
end

function META:EndNode(node--[[#: Node]])
	local prev = self:GetToken(-1)
	if prev then
		node.code_stop = prev.stop
	else
		local cur = self:GetToken()
		if cur then
			node.code_stop = cur.stop
		end
	end

	table.remove(self.nodes, 1)
	return self
end

function META:Error(msg--[[#: string]], start_token--[[#: Token | nil]], stop_token--[[#: Token | nil]], ...--[[#: ...any]])
	local tk = self:GetToken()

	local start = 0
	local stop = 0
	
	if start_token then
		start = start_token.start
	elseif tk then
		start = tk.start
	end

	if stop_token then
		stop = stop_token.stop
	elseif tk then
		stop = tk.stop
	end

	self:OnError(self.Code,msg,start,stop,...)
end

function META:OnError(code--[[#: Code]], message--[[#: string]], start--[[#: number]], stop--[[#: number]], ...--[[#: ...any]]) 
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
	if not tk then return nil end
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
		local tk = self:GetToken()
		if not tk then
			self:Error("expected $1 $2: reached end of code", start, stop, what, str)
		else
			self:Error(
				"expected $1 $2: got $3",
				start,
				stop,
				what,
				str,
				tk[what]
			)
		end
	end

	function META:ExpectValue(str--[[#: string]], error_start--[[#: Token | nil]], error_stop--[[#: Token | nil]])--[[#: Token]]
		if not self:IsValue(str) then
			error_expect(self, str, "value", error_start, error_stop)
		end

		return self:ReadToken()--[[# as Token]]
	end

	function META:ExpectType(str--[[#: TokenType]], error_start--[[#: Token | nil]], error_stop--[[#: Token | nil]])--[[#: Token]]
		if not self:IsType(str) then
			error_expect(self, str, "type", error_start, error_stop)
		end

		return self:ReadToken()--[[# as Token]]
	end
end

function META:ReadValues(values--[[#: Map<|string, true|> ]], start--[[#: Token | nil]], stop--[[#: Token | nil]])
	
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

function META:ResolvePath(path--[[#: string]])
	return path
end


do -- statements
	local runtime_syntax = require("nattlua.syntax.runtime")
	local typesystem_syntax = require("nattlua.syntax.typesystem")

	local math = require("math")
	local math_huge = math.huge
	local table_insert = require("table").insert
	local table_remove = require("table").remove
	local ipairs = _G.ipairs
	
	function META:ReadMultipleValues(max--[[#: nil | number ]], reader--[[#: ref function=(Parser, ...: ...any)>(nil | Node)]], ...--[[#: ref ...any]])
		local out = {}

		for i = 1, max or self:GetLength() do
			local node = reader(self, ...) --[[# as Node | nil]]
			if not node then break end
			out[i] = node
			if not self:IsValue(",") then break end
			node.tokens[","] = self:ExpectValue(",")
		end

		return out
	end

	--[[#do return end]]

	function META:ReadIdentifier(expect_type--[[#: nil | boolean]])
		if not self:IsType("letter") and not self:IsValue("...") then return end
		local node = self:StartNode("expression", "value") --[[#-- as ValueExpression ]]

		if self:IsValue("...") then
			node.value = self:ExpectValue("...")
		else
			node.value = self:ExpectType("letter")
		end

		if self:IsValue(":") or expect_type then
			node.tokens[":"] = self:ExpectValue(":")
			node.type_expression = self:ExpectTypeExpression(0)
		end

		self:EndNode(node)

		return node
	end

	function META:ReadValueExpressionToken(expect_value--[[#: nil | string]]) 
		local node = self:StartNode("expression", "value")
		node.value = expect_value and self:ExpectValue(expect_value) or self:ReadToken()
		self:EndNode(node)
		return node
	end

	function META:ReadValueExpressionType(expect_value--[[#: TokenType]]) 
		local node = self:StartNode("expression", "value")
		node.value = self:ExpectType(expect_value)
		self:EndNode(node)
		return node
	end


	function META:ReadFunctionBody(node--[[#: FunctionAnalyzerExpression | FunctionExpression | FunctionLocalStatement | FunctionStatement ]])
		node.tokens["arguments("] = self:ExpectValue("(")
		node.identifiers = self:ReadMultipleValues(nil, self.ReadIdentifier)
		node.tokens["arguments)"] = self:ExpectValue(")", node.tokens["arguments("])

		if self:IsValue(":") then
			node.tokens[":"] = self:ExpectValue(":")
			self:PushParserEnvironment("typesystem")
			node.return_types = self:ReadMultipleValues(nil, self.ReadTypeExpression, 0)
			self:PopParserEnvironment("typesystem")
		end

		node.statements = self:ReadNodes({["end"] = true})
		node.tokens["end"] = self:ExpectValue("end", node.tokens["function"])
		
		return node
	end

	function META:ReadTypeFunctionBody(node--[[#: FunctionTypeStatement | FunctionTypeExpression | FunctionLocalTypeStatement]])
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
		end

		if self:IsValue(":") then
			node.tokens[":"] = self:ExpectValue(":")
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

	function META:ReadAnalyzerFunctionBody(node--[[#: FunctionAnalyzerStatement | FunctionAnalyzerExpression |FunctionLocalAnalyzerStatement]], type_args--[[#: boolean]])
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

			self:EndNode(vararg)

			table_insert(node.identifiers, vararg)
		end

		node.tokens["arguments)"] = self:ExpectValue(")", node.tokens["arguments("])

		if self:IsValue(":") then
			node.tokens[":"] = self:ExpectValue(":")
			self:PushParserEnvironment("typesystem")
			node.return_types = self:ReadMultipleValues(math.huge, self.ReadTypeExpression, 0)
			self:PopParserEnvironment("typesystem")

			local start = self:GetToken()
			node.statements = self:ReadNodes({["end"] = true})
			node.tokens["end"] = self:ExpectValue("end", start, start)
		elseif not self:IsValue(",") then
			local start = self:GetToken()
			node.statements = self:ReadNodes({["end"] = true})
			node.tokens["end"] = self:ExpectValue("end", start, start)
		end

		return node
	end
		--[[# do return end ]]


	do -- expression
		function META:ReadAnalyzerFunctionExpression()
			if not (self:IsValue("analyzer") and self:IsValue("function", 1)) then return end
			local node = self:StartNode("expression", "analyzer_function")
			node.tokens["analyzer"] = self:ExpectValue("analyzer")
			node.tokens["function"] = self:ExpectValue("function")
			self:ReadAnalyzerFunctionBody(node)
			self:EndNode(node)
			return node
		end
	
		function META:ReadFunctionExpression()
			if not self:IsValue("function") then return end
			local node = self:StartNode("expression", "function")
			node.tokens["function"] = self:ExpectValue("function")
			self:ReadFunctionBody(node)
			self:EndNode(node)
			return node
		end
	
		function META:ReadIndexSubExpression()
			if not (self:IsValue(".") and self:IsType("letter", 1)) then return end
			local node = self:StartNode("expression", "binary_operator")
			node.value = self:ReadToken()
			node.right = self:ReadValueExpressionType("letter")
			self:EndNode(node)
			return node
		end
	
		function META:IsCallExpression(offset)
			return
				self:IsValue("(", offset) or
				self:IsValue("<|", offset) or
				self:IsValue("{", offset) or
				self:IsType("string", offset) or
				(self:IsValue("!", offset) and self:IsValue("(", offset + 1))
		end
	
		function META:ReadSelfCallSubExpression()
			if not (self:IsValue(":") and self:IsType("letter", 1) and self:IsCallExpression(2)) then return end
			local node = self:StartNode("expression", "binary_operator")
			node.value = self:ReadToken()
			node.right = self:ReadValueExpressionType("letter")
			self:EndNode(node)
			return node
		end

		do -- typesystem
			function META:ReadParenthesisOrTupleTypeExpression()
				if not self:IsValue("(") then return end
				local pleft = self:ExpectValue("(")
				local node = self:ReadTypeExpression(0)
			
				if not node or self:IsValue(",") then
					local first_expression = node
					local node = self:StartNode("expression", "tuple")
					
					if self:IsValue(",") then
						first_expression.tokens[","] = self:ExpectValue(",")
						node.expressions = self:ReadMultipleValues(nil, self.ReadTypeExpression, 0)
					else
						node.expressions = {}
					end
			
					if first_expression then
						table.insert(node.expressions, 1, first_expression)
					end
					node.tokens["("] = pleft
					node.tokens[")"] = self:ExpectValue(")", pleft)
					self:EndNode(node)
					return node
				end
			
				node.tokens["("] = node.tokens["("] or {}
				table_insert(node.tokens["("], 1, pleft)
				node.tokens[")"] = node.tokens[")"] or {}
				table_insert(node.tokens[")"], self:ExpectValue(")"))
				self:EndNode(node)
				return node
			end
			
			function META:ReadPrefixOperatorTypeExpression()
				if not typesystem_syntax:IsPrefixOperator(self:GetToken()) then return end
				local node = self:StartNode("expression", "prefix_operator")
				node.value = self:ReadToken()
				node.tokens[1] = node.value

				if node.value.value == "expand" then
					self:PushParserEnvironment("runtime")
				end

				node.right = self:ReadTypeExpression(math_huge)

				if node.value.value == "expand" then
					self:PopParserEnvironment()
				end

				self:EndNode(node)
				return node
			end
			
			function META:ReadValueTypeExpression()
				if not (self:IsValue("...") and self:IsType("letter", 1)) then return end
				local node = self:StartNode("expression", "value")
				node.value = self:ExpectValue("...")
				node.type_expression = self:ReadTypeExpression(0)
				self:EndNode(node)
				return node
			end

			function META:ReadTypeSignatureFunctionArgument(expect_type)
				if self:IsValue(")") then return end
			
				if expect_type or ((self:IsType("letter") or self:IsValue("...")) and self:IsValue(":", 1)) then
					local identifier = self:ReadToken()
					local token = self:ExpectValue(":")
					local exp = self:ExpectTypeExpression(0)
					exp.tokens[":"] = token
					exp.identifier = identifier
					return exp
				end
			
				return self:ExpectTypeExpression(0)
			end
			
			function META:ReadFunctionSignatureExpression()
				if not (self:IsValue("function") and self:IsValue("=", 1)) then return end
			
				local node = self:StartNode("expression", "function_signature")
				node.tokens["function"] = self:ExpectValue("function")
				node.tokens["="] = self:ExpectValue("=")
			
				node.tokens["arguments("] = self:ExpectValue("(")
				node.identifiers = self:ReadMultipleValues(nil, self.ReadTypeSignatureFunctionArgument)
				node.tokens["arguments)"] = self:ExpectValue(")")
			
				node.tokens[">"] = self:ExpectValue(">")
			
				node.tokens["return("] = self:ExpectValue("(")
				node.return_types = self:ReadMultipleValues(nil, self.ReadTypeSignatureFunctionArgument)
				node.tokens["return)"] = self:ExpectValue(")")

				self:EndNode(node)
				
				return node
			end
			
			function META:ReadTypeFunctionExpression()
				if not (self:IsValue("function") and self:IsValue("<|", 1)) then return end
				local node = self:StartNode("expression", "type_function")
				node.tokens["function"] = self:ExpectValue("function")
				self:ReadTypeFunctionBody(node)
				self:EndNode(node)
				return node
			end
					
			function META:ReadKeywordValueTypeExpression()
				if not typesystem_syntax:IsValue(self:GetToken()) then return end
				local node = self:StartNode("expression", "value")
				node.value = self:ReadToken()
				self:EndNode(node)
				return node
			end
			
			do
				function META:read_type_table_entry(i)
					if self:IsValue("[") then
						local node = self:StartNode("expression", "table_expression_value")
						node.expression_key = true
						node.tokens["["] = self:ExpectValue("[")
						node.key_expression = self:ReadTypeExpression(0)
						node.tokens["]"] = self:ExpectValue("]")
						node.tokens["="] = self:ExpectValue("=")
						node.value_expression = self:ReadTypeExpression(0)
						self:EndNode(node)
						return node
					elseif self:IsType("letter") and self:IsValue("=", 1) then
						local node = self:StartNode("expression", "table_key_value")
						node.tokens["identifier"] = self:ExpectType("letter")
						node.tokens["="] = self:ExpectValue("=")
						node.value_expression = self:ReadTypeExpression(0)
						return node
					end
				
					local node = self:StartNode("expression", "table_index_value")
					node.key = i
					node.value_expression = self:ReadTypeExpression(0)
					self:EndNode(node)
					return node
				end
				
				function META:ReadTableTypeExpression()
					if not self:IsValue("{") then return end
					local tree = self:StartNode("expression", "type_table")
					tree.tokens["{"] = self:ExpectValue("{")
					tree.children = {}
					tree.tokens["separators"] = {}
				
					for i = 1, math_huge do
						if self:IsValue("}") then break end
						local entry = self:read_type_table_entry(i)
				
						if entry.spread then
							tree.spread = true
						end
				
						tree.children[i] = entry
				
						if not self:IsValue(",") and not self:IsValue(";") and not self:IsValue("}") then
							self:Error(
								"expected $1 got $2",
								nil,
								nil,
								{",", ";", "}"},
								(self:GetToken() and self:GetToken().value) or
								"no token"
							)
				
							break
						end
				
						if not self:IsValue("}") then
							tree.tokens["separators"][i] = self:ReadToken()
						end
					end
				
					tree.tokens["}"] = self:ExpectValue("}")
					self:EndNode(tree)
					return tree
				end
			end
			
			function META:ReadStringTypeExpression()
				if not (self:IsType("$") and self:IsType("string", 1)) then return end
				local node = self:StartNode("expression", "type_string")
				node.tokens["$"] = self:ReadToken("...")
				node.value = self:ExpectType("string")
				return node
			end
			
			function META:ReadEmptyUnionTypeExpression()
				if not self:IsValue("|") then return end
				local node = self:StartNode("expression", "empty_union")
				node.tokens["|"] = self:ReadToken("|")
				self:EndNode(node)
				return node
			end
				
			function META:ReadAsSubExpression(node)
				if not self:IsValue("as") then return end
				node.tokens["as"] = self:ExpectValue("as")
				node.type_expression = self:ReadTypeExpression(0)
			end
		
			function META:ReadPostfixTypeOperatorSubExpression()
				if not typesystem_syntax:IsPostfixOperator(self:GetToken()) then return end

				local node = self:StartNode("expression", "postfix_operator")
				node.value = self:ReadToken()
				self:EndNode(node)

				return node
			end
		
			function META:ReadTypeCallSubExpression()
				if not self:IsCallExpression(0) then return end
				local node = self:StartNode("expression", "postfix_call")
		
				if self:IsValue("{") then
					node.expressions = {self:ReadTableTypeExpression()}
				elseif self:IsType("string") then
					node.expressions = {
							self:ReadValueExpressionToken()
						}
				elseif self:IsValue("<|") then
					node.tokens["call("] = self:ExpectValue("<|")
					node.expressions = self:ReadMultipleValues(nil, self.ReadTypeExpression, 0)
					node.tokens["call)"] = self:ExpectValue("|>")
				else
					node.tokens["call("] = self:ExpectValue("(")
					node.expressions = self:ReadMultipleValues(nil, self.ReadTypeExpression, 0)
					node.tokens["call)"] = self:ExpectValue(")")
				end
		
				node.type_call = true
				self:EndNode(node)
				return node
			end
		
			function META:ReadPostfixTypeIndexExpressionSubExpression()
				if not self:IsValue("[") then return end
				local node = self:StartNode("expression", "postfix_expression_index")
				node.tokens["["] = self:ExpectValue("[")
				node.expression = self:ExpectTypeExpression(0)
				node.tokens["]"] = self:ExpectValue("]")
				self:EndNode(node)
				return node
			end
		
			function META:ReadTypeSubExpression(node)
				for _ = 1, self:GetLength() do
					local left_node = node
					local found = self:ReadIndexSubExpression() or
						self:ReadSelfCallSubExpression() or
						self:ReadPostfixTypeOperatorSubExpression() or
						self:ReadTypeCallSubExpression() or
						self:ReadPostfixTypeIndexExpressionSubExpression() or
						self:ReadAsSubExpression(left_node)
					if not found then break end
					found.left = left_node
		
					if left_node.value and left_node.value.value == ":" then
						found.parser_call = true
					end
		
					node = found
				end
		
				return node
			end
		
			function META:ReadTypeExpression(priority)
				local node
				local force_upvalue
			
				if self:IsValue("^") then
					force_upvalue = true
					self:Advance(1)
				end
			
				node = self:ReadParenthesisOrTupleTypeExpression() or
					self:ReadEmptyUnionTypeExpression() or
					self:ReadPrefixOperatorTypeExpression() or
					self:ReadAnalyzerFunctionExpression() or -- shared
					self:ReadFunctionSignatureExpression() or
					self:ReadTypeFunctionExpression() or -- shared
					self:ReadFunctionExpression() or -- shared
					self:ReadValueTypeExpression() or
					self:ReadKeywordValueTypeExpression() or
					self:ReadTableTypeExpression() or
					self:ReadStringTypeExpression()
				local first = node
			
				if node then
					node = self:ReadTypeSubExpression(node)
			
					if
						first.kind == "value" and
						(first.value.type == "letter" or first.value.value == "...")
					then
						first.standalone_letter = node
						first.force_upvalue = force_upvalue
					end
				end
			
				while typesystem_syntax:GetBinaryOperatorInfo(self:GetToken()) and
				typesystem_syntax:GetBinaryOperatorInfo(self:GetToken()).left_priority > priority do
					local left_node = node
					node = self:StartNode("expression", "binary_operator")
					node.value = self:ReadToken()
					node.left = left_node
					node.right = self:ReadTypeExpression(typesystem_syntax:GetBinaryOperatorInfo(node.value).right_priority)
					self:EndNode(node)
				end

				return node
			end

			function META:IsTypeExpression()
				local token = self:GetToken()
			
				return not(
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
				)
			end

			function META:ExpectTypeExpression(priority)
				if not self:IsTypeExpression() then
					local token = self:GetToken()

					self:Error(
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
			
				return self:ReadTypeExpression(priority)
			end
		end

		do -- runtime
			local ReadTableExpression
			do
				function META:read_table_spread()
					if not (self:IsValue("...") and (self:IsType("letter", 1) or self:IsValue("{", 1) or self:IsValue("(", 1))) then return end
					local node = self:StartNode("expression", "table_spread")
					node.tokens["..."] = self:ExpectValue("...")
					node.expression = self:ExpectRuntimeExpression()
					self:EndNode(node)
					return node
				end
				
				function META:read_table_entry(i)
					if self:IsValue("[") then
						local node = self:StartNode("expression", "table_expression_value")
						node.expression_key = true
						node.tokens["["] = self:ExpectValue("[")
						node.key_expression = self:ExpectRuntimeExpression(0)
						node.tokens["]"] = self:ExpectValue("]")
						node.tokens["="] = self:ExpectValue("=")
						node.value_expression = self:ExpectRuntimeExpression(0)
						self:EndNode(node)
						return node
					elseif self:IsType("letter") and self:IsValue("=", 1) then
						local node = self:StartNode("expression", "table_key_value")
						node.tokens["identifier"] = self:ExpectType("letter")
						node.tokens["="] = self:ExpectValue("=")

						local spread = self:read_table_spread()
				
						if spread then
							node.spread = spread
						else
							node.value_expression = self:ExpectRuntimeExpression()
						end

						self:EndNode(node)
				
						return node
					end
				
					local node = self:StartNode("expression", "table_index_value")
					local spread = self:read_table_spread()
				
					if spread then
						node.spread = spread
					else
						node.value_expression = self:ExpectRuntimeExpression()
					end
				
					node.key = i

					self:EndNode(node)

					return node
				end
				
				function META:ReadTableExpression()
					if not self:IsValue("{") then return end
					local tree = self:StartNode("expression", "table")
					tree.tokens["{"] = self:ExpectValue("{")
					tree.children = {}
					tree.tokens["separators"] = {}
				
					for i = 1, self:GetLength() do
						if self:IsValue("}") then break end
						local entry = self:read_table_entry(i)
				
						if entry.kind == "table_index_value" then
							tree.is_array = true
						else
							tree.is_dictionary = true
						end
				
						if entry.spread then
							tree.spread = true
						end
				
						tree.children[i] = entry
				
						if not self:IsValue(",") and not self:IsValue(";") and not self:IsValue("}") then
							self:Error(
								"expected $1 got $2",
								nil,
								nil,
								{",", ";", "}"},
								(self:GetToken() and self:GetToken().value) or
								"no token"
							)
				
							break
						end
				
						if not self:IsValue("}") then
							tree.tokens["separators"][i] = self:ReadToken()
						end
					end
				
					tree.tokens["}"] = self:ExpectValue("}")
					self:EndNode(tree)
					return tree
				end
			end

			function META:ReadPostfixOperatorSubExpression()
				if not runtime_syntax:IsPostfixOperator(self:GetToken()) then return end
				local node = self:StartNode("expression", "postfix_operator")
				node.value = self:ReadToken()
				self:EndNode(node)
				return node
			end

			function META:ReadCallSubExpression(primary_node)
				if not self:IsCallExpression(0) then return end

				if primary_node and primary_node.kind == "function" then
					if not primary_node.tokens[")"] then
						return
					end
				end


				local node = self:StartNode("expression", "postfix_call")

				if self:IsValue("{") then
					node.expressions = {self:ReadTableExpression()}
				elseif self:IsType("string") then
					node.expressions = {self:ReadValueExpressionToken()}
				elseif self:IsValue("<|") then
					node.tokens["call("] = self:ExpectValue("<|")
					node.expressions = self:ReadMultipleValues(nil, self.ReadTypeExpression, 0)
					node.tokens["call)"] = self:ExpectValue("|>")
					node.type_call = true
				elseif self:IsValue("!") then
					node.tokens["!"] = self:ExpectValue("!")
					node.tokens["call("] = self:ExpectValue("(")
					node.expressions = self:ReadMultipleValues(nil, self.ReadTypeExpression, 0)
					node.tokens["call)"] = self:ExpectValue(")")
					node.type_call = true
				else
					node.tokens["call("] = self:ExpectValue("(")
					node.expressions = self:ReadMultipleValues(nil, self.ReadRuntimeExpression, 0)
					node.tokens["call)"] = self:ExpectValue(")")
				end

				self:EndNode(node)

				return node
			end

			function META:ReadPostfixIndexExpressionSubExpression()
				if not self:IsValue("[") then return end
				local node = self:StartNode("expression", "postfix_expression_index")
				node.tokens["["] = self:ExpectValue("[")
				node.expression = self:ExpectRuntimeExpression()
				node.tokens["]"] = self:ExpectValue("]")
				self:EndNode(node)

				return node
			end

			function META:ReadSubExpression(node)
				for _ = 1, self:GetLength() do
					local left_node = node
					
					if self:IsValue(":") and (not self:IsType("letter", 1) or not self:IsCallExpression(2)) then
						node.tokens[":"] = self:ExpectValue(":")
						node.type_expression = self:ExpectTypeExpression(0)
					elseif self:IsValue("as") then
						node.tokens["as"] = self:ExpectValue("as")
						node.type_expression = self:ExpectTypeExpression(0)
					elseif self:IsValue("is") then
						node.tokens["is"] = self:ExpectValue("is")
						node.type_expression = self:ExpectTypeExpression(0)
					end
					
					local found = self:ReadIndexSubExpression() or
						self:ReadSelfCallSubExpression() or
						self:ReadCallSubExpression(node) or
						self:ReadPostfixOperatorSubExpression() or
						self:ReadPostfixIndexExpressionSubExpression()
						
					if not found then break end
					found.left = left_node

					if left_node.value and left_node.value.value == ":" then
						found.parser_call = true
					end

					node = found
				end

				return node
			end

			function META:ReadPrefixOperatorExpression()
				if not runtime_syntax:IsPrefixOperator(self:GetToken()) then return end
				local node = self:StartNode("expression", "prefix_operator")
				node.value = self:ReadToken()
				node.tokens[1] = node.value
				node.right = self:ExpectRuntimeExpression(math.huge)
				self:EndNode(node)
				return node
			end

			function META:ReadParenthesisExpression()
				if not self:IsValue("(") then return end
				local pleft = self:ExpectValue("(")
				local node = self:ReadRuntimeExpression(0)

				if not node then
					self:Error("empty parentheses group", pleft)
					return
				end

				node.tokens["("] = node.tokens["("] or {}
				table_insert(node.tokens["("], 1, pleft)
				node.tokens[")"] = node.tokens[")"] or {}
				table_insert(node.tokens[")"], self:ExpectValue(")"))
				return node
			end

			function META:ReadValueExpression()
				if not runtime_syntax:IsValue(self:GetToken()) then return end
				return self:ReadValueExpressionToken()
			end

			function META:ReadImportExpression()
				if not (self:IsValue("import") and self:IsValue("(", 1)) then return end
				local node = self:StartNode("expression", "import")
				node.tokens["import"] = self:ExpectValue("import")
				node.tokens["("] = {self:ExpectValue("(")}
				local start = self:GetToken()
				node.expressions = self:ReadMultipleValues(nil, self.ReadRuntimeExpression, 0)
				local root = self.config.path and self.config.path:match("(.+/)") or ""
				node.path = root .. node.expressions[1].value.value:sub(2, -2)
				local nl = require("nattlua")
				local root, err = nl.ParseFile(self:ResolvePath(node.path), self.root)

				if not root then
					self:Error("error importing file: $1", start, start, err)
				end

				node.root = root.SyntaxTree
				node.analyzer = root
				node.tokens[")"] = {self:ExpectValue(")")}
				self.root.imports = self.root.imports or {}
				table.insert(self.root.imports, node)
				return node
			end
		
			function META:check_integer_division_operator(node)
				if node and not node.idiv_resolved then
					for i, token in ipairs(node.whitespace) do
						if token.value:find("\n", nil, true) then break end
						if token.type == "line_comment" and token.value:sub(1, 2) == "//" then
							table_remove(node.whitespace, i)
							local Code = require("nattlua.code.code")
							local tokens = require("nattlua.lexer.lexer")(Code("/idiv" .. token.value:sub(2), "")):GetTokens()

							for _, token in ipairs(tokens) do
								self:check_integer_division_operator(token)
							end

							self:AddTokens(tokens)
							node.idiv_resolved = true

							break
						end
					end
				end
			end	
			
			function META:ReadRuntimeExpression(priority)
				if self:GetCurrentParserEnvironment() == "typesystem" then
					return self:ReadTypeExpression(priority)
				end

				priority = priority or 0
				local node = self:ReadParenthesisExpression() or
					self:ReadPrefixOperatorExpression() or
					self:ReadAnalyzerFunctionExpression() or
					self:ReadFunctionExpression() or
					self:ReadImportExpression() or
					self:ReadValueExpression() or
					self:ReadTableExpression()
				local first = node

				if node then
					node = self:ReadSubExpression(node)

					if
						first.kind == "value" and
						(first.value.type == "letter" or first.value.value == "...")
					then
						first.standalone_letter = node
					end
				end

				self:check_integer_division_operator(self:GetToken())

				while runtime_syntax:GetBinaryOperatorInfo(self:GetToken()) and
				runtime_syntax:GetBinaryOperatorInfo(self:GetToken()).left_priority > priority do
					local left_node = node
					node = self:StartNode("expression", "binary_operator")
					node.value = self:ReadToken()
					node.left = left_node

					if node.left then
						node.left.parent = node
					end

					node.right = self:ExpectRuntimeExpression(runtime_syntax:GetBinaryOperatorInfo(node.value).right_priority)

					self:EndNode(node)

					if not node.right then
						local token = self:GetToken()
						self:Error(
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
				end

				return node
			end

			function META:IsRuntimeExpression()
				local token = self:GetToken()

				return not (
					token.type == "end_of_file" or
					token.value == "}" or
					token.value == "," or
					token.value == "]" or
					(
						(runtime_syntax:IsKeyword(token) or runtime_syntax:IsNonStandardKeyword(token)) and
						not runtime_syntax:IsPrefixOperator(token) and
						not runtime_syntax:IsValue(token) and
						token.value ~= "function"
					)
				)
			end

			function META:ExpectRuntimeExpression(priority)
				if not self:IsRuntimeExpression() then
					local token = self:GetToken()

					self:Error(
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

				return self:ReadRuntimeExpression(priority)
			end
		end
	end

	do -- statement
		local ReadDestructureAssignmentStatement
		local ReadLocalDestructureAssignmentStatement
		do -- destructure statement
			function META:IsDestructureStatement(offset)
				offset = offset or 0
				return
					(self:IsValue("{", offset + 0) and self:IsType("letter", offset + 1)) or
					(self:IsType("letter", offset + 0) and self:IsValue(",", offset + 1) and self:IsValue("{", offset + 2))
			end

			function META:IsLocalDestructureAssignmentStatement()
				if self:IsValue("local") then
					if self:IsValue("type", 1) then return self:IsDestructureStatement(2) end
					return self:IsDestructureStatement(1)
				end
			end

			function META:ReadDestructureAssignmentStatement()
				if not self:IsDestructureStatement() then return end
				local node = self:StartNode("statement", "destructure_assignment")
				do
					if self:IsType("letter") then
						node.default = self:ReadValueExpressionToken()
						node.default_comma = self:ExpectValue(",")
					end
				
					node.tokens["{"] = self:ExpectValue("{")
					node.left = self:ReadMultipleValues(nil, self.ReadIdentifier)
					node.tokens["}"] = self:ExpectValue("}")
					node.tokens["="] = self:ExpectValue("=")
					node.right = self:ReadRuntimeExpression(0)
				end
				self:EndNode(node)
				return node
			end

			function META:ReadLocalDestructureAssignmentStatement()
				if not self:IsLocalDestructureAssignmentStatement() then return end
				local node = self:StartNode("statement", "local_destructure_assignment")
				node.tokens["local"] = self:ExpectValue("local")
			
				if self:IsValue("type") then
					node.tokens["type"] = self:ExpectValue("type")
					node.environment = "typesystem"
				end
			
				do -- remaining
					if self:IsType("letter") then
						node.default = self:ReadValueExpressionToken()
						node.default_comma = self:ExpectValue(",")
					end
				
					node.tokens["{"] = self:ExpectValue("{")
					node.left = self:ReadMultipleValues(nil, self.ReadIdentifier)
					node.tokens["}"] = self:ExpectValue("}")
					node.tokens["="] = self:ExpectValue("=")
					node.right = self:ReadRuntimeExpression(0)
				end

				self:EndNode(node)

				return node
			end
		end

		do
			function META:ReadFunctionNameIndex()
				if not runtime_syntax:IsValue(self:GetToken()) then return end
				local node = self:ReadValueExpressionToken()
				local first = node

				while self:IsValue(".") or self:IsValue(":") do
					local left = node
					local self_call = self:IsValue(":")
					node = self:StartNode("expression", "binary_operator")
					node.value = self:ReadToken()
					node.right = self:ReadValueExpressionType("letter")
					node.left = left
					node.right.self_call = self_call
					self:EndNode(node)
				end

				first.standalone_letter = node
				return node
			end

			function META:ReadFunctionStatement()
				if not self:IsValue("function") then return end
				local node = self:StartNode("statement", "function")
				node.tokens["function"] = self:ExpectValue("function")
				node.expression = self:ReadFunctionNameIndex()

				if node.expression and node.expression.kind == "binary_operator" then
					node.self_call = node.expression.right.self_call
				end

				if self:IsValue("<|") then
					node.kind = "type_function"
					self:ReadTypeFunctionBody(node)
				else
					self:ReadFunctionBody(node)
				end

				self:EndNode(node)

				return node
			end

			function META:ReadAnalyzerFunctionStatement()
				if not (self:IsValue("analyzer") and self:IsValue("function", 1)) then return end
				local node = self:StartNode("statement", "analyzer_function")
				node.tokens["analyzer"] = self:ExpectValue("analyzer")
				node.tokens["function"] = self:ExpectValue("function")
				local force_upvalue

				if self:IsValue("^") then
					force_upvalue = true
					node.tokens["^"] = self:ReadToken()
				end

				node.expression = self:ReadFunctionNameIndex()

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

				self:ReadAnalyzerFunctionBody(node, true)

				self:EndNode(node)

				return node
			end
		end
		function META:ReadLocalFunctionStatement()
			if not (self:IsValue("local") and self:IsValue("function", 1)) then return end
			local node = self:StartNode("statement", "local_function")
			
			node.tokens["local"] = self:ExpectValue("local")
			node.tokens["function"] = self:ExpectValue("function")
			node.tokens["identifier"] = self:ExpectType("letter")
			self:ReadFunctionBody(node)
			self:EndNode(node)

			return node
		end
		function META:ReadLocalAnalyzerFunctionStatement()
			if not (self:IsValue("local") and self:IsValue("analyzer", 1) and self:IsValue("function", 2)) then return end

			local node = self:StartNode("statement", "local_analyzer_function")
			node.tokens["local"] = self:ExpectValue("local")
			node.tokens["analyzer"] = self:ExpectValue("analyzer")
			node.tokens["function"] = self:ExpectValue("function")
			node.tokens["identifier"] = self:ExpectType("letter")
			self:ReadAnalyzerFunctionBody(node, true)
			self:EndNode(node)

			return node
		end
		function META:ReadLocalTypeFunctionStatement()
			if not (self:IsValue("local") and self:IsValue("function", 1) and (self:IsValue("<|", 3) or self:IsValue("!", 3))) then return end

			local node = self:StartNode("statement", "local_type_function")
			node.tokens["local"] = self:ExpectValue("local")
			node.tokens["function"] = self:ExpectValue("function")
			node.tokens["identifier"] = self:ExpectType("letter")
			self:ReadTypeFunctionBody(node)
			self:EndNode(node)

			return node
		end
		function META:ReadBreakStatement()
			if not self:IsValue("break") then return nil end

			local node = self:StartNode("statement", "break")
			node.tokens["break"] = self:ExpectValue("break")
			self:EndNode(node)

			return node
		end
		function META:ReadDoStatement()
			if not self:IsValue("do") then return nil end

			local node = self:StartNode("statement", "do")
			node.tokens["do"] = self:ExpectValue("do")
			node.statements = self:ReadNodes({["end"] = true})
			node.tokens["end"] = self:ExpectValue("end", node.tokens["do"])

			self:EndNode(node)

			return node
		end
		function META:ReadGenericForStatement()
			if not self:IsValue("for") then return nil end
			local node = self:StartNode("statement", "generic_for")
			node.tokens["for"] = self:ExpectValue("for")
			node.identifiers = self:ReadMultipleValues(nil, self.ReadIdentifier)
			node.tokens["in"] = self:ExpectValue("in")
			node.expressions = self:ReadMultipleValues(math.huge, self.ExpectRuntimeExpression, 0)

			node.tokens["do"] = self:ExpectValue("do")
			node.statements = self:ReadNodes({["end"] = true})
			node.tokens["end"] = self:ExpectValue("end", node.tokens["do"])

			self:EndNode(node)

			return node
		end
		function META:ReadGotoLabelStatement()
			if not self:IsValue("::") then return nil end
			local node = self:StartNode("statement", "goto_label")
			node.tokens["::"] = self:ExpectValue("::")
			node.tokens["identifier"] = self:ExpectType("letter")
			node.tokens["::"] = self:ExpectValue("::")
			self:EndNode(node)

			return node
		end
		function META:ReadGotoStatement()
			if not self:IsValue("goto") or not self:IsType("letter", 1) then return nil end

			local node = self:StartNode("statement", "goto")
			node.tokens["goto"] = self:ExpectValue("goto")
			node.tokens["identifier"] = self:ExpectType("letter")
			self:EndNode(node)

			return node
		end
		function META:ReadIfStatement()
			if not self:IsValue("if") then return nil end
			local node = self:StartNode("statement", "if")
			node.expressions = {}
			node.statements = {}
			node.tokens["if/else/elseif"] = {}
			node.tokens["then"] = {}

			for i = 1, self:GetLength() do
				local token

				if i == 1 then
					token = self:ExpectValue("if")
				else
					token = self:ReadValues(
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
					node.expressions[i] = self:ExpectRuntimeExpression(0)
					node.tokens["then"][i] = self:ExpectValue("then")
				end

				node.statements[i] = self:ReadNodes({
					["end"] = true,
					["else"] = true,
					["elseif"] = true,
				})
				if self:IsValue("end") then break end
			end

			node.tokens["end"] = self:ExpectValue("end")
			self:EndNode(node)

			return node
		end
		function META:ReadLocalAssignmentStatement()
			if not self:IsValue("local") then return end
			local node = self:StartNode("statement", "local_assignment")
			node.tokens["local"] = self:ExpectValue("local")
			node.left = self:ReadMultipleValues(nil, self.ReadIdentifier)

			if self:IsValue("=") then
				node.tokens["="] = self:ExpectValue("=")
				node.right = self:ReadMultipleValues(nil, self.ReadRuntimeExpression, 0)
			end

			self:EndNode(node)

			return node
		end
		function META:ReadNumericForStatement()
			if not (self:IsValue("for") and self:IsValue("=", 2)) then return nil end
			local node = self:StartNode("statement", "numeric_for")
			node.tokens["for"] = self:ExpectValue("for")
			node.identifiers = self:ReadMultipleValues(1, self.ReadIdentifier)
			node.tokens["="] = self:ExpectValue("=")
			node.expressions = self:ReadMultipleValues(3, self.ExpectRuntimeExpression, 0)

			node.tokens["do"] = self:ExpectValue("do")
			node.statements = self:ReadNodes({["end"] = true})
			node.tokens["end"] = self:ExpectValue("end", node.tokens["do"])

			self:EndNode(node)

			return node
		end
		function META:ReadRepeatStatement()
			if not self:IsValue("repeat") then return nil end
			local node = self:StartNode("statement", "repeat")
			node.tokens["repeat"] = self:ExpectValue("repeat")
			node.statements = self:ReadNodes({["until"] = true})
			node.tokens["until"] = self:ExpectValue("until")
			node.expression = self:ExpectRuntimeExpression()
			self:EndNode(node)
			return node
		end
		function META:ReadSemicolonStatement()
			if not self:IsValue(";") then return nil end
			local node = self:StartNode("statement", "semicolon")
			node.tokens[";"] = self:ExpectValue(";")
			self:EndNode(node)
			return node
		end
		function META:ReadReturnStatement()
			if not self:IsValue("return") then return nil end
			local node = self:StartNode("statement", "return")
			node.tokens["return"] = self:ExpectValue("return")
			node.expressions = self:ReadMultipleValues(nil, self.ReadRuntimeExpression, 0)
			self:EndNode(node)

			return node
		end
		function META:ReadWhileStatement()
			if not self:IsValue("while") then return nil end
			local node = self:StartNode("statement", "while")
			node.tokens["while"] = self:ExpectValue("while")
			node.expression = self:ExpectRuntimeExpression()
			node.tokens["do"] = self:ExpectValue("do")
			node.statements = self:ReadNodes({["end"] = true})
			node.tokens["end"] = self:ExpectValue("end", node.tokens["do"])

			self:EndNode(node)

			return node
		end
		function META:ReadContinueStatement()
			if not self:IsValue("continue") then return nil end

			local node = self:StartNode("statement", "continue")
			node.tokens["continue"] = self:ExpectValue("continue")
			self:EndNode(node)

			return node
		end
		function META:ReadDebugCodeStatement()
			if self:IsType("analyzer_debug_code") then
				local node = self:StartNode("statement", "analyzer_debug_code")
				node.lua_code = self:ReadValueExpressionType("analyzer_debug_code")
				self:EndNode(node)

				return node
			elseif self:IsType("parser_debug_code") then
				local token = self:ExpectType("parser_debug_code")
				assert(loadstring("local parser = ...;" .. token.value:sub(3)))(self)
				local node = self:StartNode("statement", "parser_debug_code")
				
				local code = self:StartNode("expression", "value")
				code.value = token
				self:EndNode(code)

				node.lua_code = code
				
				self:EndNode(node)
				return node
			end
		end
		function META:ReadLocalTypeAssignmentStatement()
			if not (
				self:IsValue("local") and self:IsValue("type", 1) and
				runtime_syntax:GetTokenType(self:GetToken(2)) == "letter"
			) then return end
			local node = self:StartNode("statement", "local_assignment")
			node.tokens["local"] = self:ExpectValue("local")
			node.tokens["type"] = self:ExpectValue("type")
			node.left = self:ReadMultipleValues(nil, self.ReadIdentifier)
			node.environment = "typesystem"

			if self:IsValue("=") then
				node.tokens["="] = self:ExpectValue("=")
				self:PushParserEnvironment("typesystem")
				node.right = self:ReadMultipleValues(nil, self.ReadTypeExpression, 0)
				self:PopParserEnvironment()
			end

			self:EndNode(node)

			return node
		end
		function META:ReadTypeAssignmentStatement()
			if not (self:IsValue("type") and (self:IsType("letter", 1) or self:IsValue("^", 1))) then return end
			local node = self:StartNode("statement", "assignment")
			node.tokens["type"] = self:ExpectValue("type")
			node.left = self:ReadMultipleValues(nil, self.ReadTypeExpression, 0)
			node.environment = "typesystem"

			if self:IsValue("=") then
				node.tokens["="] = self:ExpectValue("=")
				self:PushParserEnvironment("typesystem")
				node.right = self:ReadMultipleValues(nil, self.ReadTypeExpression, 0)
				self:PopParserEnvironment()
			end

			self:EndNode(node)

			return node
		end

		function META:ReadCallOrAssignmentStatement()
			local start = self:GetToken()
			local left = self:ReadMultipleValues(math.huge, self.ExpectRuntimeExpression, 0)

			if self:IsValue("=") then
				local node = self:StartNode("statement", "assignment")
				node.tokens["="] = self:ExpectValue("=")

				node.left = left
				node.right = self:ReadMultipleValues(math.huge, self.ExpectRuntimeExpression, 0)
				self:EndNode(node)

				return node
			end

			if left[1] and (left[1].kind == "postfix_call" or left[1].kind == "import") and not left[2] then
				local node = self:StartNode("statement", "call_expression")
				node.value = left[1]
				node.tokens = left[1].tokens
				self:EndNode(node)

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

		function META:ReadRootNode()
			local node = self:StartNode("statement", "root")
			self.root = self.config and self.config.root or node
			local shebang

			if self:IsType("shebang") then

				shebang = self:StartNode("statement", "shebang")
				shebang.tokens["shebang"] = self:ExpectType("shebang")
				self:EndNode(shebang)

				node.tokens["shebang"] = shebang.tokens["shebang"]
			end

			node.statements = self:ReadNodes()

			if shebang then
				table.insert(node.statements, 1, shebang)
			end

			if self:IsType("end_of_file") then
				
				local eof = self:StartNode("statement", "end_of_file")
				eof.tokens["end_of_file"] = self.tokens[#self.tokens]
				self:EndNode(node)

				table.insert(node.statements, eof)
				node.tokens["eof"] = eof.tokens["end_of_file"]
			end

			self:EndNode(node)

			return node
		end

		function META:ReadNode()
			if self:IsType("end_of_file") then return end
			return
				self:ReadDebugCodeStatement() or
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

	end
end

return META.New
