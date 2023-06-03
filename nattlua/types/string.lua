--ANALYZE
local tostring = tostring
local setmetatable = _G.setmetatable
local jit = _G.jit
local type_errors = require("nattlua.types.error_messages")
local Number = require("nattlua.types.number").Number
local context = require("nattlua.analyzer.context")
local META = dofile("nattlua/types/base.lua")

--[[#local type { expression } = import("./../parser/nodes.nlua")]]

--[[#local type TBaseType = META.TBaseType]]
META.Type = "string"
--[[#type META.@Name = "TString"]]
--[[#type TString = META.@Self]]
META:GetSet("Data", nil--[[# as string | nil]])
META:GetSet("PatternContract", nil--[[# as nil | string]])

function META.Equal(a--[[#: TString]], b--[[#: TBaseType]])
	if a.Type ~= b.Type then return false end

	local b = b--[[# as TString]]

	if a:IsLiteralArgument() and b:IsLiteralArgument() then return true end

	if b:IsLiteralArgument() and not a:IsLiteral() then return false end

	if a:IsLiteral() and b:IsLiteral() then return a:GetData() == b:GetData() end

	if not a:IsLiteral() and not b:IsLiteral() then return true end

	return false
end

function META:GetHash()
	if self:IsLiteral() then return self.Data end

	local upvalue = self:GetUpvalue()

	if upvalue then
		return "__@type@__" .. upvalue:GetHash() .. "_" .. self.Type
	end

	if not jit then
		return "__@type@__" .. self.Type .. ("_%s"):format(tostring(self))
	end

	return "__@type@__" .. self.Type .. ("_%p"):format(self)
end

function META:Copy()
	local copy = self.New(self:GetData()):SetLiteral(self:IsLiteral())
	copy:SetPatternContract(self:GetPatternContract())
	copy:CopyInternalsFrom(self)
	return copy
end

function META.IsSubsetOf(A--[[#: TString]], B--[[#: TBaseType]])
	if B.Type == "tuple" then B = B:Get(1) end

	if B.Type == "any" then return true end

	if B.Type == "union" then return B:IsTargetSubsetOfChild(A) end

	if B.Type ~= "string" then return false, type_errors.subset(A, B) end

	local B = B--[[# as TString]]

	if A:IsLiteralArgument() and B:IsLiteralArgument() then return true end

	if B:IsLiteralArgument() and not A:IsLiteral() then
		return false, type_errors.subset(A, B)
	end

	if A:IsLiteral() and B:IsLiteral() and A:GetData() == B:GetData() then -- "A" subsetof "B"
		return true
	end

	if A:IsLiteral() and not B:IsLiteral() then -- "A" subsetof string
		return true
	end

	if not A:IsLiteral() and not B:IsLiteral() then -- string subsetof string
		return true
	end

	if B.PatternContract then
		local str = A:GetData()

		if not str then -- TODO: this is not correct, it should be :IsLiteral() but I have not yet decided this behavior yet
			return false, type_errors.string_pattern_type_mismatch(A)
		end

		if not str:find(B.PatternContract) then
			return false, type_errors.string_pattern_match_fail(A, B)
		end

		return true
	end

	if A:IsLiteral() and B:IsLiteral() then
		return false, type_errors.subset(A, B)
	end

	return false, type_errors.subset(A, B)
end

function META:__tostring()
	if self.PatternContract then return "$\"" .. self.PatternContract .. "\"" end

	if self:IsLiteral() then
		local str = self:GetData()

		if str then return "\"" .. str .. "\"" end
	end

	if self:IsLiteralArgument() then return "literal string" end

	return "string"
end

function META.LogicalComparison(a--[[#: TString]], b--[[#: TBaseType]], op--[[#: string]])
	if op == ">" then
		if a:IsLiteral() and b:IsLiteral() then return a:GetData() > b:GetData() end

		return nil
	elseif op == "<" then
		if a:IsLiteral() and b:IsLiteral() then return a:GetData() < b:GetData() end

		return nil
	elseif op == "<=" then
		if a:IsLiteral() and b:IsLiteral() then return a:GetData() <= b:GetData() end

		return nil
	elseif op == ">=" then
		if a:IsLiteral() and b:IsLiteral() then return a:GetData() >= b:GetData() end

		return nil
	elseif op == "==" then
		if a:IsLiteral() and b:IsLiteral() then return a:GetData() == b:GetData() end

		return nil
	end

	return false, type_errors.binary(op, a, b)
end

function META:IsFalsy()
	return false
end

function META:IsTruthy()
	return true
end

function META:Get()
	return false, type_errors.index_string_attempt()
end

function META.New(data--[[#: string | nil]])
	local self = setmetatable(
		{
			Data = data,
			Falsy = false,
			Truthy = true,
			Literal = false,
			LiteralArgument = false,
			ReferenceArgument = false,
		},
		META
	)
	-- analyzer might be nil when strings are made outside of the analyzer, like during tests
	local analyzer = context:GetCurrentAnalyzer()

	if analyzer then
		self:SetMetaTable(analyzer:GetDefaultEnvironment("typesystem").string_metatable)
	end

	return self
end

local cache--[[#: Map<|string, TBaseType|>]] = {}
return {
	String = META.New,
	LString = function(str--[[#: string]])
		return META.New(str):SetLiteral(true)
	end,
	ConstString = function(str--[[#: string]])
		if cache[str] then return cache[str] end

		local obj = META.New(str):SetLiteral(true)
		cache[str] = obj
		return obj
	end,
	LStringNoMeta = function(data--[[#: string]])
		return setmetatable(
			{
				Data = data,
				Falsy = false,
				Truthy = true,
				Literal = false,
				LiteralArgument = false,
				ReferenceArgument = false,
			},
			META
		):SetLiteral(true)
	end,
	NodeToString = function(node--[[#: expression["value"] ]], is_local--[[#: boolean | nil]])
		return META.New(node.value.value):SetLiteral(true)
	end,
}