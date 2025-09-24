--ANALYZE
--[[HOTRELOAD
		run_test("test/tests/nattlua/parser.lua")

]]
local table_insert = _G.table.insert
local table_sort = _G.table.sort
local pairs = _G.pairs
local ipairs = _G.ipairs
local type = _G.type
local class = require("nattlua.other.class")

--[[#local type { Token } = import("~/nattlua/lexer/token.lua")]]

--[[#type TreeNode = {[number] = self | nil, value = any | nil, max_len = nil | number}]]
--[[#type BinaryOperatorInfo = {op = string, left_priority = number, right_priority = number}]]
--[[#type OperatorFunctionInfo = {op = string, info = {string, string} | {string, string, string}}]]
--[[#type CompiledTree = {tree = TreeNode, lookup = nil | Function}]]
local META = class.CreateTemplate("syntax")
--[[#type META.@Name = "Syntax"]]
--[[#type META.@Self = {
	BinaryOperatorInfo = List<|BinaryOperatorInfo|>,
	BinaryOperatorInfoTree = function=(Token)>(BinaryOperatorInfo | nil),
	NumberAnnotations = List<|string|>,
	Symbols = List<|string|>,
	BinaryOperators = Map<|string, true|>,
	PrefixOperators = List<|string|>,
	PrefixOperatorsTree = function=(Token)>(string | nil),
	PostfixOperators = List<|string|>,
	PostfixOperatorsTree = function=(Token)>(string | nil),
	PrimaryBinaryOperators = List<|string|>,
	PrimaryBinaryOperatorsTree = function=(Token)>(string | nil),
	SymbolCharacters = List<|string|>,
	SymbolPairs = Map<|string, string|>,
	KeywordValues = List<|string|>,
	KeywordValuesTree = function=(Token)>(string | nil),
	Keywords = List<|string|>,
	KeywordsTree = function=(Token)>(string | nil),
	NonStandardKeywords = List<|string|>,
	NonStandardKeywordsTree = function=(Token)>(string | nil),
	BinaryOperatorFunctionTranslate = List<|OperatorFunctionInfo|>,
	BinaryOperatorFunctionTranslateTree = function=(Token)>(OperatorFunctionInfo | nil),
	PostfixOperatorFunctionTranslate = List<|OperatorFunctionInfo|>,
	PostfixOperatorFunctionTranslateTree = function=(Token)>(OperatorFunctionInfo | nil),
	PrefixOperatorFunctionTranslate = List<|OperatorFunctionInfo|>,
	PrefixOperatorFunctionTranslateTree = function=(Token)>(OperatorFunctionInfo | nil),
	ReadMap = Map<|string, true|>,
}]]

-- Fixed version - the key issue was not respecting token length in the loop
local function build_tree1(
	items--[[#: List<|string|> | List<|BinaryOperatorInfo|> | List<|OperatorFunctionInfo|>]]
)
	local return_value = type(items[1]) == "table"
	local longest = 0
	local map = {}

	local lookup = {}

	if return_value then
		for i,v in ipairs(items) do
			lookup[v.op] = v
		end
	else
		for i,v in ipairs(items) do
			lookup[v] = v
		end
	end

	if return_value then
		table.sort(items, function(a, b)
			return #a.op > #b.op
		end)
	else
		table.sort(items, function(a, b)
			return #a > #b
		end)
	end

	for _, item in ipairs(items) do
		local str

		if return_value then str = item.op else str = item end

		if #str > longest then longest = #str end

		str = str--[[# as string]]
		local node = map

		for i = 1, #str do
			local b = str:byte(i)
			node[b] = node[b] or {}
			node = node[b]

			if i == #str then
				if return_value then node.END = item else node.END = item end
			end
		end
	end

	return function(token)
		if token.value then
			return lookup[token.value]
		end
		local token_length = token:GetLength()

		if token_length > longest then return nil end

		local node = map

		for i = 0, token_length - 1 do
			node = node[token:GetByte(i)]

			if not node then return nil end
		end

		return node.END
	end
end

local function build_tree2(
	items--[[#: List<|string|> | List<|BinaryOperatorInfo|> | List<|OperatorFunctionInfo|>]]
)
	if false--[[# as true]] then return _--[[# as any]] end

	local ffi = require("ffi")
	local return_value = type(items[1]) == "table"
	local longest = 0
	local max_nodes = 1 -- root

	local lookup = {}

	if return_value then
		for i,v in ipairs(items) do
			lookup[v.op] = v
		end
	else
		for i,v in ipairs(items) do
			lookup[v] = v
		end
	end


	if return_value then
		table.sort(items, function(a, b)
			return #a.op > #b.op
		end)

		for _, str in ipairs(items) do
			max_nodes = max_nodes + #str.op
			longest = math.max(longest, #str.op)
		end
	else
		table.sort(items, function(a, b)
			return #a > #b
		end)

		for _, str in ipairs(items) do
			max_nodes = max_nodes + #str
			longest = math.max(longest, #str)
		end
	end

	local node_type = ffi.typeof([[
		struct {
			uint8_t children[256];
			uint8_t end_marker;
		}
	]])
	local node_array_type = ffi.typeof("$[?]", node_type)
	local nodes = ffi.new(node_array_type, max_nodes)
	local string_storage = {}
	local node_count = 1

	for i = 0, 255 do
		nodes[0].children[i] = 0
	end

	nodes[0].end_marker = 0

	for _, item in ipairs(items) do
		local current_node = 0

		if return_value then str = item.op else str = item end

		for i = 1, #str do
			local byte_val = str:byte(i)
			local child_node = nodes[current_node].children[byte_val]

			if child_node == 0 then
				child_node = node_count
				node_count = node_count + 1

				for j = 0, 255 do
					nodes[child_node].children[j] = 0
				end

				nodes[child_node].end_marker = 0
				nodes[current_node].children[byte_val] = child_node
			end

			current_node = child_node
		end

		nodes[current_node].end_marker = 1
		string_storage[current_node] = item
	end

	return function(token)
		if token.value then
			return lookup[token.value]
		end

		local token_length = token:GetLength()

		if token_length > longest then return nil end

		local node_index = 0

		if token_length == 1 then
			local child = nodes[0].children[token:GetByte(0)]

			if child == 0 then return nil end

			return nodes[child].end_marker == 1 and string_storage[child] or nil
		end

		for i = 0, token_length - 1 do
			local child = nodes[node_index].children[token:GetByte(i)]

			if child == 0 then return nil end

			node_index = child
		end

		return nodes[node_index].end_marker == 1 and string_storage[node_index] or nil
	end
end

if jit then build_tree = build_tree2 else build_tree = build_tree1 end

function META.New()
	return META.NewObject(
		{
			NumberAnnotations = {},
			BinaryOperatorInfo = {},
			Symbols = {},
			BinaryOperators = {},
			PrefixOperators = {},
			PostfixOperators = {},
			PrimaryBinaryOperators = {},
			SymbolCharacters = {},
			SymbolPairs = {},
			KeywordValues = {},
			Keywords = {},
			NonStandardKeywords = {},
			BinaryOperatorFunctionTranslate = {},
			PostfixOperatorFunctionTranslate = {},
			PrefixOperatorFunctionTranslate = {},
			ReadMap = {},
		}--[[# as META.@Self]],
		true
	)
end

local function has_value(tbl--[[#: {[1 .. inf] = string} | {}]], value--[[#: string]])--[[#: boolean]]
	for k, v in ipairs(tbl) do
		if v == value then return true end
	end

	return false
end

function META:AddSymbols(tbl--[[#: List<|string|>]])
	for _, symbol in pairs(tbl) do
		if symbol:find("%p") and not has_value(self.Symbols, symbol) then
			table_insert(self.Symbols, symbol)
			self.ReadMap[symbol] = true
		end
	end

	table_sort(self.Symbols, function(a, b)
		return #a > #b
	end)
end

function META:AddNumberAnnotations(tbl--[[#: List<|string|>]])
	for i, v in ipairs(tbl) do
		if not has_value(self.NumberAnnotations, v) then
			table.insert(self.NumberAnnotations, v)
		end
	end

	table.sort(self.NumberAnnotations, function(a, b)
		return #a > #b
	end)
end

function META:AddBinaryOperators(tbl--[[#: List<|List<|string|>|>]])
	for priority, group in ipairs(tbl) do
		for _, token in ipairs(group) do
			local right = token:sub(1, 1) == "R"

			if right then token = token:sub(2) end

			local info--[[#: BinaryOperatorInfo]] = {
				op = token,
				left_priority = right and (priority + 1) or priority,
				right_priority = priority,
			}
			table.insert(self.BinaryOperatorInfo, info)
			self:AddSymbols({token})
			self.BinaryOperators[token] = true
			self.ReadMap[token] = true
		end
	end

	-- Build and compile the tree
	self.BinaryOperatorInfoTree = build_tree(self.BinaryOperatorInfo)
end

function META:AddPostfixOperators(tbl--[[#: List<|string|>]])
	self:AddSymbols(tbl)

	for _, str in ipairs(tbl) do
		table.insert(self.PostfixOperators, str)
		self.ReadMap[str] = true
	end

	-- Build and compile the tree
	self.PostfixOperatorsTree = build_tree(self.PostfixOperators)
end

function META:AddPrefixOperators(tbl--[[#: List<|string|>]])
	self:AddSymbols(tbl)

	for _, str in ipairs(tbl) do
		table.insert(self.PrefixOperators, str)
		self.ReadMap[str] = true
	end

	-- Build and compile the tree
	self.PrefixOperatorsTree = build_tree(self.PrefixOperators)
end

function META:AddPrimaryBinaryOperators(tbl--[[#: List<|string|>]])
	self:AddSymbols(tbl)

	for _, str in ipairs(tbl) do
		table.insert(self.PrimaryBinaryOperators, str)
		self.ReadMap[str] = true
	end

	-- Build and compile the tree
	self.PrimaryBinaryOperatorsTree = build_tree(self.PrimaryBinaryOperators)
end

function META:AddSymbolCharacters(tbl--[[#: List<|string | {string, string}|>]])
	local list = {}

	for _, val in ipairs(tbl) do
		if type(val) == "table" then
			table_insert(list, val[1])
			table_insert(list, val[2])
			self.SymbolPairs[val[1]] = val[2]
		else
			table_insert(list, val)
		end
	end

	self.SymbolCharacters = list
	self:AddSymbols(list)
end

function META:AddKeywords(tbl--[[#: List<|string|>]])
	self:AddSymbols(tbl)

	for _, str in ipairs(tbl) do
		table.insert(self.Keywords, str)
		self.ReadMap[str] = true
	end

	-- Build and compile the tree
	self.KeywordsTree = build_tree(self.Keywords)
end

function META:AddKeywordValues(tbl--[[#: List<|string|>]])
	self:AddSymbols(tbl)

	for _, str in ipairs(tbl) do
		table.insert(self.Keywords, str)
		table.insert(self.KeywordValues, str)
		self.ReadMap[str] = true
	end

	-- Build and compile both trees
	self.KeywordsTree = build_tree(self.Keywords)
	self.KeywordValuesTree = build_tree(self.KeywordValues)
end

function META:AddNonStandardKeywords(tbl--[[#: List<|string|>]])
	self:AddSymbols(tbl)

	for _, str in ipairs(tbl) do
		table.insert(self.NonStandardKeywords, str)
		self.ReadMap[str] = true
	end

	-- Build and compile the tree
	self.NonStandardKeywordsTree = build_tree(self.NonStandardKeywords)
end

function META:AddBinaryOperatorFunctionTranslate(tbl--[[#: Map<|string, string|>]])
	for op, v in pairs(tbl) do
		local a, b, c = v:match("(.-)A(.-)B(.*)")

		if a and b and c then
			local info--[[#: OperatorFunctionInfo]] = {op = op, info = {" " .. a, b, c .. " "}}
			table.insert(self.BinaryOperatorFunctionTranslate, info)
		end

		self.ReadMap[op] = true
	end

	-- Build and compile the tree
	self.BinaryOperatorFunctionTranslateTree = build_tree(self.BinaryOperatorFunctionTranslate)
end

function META:AddPrefixOperatorFunctionTranslate(tbl--[[#: Map<|string, string|>]])
	for op, v in pairs(tbl) do
		local a, b = v:match("^(.-)A(.-)$")

		if a and b then
			local info--[[#: OperatorFunctionInfo]] = {op = op, info = {" " .. a, b .. " "}}
			table.insert(self.PrefixOperatorFunctionTranslate, info)
		end

		self.ReadMap[op] = true
	end

	-- Build and compile the tree
	self.PrefixOperatorFunctionTranslateTree = build_tree(self.PrefixOperatorFunctionTranslate)
end

function META:AddPostfixOperatorFunctionTranslate(tbl--[[#: Map<|string, string|>]])
	for op, v in pairs(tbl) do
		local a, b = v:match("^(.-)A(.-)$")

		if a and b then
			local info--[[#: OperatorFunctionInfo]] = {op = op, info = {" " .. a, b .. " "}}
			table.insert(self.PostfixOperatorFunctionTranslate, info)
		end

		self.ReadMap[op] = true
	end

	-- Build and compile the tree
	self.PostfixOperatorFunctionTranslateTree = build_tree(self.PostfixOperatorFunctionTranslate)
end

function META:GetNumberAnnotations()
	return self.NumberAnnotations
end

function META:GetBinaryOperatorInfo(token--[[#: Token]])--[[#: BinaryOperatorInfo | nil]]
	return self.BinaryOperatorInfoTree(token)
end

function META:IsPrefixOperator(token--[[#: Token]])--[[#: boolean]]
	return self.PrefixOperatorsTree(token) ~= nil
end

function META:IsPostfixOperator(token--[[#: Token]])--[[#: boolean]]
	return self.PostfixOperatorsTree(token) ~= nil
end

function META:IsPrimaryBinaryOperator(token--[[#: Token]])--[[#: boolean]]
	return self.PrimaryBinaryOperatorsTree(token) ~= nil
end

function META:IsVariableName(token--[[#: Token]])--[[#: boolean]]
	return token.type == "letter" and
		not self:IsKeyword(token)
		and
		not self:IsKeywordValue(token)
		and
		not self:IsNonStandardKeyword(token)
end

function META:IsKeyword(token--[[#: Token]])--[[#: boolean]]
	return self.KeywordsTree(token) ~= nil
end

function META:IsKeywordValue(token--[[#: Token]])--[[#: boolean]]
	return self.KeywordValuesTree(token) ~= nil
end

function META:IsNonStandardKeyword(token--[[#: Token]])--[[#: boolean]]
	return self.NonStandardKeywordsTree(token) ~= nil
end

function META:BuildReadMapReader(extra_map)
	local list = {}
	for k,v in pairs(self.ReadMap) do
		table.insert(list, k)
	end
	if extra_map then
		for k,v in pairs(extra_map) do
			if not self.ReadMap[k] then
				table.insert(list, k)
			end
		end
	end
	return build_tree(list)
end

function META:GetSymbols()
	return self.Symbols
end

function META:GetFunctionForBinaryOperator(token--[[#: Token]])--[[#: {string, string, string} | nil]]
	local result = self.BinaryOperatorFunctionTranslateTree(token)
	return result and result.info or nil
end

function META:GetFunctionForPrefixOperator(token--[[#: Token]])--[[#: {string, string} | nil]]
	local result = self.PrefixOperatorFunctionTranslateTree(token)
	return result and result.info or nil
end

function META:GetFunctionForPostfixOperator(token--[[#: Token]])--[[#: {string, string} | nil]]
	local result = self.PostfixOperatorFunctionTranslateTree(token)
	return result and result.info or nil
end

function META:IsValue(token--[[#: Token]])--[[#: boolean]]
	if token.type == "number" or token.type == "string" then return true end

	if self:IsKeywordValue(token) then return true end

	if self:IsKeyword(token) then return false end

	if token.type == "letter" then return true end

	return false
end

function META:GetTokenType(tk--[[#: Token]])--[[#: string]]
	if tk.type == "letter" and self:IsKeyword(tk) then
		return "keyword"
	elseif tk.type == "symbol" then
		if self:IsPrefixOperator(tk) then
			return "operator_prefix"
		elseif self:IsPostfixOperator(tk) then
			return "operator_postfix"
		elseif self:GetBinaryOperatorInfo(tk) then
			return "operator_binary"
		end
	end

	return tk.type
end

function META:IsRuntimeExpression(token--[[#: Token]])--[[#: boolean]]
	if token.type == "end_of_file" then return false end

	if token.type == "number" or token.type == "string" then return true end

	return (
			not token:ValueEquals("}") and
			not token:ValueEquals(",")
			and
			not token:ValueEquals("]")
			and
			not token:ValueEquals(")")
			and
			not (
				(
					self:IsKeyword(token) or
					self:IsNonStandardKeyword(token)
				) and
				not self:IsPrefixOperator(token)
				and
				not self:IsValue(token)
				and
				not token:ValueEquals("function")
			)
		)
end

return META
