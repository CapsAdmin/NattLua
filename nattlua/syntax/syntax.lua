--ANALYZE
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
local META = class.CreateTemplate("syntax")
--[[#type META.@Name = "Syntax"]]
--[[#type META.@Self = {
	BinaryOperatorInfo = List<|BinaryOperatorInfo|>,
	BinaryOperatorInfoTree = TreeNode,
	NumberAnnotations = List<|string|>,
	Symbols = List<|string|>,
	BinaryOperators = Map<|string, true|>,
	PrefixOperators = List<|string|>,
	PrefixOperatorsTree = TreeNode,
	PostfixOperators = List<|string|>,
	PostfixOperatorsTree = TreeNode,
	PrimaryBinaryOperators = List<|string|>,
	PrimaryBinaryOperatorsTree = TreeNode,
	SymbolCharacters = List<|string|>,
	SymbolPairs = Map<|string, string|>,
	KeywordValues = List<|string|>,
	KeywordValuesTree = TreeNode,
	Keywords = List<|string|>,
	KeywordsTree = TreeNode,
	NonStandardKeywords = List<|string|>,
	NonStandardKeywordsTree = TreeNode,
	BinaryOperatorFunctionTranslate = List<|OperatorFunctionInfo|>,
	BinaryOperatorFunctionTranslateTree = TreeNode,
	PostfixOperatorFunctionTranslate = List<|OperatorFunctionInfo|>,
	PostfixOperatorFunctionTranslateTree = TreeNode,
	PrefixOperatorFunctionTranslate = List<|OperatorFunctionInfo|>,
	PrefixOperatorFunctionTranslateTree = TreeNode,
}]]

-- Helper function to build a tree from a list of strings/operators
local function build_tree(
	items--[[#: List<|string|> | List<|BinaryOperatorInfo|> | List<|OperatorFunctionInfo|>]]
)--[[#: TreeNode]]
	local tree = {max_len = 0}

	for _, item in ipairs(items) do
		local current = tree
		local str--[[#: string]]

		if type(item) == "table" then str = item.op else str = item end

		tree.max_len = math.max(tree.max_len, #str)

		-- Traverse/build the tree byte by byte
		for i = 1, #str do
			local byte = str:byte(i)

			if not current[byte] then current[byte] = {} end

			current = current[byte]
		end

		-- Store the value at the leaf
		current.value = item
	end

	return tree
end

-- Helper function to lookup an operator in the tree using token:GetByte()
local function lookup_in_tree(tree--[[#: TreeNode]], token--[[#: Token]])--[[#: any]]
	local current = tree
	local length = token:GetLength()

	if length > tree.max_len--[[# as number]] then return nil end

	if length == 1 then
		local byte = token:GetByte(0)
		current = current[byte]--[[# as any]]
		return current and current.value or nil
	end

	for i = 0, length - 1 do -- assuming 0-based offset
		local byte = token:GetByte(i)
		current = current[byte]--[[# as any]]

		if not current then return nil -- No match found
		end
	end

	return current.value
end

function META.New()
	return META.NewObject(
		{
			NumberAnnotations = {},
			BinaryOperatorInfo = {},
			BinaryOperatorInfoTree = {},
			Symbols = {},
			BinaryOperators = {},
			PrefixOperators = {},
			PrefixOperatorsTree = {},
			PostfixOperators = {},
			PostfixOperatorsTree = {},
			PrimaryBinaryOperators = {},
			PrimaryBinaryOperatorsTree = {},
			SymbolCharacters = {},
			SymbolPairs = {},
			KeywordValues = {},
			KeywordValuesTree = {},
			Keywords = {},
			KeywordsTree = {},
			NonStandardKeywords = {},
			NonStandardKeywordsTree = {},
			BinaryOperatorFunctionTranslate = {},
			BinaryOperatorFunctionTranslateTree = {},
			PostfixOperatorFunctionTranslate = {},
			PostfixOperatorFunctionTranslateTree = {},
			PrefixOperatorFunctionTranslate = {},
			PrefixOperatorFunctionTranslateTree = {},
		},
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

function META:GetNumberAnnotations()
	return self.NumberAnnotations
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
		end
	end

	-- Build the tree after adding all operators
	self.BinaryOperatorInfoTree = build_tree(self.BinaryOperatorInfo)
end

function META:GetBinaryOperatorInfo(token--[[#: Token]])--[[#: BinaryOperatorInfo | nil]]
	return lookup_in_tree(self.BinaryOperatorInfoTree, token)
end

function META:AddPrefixOperators(tbl--[[#: List<|string|>]])
	self:AddSymbols(tbl)

	for _, str in ipairs(tbl) do
		table.insert(self.PrefixOperators, str)
	end

	-- Build the tree
	self.PrefixOperatorsTree = build_tree(self.PrefixOperators)
end

function META:IsPrefixOperator(token--[[#: Token]])--[[#: boolean]]
	return lookup_in_tree(self.PrefixOperatorsTree, token) ~= nil
end

function META:AddPostfixOperators(tbl--[[#: List<|string|>]])
	self:AddSymbols(tbl)

	for _, str in ipairs(tbl) do
		table.insert(self.PostfixOperators, str)
	end

	-- Build the tree
	self.PostfixOperatorsTree = build_tree(self.PostfixOperators)
end

function META:IsPostfixOperator(token--[[#: Token]])--[[#: boolean]]
	return lookup_in_tree(self.PostfixOperatorsTree, token) ~= nil
end

function META:AddPrimaryBinaryOperators(tbl--[[#: List<|string|>]])
	self:AddSymbols(tbl)

	for _, str in ipairs(tbl) do
		table.insert(self.PrimaryBinaryOperators, str)
	end

	-- Build the tree
	self.PrimaryBinaryOperatorsTree = build_tree(self.PrimaryBinaryOperators)
end

function META:IsPrimaryBinaryOperator(token--[[#: Token]])--[[#: boolean]]
	return lookup_in_tree(self.PrimaryBinaryOperatorsTree, token) ~= nil
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
	end

	-- Build the tree
	self.KeywordsTree = build_tree(self.Keywords)
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
	return lookup_in_tree(self.KeywordsTree, token) ~= nil
end

function META:AddKeywordValues(tbl--[[#: List<|string|>]])
	self:AddSymbols(tbl)

	for _, str in ipairs(tbl) do
		table.insert(self.Keywords, str)
		table.insert(self.KeywordValues, str)
	end

	-- Build the trees
	self.KeywordsTree = build_tree(self.Keywords)
	self.KeywordValuesTree = build_tree(self.KeywordValues)
end

function META:IsKeywordValue(token--[[#: Token]])--[[#: boolean]]
	return lookup_in_tree(self.KeywordValuesTree, token) ~= nil
end

function META:AddNonStandardKeywords(tbl--[[#: List<|string|>]])
	self:AddSymbols(tbl)

	for _, str in ipairs(tbl) do
		table.insert(self.NonStandardKeywords, str)
	end

	-- Build the tree
	self.NonStandardKeywordsTree = build_tree(self.NonStandardKeywords)
end

function META:IsNonStandardKeyword(token--[[#: Token]])--[[#: boolean]]
	return lookup_in_tree(self.NonStandardKeywordsTree, token) ~= nil
end

function META:GetSymbols()
	return self.Symbols
end

function META:AddBinaryOperatorFunctionTranslate(tbl--[[#: Map<|string, string|>]])
	for k, v in pairs(tbl) do
		local a, b, c = v:match("(.-)A(.-)B(.*)")

		if a and b and c then
			local info--[[#: OperatorFunctionInfo]] = {op = k, info = {" " .. a, b, c .. " "}}
			table.insert(self.BinaryOperatorFunctionTranslate, info)
		end
	end

	-- Build the tree
	self.BinaryOperatorFunctionTranslateTree = build_tree(self.BinaryOperatorFunctionTranslate)
end

function META:GetFunctionForBinaryOperator(token--[[#: Token]])--[[#: {string, string, string} | nil]]
	local result--[[#: OperatorFunctionInfo | nil]] = lookup_in_tree(self.BinaryOperatorFunctionTranslateTree, token)
	return result and result.info or nil
end

function META:AddPrefixOperatorFunctionTranslate(tbl--[[#: Map<|string, string|>]])
	for k, v in pairs(tbl) do
		local a, b = v:match("^(.-)A(.-)$")

		if a and b then
			local info--[[#: OperatorFunctionInfo]] = {op = k, info = {" " .. a, b .. " "}}
			table.insert(self.PrefixOperatorFunctionTranslate, info)
		end
	end

	-- Build the tree
	self.PrefixOperatorFunctionTranslateTree = build_tree(self.PrefixOperatorFunctionTranslate)
end

function META:GetFunctionForPrefixOperator(token--[[#: Token]])--[[#: {string, string} | nil]]
	local result--[[#: OperatorFunctionInfo | nil]] = lookup_in_tree(self.PrefixOperatorFunctionTranslateTree, token)
	return result and result.info or nil
end

function META:AddPostfixOperatorFunctionTranslate(tbl--[[#: Map<|string, string|>]])
	for k, v in pairs(tbl) do
		local a, b = v:match("^(.-)A(.-)$")

		if a and b then
			local info--[[#: OperatorFunctionInfo]] = {op = k, info = {" " .. a, b .. " "}}
			table.insert(self.PostfixOperatorFunctionTranslate, info)
		end
	end

	-- Build the tree
	self.PostfixOperatorFunctionTranslateTree = build_tree(self.PostfixOperatorFunctionTranslate)
end

function META:GetFunctionForPostfixOperator(token--[[#: Token]])--[[#: {string, string} | nil]]
	local result--[[#: OperatorFunctionInfo | nil]] = lookup_in_tree(self.PostfixOperatorFunctionTranslateTree, token)
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
