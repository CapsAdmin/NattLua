local tostring = _G.tostring
local ipairs = _G.ipairs
local setmetatable = _G.setmetatable
local table = _G.table
local Tuple = require("nattlua.types.tuple").Tuple
local VarArg = require("nattlua.types.tuple").VarArg
local Any = require("nattlua.types.any").Any
local error_messages = require("nattlua.error_messages")
local META = require("nattlua.types.base")()
--[[#local type TBaseType = META.TBaseType]]
--[[#type META.@Name = "TFunction"]]
--[[#type TFunction = META.@Self]]
--[[#type TFunction.scopes = List<|any|>]]
--[[#type TFunction.scope = any]]
--[[#type TFunction.suppress = boolean]]
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
META:IsSet("InputArgumentsInferred", false)

function META.LogicalComparison(l--[[#: TFunction]], r--[[#: TFunction]], op--[[#: string]])
	if op == "==" then return l:Equal(r) end

	return false, error_messages.binary(op, l, r)
end

function META:__tostring()
	if self.suppress then return "current_function" end

	self.suppress = true
	local s = "function=" .. tostring(self:GetInputSignature()) .. ">" .. tostring(self:GetOutputSignature())
	self.suppress = false
	return s
end

function META:IsLiteral()
	return true
end

function META.Equal(a--[[#: TFunction]], b--[[#: TBaseType]], visited--[[#: any]])
	if a.Type ~= b.Type then return false, "types differ" end

	local ok, reason = a:GetInputSignature():Equal(b:GetInputSignature(), visited)

	if not ok then return false, "input signature mismatch: " .. reason end

	local ok, reason = a:GetOutputSignature():Equal(b:GetOutputSignature(), visited)

	if not ok then return false, "output signature mismatch: " .. reason end

	return true, "ok"
end

function META:GetHash(visited)
	visited = visited or {}

	if visited[self] then return visited[self] end

	visited[self] = "*circular*"
	local result = "("

	-- Add hash for input signature
	if self:GetInputSignature() then
		result = result .. self:GetInputSignature():GetHash(visited)
	end

	result = result .. ")=>("

	-- Add hash for output signature
	if self:GetOutputSignature() then
		result = result .. self:GetOutputSignature():GetHash(visited)
	end

	result = result .. ")"
	visited[self] = result
	return visited[self]
end

local function copy_val(val, map, copy_tables)
	if not val then return val end

	-- if it's already copied
	if map[val] then return map[val] end

	map[val] = val:Copy(map, copy_tables)
	return map[val]
end

function META:Copy(map--[[#: Map<|any, any|> | nil]], copy_tables)
	map = map or {}

	if map[self] then return map[self] end

	local copy = META.New()
	map[self] = copy
	copy.InputSignature = copy_val(self.InputSignature, map, copy_tables)
	copy.OutputSignature = copy_val(self.OutputSignature, map, copy_tables)
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
	copy:SetLiteralFunction(self:IsLiteralFunction())
	copy:SetInputArgumentsInferred(self:IsInputArgumentsInferred())
	return copy
end

function META.IsSubsetOf(a--[[#: TFunction]], b--[[#: TBaseType]])
	if b.Type == "tuple" then b = b:GetWithNumber(1) end

	if b.Type == "union" then return b:IsTargetSubsetOfChild(a) end

	if b.Type == "any" then return true end

	if b.Type ~= "function" then return false, error_messages.subset(a, b) end

	local ok, reason = a:GetInputSignature():IsSubsetOf(b:GetInputSignature())

	if not ok then
		return false,
		error_messages.because(error_messages.subset(a:GetInputSignature(), b:GetInputSignature()), reason)
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
		error_messages.because(error_messages.subset(a:GetOutputSignature(), b:GetOutputSignature()), reason)
	end

	return true
end

function META.IsCallbackSubsetOf(a--[[#: TFunction]], b--[[#: TFunction]])
	if
		(
			not b:IsCalled() and
			not b:IsExplicitOutputSignature()
		)
		or
		(
			not a:IsCalled() and
			not a:IsExplicitOutputSignature()
		)
	then
		return true
	end

	local ok, reason = a:GetInputSignature():IsSubsetOf(b:GetInputSignature(), a:GetInputSignature():GetMinimumLength())

	if not ok then
		return false,
		error_messages.because(error_messages.subset(a:GetInputSignature(), b:GetInputSignature()), reason)
	end

	local ok, reason = a:GetOutputSignature():IsSubsetOf(b:GetOutputSignature())

	if not ok then
		return false,
		error_messages.because(error_messages.subset(a:GetOutputSignature(), b:GetOutputSignature()), reason)
	end

	return true
end

do
	function META:AddScope(scope--[[#: any]])
		table.insert(self.scopes, scope)
	end

	function META:GetSideEffects()
		local out = {}

		for _, scope in ipairs(self.scopes) do
			for _, val in ipairs(scope:GetDependencies()) do
				if (val.Type == "upvalue" and val:GetScope() or val.scope) ~= scope then
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
	return META.NewObject(
		{
			Type = "function",
			Falsy = false,
			Called = false,
			Contract = false,
			Hash = false,
			Truthy = true,
			ReferenceType = false,
			ExplicitInputSignature = false,
			ExplicitOutputSignature = false,
			ArgumentsInferred = false,
			PreventInputArgumentExpansion = false,
			scopes = {},
			scope = false,
			InputSignature = input or false,
			OutputSignature = output or false,
			recursively_called = false,
			AnalyzerFunction = false,
			FunctionBodyNode = false,
			Upvalue = false,
			UpvaluePosition = false,
			InputIdentifiers = false,
			LiteralFunction = false,
			Scope = false,
			Parent = false,
			suppress = false,
			InputArgumentsInferred = false,
		}
	)
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
