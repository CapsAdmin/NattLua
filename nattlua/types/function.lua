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
--[[#type TFunction.suppress = boolean]]
META.Type = "function"
META.Truthy = true
META.Falsy = false
META:IsSet("Called", false)
META:IsSet("ExplicitInputSignature", false)
META:IsSet("ExplicitOutputSignature", false)
META:GetSet("InputSignature", nil--[[# as TTuple]])
META:GetSet("OutputSignature", nil--[[# as TTuple]])
META:GetSet("FunctionBodyNode", nil--[[# as nil | any]])
META:GetSet("Scope", nil--[[# as nil | any]])
META:GetSet("UpvaluePosition", nil--[[# as nil | number]])
META:GetSet("InputIdentifiers", nil--[[# as nil | List<|any|>]])
META:GetSet("AnalyzerFunction", nil--[[# as nil | Function]])
META:IsSet("ArgumentsInferred", false)
META:GetSet("PreventInputArgumentExpansion", false)

function META:__tostring()
	return "function=" .. tostring(self:GetInputSignature()) .. ">" .. tostring(self:GetOutputSignature())
end

function META:__call(...--[[#: ...any]])
	local f = self:GetAnalyzerFunction()

	if f then return f(...) end
end

function META.Equal(a--[[#: TFunction]], b--[[#: TBaseType]])
	return a.Type == b.Type and
		a:GetInputSignature():Equal(b:GetInputSignature()) and
		a:GetOutputSignature():Equal(b:GetOutputSignature())
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
	copy:SetLiteral(self:IsLiteral())
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
	local self = setmetatable(
		{
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
			suppress = false,
		},
		META
	)
	return self
end

do
	local function call_function_internal(self, obj, input)
		local call_analyzer = require("nattlua.types.function_call_analyzer")
		local call_body = require("nattlua.types.function_call_body")
		local call_function_signature = require("nattlua.types.function_call_function_signature")
		-- mark the object as called so the unreachable code step won't call it
		obj:SetCalled(true)

		-- infer any uncalled functions in the arguments to get their return type
		for i, b in ipairs(input:GetData()) do
			if b.Type == "function" and not b:IsCalled() and not b:IsExplicitOutputSignature() then
				local a = obj:GetInputSignature():Get(i)

				if
					a and
					(
						(
							a.Type == "function" and
							not a:GetOutputSignature():IsSubsetOf(b:GetOutputSignature())
						)
						or
						not a:IsSubsetOf(b)
					)
				then
					local func = a

					if func.Type == "union" then func = a:GetType("function") end

					b:SetArgumentsInferred(true)

					-- TODO: callbacks with ref arguments should not be called
					-- mixed ref args make no sense, maybe ref should be a keyword for the function instead?
					if not b:IsRefFunction() and func then
						self:Assert(b:Call(self, func:GetInputSignature():Copy(nil, true)))
					end
				end
			end
		end

		if obj:GetAnalyzerFunction() then
			return call_analyzer(self, obj, input)
		elseif obj:GetFunctionBodyNode() then
			return call_body(self, obj, input)
		end

		return call_function_signature(self, obj, input)
	end

	function META:Call(analyzer, input, call_node, not_recursive_call)
		if
			analyzer:IsRuntime() and
			self:IsCalled() and
			not self:IsRefFunction()
			and
			self:GetFunctionBodyNode() and
			self:GetFunctionBodyNode().environment == "runtime" and
			not self:GetAnalyzerFunction()
			and
			self:IsExplicitInputSignature()
		then
			if self.scope and self.scope.throws then
				analyzer:GetScope():CertainReturn()
			end

			return self:GetOutputSignature():Copy()
		end

		if
			not analyzer.config.should_crawl_untyped_functions and
			analyzer:IsRuntime() and
			self:IsCalled() and
			not self:IsRefFunction()
			and
			self:GetFunctionBodyNode() and
			self:GetFunctionBodyNode().environment == "runtime" and
			not self:GetAnalyzerFunction()
			and
			not self:IsExplicitInputSignature()
		then
			if self.scope and self.scope.throws then
				analyzer:GetScope():CertainReturn()
			end

			return self:GetOutputSignature():Copy()
		end

		local ok, err = analyzer:PushCallFrame(self, call_node, not_recursive_call)

		if not ok == false then return ok, err end

		if ok then return ok end

		local ok, err = call_function_internal(analyzer, self, input)
		analyzer:PopCallFrame()
		return ok, err
	end
end

function META:NewIndex(analyzer, key, val)
	
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