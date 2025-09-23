--ANALYZE
local table_insert = _G.table.insert
local table_sort = _G.table.sort
local pairs = _G.pairs
local ipairs = _G.ipairs
local type = _G.type
local class = require("nattlua.other.class")

--[[#local type { Token } = import("~/nattlua/lexer/token.lua")]]

local META = class.CreateTemplate("syntax")
--[[#type META.@Name = "Syntax"]]
--[[#type META.@Self = {
	BinaryOperatorInfo = List<|{op = string, left_priority = number, right_priority = number}|>,
	BinaryOperatorsMaxLength = number,
	PostfixOperatorsMaxLength = number,
	PrimaryBinaryOperatorsMaxLength = number,
	KeywordsMaxLength = number,
	KeywordValuesMaxLength = number,
	NonStandardKeywordsMaxLength = number,
	BinaryOperatorFunctionTranslateMaxLength = number,
	PrefixOperatorFunctionTranslateMaxLength = number,
	PostfixOperatorFunctionTranslateMaxLength = number,
	PrefixOperatorsMaxLength = number,
	NumberAnnotations = List<|string|>,
	Symbols = List<|string|>,
	BinaryOperators = Map<|string, true|>,
	PrefixOperators = List<|string|>,
	PostfixOperators = List<|string|>,
	PrimaryBinaryOperators = List<|string|>,
	SymbolCharacters = List<|string|>,
	SymbolPairs = Map<|string, string|>,
	KeywordValues = List<|string|>,
	Keywords = List<|string|>,
	NonStandardKeywords = List<|string|>,
	BinaryOperatorFunctionTranslate = List<|{op = string, info = {string, string, string}}|>,
	PostfixOperatorFunctionTranslate = List<|{op = string, info = {string, string}}|>,
	PrefixOperatorFunctionTranslate = List<|{op = string, info = {string, string}}|>,
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
			SymbolCharacters = {},
			SymbolPairs = {},
			KeywordValues = {},
			Keywords = {},
			NonStandardKeywords = {},
			BinaryOperatorFunctionTranslate = {},
			PostfixOperatorFunctionTranslate = {},
			PrefixOperatorFunctionTranslate = {},
			BinaryOperatorsMaxLength = 0,
			PrefixOperatorsMaxLength = 0,
			PostfixOperatorsMaxLength = 0,
			PrimaryBinaryOperatorsMaxLength = 0,
			KeywordsMaxLength = 0,
			KeywordValuesMaxLength = 0,
			NonStandardKeywordsMaxLength = 0,
			BinaryOperatorFunctionTranslateMaxLength = 0,
			PrefixOperatorFunctionTranslateMaxLength = 0,
			PostfixOperatorFunctionTranslateMaxLength = 0,
		},
		true
	)
end

local function has_value(tbl--[[#: {[1 .. inf] = string} | {}]], value--[[#: string]])
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

			if right then
				table.insert(
					self.BinaryOperatorInfo,
					{
						op = token,
						left_priority = priority + 1,
						right_priority = priority,
					}
				)
			else
				table.insert(
					self.BinaryOperatorInfo,
					{
						op = token,
						left_priority = priority,
						right_priority = priority,
					}
				)
			end

			self:AddSymbols({token})
			self.BinaryOperators[token] = true
			self.BinaryOperatorsMaxLength = math.max(#token, self.BinaryOperatorsMaxLength)
		end
	end
end

function META:GetBinaryOperatorInfo(token--[[#: Token]])
	if token:GetLength() > self.BinaryOperatorsMaxLength then return nil end

	for _, info in ipairs(self.BinaryOperatorInfo) do
		if token:ValueEquals(info.op) then return info end
	end
end

function META:AddPrefixOperators(tbl--[[#: List<|string|>]])
	self:AddSymbols(tbl)

	for _, str in ipairs(tbl) do
		table.insert(self.PrefixOperators, str)
		self.PrefixOperatorsMaxLength = math.max(#str, self.PrefixOperatorsMaxLength)
	end
end

function META:IsPrefixOperator(token--[[#: Token]])
	if token:GetLength() > self.PrefixOperatorsMaxLength then return false end

	for _, op in ipairs(self.PrefixOperators) do
		if token:ValueEquals(op) then return true end
	end

	return false
end

function META:AddPostfixOperators(tbl--[[#: List<|string|>]])
	self:AddSymbols(tbl)

	for _, str in ipairs(tbl) do
		table.insert(self.PostfixOperators, str)
		self.PostfixOperatorsMaxLength = math.max(#str, self.PostfixOperatorsMaxLength)
	end
end

function META:IsPostfixOperator(token--[[#: Token]])
	if token:GetLength() > self.PostfixOperatorsMaxLength then return false end

	for _, op in ipairs(self.PostfixOperators) do
		if token:ValueEquals(op) then return true end
	end

	return false
end

function META:AddPrimaryBinaryOperators(tbl--[[#: List<|string|>]])
	self:AddSymbols(tbl)

	for _, str in ipairs(tbl) do
		table.insert(self.PrimaryBinaryOperators, str)
		self.PrimaryBinaryOperatorsMaxLength = math.max(#str, self.PrimaryBinaryOperatorsMaxLength)
	end
end

function META:IsPrimaryBinaryOperator(token--[[#: Token]])
	if token:GetLength() > self.PrimaryBinaryOperatorsMaxLength then return false end

	for _, op in ipairs(self.PrimaryBinaryOperators) do
		if token:ValueEquals(op) then return true end
	end

	return false
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
		self.KeywordsMaxLength = math.max(#str, self.KeywordsMaxLength)
	end
end

function META:IsVariableName(token--[[#: Token]])
	return token.type == "letter" and
		not self:IsKeyword(token)
		and
		not self:IsKeywordValue(token)
		and
		not self:IsNonStandardKeyword(token)
end

function META:IsKeyword(token--[[#: Token]])
	if token:GetLength() > self.KeywordsMaxLength then return false end

	for _, str in ipairs(self.Keywords) do
		if token:ValueEquals(str) then return true end
	end

	return false
end

function META:AddKeywordValues(tbl--[[#: List<|string|>]])
	self:AddSymbols(tbl)

	for _, str in ipairs(tbl) do
		table.insert(self.Keywords, str)
		table.insert(self.KeywordValues, str)
		self.KeywordsMaxLength = math.max(#str, self.KeywordsMaxLength)
		self.KeywordValuesMaxLength = math.max(#str, self.KeywordValuesMaxLength)
	end
end

function META:IsKeywordValue(token--[[#: Token]])
	if token:GetLength() > self.KeywordValuesMaxLength then return false end

	for _, str in ipairs(self.KeywordValues) do
		if token:ValueEquals(str) then return true end
	end
end

function META:AddNonStandardKeywords(tbl--[[#: List<|string|>]])
	self:AddSymbols(tbl)

	for _, str in ipairs(tbl) do
		table.insert(self.NonStandardKeywords, str)
		self.NonStandardKeywordsMaxLength = math.max(#str, self.NonStandardKeywordsMaxLength)
	end
end

function META:IsNonStandardKeyword(token--[[#: Token]])
	if token:GetLength() > self.NonStandardKeywordsMaxLength then return false end

	for _, str in ipairs(self.NonStandardKeywords) do
		if token:ValueEquals(str) then return true end
	end

	return false
end

function META:GetSymbols()
	return self.Symbols
end

function META:AddBinaryOperatorFunctionTranslate(tbl--[[#: Map<|string, string|>]])
	for k, v in pairs(tbl) do
		local a, b, c = v:match("(.-)A(.-)B(.*)")

		if a and b and c then
			table.insert(self.BinaryOperatorFunctionTranslate, {op = k, info = {" " .. a, b, c .. " "}})
			self.BinaryOperatorFunctionTranslateMaxLength = math.max(#k, self.BinaryOperatorFunctionTranslateMaxLength)
		end
	end
end

function META:GetFunctionForBinaryOperator(token--[[#: Token]])
	if token:GetLength() > self.BinaryOperatorFunctionTranslateMaxLength then
		return nil
	end

	for _, v in ipairs(self.BinaryOperatorFunctionTranslate) do
		if token:ValueEquals(v.op) then return v.info end
	end
end

function META:AddPrefixOperatorFunctionTranslate(tbl--[[#: Map<|string, string|>]])
	for k, v in pairs(tbl) do
		local a, b = v:match("^(.-)A(.-)$")

		if a and b then
			table.insert(self.PrefixOperatorFunctionTranslate, {op = k, info = {" " .. a, b .. " "}})
			self.PrefixOperatorFunctionTranslateMaxLength = math.max(#k, self.PrefixOperatorFunctionTranslateMaxLength)
		end
	end
end

function META:GetFunctionForPrefixOperator(token--[[#: Token]])
	if token:GetLength() > self.PrefixOperatorFunctionTranslateMaxLength then
		return nil
	end

	for _, v in ipairs(self.PrefixOperatorFunctionTranslate) do
		if token:ValueEquals(v.op) then return v.info end
	end
end

function META:AddPostfixOperatorFunctionTranslate(tbl--[[#: Map<|string, string|>]])
	for k, v in pairs(tbl) do
		local a, b = v:match("^(.-)A(.-)$")

		if a and b then
			table.insert(self.PostfixOperatorFunctionTranslate, {op = k, info = {" " .. a, b .. " "}})
			self.PostfixOperatorFunctionTranslateMaxLength = math.max(#k, self.PostfixOperatorFunctionTranslateMaxLength)
		end
	end
end

function META:GetFunctionForPostfixOperator(token--[[#: Token]])
	if token:GetLength() > self.PostfixOperatorFunctionTranslateMaxLength then
		return nil
	end

	for _, v in ipairs(self.PostfixOperatorFunctionTranslate) do
		if token:ValueEquals(v.op) then return v.info end
	end
end

function META:IsValue(token--[[#: Token]])
	if token.type == "number" or token.type == "string" then return true end

	if self:IsKeywordValue(token) then return true end

	if self:IsKeyword(token) then return false end

	if token.type == "letter" then return true end

	return false
end

function META:GetTokenType(tk--[[#: Token]])
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

function META:IsRuntimeExpression(token--[[#: Token]])
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
