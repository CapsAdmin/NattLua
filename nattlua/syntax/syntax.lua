--ANALYZE
--[[HOTRELOAD
	run_test("test/tests/nattlua/parser.lua")
	run_lua("test/performance/lexer.lua")
]]
local table_insert = _G.table.insert
local table_sort = _G.table.sort
local pairs = _G.pairs
local ipairs = _G.ipairs
local type = _G.type
local class = require("nattlua.other.class")
local callstack = require("nattlua.other.callstack")

--[[#local type { Token } = import("~/nattlua/lexer/token.lua")]]

--[[#type TreeNode = {[number] = self | nil, value = any | nil, max_len = nil | number}]]
--[[#type BinaryOperatorInfo = {op = string, left_priority = number, right_priority = number}]]
--[[#type OperatorFunctionInfo = {op = string, info = {string, string} | {string, string, string}}]]
--[[#type CompiledTree = {tree = TreeNode, lookup = nil | Function}]]
local META = class.CreateTemplate("syntax")
--[[#type META.@Name = "Syntax"]]
--[[#type META.@Self = {
	BinaryOperatorInfo = Map<|string, BinaryOperatorInfo|>,
	NumberAnnotations = List<|string|>,
	Symbols = List<|string|>,
	BinaryOperators = Map<|string, true|>,
	PrefixOperators = Map<|string, true|>,
	PostfixOperators = Map<|string, true|>,
	PrimaryBinaryOperators = Map<|string, true|>,
	SymbolPairs = Map<|string, string|>, -- used by language server
	KeywordValues = Map<|string, true|>,
	Keywords = Map<|string, true|>,
	NonStandardKeywords = Map<|string, true|>,
	BinaryOperatorFunctionTranslate = Map<|string, OperatorFunctionInfo|>,
	PostfixOperatorFunctionTranslate = Map<|string, OperatorFunctionInfo|>,
	PrefixOperatorFunctionTranslate = Map<|string, OperatorFunctionInfo|>,
	ReadMap = Map<|string, true|>,
}]]

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

			self:AddSymbols({token})
			self.BinaryOperatorInfo[token] = {
				op = token,
				left_priority = right and (priority + 1) or priority,
				right_priority = priority,
			}
			self.ReadMap[token] = true
		end
	end
end

function META:AddPostfixOperators(tbl--[[#: List<|string|>]])
	self:AddSymbols(tbl)

	for _, str in ipairs(tbl) do
		self.PostfixOperators[str] = true
		self.ReadMap[str] = true
	end
end

function META:AddPrefixOperators(tbl--[[#: List<|string|>]])
	self:AddSymbols(tbl)

	for _, str in ipairs(tbl) do
		self.PrefixOperators[str] = true
		self.ReadMap[str] = true
	end
end

function META:AddPrimaryBinaryOperators(tbl--[[#: List<|string|>]])
	self:AddSymbols(tbl)

	for _, str in ipairs(tbl) do
		self.PrimaryBinaryOperators[str] = true
		self.ReadMap[str] = true
	end
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

	self:AddSymbols(list)
end

function META:AddKeywords(tbl--[[#: List<|string|>]])
	self:AddSymbols(tbl)

	for _, str in ipairs(tbl) do
		self.Keywords[str] = true
		self.ReadMap[str] = true
	end
end

function META:AddKeywordValues(tbl--[[#: List<|string|>]])
	self:AddSymbols(tbl)

	for _, str in ipairs(tbl) do
		self.Keywords[str] = true
		self.KeywordValues[str] = true
		self.ReadMap[str] = true
	end
end

function META:AddNonStandardKeywords(tbl--[[#: List<|string|>]])
	self:AddSymbols(tbl)

	for _, str in ipairs(tbl) do
		self.NonStandardKeywords[str] = true
		self.ReadMap[str] = true
	end
end

function META:AddBinaryOperatorFunctionTranslate(tbl--[[#: Map<|string, string|>]])
	for op, v in pairs(tbl) do
		local a, b, c = v:match("(.-)A(.-)B(.*)")

		if a and b and c then
			self.BinaryOperatorFunctionTranslate[op] = {op = op, info = {" " .. a, b, c .. " "}}
		end

		self.ReadMap[op] = true
	end
end

function META:AddPrefixOperatorFunctionTranslate(tbl--[[#: Map<|string, string|>]])
	for op, v in pairs(tbl) do
		local a, b = v:match("^(.-)A(.-)$")

		if a and b then
			self.PrefixOperatorFunctionTranslate[op] = {op = op, info = {" " .. a, b .. " "}}
		end

		self.ReadMap[op] = true
	end
end

function META:AddPostfixOperatorFunctionTranslate(tbl--[[#: Map<|string, string|>]])
	for op, v in pairs(tbl) do
		local a, b = v:match("^(.-)A(.-)$")

		if a and b then
			self.PostfixOperatorFunctionTranslate[op] = {op = op, info = {" " .. a, b .. " "}}
		end

		self.ReadMap[op] = true
	end
end

function META:GetNumberAnnotations()
	return self.NumberAnnotations
end

function META:GetBinaryOperatorInfo(token--[[#: Token]])--[[#: BinaryOperatorInfo | nil]]
	if not token.sub_type then return nil end

	return self.BinaryOperatorInfo[token.sub_type]
end

function META:IsPrefixOperator(token--[[#: Token]])--[[#: boolean]]
	if token.type == "number" then return false end

	if token.type == "string" then return false end

	if not token.sub_type then return false end

	return self.PrefixOperators[token.sub_type] or false
end

function META:IsPostfixOperator(token--[[#: Token]])--[[#: boolean]]
	if token.type == "number" then return false end

	if token.type == "string" then return false end

	if not token.sub_type then return false end

	return self.PostfixOperators[token.sub_type] or false
end

function META:IsPrimaryBinaryOperator(token--[[#: Token]])--[[#: boolean]]
	if token.type == "number" then return false end

	if token.type == "string" then return false end

	if not token.sub_type then return false end

	return self.PrimaryBinaryOperators[token.sub_type] or false
end

function META:IsVariableName(token--[[#: Token]])--[[#: boolean]]
	return not token.sub_type
end

function META:IsKeyword(token--[[#: Token]])--[[#: boolean]]
	if not token.sub_type then return false end

	return self.Keywords[token.sub_type] or false
end

function META:IsKeywordValue(token--[[#: Token]])--[[#: boolean]]
	if not token.sub_type then return false end

	return self.KeywordValues[token.sub_type] or false
end

function META:IsNonStandardKeyword(token--[[#: Token]])--[[#: boolean]]
	if not token.sub_type then return false end

	return self.NonStandardKeywords[token.sub_type] or false
end

function META:GetSymbols()
	return self.Symbols
end

function META:GetFunctionForBinaryOperator(token--[[#: Token]])--[[#: {string, string, string} | nil]]
	if not token.sub_type then return nil end

	return self.BinaryOperatorFunctionTranslate[token.sub_type]
end

function META:GetFunctionForPrefixOperator(token--[[#: Token]])--[[#: {string, string} | nil]]
	if not token.sub_type then return nil end

	return self.PrefixOperatorFunctionTranslate[token.sub_type]
end

function META:GetFunctionForPostfixOperator(token--[[#: Token]])--[[#: {string, string} | nil]]
	if not token.sub_type then return nil end

	return self.PostfixOperatorFunctionTranslate[token.sub_type]
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
	if token.type == "number" or token.type == "string" then return true end

	-- letter with no sub type means its an identifier
	if token.type == "letter" and not token.sub_type then return true end

	if token.sub_type == "function" then return true end

	if token.sub_type == "|" then return true end

	if token.sub_type == "{" then return true end

	if token.sub_type == "(" then return true end

	if token.sub_type == "$" then return true end

	if token.sub_type == "<" then return true end -- lsx expression
	if self:IsPrefixOperator(token) then return true end

	if self:IsKeywordValue(token) then return true end

	if self:IsKeyword(token) then return false end

	if token.type == "letter" then return true end

	return false
end


function META:IsTypesystemExpression(token--[[#: Token]])--[[#: boolean]]
	do
		if token.type == "string" or token.type == "number" then return true end

		return not (
			not token or
			token.type == "end_of_file" or
			token.sub_type == ("}") or
			token.sub_type == (",") or
			token.sub_type == ("]") or
			(
				self:IsKeyword(token) and
				not self:IsPrefixOperator(token)
				and
				not self:IsValue(token)
				and
				token.sub_type ~= "function"
			)
		)
	end


	if token.type == "number" or token.type == "string" then return true end

	-- letter with no sub type means its an identifier
	if token.type == "letter" and not token.sub_type then return true end

	if token.sub_type == "function" then return true end

	if token.sub_type == "|" then return true end

	if token.sub_type == "{" then return true end

	if token.sub_type == "(" then return true end

	if token.sub_type == "$" then return true end

	if token.sub_type == "<" then return true end -- lsx expression
	if self:IsPrefixOperator(token) then return true end

	if self:IsKeywordValue(token) then return true end

	if self:IsKeyword(token) then return false end

	if token.type == "letter" then return true end

	return false
end

return META
