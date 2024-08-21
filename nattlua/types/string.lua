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

	if a.Data and b.Data then return a.Data == b.Data end

	if not a.Data and not b.Data then return true end

	return false
end

function META:GetHash()
	if self.Data then return self.Data end

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
	local copy = self.New(self.Data)
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

	if A.Data and B.Data and A.Data == B.Data then -- "A" subsetof "B"
		return true
	end

	if A.Data and not B.Data then -- "A" subsetof string
		return true
	end

	if not A.Data and not B.Data then -- string subsetof string
		return true
	end

	if B.PatternContract then
		local str = A.Data

		if not str then -- TODO: this is not correct, it should be .Data but I have not yet decided this behavior yet
			return false, type_errors.string_pattern_type_mismatch(A)
		end

		if not str:find(B.PatternContract) then
			return false, type_errors.string_pattern_match_fail(A, B)
		end

		return true
	end

	if A.Data and B.Data then
		return false, type_errors.subset(A, B)
	end

	return false, type_errors.subset(A, B)
end

function META:__tostring()
	if self.PatternContract then return "$\"" .. self.PatternContract .. "\"" end

	if self.Data then
		local str = self.Data

		if str then return "\"" .. str .. "\"" end
	end

	return "string"
end

function META.LogicalComparison(a--[[#: TString]], b--[[#: TBaseType]], op--[[#: string]])
	if op == ">" then
		if a.Data and b.Data then return a.Data > b.Data end

		return nil
	elseif op == "<" then
		if a.Data and b.Data then return a.Data < b.Data end

		return nil
	elseif op == "<=" then
		if a.Data and b.Data then return a.Data <= b.Data end

		return nil
	elseif op == ">=" then
		if a.Data and b.Data then return a.Data >= b.Data end

		return nil
	elseif op == "==" then
		if a.Data and b.Data then return a.Data == b.Data end

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
			ReferenceType = false,
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

function META:IsLiteral()
	return self.Data ~= nil
end

function META:Widen(obj--[[#: TBaseType | nil]])
	if not obj then return META.New() end
	if self.ReferenceType == obj.ReferenceType and self.Data == obj.Data then return self end
	local self = self:Copy()
	if obj:IsReferenceType() then
		self:SetReferenceType(true)
	else
		if not obj:IsLiteral() then
			self.Data = nil
		end
	end
	return self
end

local cache--[[#: Map<|string, TBaseType|>]] = {}
return {
	String = function(data) return META.New() end,
	LString = function(str--[[#: string]])
		return META.New(str)
	end,
	ConstString = function(str--[[#: string]])
		if cache[str] then return cache[str] end

		local obj = META.New(str)
		cache[str] = obj
		return obj
	end,
	LStringNoMeta = function(data--[[#: string]])
		return setmetatable(
			{
				Data = data,
				Falsy = false,
				Truthy = true,
				ReferenceType = false,
			},
			META
		)
	end,
	NodeToString = function(node--[[#: expression["value"] ]], is_local--[[#: boolean | nil]])
		return META.New(node.value.value)
	end,
}