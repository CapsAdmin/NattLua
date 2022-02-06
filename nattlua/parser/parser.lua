--[[#local type { Token, TokenType } = import_type<|"nattlua/lexer/token.nlua"|>]]
--[[#local type { ExpressionKind, StatementKind, FunctionAnalyzerStatement,
FunctionTypeStatement,
FunctionAnalyzerExpression,
FunctionTypeExpression,
FunctionExpression,
FunctionLocalStatement,
FunctionLocalTypeStatement,
FunctionStatement,
FunctionLocalAnalyzerStatement  } = import_type<|"nattlua/parser/nodes.nlua"|>]]
--[[#import_type<|"nattlua/code/code.lua"|>]]

--[[#local type NodeType = "expression" | "statement"]]
--[[#local type Node = any]]
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

--[[#type META.@Self = {
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
	type META.@Name = "Parser"
	local type Parser = META.@Self
	]]

function META.New(tokens--[[#: List<|Token|>]], code --[[#: Code]], config--[[#: any]])
	return setmetatable(
		{
			config = config,
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

function META:EndNode(node)
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

--[[#do return end]]

do -- statements
	local runtime_syntax = require("nattlua.syntax.runtime")
	local typesystem_syntax = require("nattlua.syntax.typesystem")

	local math = require("math")
	local math_huge = math.huge
	local table_insert = require("table").insert
	local table_remove = require("table").remove
	local ipairs = _G.ipairs
	
	local IsTypeExpression
	local ExpectTypeExpression = nil --[[# as function=(Parser, number)>(Node)]]
	local ReadTypeExpression = nil --[[# as function=(Parser, number)>(Node)]]
	
	local IsRuntimeExpression
	local ReadRuntimeExpression
	local ExpectRuntimeExpression

	local function ReadMultipleValues(parser--[[#: Parser ]], max--[[#: nil | number ]], reader--[[#: ref function=(Parser, ...: ...any)>(nil | Node)]], ...--[[#: ref ...any]])
		local out = {}

		for i = 1, max or parser:GetLength() do
			local node = reader(parser, ...)
			if not node then break end
			out[i] = node
			if not parser:IsValue(",") then break end
			node.tokens[","] = parser:ExpectValue(",")
		end

		return out
	end


	local function ReadIdentifier(parser--[[#: Parser]], expect_type--[[#: nil | boolean]])
		if not parser:IsType("letter") and not parser:IsValue("...") then return end
		local node = parser:StartNode("expression", "value")

		if parser:IsValue("...") then
			node.value = parser:ExpectValue("...")
		else
			node.value = parser:ExpectType("letter")
		end

		if parser:IsValue(":") or expect_type then
			node.tokens[":"] = parser:ExpectValue(":")
			node.type_expression = ExpectTypeExpression(parser, 0)
		end

		parser:EndNode(node)

		return node
	end

	local function ReadValueExpressionToken(parser--[[#: Parser]], expect_value--[[#: nil | string]]) 
		local node = parser:StartNode("expression", "value")
		node.value = expect_value and parser:ExpectValue(expect_value) or parser:ReadToken()
		parser:EndNode(node)
		return node
	end

	local function ReadValueExpressionType(parser--[[#: Parser]], expect_value--[[#: TokenType]]) 
		local node = parser:StartNode("expression", "value")
		node.value = parser:ExpectType(expect_value)
		parser:EndNode(node)
		return node
	end


	local function ReadFunctionBody(parser--[[#: Parser]], node--[[#: FunctionAnalyzerExpression | FunctionExpression | FunctionLocalStatement | FunctionStatement ]])
		node.tokens["arguments("] = parser:ExpectValue("(")
		node.identifiers = ReadMultipleValues(parser, nil, ReadIdentifier)
		node.tokens["arguments)"] = parser:ExpectValue(")", node.tokens["arguments("])

		if parser:IsValue(":") then
			node.tokens[":"] = parser:ExpectValue(":")
			parser:PushParserEnvironment("typesystem")
			node.return_types = ReadMultipleValues(parser, nil, ReadTypeExpression, 0)
			parser:PopParserEnvironment("typesystem")
		end

		node.statements = parser:ReadNodes({["end"] = true})
		node.tokens["end"] = parser:ExpectValue("end", node.tokens["function"])
		
		return node
	end

	local function ReadTypeFunctionBody(parser--[[#: Parser]], node--[[#: FunctionTypeStatement | FunctionTypeExpression | FunctionLocalTypeStatement]])
		if parser:IsValue("!") then
			node.tokens["!"] = parser:ExpectValue("!")	
			node.tokens["arguments("] = parser:ExpectValue("(")				
			node.identifiers = ReadMultipleValues(parser, nil, ReadIdentifier, true)

			if parser:IsValue("...") then
				table_insert(node.identifiers, ReadValueExpressionToken(parser, "..."))
			end
			node.tokens["arguments)"] = parser:ExpectValue(")")
		else
			node.tokens["arguments("] = parser:ExpectValue("<|")
			node.identifiers = ReadMultipleValues(parser, nil, ReadIdentifier, true)

			if parser:IsValue("...") then
				table_insert(node.identifiers, ReadValueExpressionToken(parser, "..."))
			end

			node.tokens["arguments)"] = parser:ExpectValue("|>", node.tokens["arguments("])
		end

		if parser:IsValue(":") then
			node.tokens[":"] = parser:ExpectValue(":")
			parser:PushParserEnvironment("typesystem")
			node.return_types = ReadMultipleValues(parser, math.huge, ExpectTypeExpression, 0)
			parser:PopParserEnvironment("typesystem")
		end

		node.environment = "typesystem"

		parser:PushParserEnvironment("typesystem")

		local start = parser:GetToken()
		node.statements = parser:ReadNodes({["end"] = true})
		node.tokens["end"] = parser:ExpectValue("end", start, start)

		parser:PopParserEnvironment()

		return node
	end

	local function ReadTypeFunctionArgument(parser--[[#: Parser]], expect_type--[[#: nil | boolean]])
		if parser:IsValue(")") then return end
		if parser:IsValue("...") then return end

		if expect_type or parser:IsType("letter") and parser:IsValue(":", 1) then
			local identifier = parser:ReadToken()
			local token = parser:ExpectValue(":")
			local exp = ExpectTypeExpression(parser, 0)
			exp.tokens[":"] = token
			exp.identifier = identifier
			return exp
		end

		return ExpectTypeExpression(parser, 0)
	end

	local function ReadAnalyzerFunctionBody(parser--[[#: Parser]], node--[[#: FunctionAnalyzerStatement | FunctionAnalyzerExpression |FunctionLocalAnalyzerStatement]], type_args--[[#: boolean]])
		node.tokens["arguments("] = parser:ExpectValue("(")

		node.identifiers = ReadMultipleValues(parser, math_huge, ReadTypeFunctionArgument, type_args)

		if parser:IsValue("...") then
			local vararg = parser:StartNode("expression", "value")
			vararg.value = parser:ExpectValue("...")

			if parser:IsValue(":") or type_args then
				vararg.tokens[":"] = parser:ExpectValue(":")
				vararg.type_expression = ExpectTypeExpression(parser, 0)
			else
				if parser:IsType("letter") then
					vararg.type_expression = ExpectTypeExpression(parser, 0)
				end
			end

			parser:EndNode(vararg)

			table_insert(node.identifiers, vararg)
		end

		node.tokens["arguments)"] = parser:ExpectValue(")", node.tokens["arguments("])

		if parser:IsValue(":") then
			node.tokens[":"] = parser:ExpectValue(":")
			parser:PushParserEnvironment("typesystem")
			node.return_types = ReadMultipleValues(parser, math.huge, ReadTypeExpression, 0)
			parser:PopParserEnvironment("typesystem")

			local start = parser:GetToken()
			node.statements = parser:ReadNodes({["end"] = true})
			node.tokens["end"] = parser:ExpectValue("end", start, start)
		elseif not parser:IsValue(",") then
			local start = parser:GetToken()
			node.statements = parser:ReadNodes({["end"] = true})
			node.tokens["end"] = parser:ExpectValue("end", start, start)
		end

		return node
	end
		--[[# do return end ]]


	do -- expression
		local function ReadAnalyzerFunctionExpression(parser)
			if not (parser:IsValue("analyzer") and parser:IsValue("function", 1)) then return end
			local node = parser:StartNode("expression", "analyzer_function")
			node.tokens["analyzer"] = parser:ExpectValue("analyzer")
			node.tokens["function"] = parser:ExpectValue("function")
			ReadAnalyzerFunctionBody(parser, node)
			parser:EndNode(node)
			return node
		end
	
		local function ReadFunctionExpression(parser)
			if not parser:IsValue("function") then return end
			local node = parser:StartNode("expression", "function")
			node.tokens["function"] = parser:ExpectValue("function")
			ReadFunctionBody(parser, node)
			parser:EndNode(node)
			return node
		end
	
		local function ReadIndexSubExpression(parser)
			if not (parser:IsValue(".") and parser:IsType("letter", 1)) then return end
			local node = parser:StartNode("expression", "binary_operator")
			node.value = parser:ReadToken()
			node.right = ReadValueExpressionType(parser, "letter")
			parser:EndNode(node)
			return node
		end
	
		local function IsCallExpression(parser, offset)
			return
				parser:IsValue("(", offset) or
				parser:IsValue("<|", offset) or
				parser:IsValue("{", offset) or
				parser:IsType("string", offset) or
				(parser:IsValue("!", offset) and parser:IsValue("(", offset + 1))
		end
	
		local function ReadSelfCallSubExpression(parser)
			if not (parser:IsValue(":") and parser:IsType("letter", 1) and IsCallExpression(parser, 2)) then return end
			local node = parser:StartNode("expression", "binary_operator")
			node.value = parser:ReadToken()
			node.right = ReadValueExpressionType(parser, "letter")
			parser:EndNode(node)
			return node
		end

		do -- typesystem
			local function ReadParenthesisOrTupleTypeExpression(parser)
				if not parser:IsValue("(") then return end
				local pleft = parser:ExpectValue("(")
				local node = ReadTypeExpression(parser, 0)
			
				if not node or parser:IsValue(",") then
					local first_expression = node
					local node = parser:StartNode("expression", "tuple")
					
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
					node.tokens[")"] = parser:ExpectValue(")", pleft)
					parser:EndNode(node)
					return node
				end
			
				node.tokens["("] = node.tokens["("] or {}
				table_insert(node.tokens["("], 1, pleft)
				node.tokens[")"] = node.tokens[")"] or {}
				table_insert(node.tokens[")"], parser:ExpectValue(")"))
				parser:EndNode(node)
				return node
			end
			
			local function ReadPrefixOperatorTypeExpression(parser)
				if not typesystem_syntax:IsPrefixOperator(parser:GetToken()) then return end
				local node = parser:StartNode("expression", "prefix_operator")
				node.value = parser:ReadToken()
				node.tokens[1] = node.value

				if node.value.value == "expand" then
					parser:PushParserEnvironment("runtime")
				end

				node.right = ReadTypeExpression(parser, math_huge)

				if node.value.value == "expand" then
					parser:PopParserEnvironment()
				end

				parser:EndNode(node)
				return node
			end
			
			local function ReadValueTypeExpression(parser)
				if not (parser:IsValue("...") and parser:IsType("letter", 1)) then return end
				local node = parser:StartNode("expression", "value")
				node.value = parser:ExpectValue("...")
				node.type_expression = ReadTypeExpression(parser, 0)
				parser:EndNode(node)
				return node
			end

			local function ReadTypeFunctionArgument(parser, expect_type)
				if parser:IsValue(")") then return end
			
				if expect_type or ((parser:IsType("letter") or parser:IsValue("...")) and parser:IsValue(":", 1)) then
					local identifier = parser:ReadToken()
					local token = parser:ExpectValue(":")
					local exp = ExpectTypeExpression(parser, 0)
					exp.tokens[":"] = token
					exp.identifier = identifier
					return exp
				end
			
				return ExpectTypeExpression(parser, 0)
			end
			
			local function ReadFunctionSignatureExpression(parser)
				if not (parser:IsValue("function") and parser:IsValue("=", 1)) then return end
			
				local node = parser:StartNode("expression", "function_signature")
				node.tokens["function"] = parser:ExpectValue("function")
				node.tokens["="] = parser:ExpectValue("=")
			
				node.tokens["arguments("] = parser:ExpectValue("(")
				node.identifiers = ReadMultipleValues(parser, nil, ReadTypeFunctionArgument)
				node.tokens["arguments)"] = parser:ExpectValue(")")
			
				node.tokens[">"] = parser:ExpectValue(">")
			
				node.tokens["return("] = parser:ExpectValue("(")
				node.return_types = ReadMultipleValues(parser, nil, ReadTypeFunctionArgument)
				node.tokens["return)"] = parser:ExpectValue(")")

				parser:EndNode(node)
				
				return node
			end
			
			local function ReadTypeFunctionExpression(parser)
				if not (parser:IsValue("function") and parser:IsValue("<|", 1)) then return end
				local node = parser:StartNode("expression", "type_function")
				node.tokens["function"] = parser:ExpectValue("function")
				ReadTypeFunctionBody(parser, node)
				parser:EndNode(node)
				return node
			end
					
			local function ReadKeywordValueTypeExpression(parser)
				if not typesystem_syntax:IsValue(parser:GetToken()) then return end
				local node = parser:StartNode("expression", "value")
				node.value = parser:ReadToken()
				parser:EndNode(node)
				return node
			end
			

			local ReadTableTypeExpression
			do
				local function read_type_table_entry(parser, i)
					if parser:IsValue("[") then
						local node = parser:StartNode("expression", "table_expression_value")
						node.expression_key = true
						node.tokens["["] = parser:ExpectValue("[")
						node.key_expression = ReadTypeExpression(parser, 0)
						node.tokens["]"] = parser:ExpectValue("]")
						node.tokens["="] = parser:ExpectValue("=")
						node.value_expression = ReadTypeExpression(parser, 0)
						parser:EndNode(node)
						return node
					elseif parser:IsType("letter") and parser:IsValue("=", 1) then
						local node = parser:StartNode("expression", "table_key_value")
						node.tokens["identifier"] = parser:ExpectType("letter")
						node.tokens["="] = parser:ExpectValue("=")
						node.value_expression = ReadTypeExpression(parser, 0)
						return node
					end
				
					local node = parser:StartNode("expression", "table_index_value")
					node.key = i
					node.value_expression = ReadTypeExpression(parser, 0)
					parser:EndNode(node)
					return node
				end
				
				function ReadTableTypeExpression(parser)
					if not parser:IsValue("{") then return end
					local tree = parser:StartNode("expression", "type_table")
					tree.tokens["{"] = parser:ExpectValue("{")
					tree.children = {}
					tree.tokens["separators"] = {}
				
					for i = 1, math_huge do
						if parser:IsValue("}") then break end
						local entry = read_type_table_entry(parser, i)
				
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
				
					tree.tokens["}"] = parser:ExpectValue("}")
					parser:EndNode(tree)
					return tree
				end
			end
			
			local function ReadStringTypeExpression(parser)
				if not (parser:IsType("$") and parser:IsType("string", 1)) then return end
				local node = parser:StartNode("expression", "type_string")
				node.tokens["$"] = parser:ReadToken("...")
				node.value = parser:ExpectType("string")
				return node
			end
			
			local function ReadEmptyUnionTypeExpression(parser)
				if not parser:IsValue("|") then return end
				local node = parser:StartNode("expression", "empty_union")
				node.tokens["|"] = parser:ReadToken("|")
				parser:EndNode(node)
				return node
			end
				
			local function ReadAsSubExpression(parser, node)
				if not parser:IsValue("as") then return end
				node.tokens["as"] = parser:ExpectValue("as")
				node.type_expression = ReadTypeExpression(parser, 0)
			end
		
			local function ReadPostfixOperatorSubExpression(parser)
				if not typesystem_syntax:IsPostfixOperator(parser:GetToken()) then return end

				local node = parser:StartNode("expression", "postfix_operator")
				node.value = parser:ReadToken()
				parser:EndNode(node)

				return node
			end
		
			local function ReadCallSubExpression(parser)
				if not IsCallExpression(parser, 0) then return end
				local node = parser:StartNode("expression", "postfix_call")
		
				if parser:IsValue("{") then
					node.expressions = {ReadTableTypeExpression(parser)}
				elseif parser:IsType("string") then
					node.expressions = {
							ReadValueExpressionToken(parser)
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
				parser:EndNode(node)
				return node
			end
		
			local function ReadPostfixIndexExpressionSubExpression(parser)
				if not parser:IsValue("[") then return end
				local node = parser:StartNode("expression", "postfix_expression_index")
				node.tokens["["] = parser:ExpectValue("[")
				node.expression = ExpectTypeExpression(parser, 0)
				node.tokens["]"] = parser:ExpectValue("]")
				parser:EndNode(node)
				return node
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
				local node
				local force_upvalue
			
				if parser:IsValue("^") then
					force_upvalue = true
					parser:Advance(1)
				end
			
				node = ReadParenthesisOrTupleTypeExpression(parser) or
					ReadEmptyUnionTypeExpression(parser) or
					ReadPrefixOperatorTypeExpression(parser) or
					ReadAnalyzerFunctionExpression(parser) or -- shared
					ReadFunctionSignatureExpression(parser) or
					ReadTypeFunctionExpression(parser) or -- shared
					ReadFunctionExpression(parser) or -- shared
					ReadValueTypeExpression(parser) or
					ReadKeywordValueTypeExpression(parser) or
					ReadTableTypeExpression(parser) or
					ReadStringTypeExpression(parser)
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
					node = parser:StartNode("expression", "binary_operator")
					node.value = parser:ReadToken()
					node.left = left_node
					node.right = ReadTypeExpression(parser, typesystem_syntax:GetBinaryOperatorInfo(node.value).right_priority)
					parser:EndNode(node)
				end

				return node
			end

			function IsTypeExpression(parser)
				local token = parser:GetToken()
			
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

			function ExpectTypeExpression(parser, priority)
				if not IsTypeExpression(parser) then
					local token = parser:GetToken()

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
		end

		do -- runtime
			local ReadTableExpression
			do
				local function read_table_spread(parser)
					if not (parser:IsValue("...") and (parser:IsType("letter", 1) or parser:IsValue("{", 1) or parser:IsValue("(", 1))) then return end
					local node = parser:StartNode("expression", "table_spread")
					node.tokens["..."] = parser:ExpectValue("...")
					node.expression = ExpectRuntimeExpression(parser)
					parser:EndNode(node)
					return node
				end
				
				local function read_table_entry(parser, i)
					if parser:IsValue("[") then
						local node = parser:StartNode("expression", "table_expression_value")
						node.expression_key = true
						node.tokens["["] = parser:ExpectValue("[")
						node.key_expression = ExpectRuntimeExpression(parser, 0)
						node.tokens["]"] = parser:ExpectValue("]")
						node.tokens["="] = parser:ExpectValue("=")
						node.value_expression = ExpectRuntimeExpression(parser, 0)
						parser:EndNode(node)
						return node
					elseif parser:IsType("letter") and parser:IsValue("=", 1) then
						local node = parser:StartNode("expression", "table_key_value")
						node.tokens["identifier"] = parser:ExpectType("letter")
						node.tokens["="] = parser:ExpectValue("=")

						local spread = read_table_spread(parser)
				
						if spread then
							node.spread = spread
						else
							node.value_expression = ExpectRuntimeExpression(parser)
						end

						parser:EndNode(node)
				
						return node
					end
				
					local node = parser:StartNode("expression", "table_index_value")
					local spread = read_table_spread(parser)
				
					if spread then
						node.spread = spread
					else
						node.value_expression = ExpectRuntimeExpression(parser)
					end
				
					node.key = i

					parser:EndNode(node)

					return node
				end
				
				function ReadTableExpression(parser)
					if not parser:IsValue("{") then return end
					local tree = parser:StartNode("expression", "table")
					tree.tokens["{"] = parser:ExpectValue("{")
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
				
					tree.tokens["}"] = parser:ExpectValue("}")
					parser:EndNode(tree)
					return tree
				end
			end

			local function ReadPostfixOperatorSubExpression(parser)
				if not runtime_syntax:IsPostfixOperator(parser:GetToken()) then return end
				local node = parser:StartNode("expression", "postfix_operator")
				node.value = parser:ReadToken()
				parser:EndNode(node)
				return node
			end

			local function ReadCallSubExpression(parser, primary_node)
				if not IsCallExpression(parser, 0) then return end

				if primary_node and primary_node.kind == "function" then
					if not primary_node.tokens[")"] then
						return
					end
				end


				local node = parser:StartNode("expression", "postfix_call")

				if parser:IsValue("{") then
					node.expressions = {ReadTableExpression(parser)}
				elseif parser:IsType("string") then
					node.expressions = {ReadValueExpressionToken(parser)}
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

				parser:EndNode(node)

				return node
			end

			local function ReadPostfixIndexExpressionSubExpression(parser)
				if not parser:IsValue("[") then return end
				local node = parser:StartNode("expression", "postfix_expression_index")
				node.tokens["["] = parser:ExpectValue("[")
				node.expression = ExpectRuntimeExpression(parser)
				node.tokens["]"] = parser:ExpectValue("]")
				parser:EndNode(node)

				return node
			end

			local function ReadSubExpression(parser, node)
				for _ = 1, parser:GetLength() do
					local left_node = node
					
					if parser:IsValue(":") and (not parser:IsType("letter", 1) or not IsCallExpression(parser, 2)) then
						node.tokens[":"] = parser:ExpectValue(":")
						node.type_expression = ExpectTypeExpression(parser, 0)
					elseif parser:IsValue("as") then
						node.tokens["as"] = parser:ExpectValue("as")
						node.type_expression = ExpectTypeExpression(parser, 0)
					elseif parser:IsValue("is") then
						node.tokens["is"] = parser:ExpectValue("is")
						node.type_expression = ExpectTypeExpression(parser, 0)
					end
					
					local found = ReadIndexSubExpression(parser) or
						ReadSelfCallSubExpression(parser) or
						ReadCallSubExpression(parser, node) or
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
				local node = parser:StartNode("expression", "prefix_operator")
				node.value = parser:ReadToken()
				node.tokens[1] = node.value
				node.right = ExpectRuntimeExpression(parser, math.huge)
				parser:EndNode(node)
				return node
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
				return ReadValueExpressionToken(parser)
			end

			local function ReadImportExpression(parser)
				if not (parser:IsValue("import") and parser:IsValue("(", 1)) then return end
				local node = parser:StartNode("expression", "import")
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
			
			function ReadRuntimeExpression(parser, priority)
				if parser:GetCurrentParserEnvironment() == "typesystem" then
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
					node = parser:StartNode("expression", "binary_operator")
					node.value = parser:ReadToken()
					node.left = left_node

					if node.left then
						node.left.parent = node
					end

					node.right = ExpectRuntimeExpression(parser, runtime_syntax:GetBinaryOperatorInfo(node.value).right_priority)

					parser:EndNode(node)

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
				end

				return node
			end

			function IsRuntimeExpression(parser)
				local token = parser:GetToken()

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

			function ExpectRuntimeExpression(parser, priority)
				if not IsRuntimeExpression(parser) then
					local token = parser:GetToken()

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
		end
	end

	do -- statement
		local ReadDestructureAssignmentStatement
		local ReadLocalDestructureAssignmentStatement
		do -- destructure statement
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

			function ReadDestructureAssignmentStatement(parser)
				if not IsDestructureStatement(parser) then return end
				local node = parser:StartNode("statement", "destructure_assignment")
				do
					if parser:IsType("letter") then
						node.default = ReadValueExpressionToken(parser)
						node.default_comma = parser:ExpectValue(",")
					end
				
					node.tokens["{"] = parser:ExpectValue("{")
					node.left = ReadMultipleValues(parser, nil, ReadIdentifier)
					node.tokens["}"] = parser:ExpectValue("}")
					node.tokens["="] = parser:ExpectValue("=")
					node.right = ReadRuntimeExpression(parser, 0)
				end
				parser:EndNode(node)
				return node
			end

			function ReadLocalDestructureAssignmentStatement(parser)
				if not IsLocalDestructureAssignmentStatement(parser) then return end
				local node = parser:StartNode("statement", "local_destructure_assignment")
				node.tokens["local"] = parser:ExpectValue("local")
			
				if parser:IsValue("type") then
					node.tokens["type"] = parser:ExpectValue("type")
					node.environment = "typesystem"
				end
			
				do -- remaining
					if parser:IsType("letter") then
						node.default = ReadValueExpressionToken(parser)
						node.default_comma = parser:ExpectValue(",")
					end
				
					node.tokens["{"] = parser:ExpectValue("{")
					node.left = ReadMultipleValues(parser, nil, ReadIdentifier)
					node.tokens["}"] = parser:ExpectValue("}")
					node.tokens["="] = parser:ExpectValue("=")
					node.right = ReadRuntimeExpression(parser, 0)
				end

				parser:EndNode(node)

				return node
			end
		end

		local ReadFunctionStatement
		local ReadAnalyzerFunctionStatement
		do
			local function ReadFunctionNameIndex(parser)
				if not runtime_syntax:IsValue(parser:GetToken()) then return end
				local node = ReadValueExpressionToken(parser)
				local first = node

				while parser:IsValue(".") or parser:IsValue(":") do
					local left = node
					local self_call = parser:IsValue(":")
					node = parser:StartNode("expression", "binary_operator")
					node.value = parser:ReadToken()
					node.right = ReadValueExpressionType(parser, "letter")
					node.left = left
					node.right.self_call = self_call
					parser:EndNode(node)
				end

				first.standalone_letter = node
				return node
			end

			function ReadFunctionStatement(parser)
				if not parser:IsValue("function") then return end
				local node = parser:StartNode("statement", "function")
				node.tokens["function"] = parser:ExpectValue("function")
				node.expression = ReadFunctionNameIndex(parser)

				if node.expression and node.expression.kind == "binary_operator" then
					node.self_call = node.expression.right.self_call
				end

				if parser:IsValue("<|") then
					node.kind = "type_function"
					ReadTypeFunctionBody(parser, node)
				else
					ReadFunctionBody(parser, node)
				end

				parser:EndNode(node)

				return node
			end

			function ReadAnalyzerFunctionStatement(parser)
				if not (parser:IsValue("analyzer") and parser:IsValue("function", 1)) then return end
				local node = parser:StartNode("statement", "analyzer_function")
				node.tokens["analyzer"] = parser:ExpectValue("analyzer")
				node.tokens["function"] = parser:ExpectValue("function")
				local force_upvalue

				if parser:IsValue("^") then
					force_upvalue = true
					node.tokens["^"] = parser:ReadToken()
				end

				node.expression = ReadFunctionNameIndex(parser)

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

				parser:EndNode(node)

				return node
			end
		end
		local function ReadLocalFunctionStatement(parser)
			if not (parser:IsValue("local") and parser:IsValue("function", 1)) then return end
			local node = parser:StartNode("statement", "local_function")
			
			node.tokens["local"] = parser:ExpectValue("local")
			node.tokens["function"] = parser:ExpectValue("function")
			node.tokens["identifier"] = parser:ExpectType("letter")
			ReadFunctionBody(parser, node)
			parser:EndNode(node)

			return node
		end
		local function ReadLocalAnalyzerFunctionStatement(parser)
			if not (parser:IsValue("local") and parser:IsValue("analyzer", 1) and parser:IsValue("function", 2)) then return end

			local node = parser:StartNode("statement", "local_analyzer_function")
			node.tokens["local"] = parser:ExpectValue("local")
			node.tokens["analyzer"] = parser:ExpectValue("analyzer")
			node.tokens["function"] = parser:ExpectValue("function")
			node.tokens["identifier"] = parser:ExpectType("letter")
			ReadAnalyzerFunctionBody(parser, node, true)
			parser:EndNode(node)

			return node
		end
		local function ReadLocalTypeFunctionStatement(parser)
			if not (parser:IsValue("local") and parser:IsValue("function", 1) and (parser:IsValue("<|", 3) or parser:IsValue("!", 3))) then return end

			local node = parser:StartNode("statement", "local_type_function")
			node.tokens["local"] = parser:ExpectValue("local")
			node.tokens["function"] = parser:ExpectValue("function")
			node.tokens["identifier"] = parser:ExpectType("letter")
			ReadTypeFunctionBody(parser, node)
			parser:EndNode(node)

			return node
		end
		local function ReadBreakStatement(parser)
			if not parser:IsValue("break") then return nil end

			local node = parser:StartNode("statement", "break")
			node.tokens["break"] = parser:ExpectValue("break")
			parser:EndNode(node)

			return node
		end
		local function ReadDoStatement(parser)
			if not parser:IsValue("do") then return nil end

			local node = parser:StartNode("statement", "do")
			node.tokens["do"] = parser:ExpectValue("do")
			node.statements = parser:ReadNodes({["end"] = true})
			node.tokens["end"] = parser:ExpectValue("end", node.tokens["do"])

			parser:EndNode(node)

			return node
		end
		local function ReadGenericForStatement(parser)
			if not parser:IsValue("for") then return nil end
			local node = parser:StartNode("statement", "generic_for")
			node.tokens["for"] = parser:ExpectValue("for")
			node.identifiers = ReadMultipleValues(parser, nil, ReadIdentifier)
			node.tokens["in"] = parser:ExpectValue("in")
			node.expressions = ReadMultipleValues(parser, math.huge, ExpectRuntimeExpression, 0)

			node.tokens["do"] = parser:ExpectValue("do")
			node.statements = parser:ReadNodes({["end"] = true})
			node.tokens["end"] = parser:ExpectValue("end", node.tokens["do"])

			parser:EndNode(node)

			return node
		end
		local function ReadGotoLabelStatement(parser)
			if not parser:IsValue("::") then return nil end
			local node = parser:StartNode("statement", "goto_label")
			node.tokens["::"] = parser:ExpectValue("::")
			node.tokens["identifier"] = parser:ExpectType("letter")
			node.tokens["::"] = parser:ExpectValue("::")
			parser:EndNode(node)

			return node
		end
		local function ReadGotoStatement(parser)
			if not parser:IsValue("goto") or not parser:IsType("letter", 1) then return nil end

			local node = parser:StartNode("statement", "goto")
			node.tokens["goto"] = parser:ExpectValue("goto")
			node.tokens["identifier"] = parser:ExpectType("letter")
			parser:EndNode(node)

			return node
		end
		local function ReadIfStatement(parser)
			if not parser:IsValue("if") then return nil end
			local node = parser:StartNode("statement", "if")
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

			node.tokens["end"] = parser:ExpectValue("end")
			parser:EndNode(node)

			return node
		end
		local function ReadLocalAssignmentStatement(parser)
			if not parser:IsValue("local") then return end
			local node = parser:StartNode("statement", "local_assignment")
			node.tokens["local"] = parser:ExpectValue("local")
			node.left = ReadMultipleValues(parser, nil, ReadIdentifier)

			if parser:IsValue("=") then
				node.tokens["="] = parser:ExpectValue("=")
				node.right = ReadMultipleValues(parser, nil, ReadRuntimeExpression, 0)
			end

			parser:EndNode(node)

			return node
		end
		local function ReadNumericForStatement(parser)
			if not (parser:IsValue("for") and parser:IsValue("=", 2)) then return nil end
			local node = parser:StartNode("statement", "numeric_for")
			node.tokens["for"] = parser:ExpectValue("for")
			node.identifiers = ReadMultipleValues(parser, 1, ReadIdentifier)
			node.tokens["="] = parser:ExpectValue("=")
			node.expressions = ReadMultipleValues(parser, 3, ExpectRuntimeExpression, 0)

			node.tokens["do"] = parser:ExpectValue("do")
			node.statements = parser:ReadNodes({["end"] = true})
			node.tokens["end"] = parser:ExpectValue("end", node.tokens["do"])

			parser:EndNode(node)

			return node
		end
		local function ReadRepeatStatement(parser)
			if not parser:IsValue("repeat") then return nil end
			local node = parser:StartNode("statement", "repeat")
			node.tokens["repeat"] = parser:ExpectValue("repeat")
			node.statements = parser:ReadNodes({["until"] = true})
			node.tokens["until"] = parser:ExpectValue("until")
			node.expression = ExpectRuntimeExpression(parser)
			parser:EndNode(node)
			return node
		end
		local function ReadSemicolonStatement(parser)
			if not parser:IsValue(";") then return nil end
			local node = parser:StartNode("statement", "semicolon")
			node.tokens[";"] = parser:ExpectValue(";")
			parser:EndNode(node)
			return node
		end
		local function ReadReturnStatement(parser)
			if not parser:IsValue("return") then return nil end
			local node = parser:StartNode("statement", "return")
			node.tokens["return"] = parser:ExpectValue("return")
			node.expressions = ReadMultipleValues(parser, nil, ReadRuntimeExpression, 0)
			parser:EndNode(node)

			return node
		end
		local function ReadWhileStatement(parser)
			if not parser:IsValue("while") then return nil end
			local node = parser:StartNode("statement", "while")
			node.tokens["while"] = parser:ExpectValue("while")
			node.expression = ExpectRuntimeExpression(parser)
			node.tokens["do"] = parser:ExpectValue("do")
			node.statements = parser:ReadNodes({["end"] = true})
			node.tokens["end"] = parser:ExpectValue("end", node.tokens["do"])

			parser:EndNode(node)

			return node
		end
		local function ReadContinueStatement(parser)
			if not parser:IsValue("continue") then return nil end

			local node = parser:StartNode("statement", "continue")
			node.tokens["continue"] = parser:ExpectValue("continue")
			parser:EndNode(node)

			return node
		end
		local function ReadDebugCodeStatement(parser)
			if parser:IsType("analyzer_debug_code") then
				local node = parser:StartNode("statement", "analyzer_debug_code")
				node.lua_code = ReadValueExpressionType(parser, "analyzer_debug_code")
				parser:EndNode(node)

				return node
			elseif parser:IsType("parser_debug_code") then
				local token = parser:ExpectType("parser_debug_code")
				assert(loadstring("local parser = ...;" .. token.value:sub(3)))(parser)
				local node = parser:StartNode("statement", "parser_debug_code")
				
				local code = parser:StartNode("expression", "value")
				code.value = token
				parser:EndNode(code)

				node.lua_code = code
				
				parser:EndNode(node)
				return node
			end
		end
		local function ReadLocalTypeAssignmentStatement(parser)
			if not (
				parser:IsValue("local") and parser:IsValue("type", 1) and
				runtime_syntax:GetTokenType(parser:GetToken(2)) == "letter"
			) then return end
			local node = parser:StartNode("statement", "local_assignment")
			node.tokens["local"] = parser:ExpectValue("local")
			node.tokens["type"] = parser:ExpectValue("type")
			node.left = ReadMultipleValues(parser, nil, ReadIdentifier)
			node.environment = "typesystem"

			if parser:IsValue("=") then
				node.tokens["="] = parser:ExpectValue("=")
				parser:PushParserEnvironment("typesystem")
				node.right = ReadMultipleValues(parser, nil, ReadTypeExpression, 0)
				parser:PopParserEnvironment()
			end

			parser:EndNode(node)

			return node
		end
		local function ReadTypeAssignmentStatement(parser)
			if not (parser:IsValue("type") and (parser:IsType("letter", 1) or parser:IsValue("^", 1))) then return end
			local node = parser:StartNode("statement", "assignment")
			node.tokens["type"] = parser:ExpectValue("type")
			node.left = ReadMultipleValues(parser, nil, ReadTypeExpression, 0)
			node.environment = "typesystem"

			if parser:IsValue("=") then
				node.tokens["="] = parser:ExpectValue("=")
				parser:PushParserEnvironment("typesystem")
				node.right = ReadMultipleValues(parser, nil, ReadTypeExpression, 0)
				parser:PopParserEnvironment()
			end

			parser:EndNode(node)

			return node
		end

		local function ReadCallOrAssignmentStatement(parser)
			local start = parser:GetToken()
			local left = ReadMultipleValues(parser, math.huge, ExpectRuntimeExpression, 0)

			if parser:IsValue("=") then
				local node = parser:StartNode("statement", "assignment")
				node.tokens["="] = parser:ExpectValue("=")

				node.left = left
				node.right = ReadMultipleValues(parser, math.huge, ExpectRuntimeExpression, 0)
				parser:EndNode(node)

				return node
			end

			if left[1] and (left[1].kind == "postfix_call" or left[1].kind == "import") and not left[2] then
				local node = parser:StartNode("statement", "call_expression")
				node.value = left[1]
				node.tokens = left[1].tokens
				parser:EndNode(node)

				return node
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
end

return META.New
