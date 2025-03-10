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
META:GetSet("Data", false--[[# as string | false]])
META:GetSet("PatternContract", false--[[# as false | string]])

function META.Equal(a--[[#: TString]], b--[[#: TString]])
	if a.Type ~= b.Type then return false, "types differ" end

	return a.Data == b.Data, "string values are equal"
end

function META:GetHash()
	if self.Data then return self.Data end

	local upvalue = self:GetUpvalue()

	if upvalue then return upvalue:GetHash() end

	return self
end

function META:Copy()
	local copy = self.New(self.Data)
	copy:SetPatternContract(self:GetPatternContract())
	copy:SetMetaTable(self:GetMetaTable())
	copy:CopyInternalsFrom(self)
	return copy
end

function META.IsSubsetOf(A--[[#: TString]], B--[[#: TBaseType]])
	if false--[[# as true]] then return false end

	if B.Type == "tuple" then B = B:GetWithNumber(1) end

	if B.Type == "any" then return true end

	if B.Type == "union" then return B:IsTargetSubsetOfChild(A) end

	if B.Type ~= "string" then return false, type_errors.subset(A, B) end

	local B = B--[[# as TString]]

	
	if not A.Data and B.PatternContract then
		if A.PatternContract == B.PatternContract then return true end

		return false, type_errors.string_pattern_type_mismatch(A)
	end

	if A.Data == B.Data and not B.PatternContract then -- "A" subsetof "B" or string subsetof string
		return true
	end

	if A.Data and not B.Data and not B.PatternContract then -- "A" subsetof string
	return true end

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

	return false, type_errors.subset(A, B)
end

function META:__tostring()
	if self.PatternContract then return "$\"" .. self.PatternContract .. "\"" end

	if self.Data then return "\"" .. self.Data .. "\"" end

	return "string"
end

function META.LogicalComparison(a--[[#: TString]], b--[[#: TBaseType]], op--[[#: string]])
	if not a.Data or not b.Data then return nil end -- undefined comparison, nil is the same as true | false
	if op == ">" then
		return a.Data > b.Data
	elseif op == "<" then
		return a.Data < b.Data
	elseif op == "<=" then
		return a.Data <= b.Data
	elseif op == ">=" then
		return a.Data >= b.Data
	elseif op == "==" then
		return a.Data == b.Data
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

local function new(data--[[#: string | nil]])
	return setmetatable(
		{
			Type = "string",
			Data = data or false,
			PatternContract = false,
			Falsy = false,
			Truthy = true,
			ReferenceType = false,
			Parent = false,
			Upvalue = false,
			Parent = false,
			Contract = false,
			MetaTable = false,
		},
		META
	)
end

do
	META:GetSet("MetaTable", false--[[# as TBaseType | false]])

	function META:GetMetaTable()
		local contract = self:GetContract()

		if contract and contract.MetaTable then return contract.MetaTable end

		return self.MetaTable
	end
end

function META.New(data--[[#: string | nil]])
	local self = new(data)
	-- analyzer might be nil when strings are made outside of the analyzer, like during tests
	local analyzer = context:GetCurrentAnalyzer()

	if analyzer then
		self:SetMetaTable(analyzer:GetDefaultEnvironment("typesystem").string_metatable)
	end

	return self
end

function META:IsLiteral()
	return self.Data ~= false and self.PatternContract == false
end

function META:Widen()
	return META.New()
end

function META:CopyLiteralness(obj--[[#: TBaseType]])
	if self.ReferenceType == obj.ReferenceType and self.Data == obj.Data then
		return self
	end

	local self = self:Copy()

	if obj:IsReferenceType() then
		self:SetReferenceType(true)
	else
		if  obj.PatternContract then

		else
			if obj.Type == "union" then
				local str = (obj --[[#as any]]):GetType("string")

				if str then
					if str.PatternContract then return self end
				end
			end

			if not obj:IsLiteral() then self.Data = false end
		end
	end

	return self
end

local cache--[[#: Map<|string, TBaseType|>]] = {}
return {
	String = function(data)
		return META.New()
	end,
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
		return new(data)
	end,
}
