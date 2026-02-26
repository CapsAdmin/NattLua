--ANALYZE
local tostring = tostring
local setmetatable = _G.setmetatable
local jit = _G.jit
local error_messages = require("nattlua.error_messages")
local Number = require("nattlua.types.number").Number
local context = require("nattlua.analyzer.context")
local shared = require("nattlua.types.shared")
local META = require("nattlua.types.base")()
--[[#local type TBaseType = META.TBaseType]]
META.Type = "string"
--[[#type META.@Name = "TString"]]
--[[#local type TString = META.@SelfArgument]]
--[[#type TString.Type = "string"]]
--[[#type TString.lua_compiler = false | string]]
META:GetSet("Data", false--[[# as string | false]])
META:GetSet("Hash", false--[[# as string]])
META:GetSet("PatternContract", false--[[# as false | string]])
local STRING_ID = "string"

local function compute_hash(data--[[#: nil | string]], pattern--[[#: nil | string]])--[[#: string]]
	if pattern then return pattern elseif data then return data end

	return STRING_ID
end

function META:GetHashForMutationTracking()
	if self.Data then return self.Hash end

	local upvalue = self:GetUpvalue()

	if upvalue then return upvalue:GetHashForMutationTracking() end

	return self
end

function META:Copy()
	local copy = self.New(self.Data)
	copy:SetPatternContract(self:GetPatternContract())
	copy:SetMetaTable(self:GetMetaTable())
	copy:CopyInternalsFrom(self)
	copy.Hash = compute_hash(copy.Data, copy.PatternContract)
	return copy
end

function META.IsSubsetOf(A--[[#: TString]], B--[[#: TString | TBaseType]])
	return shared.IsSubsetOf(A, B)
end

function META:__tostring()
	if self.PatternContract then return "$\"" .. self.PatternContract .. "\"" end

	if self.Data then return "\"" .. self.Data .. "\"" end

	return "string"
end

function META:Get()
	return false, error_messages.index_string_attempt()
end

local function new(data--[[#: string | nil]], pattern--[[#: string | nil]])
	return META.NewObject(
		{
			Type = "string",
			Data = data or false,
			PatternContract = pattern or false,
			TruthyFalsy = "truthy",
			Upvalue = false,
			Contract = false,
			MetaTable = false,
			Hash = compute_hash(data, pattern),
			lua_compiler = false,
		}
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

function META.New(data--[[#: string | nil]], pattern--[[#: string | nil]])
	local self = new(data, pattern)
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
	if self.PatternContract then return self end

	return META.New()
end

function META:CopyLiteralness(obj--[[#: TBaseType]])
	local self = self:Copy()

	if obj.Type == "string" and obj.PatternContract then

	else
		if obj.Type == "union" then
			local str = obj:GetType("string")

			if str then if str.PatternContract then return self end end
		end

		if not obj:IsLiteral() then
			self.Data = false
			self.Hash = compute_hash(self.Data, self.PatternContract)
		end
	end

	return self
end

local cache--[[#: Map<|string, TBaseType|>]] = {}
return {
	TString = TString,
	String = function(data)
		return META.New()
	end,
	LString = function(str--[[#: string]])
		return META.New(str)
	end,
	StringPattern = function(str--[[#: string]])
		return META.New(nil, str)
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