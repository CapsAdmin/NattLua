local tostring = _G.tostring
local ipairs = _G.ipairs
local setmetatable = _G.setmetatable
local table = _G.table
local Tuple = require("nattlua.types.tuple").Tuple
local VarArg = require("nattlua.types.tuple").VarArg
local Any = require("nattlua.types.any").Any
local type_errors = require("nattlua.types.error_messages")
local META = dofile("nattlua/types/base.lua")
--[[#local type TBaseType = META.TBaseType]]
--[[#type META.@Name = "TFunction"]]
--[[#type TFunction = META.@Self]]
--[[#type TFunction.scopes = List<|any|>]]

META.Type = "function"
META.Truthy = true
META.Falsy = false
META:IsSet("Called", false)
META:IsSet("ExplicitInputSignature", false)
META:IsSet("ExplicitOutputSignature", false)
META:GetSet("InputSignature", nil --[[# as TTuple]])
META:GetSet("OutputSignature", nil --[[# as TTuple]])
META:GetSet("FunctionBodyNode", nil --[[# as nil | any]])
META:GetSet("Scope", nil --[[# as nil | any]])
META:GetSet("UpvaluePosition", nil --[[# as nil | number]])
META:GetSet("InputIdentifiers", nil --[[# as nil | List<|any|>]])
META:GetSet("AnalyzerFunction", nil --[[# as nil | Function]])
META:IsSet("ArgumentsInferred", false)
META:GetSet("PreventInputArgumentExpansion", false)

function META:__tostring()
	return "function=" .. tostring(self:GetInputSignature()) .. ">" .. tostring(self:GetOutputSignature())
end

function META:__call(...--[[#: ...any]])
	if self:GetAnalyzerFunction() then return self:GetAnalyzerFunction()(...) end
end

function META.Equal(a--[[#: TFunction]], b--[[#: TBaseType]])
	return a.Type == b.Type and
		a:GetInputSignature():Equal(b:GetInputSignature()) and
		a:GetOutputSignature():Equal(b:GetOutputSignature())
end

function META:Copy(map--[[#: Map<|any, any|> | nil ]], copy_tables--[[#: nil | boolean]])
	map = map or {}
	local copy = self.New(self:GetInputSignature():Copy(map, copy_tables), self:GetOutputSignature():Copy(map, copy_tables))
	map[self] = map[self] or copy
	copy:SetUpvaluePosition(self:GetUpvaluePosition())
	copy:SetAnalyzerFunction(self:GetAnalyzerFunction())
	copy:SetScope(self:GetScope())
	copy:SetLiteral(self:IsLiteral())
	copy:CopyInternalsFrom(self)
	copy:SetFunctionBodyNode(self:GetFunctionBodyNode())
	copy:SetInputIdentifiers(self:GetInputIdentifiers())
	copy:SetCalled(self:IsCalled())
	--copy:SetExplicitInputSignature(self:IsExplicitInputSignature())
	--copy:SetExplicitOutputSignature(self:IsExplicitOutputSignature())
	copy:SetArgumentsInferred(self:IsArgumentsInferred())
	copy:SetPreventInputArgumentExpansion(self:GetPreventInputArgumentExpansion())
	return copy
end

function META.IsSubsetOf(A--[[#: TFunction]], B--[[#: TBaseType]])
	if B.Type == "tuple" then B = B:Get(1) end

	if B.Type == "union" then return B:IsTargetSubsetOfChild(A) end

	if B.Type == "any" then return true end

	if B.Type ~= "function" then return type_errors.type_mismatch(A, B) end

	local ok, reason = A:GetInputSignature():IsSubsetOf(B:GetInputSignature())

	if not ok then
		return type_errors.subset(A:GetInputSignature(), B:GetInputSignature(), reason)
	end

	local ok, reason = A:GetOutputSignature():IsSubsetOf(B:GetOutputSignature())

	if
		not ok and
		(
			(
				not B:IsCalled() and
				not B:IsExplicitOutputSignature()
			)
			or
			(
				not A:IsCalled() and
				not A:IsExplicitOutputSignature()
			)
		)
	then
		return true
	end

	if not ok then
		return type_errors.subset(A:GetOutputSignature(), B:GetOutputSignature(), reason)
	end

	return true
end

function META.IsCallbackSubsetOf(A--[[#: TFunction]], B--[[#: TBaseType]])
	if B.Type == "tuple" then B = B:Get(1) end

	if B.Type == "union" then return B:IsTargetSubsetOfChild(A) end

	if B.Type == "any" then return true end

	if B.Type ~= "function" then return type_errors.type_mismatch(A, B) end

	local ok, reason = A:GetInputSignature():IsSubsetOf(B:GetInputSignature(), A:GetInputSignature():GetMinimumLength())

	if not ok then
		return type_errors.subset(A:GetInputSignature(), B:GetInputSignature(), reason)
	end

	local ok, reason = A:GetOutputSignature():IsSubsetOf(B:GetOutputSignature())

	if
		not ok and
		(
			(
				not B:IsCalled() and
				not B:IsExplicitOutputSignature()
			)
			or
			(
				not A:IsCalled() and
				not A:IsExplicitOutputSignature()
			)
		)
	then
		return true
	end

	if not ok then
		return type_errors.subset(A:GetOutputSignature(), B:GetOutputSignature(), reason)
	end

	return true
end

do
	function META:AddScope(arguments--[[#: TTuple]], return_result--[[#: TTuple]], scope--[[#: any]])
		self.scopes = self.scopes or {}
		table.insert(
			self.scopes,
			{
				arguments = arguments,
				return_result = return_result,
				scope = scope,
			}
		)
	end

	function META:GetSideEffects()
		local out = {}

		for _, call_info in ipairs(self.scopes) do
			for _, val in ipairs(call_info.scope:GetDependencies()) do
				if val.scope ~= call_info.scope then table.insert(out, val) end
			end
		end

		return out
	end

	function META:GetCallCount()
		return #self.scopes
	end

	function META:IsPure()
		return #self:GetSideEffects() == 0
	end
end

function META:IsRefFunction()
	for i, v in ipairs(self:GetInputSignature():GetData()) do
		if v:IsReferenceArgument() then return true end
	end

	for i, v in ipairs(self:GetOutputSignature():GetData()) do
		if v:IsReferenceArgument() then return true end
	end

	return false
end

function META.New(input--[[#: TTuple]], output--[[#: TTuple]])
	local self = setmetatable({
		Falsy = false, 
		Truthy = true, 
		Literal = false, 
		LiteralArgument = false, 
		ReferenceArgument = false,
		Called = false,
		ExplicitInputSignature = false,
		ExplicitOutputSignature = false,
		ArgumentsInferred = false,
		PreventInputArgumentExpansion = false,
		scopes = {},
		InputSignature = input,
		OutputSignature = output,
	}, META)
	return self
end

return {
	Function = META.New,
	AnyFunction = function()
		return META.New(Tuple({VarArg(Any())}), Tuple({VarArg(Any())}))
	end,
	LuaTypeFunction = function(lua_function--[[#: Function]], arg--[[#: List<|TBaseType|>]], ret--[[#: List<|TBaseType|>]])
		local self = META.New(Tuple(arg), Tuple(ret))
		self:SetAnalyzerFunction(lua_function)
		return self
	end,
}
