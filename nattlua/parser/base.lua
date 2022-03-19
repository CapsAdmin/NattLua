--[[#local type { Token, TokenType } = import("~/nattlua/lexer/token.nlua")]]

--[[#local type { 
	ExpressionKind,
	StatementKind,
	FunctionAnalyzerStatement,
	FunctionTypeStatement,
	FunctionAnalyzerExpression,
	FunctionTypeExpression,
	FunctionExpression,
	FunctionLocalStatement,
	FunctionLocalTypeStatement,
	FunctionStatement,
	FunctionLocalAnalyzerStatement,
	ValueExpression,
	Nodes
 } = import("./nodes.nlua")]]

--[[#import<|"~/nattlua/code/code.lua"|>]]
--[[#local type NodeType = "expression" | "statement"]]
local Node = require("nattlua.parser.node")
local ipairs = _G.ipairs
local pairs = _G.pairs
local setmetatable = _G.setmetatable
local type = _G.type
local table = _G.table
local helpers = require("nattlua.other.helpers")
local quote_helper = require("nattlua.other.quote")
local META = {}
META.__index = META
--[[#local type Node = Node.@Self]]
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
	OnNode = nil | function=(self, any)>(nil),
}]]
--[[#type META.@Name = "Parser"]]
--[[#local type Parser = META.@Self]]

function META.New(
	tokens--[[#: List<|Token|>]],
	code--[[#: Code]],
	config--[[#: nil | {
		root = nil | Node,
		on_statement = nil | function=(Parser, Node)>(Node),
		path = nil | string,
	}]]
)
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

	function META:PushParserEnvironment(env--[[#: "runtime" | "typesystem"]])
		table.insert(self.environment_stack, 1, env)
	end

	function META:PopParserEnvironment()
		table.remove(self.environment_stack, 1)
	end
end

function META:StartNode(
	type--[[#: ref ("statement" | "expression")]],
	kind--[[#: ref (StatementKind | ExpressionKind)]]
)--[[#: ref Node]]
	local code_start = assert(self:GetToken()).start
	local node = Node.New(
		{
			type = type,
			kind = kind,
			Code = self.Code,
			code_start = code_start,
			code_stop = code_start,
			environment = self:GetCurrentParserEnvironment(),
			parent = self.nodes[1],
		}
	)

	if type == "expression" then
		self.current_expression = node
	else
		self.current_statement = node
	end

	if self.OnNode then self:OnNode(node) end

	table.insert(self.nodes, 1, node)

	--[[#local function todo<||>
		for _, t in pairs<|Nodes|> do
			if t.kind == kind and t.type == type then
				node = copy<|node|>.@Contract
				 = t

				break
			end
		end
	end]]

	--[[#todo<||>]]
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

	table.remove(self.nodes, 1)
	return self
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
	local function error_expect(
		self--[[#: META.@Self]],
		str--[[#: string]],
		what--[[#: string]],
		start--[[#: Token | nil]],
		stop--[[#: Token | nil]]
	)
		local tk = self:GetToken()

		if not tk then
			self:Error("expected $1 $2: reached end of code", start, stop, what, str)
		else
			self:Error("expected $1 $2: got $3", start, stop, what, str, tk[what])
		end
	end

	function META:ExpectValue(str--[[#: string]], error_start--[[#: Token | nil]], error_stop--[[#: Token | nil]])--[[#: Token]]
		if not self:IsValue(str) then
			error_expect(self, str, "value", error_start, error_stop)
		end

		return self:ReadToken()--[[# as Token]]
	end

	function META:ExpectType(
		str--[[#: TokenType]],
		error_start--[[#: Token | nil]],
		error_stop--[[#: Token | nil]]
	)--[[#: Token]]
		if not self:IsType(str) then
			error_expect(self, str, "type", error_start, error_stop)
		end

		return self:ReadToken()--[[# as Token]]
	end
end

function META:ReadValues(
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

	return self:ReadToken()
end

function META:ReadNodes(stop_token--[[#: {[string] = true} | nil]])
	local out = {}
	local i = 1

	for _ = 1, self:GetLength() do
		local tk = self:GetToken()

		if not tk then break end

		if stop_token and stop_token[tk.value] then break end

		local node = self:ReadNode()

		if not node then break end

		if node[1] then
			for _, v in ipairs(node) do
				out[i] = v
				i = i + 1
			end
		else
			out[i] = node
			i = i + 1
		end

		if self.config and self.config.on_statement then
			out[i] = self.config.on_statement(self, out[i - 1]) or out[i - 1]
		end
	end

	return out
end

function META:ResolvePath(path--[[#: string]])
	return path
end

function META:ReadMultipleValues(
	max--[[#: nil | number]],
	reader--[[#: ref function=(Parser, ...: ...any)>(nil | Node)]],
	...--[[#: ref ...any]]
)
	local out = {}

	for i = 1, max or self:GetLength() do
		local node = reader(self, ...)--[[# as Node | nil]]

		if not node then break end

		out[i] = node

		if not self:IsValue(",") then break end

		node.tokens[","] = self:ExpectValue(",")
	end

	return out
end

return META
