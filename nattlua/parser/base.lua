--[[# --ANALYZE
local type { Token, TokenType } = import("~/nattlua/lexer/token.lua")]]

--[[#local type { ExpressionKind, StatementKind, Nodes, Node } = import("~/nattlua/parser/node.lua")]]

--[[#local type ParserConfig = import("~/nattlua/parser/config.nlua")]]

--[[#local type { Code } = import<|"~/nattlua/code.lua"|>]]

--[[#local type NodeType = "expression" | "statement"]]
local NewNode = require("nattlua.parser.node").New
local ipairs = _G.ipairs
local pairs = _G.pairs
local assert = _G.assert
local setmetatable = _G.setmetatable
local type = _G.type
local table = _G.table
local math_min = math.min
local class = require("nattlua.other.class")
local Token = require("nattlua.lexer.token").New
local META = class.CreateTemplate("parser")
META.OnInitialize = {}
--[[#type META.@Self = {
	@Name = "Parser",
	config = ParserConfig,
	Code = Code,
	tokens = List<|Token|>,
	current_token_index = number,
	suppress_on_parsed_node = false | {parent = Node | false, node_stack = List<|Node|>},
	RootStatement = false | Node,
	TealCompat = any,
	dont_hoist_next_import = any,
	imported = any,
	statement_count = any,
	dollar_signs = any,
	value = any,
	context_values = any,
	FFI_DECLARATION_PARSER = boolean,
	CDECL_PARSING_MODE = "typeof" | "ffinew" | false,
	OnPreCreateNode = function=(self: any, node: any)>(),
	OnError = function=(
		self: self,
		code: Code,
		message: string,
		start: number,
		stop: number,
		...: ...any
	)>(),
}]]
--[[#type META.@Name = "Parser"]]
require("nattlua.other.context_mixin")(META)
--[[#local type Parser = META.@Self]]

function META:OnPreCreateNode(node--[[#: any]]) end

function META:OnParsedNode(node--[[#: any]]) end

function META.New(
	tokens--[[#: List<|Token|>]],
	code--[[#: Code]],
	config--[[#: nil | false | {
		root = nil | Node,
		on_parsed_node = nil | function=(Parser, Node)>(Node),
		path = nil | string,
	}]]
)
	local self = {
		config = config or {},
		Code = code,
		current_token_index = 1,
		tokens = tokens,
		suppress_on_parsed_node = false,
		RootStatement = false,
		TealCompat = false,
		dont_hoist_next_import = false,
		imported = false,
		statement_count = false,
		dollar_signs = false,
		CDECL_PARSING_MODE = false,
		value = false,
		FFI_DECLARATION_PARSER = false,
		OnPreCreateNode = META.OnPreCreateNode,
		OnError = META.OnError,
	}

	for _, func in ipairs(META.OnInitialize) do
		func(self)
	end

	return setmetatable(self, META)
end

do
	function META:PushParserEnvironment(env--[[#: "typesystem" | "runtime"]])
		self:PushContextValue("parser_environment", env)
	end

	function META:GetCurrentParserEnvironment()
		return self:GetContextValue("parser_environment") or "runtime"
	end

	function META:PopParserEnvironment()
		self:PopContextValue("parser_environment")
	end
end

do
	function META:PushParentNode(node--[[#: any]])
		self:PushContextValue("parent_node", node)
	end

	function META:GetParentNode(level--[[#: nil | number]])
		return self:GetContextValue("parent_node", level) or false--[[# as Node | false]]
	end

	function META:PopParentNode()
		self:PopContextValue("parent_node")
	end
end

--[=[
ALL_NODES = {}
local function dump_fields(node)
	if false --[[# as true]] then return end
	local key = node.type .. "_" .. node.kind
	ALL_NODES[node.type] = ALL_NODES[node.type] or {}
	ALL_NODES[node.type][node.kind] = ALL_NODES[node.type][node.kind] or {tokens = {}}
	local NODE = ALL_NODES[node.type][node.kind]

	for k, v in pairs(node) do
		NODE[k] = NODE[k] or {}
		NODE[k][type(v)] = true
	end

	for k, v in pairs(node.tokens) do
		NODE.tokens[k] = true
	end
end
]=]
function META:StartNode(
	node_type--[[#: ref (keysof<|Nodes|>)]],
	kind--[[#: ref (StatementKind | ExpressionKind)]],
	start_node--[[#: nil | Node]]
)--[[#: ref any]]
	local code_start = start_node and start_node.code_start or assert(self:GetToken()).start
	local node = NewNode(
		node_type,
		kind,
		self:GetCurrentParserEnvironment(),
		self.Code,
		code_start,
		code_start,
		self:GetParentNode()
	)
	self:OnPreCreateNode(node)
	self:PushParentNode(node)
	return node
end

function META:EndNode(node--[[#: Node]])
	local prev = self:GetToken(-1)

	if prev then
		node.code_stop = prev.stop
	else
		local cur = self:GetToken()

		if cur then node.code_stop = cur.stop end
	end

	self:PopParentNode()
	self:OnParsedNode(node)

	if self.config.on_parsed_node then
		if
			node.type == "expression" and
			self.suppress_on_parsed_node and
			self.suppress_on_parsed_node.parent == self:GetParentNode()
		then
			table.insert((self.suppress_on_parsed_node--[[# as any]]).node_stack, node)
		else
			local new_node = self.config.on_parsed_node(self, node)

			if new_node then
				node = new_node--[[# as any]]
				node.parent = self:GetParentNode()
			end
		end
	end

	return node
end

function META:SuppressOnNode()
	self.suppress_on_parsed_node = {parent = self:GetParentNode(), node_stack = {}}
end

function META:ReRunOnNode(node_stack--[[#: List<|Node|>]])
	if not self.suppress_on_parsed_node then return end

	for _, node_a in ipairs(self.suppress_on_parsed_node.node_stack) do
		for i, node_b in ipairs(node_stack) do
			if node_a == node_b and self.config.on_parsed_node then
				local new_node = self.config.on_parsed_node(self, node_a)

				if new_node then
					node_stack[i] = new_node
					new_node.parent = self:GetParentNode()
				end
			end
		end
	end

	self.suppress_on_parsed_node = false
end

function META:Error(
	msg--[[#: string]],
	start_token--[[#: Token | nil]],
	stop_token--[[#: Token | nil]],
	...--[[#: ...any]]
)
	local tk = self:GetToken()
	local start = 0
	local stop = 0

	if start_token then
		start = start_token.start
	elseif tk then
		start = tk.start
	end

	if stop_token then stop = stop_token.stop elseif tk then stop = tk.stop end

	self:OnError(self.Code, msg, start, stop, ...)
end

function META:OnError(
	code--[[#: Code]],
	message--[[#: string]],
	start--[[#: number]],
	stop--[[#: number]],
	...--[[#: ...any]]
) end

function META:GetToken(offset--[[#: number | nil]])
	return self.tokens[self.current_token_index + (
			offset or
			0
		)] or
		self:NewToken("end_of_file", "")
end

function META:GetPosition()
	return self.current_token_index
end

function META:SetPosition(pos--[[#: number]])
	self.current_token_index = pos
end

function META:GetLength()
	return #self.tokens
end

function META:Advance(offset--[[#: number]])
	self.current_token_index = self.current_token_index + offset
end

function META:ConsumeToken()
	local tk = self:GetToken()
	self:Advance(1)
	return tk
end

function META:IsTokenValue(str--[[#: string]], offset--[[#: number | nil]])
	local tk = self:GetToken(offset)

	if tk then return tk.value == str end
end

function META:IsTokenType(token_type--[[#: TokenType]], offset--[[#: number | nil]])
	local tk = self:GetToken(offset)

	if tk then return tk.type == token_type end
end

function META:ParseToken()
	local tk = self:GetToken()

	if not tk then return nil end

	self:Advance(1)
	tk.parent = self:GetParentNode()
	return tk
end

function META:RemoveToken(i)
	local t = self.tokens[i]
	table.remove(self.tokens, i)
	return t
end

function META:AddTokens(tokens--[[#: {[1 .. inf] = Token}]])
	local eof = table.remove(self.tokens)--[[# as Token]]

	for i, token in ipairs(tokens) do
		if token.type == "end_of_file" then break end

		table.insert(self.tokens, self.current_token_index + i - 1, token)
	end

	table.insert(self.tokens, eof)
end

do
	local function error_expect(
		self--[[#: META.@Self]],
		str--[[#: string]],
		what--[[#: string]],
		start--[[#: Token | nil]],
		stop--[[#: Token | nil]]
	)
		local tk = self:GetToken()
		local node = self:GetParentNode()
		local kind = node and node.kind or "unknown"

		if not tk then
			self:Error(
				"expected $1 $2: reached end of code while parsing $3",
				start,
				stop,
				what,
				str,
				kind
			)
		else
			self:Error("expected $1 $2: got $3 while parsing $4", start, stop, what, str, tk[what], kind)
		end
	end

	function META:ExpectTokenValue(str--[[#: string]], error_start--[[#: Token | nil]], error_stop--[[#: Token | nil]])--[[#: Token]]
		if not self:IsTokenValue(str) then
			error_expect(self, str, "value", error_start, error_stop)
			return self:NewToken("letter", str)
		end

		return self:ParseToken()--[[# as Token]]
	end

	function META:ExpectValueTranslate(
		str--[[#: string]],
		new_str--[[#: string]],
		error_start--[[#: Token | nil]],
		error_stop--[[#: Token | nil]]
	)--[[#: Token]]
		if not self:IsTokenValue(str) then
			error_expect(self, str, "value", error_start, error_stop)
			return self:NewToken("value", str)
		end

		local tk = self:ParseToken()--[[# as Token]]
		tk.value = new_str
		return tk
	end

	function META:ExpectTokenType(
		str--[[#: TokenType]],
		error_start--[[#: Token | nil]],
		error_stop--[[#: Token | nil]]
	)--[[#: Token]]
		if not self:IsTokenType(str) then
			error_expect(self, str, "type", error_start, error_stop)
			return self:NewToken(str, "")
		end

		return self:ParseToken()--[[# as Token]]
	end

	function META:NewToken(type--[[#: TokenType]], value--[[#: string]])
		return Token(type, value, 0, 0)
	end
end

function META:ParseValues(
	values--[[#: Map<|string, true|>]],
	start--[[#: Token | nil]],
	stop--[[#: Token | nil]]
)
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

	return self:ParseToken()
end

function META:ParseStatements(stop_token--[[#: {[string] = true} | nil]], out--[[#: List<|any|>]])
	out = out or {}
	local i = #out

	for _ = self:GetPosition(), self:GetLength() do
		local tk = self:GetToken()

		if not tk then break end

		if stop_token and stop_token[tk.value] then break end

		local node = (self--[[# as any]]):ParseStatement()

		if not node then break end

		if node.type then
			i = i + 1
			out[i] = node
		else
			for _, v in ipairs(node) do
				i = i + 1
				out[i] = v
			end
		end
	end

	return out
end

function META:ParseMultipleValues(
	reader--[[#: ref function=(Parser, ...: ref ...any)>(ref (nil | Node))]],
	a--[[#: ref any]],
	b--[[#: ref any]],
	c--[[#: ref any]]
)
	local out = {}

	for i = 1, math_min(self:GetLength(), 200) do
		local node = reader(self, a, b, c)

		if not node then break end

		out[i] = node

		if not self:IsTokenValue(",") then break end

		(node.tokens--[[# as any]])[","] = self:ExpectTokenValue(",")
	end

	return out
end

function META:ParseFixedMultipleValues(
	max--[[#: number]],
	reader--[[#: ref function=(Parser, ...: ref ...any)>(ref (any))]],
	a--[[#: ref any]],
	b--[[#: ref any]],
	c--[[#: ref any]]
)
	local out = {}

	for i = 1, max do
		local node = reader(self, a, b, c)

		if not node then break end

		out[i] = node

		if not self:IsTokenValue(",") then break end

		(node.tokens--[[# as any]])[","] = self:ExpectTokenValue(",")
	end

	return out
end

function META:ParseMultipleValuesAppend(
	reader--[[#: ref function=(Parser, ...: ref ...any)>(ref (nil | Node))]],
	out--[[#: List<|Node|>]],
	a--[[#: ref any]],
	b--[[#: ref any]],
	c--[[#: ref any]]
)
	for i = #out + 1, math_min(self:GetLength(), 20) do
		local node = reader(self, a, b, c)

		if not node then break end

		out[i] = node

		if not self:IsTokenValue(",") then break end

		(node.tokens--[[# as any]])[","] = self:ExpectTokenValue(",")
	end

	return out
end

function META:ErrorExpression()
	local node = self:StartNode("expression", "error")--[[# as any]]
	node = self:EndNode(node)
	return node
end

function META:ErrorStatement()
	local node = self:StartNode("statement", "error")--[[# as any]]
	node = self:EndNode(node)
	return node
end

return META
