local tostring = _G.tostring
local ipairs = _G.ipairs
local setmetatable = _G.setmetatable
local table = _G.table

--[[#local type { TTuple } = require("nattlua.types.tuple")]]

--[[#local type { TUnion } = require("nattlua.types.union")]]

--[[#local type { TAny } = require("nattlua.types.any")]]

local Tuple = require("nattlua.types.tuple").Tuple
local VarArg = require("nattlua.types.tuple").VarArg
local Any = require("nattlua.types.any").Any
--
local error_messages = require("nattlua.error_messages")
local META = require("nattlua.types.base")()
--[[#local type TBaseType = META.TBaseType]]
--[[#type META.@Name = "TFunction"]]
--[[#local type TFunction = META.@Self]]
--[[#type TFunction.Type = "function"]]
--[[#type TFunction.suppress = boolean]]
--[[#type TFunction.InputModifiers = Map<|number, Map<|string, any|>|> | false]]
--[[#type TFunction.OutputModifiers = Map<|number, Map<|string, any|>|> | false]]
META.Type = "function"
META:IsSet("Called", false)
META:IsSet("ExplicitInputSignature", false)
META:IsSet("ExplicitOutputSignature", false)
META:GetSet("InputSignature", false--[[# as TTuple | false]])
META:GetSet("OutputSignature", false--[[# as TTuple | false]])
META:GetSet("FunctionBodyNode", false--[[# as false | any]])
META:GetSet("Scope", false--[[# as false | any]])
META:GetSet("UpvaluePosition", false--[[# as false | number]])
META:GetSet("InputIdentifiers", false--[[# as false | List<|any|>]])
META:GetSet("AnalyzerFunction", false--[[# as false | Function]])
META:IsSet("ArgumentsInferred", false)
META:IsSet("LiteralFunction", false)
META:GetSet("PreventInputArgumentExpansion", false)
META:IsSet("InputArgumentsInferred", false)
META:GetSet("InputModifiers", false--[[# as TFunction.InputModifiers]])
META:GetSet("OutputModifiers", false--[[# as TFunction.OutputModifiers]])

function META.LogicalComparison(l--[[#: TFunction]], r--[[#: TFunction]], op--[[#: string]])
	if op == "==" then
		local ok = l:Equal(r)
		return ok
	end

	return false, error_messages.binary(op, l, r)
end

function META:__tostring()
	if self.suppress then return "current_function" end

	self.suppress = true
	local input = self:GetInputSignature()
	local output = self:GetOutputSignature()
	local s = "function=" .. (
			input and
			tostring(input) or
			"nil"
		) .. ">" .. (
			output and
			tostring(output) or
			"nil"
		)
	self.suppress = false
	return s
end

function META:IsLiteral()
	return true
end

function META.Equal(a--[[#: TFunction]], b--[[#: TBaseType]], visited--[[#: any]])
	if a.Type ~= b.Type then return false, "types differ" end

	local a_input = a:GetInputSignature()
	local b_input = b:GetInputSignature()--[[# as TTuple]]

	if not a_input or not b_input then return false, "missing input signature" end

	local ok, reason = a_input:Equal(b_input, visited)

	if not ok then return false, "input signature mismatch: " .. reason end

	local a_output = a:GetOutputSignature()
	local b_output = b:GetOutputSignature()--[[# as TTuple]]

	if not a_output or not b_output then return false, "missing output signature" end

	local ok, reason = a_output:Equal(b_output, visited)

	if not ok then return false, "output signature mismatch: " .. reason end

	return true, "ok"
end

local context = require("nattlua.analyzer.context")

function META:Get(key--[[#: TBaseType]])--[[#: (TBaseType | false), (any | nil)]]
	if
		key.Type == "string" and
		key:IsLiteral() and
		(
			key
		--[[# as any]]):GetData():sub(1, 1) == "@"
	then
		local a = context:GetCurrentAnalyzer()--[[# as any]]

		if a and a:GetCurrentAnalyzerEnvironment() == "typesystem" then
			return (
					assert(
						(self--[[# as any]])["Get" .. (key--[[# as any]]):GetData():sub(2)],
						(key--[[# as any]]):GetData() .. " is not a function"
					)
				)(self) or
				Nil()
		end
	end

	return false, error_messages.undefined_get(self, key, self.Type)
end

function META:GetHash(visited)
	visited = visited or {}

	if visited[self] then return visited[self] end

	visited[self] = "*circular*"
	local result = "("
	-- Add hash for input signature
	local input = self:GetInputSignature()

	if input then
		local h = input:GetHash(visited)

		if h then result = result .. h end
	end

	result = result .. ")=>("
	-- Add hash for output signature
	local output = self:GetOutputSignature()

	if output then
		local h = output:GetHash(visited)

		if h then result = result .. h end
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
	copy:SetInputSignature(copy_val(self.InputSignature, map, copy_tables)--[[# as TTuple | false]])
	copy:SetOutputSignature(copy_val(self.OutputSignature, map, copy_tables)--[[# as TTuple | false]])
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
	copy:SetInputModifiers(self.InputModifiers)
	copy:SetOutputModifiers(self.OutputModifiers)
	return copy
end

function META.IsSubsetOf(a--[[#: TFunction]], b--[[#: TBaseType]])
	if b.Type == "deferred" then b = b:Unwrap() end

	if b.Type == "tuple" then
		b = assert(b:GetWithNumber(1--[[# as any]]))--[[# as TBaseType]]
	end

	if b.Type == "union" then return b:IsTargetSubsetOfChild(a) end

	if b.Type == "any" then return true end

	if b.Type ~= "function" then return false, error_messages.subset(a, b) end

	local a_input = a:GetInputSignature()
	local b_input = b:GetInputSignature()

	if not a_input or not b_input then return false, "missing input signature" end

	local ok, reason = a_input:IsSubsetOf(b_input)

	if not ok then
		return false,
		error_messages.because(error_messages.subset(a_input, b_input), reason)
	end

	local a_output = a:GetOutputSignature()
	local b_output = b:GetOutputSignature()

	if not a_output or not b_output then return false, "missing output signature" end

	local ok, reason = a_output:IsSubsetOf(b_output)

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
		error_messages.because(error_messages.subset(a_output, b_output), reason)
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

	local a_input = a:GetInputSignature()
	local b_input = b:GetInputSignature()

	if not a_input or not b_input then return false, "missing input signature" end

	local ok, reason = a_input:IsSubsetOf(b_input, a_input:GetMinimumLength())

	if not ok then
		return false,
		error_messages.because(error_messages.subset(a_input, b_input), reason)
	end

	local a_output = a:GetOutputSignature()
	local b_output = b:GetOutputSignature()

	if not a_output or not b_output then return false, "missing output signature" end

	local ok, reason = a_output:IsSubsetOf(b_output)

	if not ok then
		return false,
		error_messages.because(error_messages.subset(a_output, b_output), reason)
	end

	return true
end

function META:HasReferenceTypes()
	local input = self:GetInputSignature()

	if input then
		for i, v in ipairs(input:GetData()) do
			if self:IsInputModifier(i, "ref") then return true end
		end
	end

	local output = self:GetOutputSignature()

	if output then
		for i, v in ipairs(output:GetData()) do
			if self:IsOutputModifier(i, "ref") then return true end
		end
	end

	return false
end

function META:SetInputModifier(index--[[#: number]], modifiers--[[#: Map<|string, any|>]])
	if not self.InputModifiers then self.InputModifiers = {} end

	if self.InputModifiers then self.InputModifiers[index] = modifiers end
end

function META:SetOutputModifier(index--[[#: number]], modifiers--[[#: Map<|string, any|>]])
	if not self.OutputModifiers then self.OutputModifiers = {} end

	if self.OutputModifiers then self.OutputModifiers[index] = modifiers end
end

function META:IsInputModifier(index--[[#: number]], modifier--[[#: string]])
	if not self.InputModifiers then return false end

	if not self.InputModifiers[index] then return false end

	return self.InputModifiers[index][modifier]
end

function META:IsOutputModifier(index--[[#: number]], modifier--[[#: string]])
	if not self.OutputModifiers then return false end

	if not self.OutputModifiers[index] then return false end

	return self.OutputModifiers[index][modifier]
end

function META.New(input--[[#: TTuple]], output--[[#: TTuple]])
	return META.NewObject(
		{
			TruthyFalsy = "truthy",
			Type = "function",
			Called = false,
			Contract = false,
			Hash = false,
			ExplicitInputSignature = false,
			ExplicitOutputSignature = false,
			ArgumentsInferred = false,
			PreventInputArgumentExpansion = false,
			InputSignature = input or false,
			OutputSignature = output or false,
			AnalyzerFunction = false,
			FunctionBodyNode = false,
			Upvalue = false,
			UpvaluePosition = false,
			InputIdentifiers = false,
			LiteralFunction = false,
			Scope = false,
			suppress = false--[[# as boolean]],
			InputArgumentsInferred = false,
			InputModifiers = false,
			OutputModifiers = false,
			Data = false,
		}
	)
end

return {
	TFunction = TFunction,
	Function = META.New,
	AnyFunction = function()
		return META.New(
			Tuple({VarArg(Any()--[[# as any]])})--[[# as TTuple]],
			Tuple({VarArg(Any()--[[# as any]])})--[[# as TTuple]]
		)
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
