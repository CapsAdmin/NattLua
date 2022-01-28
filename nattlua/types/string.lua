local tostring = tostring
local error = error
local setmetatable = _G.setmetatable
local type_errors = require("nattlua.types.error_messages")
local Number = require("nattlua.types.number").Number
local Table = require("nattlua.types.table").Table
local context = require("nattlua.analyzer.context")
local META = dofile("nattlua/types/base.lua")

META.Type = "string"
--[[#type META.@Name = "TString"]]
--[[#type TString = META.@Self]]
META:GetSet("Data", nil--[[# as string | nil]])
META:GetSet("PatternContract", nil--[[# as nil | string]])

function META.Equal(a--[[#: TString]], b--[[#: TString]])
	if a.Type ~= b.Type then return false end

	if a:IsLiteral() and b:IsLiteral() then return a:GetData() == b:GetData() end
	if not a:IsLiteral() and not b:IsLiteral() then return true end
	return false
end

function META:GetHash()
	if self:IsLiteral() then
		return self.Data
	end
	return "__@type@__" .. self.Type
end

function META:Copy()
	local copy = self.New(self:GetData()):SetLiteral(self:IsLiteral())
	copy:SetPatternContract(self:GetPatternContract())
	copy:CopyInternalsFrom(self)
	return copy
end

function META.IsSubsetOf(A, B)
	if B.Type == "tuple" then B = B:Get(1) end
	if B.Type == "any" then return true end
	if B.Type == "union" then return B:IsTargetSubsetOfChild(A) end
	if B.Type ~= "string" then return type_errors.type_mismatch(A, B) end
	if A:IsLiteral() and B:IsLiteral() and A:GetData() == B:GetData() then
		-- "A" subsetof "B"
		return true end
	if A:IsLiteral() and not B:IsLiteral() then
		-- "A" subsetof string
		return true end
	if not A:IsLiteral() and not B:IsLiteral() then
		-- string subsetof string
		return true end

	if B.PatternContract then
		if not A:GetData() then -- TODO: this is not correct, it should be :IsLiteral() but I have not yet decided this behavior yet
            return type_errors.literal(A) end
		if not A:GetData():find(B.PatternContract) then return type_errors.string_pattern(A, B) end
		return true
	end

	if A:IsLiteral() and B:IsLiteral() then return type_errors.value_mismatch(A, B) end
	return type_errors.subset(A, B)
end

function META:__tostring()
	if self.PatternContract then return "$(" .. self.PatternContract .. ")" end

	if self:IsLiteral() then
		if self:GetData() then return "\"" .. self:GetData() .. "\"" end
		if self:GetData() == nil then return "string" end
		return tostring(self:GetData())
	end

	if self:GetData() == nil then return "string" end
	return "string(" .. tostring(self:GetData()) .. ")"
end

function META.LogicalComparison(a--[[#: TString]], b--[[#: TString]], op)
	if op == ">" then
		if a:IsLiteral() and b:IsLiteral() then
			return a:GetData() > b:GetData()
		end
		return nil
	elseif op == "<" then
		if a:IsLiteral() and b:IsLiteral() then
			return a:GetData() < b:GetData()
		end
		return nil
	elseif op == "<=" then
		if a:IsLiteral() and b:IsLiteral() then
			return a:GetData() <= b:GetData()
		end
		return nil
	elseif op == ">=" then
		if a:IsLiteral() and b:IsLiteral() then
			return a:GetData() >= b:GetData()
		end
		return nil
	elseif op == "==" then
		if a:IsLiteral() and b:IsLiteral() then
			return a:GetData() == b:GetData()
		end
		return nil
	end

	return type_errors.binary(op, a, b)
end

function META:IsFalsy()
	return false
end

function META:IsTruthy()
	return true
end

function META:PrefixOperator(op--[[#: string]])
	if op == "#" then return Number(self:GetData() and #self:GetData() or nil):SetLiteral(self:IsLiteral()) end
end

function META.New(data--[[#: string | nil]])
	local self = setmetatable({Data = data}, META)

	-- analyzer might be nil when strings are made outside of the analyzer, like during tests
	local analyzer = context:GetCurrentAnalyzer()
	if analyzer then
		self:SetMetaTable(analyzer:GetDefaultEnvironment("typesystem").string_metatable)
	end

	return self
end

return
	{
		String = META.New,
		LString = function(num--[[#: string]])
			return META.New(num):SetLiteral(true)
		end,
		LStringNoMeta = function(str)
			return setmetatable({Data = str}, META):SetLiteral(true)
		end,
		NodeToString = function(node--[[#: Token]])
			return META.New(node.value.value):SetLiteral(true):SetNode(node)
		end
	}
