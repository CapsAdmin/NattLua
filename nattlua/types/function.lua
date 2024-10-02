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
META:GetSet("InputSignature", false--[[# as TTuple]])
META:GetSet("OutputSignature", false--[[# as TTuple]])
META:GetSet("FunctionBodyNode", false--[[# as nil | any]])
META:GetSet("Scope", false--[[# as nil | any]])
META:GetSet("UpvaluePosition", false--[[# as nil | number]])
META:GetSet("InputIdentifiers", false--[[# as nil | List<|any|>]])
META:GetSet("AnalyzerFunction", false--[[# as nil | Function]])
META:IsSet("ArgumentsInferred", false)
META:IsSet("LiteralFunction", false)
META:GetSet("PreventInputArgumentExpansion", false)

function META:__tostring()
	return "function=" .. tostring(self:GetInputSignature()) .. ">" .. tostring(self:GetOutputSignature())
end

function META:IsLiteral()
	return true
end

function META.Equal(a--[[#: TFunction]], b--[[#: TBaseType]])
	return a.Type == b.Type and
		a:GetInputSignature():Equal(b:GetInputSignature()) and
		a:GetOutputSignature():Equal(b:GetOutputSignature()) and
		(
			not (
				b:GetFunctionBodyNode() and
				a:GetFunctionBodyNode()
			) or
			(
				b:GetFunctionBodyNode() == a:GetFunctionBodyNode()
			)
		)
end

function META:Copy(map--[[#: Map<|any, any|> | nil]], copy_tables--[[#: nil | boolean]])
	map = map or {}
	local copy = self.New(
		self:GetInputSignature():Copy(map, copy_tables),
		self:GetOutputSignature():Copy(map, copy_tables)
	)
	map[self] = map[self] or copy
	copy:SetUpvaluePosition(self:GetUpvaluePosition())
	copy:SetAnalyzerFunction(self:GetAnalyzerFunction())
	copy:SetScope(self:GetScope())
	copy:CopyInternalsFrom(self)
	copy:SetFunctionBodyNode(self:GetFunctionBodyNode())
	copy:SetInputIdentifiers(self:GetInputIdentifiers())
	copy:SetCalled(self:IsCalled())
	copy:SetExplicitInputSignature(self:IsExplicitInputSignature())
	copy:SetExplicitOutputSignature(self:IsExplicitOutputSignature())
	copy:SetArgumentsInferred(self:IsArgumentsInferred())
	copy:SetPreventInputArgumentExpansion(self:GetPreventInputArgumentExpansion())
	return copy
end

function META.IsSubsetOf(a--[[#: TFunction]], b--[[#: TBaseType]])
	if b.Type == "tuple" then b = b:Get(1) end

	if b.Type == "union" then return b:IsTargetSubsetOfChild(a) end

	if b.Type == "any" then return true end

	if b.Type ~= "function" then return false, type_errors.subset(a, b) end

	local ok, reason = a:GetInputSignature():IsSubsetOf(b:GetInputSignature())

	if not ok then
		return false,
		type_errors.because(type_errors.subset(a:GetInputSignature(), b:GetInputSignature()), reason)
	end

	local ok, reason = a:GetOutputSignature():IsSubsetOf(b:GetOutputSignature())

	if
		not ok and
		(
			(
				not b:IsCalled() and
				not b:IsExplicitOutputSignature()
			)
			or
			(
				not a:IsCalled() and
				not a:IsExplicitOutputSignature()
			)
		)
	then
		return true
	end

	if not ok then
		return false,
		type_errors.because(type_errors.subset(a:GetOutputSignature(), b:GetOutputSignature()), reason)
	end

	return true
end

function META.IsCallbackSubsetOf(a--[[#: TFunction]], b--[[#: TBaseType]])
	if b.Type == "tuple" then b = b:Get(1) end

	if b.Type == "union" then return b:IsTargetSubsetOfChild(a) end

	if b.Type == "any" then return true end

	if b.Type ~= "function" then return false, type_errors.subset(a, b) end

	local ok, reason = a:GetInputSignature():IsSubsetOf(b:GetInputSignature(), a:GetInputSignature():GetMinimumLength())

	if not ok then
		return false,
		type_errors.because(type_errors.subset(a:GetInputSignature(), b:GetInputSignature()), reason)
	end

	local ok, reason = a:GetOutputSignature():IsSubsetOf(b:GetOutputSignature())

	if
		not ok and
		(
			(
				not b:IsCalled() and
				not b:IsExplicitOutputSignature()
			)
			or
			(
				not a:IsCalled() and
				not a:IsExplicitOutputSignature()
			)
		)
	then
		return true
	end

	if not ok then
		return false,
		type_errors.because(type_errors.subset(a:GetOutputSignature(), b:GetOutputSignature()), reason)
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
				if (val.Type == "upvalue" and val:GetScope() or val.scope) ~= call_info.scope then
					table.insert(out, val)
				end
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

function META:HasReferenceTypes()
	for i, v in ipairs(self:GetInputSignature():GetData()) do
		if v:IsReferenceType() then return true end
	end

	for i, v in ipairs(self:GetOutputSignature():GetData()) do
		if v:IsReferenceType() then return true end
	end

	return false
end

function META.New(input--[[#: TTuple]], output--[[#: TTuple]])
	local self = setmetatable(
		{
			Type = "function",
			Falsy = false,
			Called = false,
			Contract = false,
			Name = false,
			MetaTable = false,
			TypeOverride = false,
			Truthy = true,
			ReferenceType = false,
			ExplicitInputSignature = false,
			ExplicitOutputSignature = false,
			ArgumentsInferred = false,
			PreventInputArgumentExpansion = false,
			scopes = {},
			InputSignature = input,
			OutputSignature = output,
			scope = false,
			recursively_called = false,
			UniqueID = false,
			AnalyzerFunction = false,
			FunctionBodyNode = false,
			Upvalue = false,
			UpvaluePosition = false,
			InputIdentifiers = false,
			AnalyzerEnvironment = false,
			LiteralFunction = false,
			Node = false,
			Scope = false,
			Parent = false,
		},
		META
	)
	return self
end

return {
	Function = META.New,
	AnyFunction = function()
		return META.New(Tuple({VarArg(Any())}), Tuple({VarArg(Any())}))
	end,
	LuaTypeFunction = function(
		lua_function--[[#: Function]],
		arg--[[#: List<|TBaseType|>]],
		ret--[[#: List<|TBaseType|>]]
	)
		local self = META.New(Tuple(arg), Tuple(ret))
		self:SetAnalyzerFunction(lua_function)
		return self
	end,
}
