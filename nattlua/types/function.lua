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
local shared = require("nattlua.types.shared")
--
local error_messages = require("nattlua.error_messages")
local META = require("nattlua.types.base")()
--[[#local type TBaseType = META.TBaseType]]
--[[#type META.@Name = "TFunction"]]
--[[#local type TFunction = META.@SelfArgument]]
--[[#type TFunction.Type = "function"]]
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

function META:__tostring()
	if self:IsSuppressed() then return "current_function" end

	self:PushSuppress()
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
	self:PopSuppress()
	return s
end

function META:IsLiteral()
	return true
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

	local existing = map[self]

	if existing then return existing end

	local copy = META.New()
	map[self] = copy

	do
		local input = self.InputSignature

		if input then
			local mapped = map[input]

			if mapped then
				copy.InputSignature = mapped
			else
				map[input] = input:Copy(map, copy_tables)
				copy.InputSignature = map[input]
			end
		else
			copy.InputSignature = false
		end
	end

	do
		local output = self.OutputSignature

		if output then
			local mapped = map[output]

			if mapped then
				copy.OutputSignature = mapped
			else
				map[output] = output:Copy(map, copy_tables)
				copy.OutputSignature = map[output]
			end
		else
			copy.OutputSignature = false
		end
	end

	copy.UpvaluePosition = self.UpvaluePosition
	copy.AnalyzerFunction = self.AnalyzerFunction
	copy.Scope = self.Scope
	copy:CopyInternalsFrom(self)
	copy.FunctionBodyNode = self.FunctionBodyNode
	copy.InputIdentifiers = self.InputIdentifiers
	copy.Called = self.Called
	copy.ExplicitInputSignature = self.ExplicitInputSignature
	copy.ExplicitOutputSignature = self.ExplicitOutputSignature
	copy.ArgumentsInferred = self.ArgumentsInferred
	copy.PreventInputArgumentExpansion = self.PreventInputArgumentExpansion
	copy.LiteralFunction = self.LiteralFunction
	copy.InputArgumentsInferred = self.InputArgumentsInferred
	copy.InputModifiers = self.InputModifiers
	copy.OutputModifiers = self.OutputModifiers
	return copy
end

function META:CopyForReturn(map--[[#: Map<|any, any|> | nil]])
	map = map or {}

	local existing = map[self]

	if existing then return existing end

	local copy = META.New()
	map[self] = copy

	do
		local input = self.InputSignature

		if input then
			local mapped = map[input]

			if mapped then
				copy.InputSignature = mapped
			else
				copy.InputSignature = input:CopyForReturn(map)
			end
		else
			copy.InputSignature = false
		end
	end

	do
		local output = self.OutputSignature

		if output then
			local mapped = map[output]

			if mapped then
				copy.OutputSignature = mapped
			else
				copy.OutputSignature = output:CopyForReturn(map)
			end
		else
			copy.OutputSignature = false
		end
	end

	copy.UpvaluePosition = self.UpvaluePosition
	copy.AnalyzerFunction = self.AnalyzerFunction
	copy.Scope = self.Scope
	copy:CopyInternalsFrom(self)
	copy.FunctionBodyNode = self.FunctionBodyNode
	copy.InputIdentifiers = self.InputIdentifiers
	copy.Called = self.Called
	copy.ExplicitInputSignature = self.ExplicitInputSignature
	copy.ExplicitOutputSignature = self.ExplicitOutputSignature
	copy.ArgumentsInferred = self.ArgumentsInferred
	copy.PreventInputArgumentExpansion = self.PreventInputArgumentExpansion
	copy.LiteralFunction = self.LiteralFunction
	copy.InputArgumentsInferred = self.InputArgumentsInferred
	copy.InputModifiers = self.InputModifiers
	copy.OutputModifiers = self.OutputModifiers
	return copy
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

	local ok, reason = shared.IsSubsetOf(a_input, b_input, nil, a_input:GetMinimumLength())

	if not ok then
		return false,
		error_messages.because(error_messages.subset(a_input, b_input), reason)
	end

	local a_output = a:GetOutputSignature()
	local b_output = b:GetOutputSignature()

	if not a_output or not b_output then return false, "missing output signature" end

	local ok, reason = shared.IsSubsetOf(a_output, b_output)

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
	return META.NewObject{
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
		InputArgumentsInferred = false,
		InputModifiers = false,
		OutputModifiers = false,
		Data = false,
	}
end

return {
	TFunction = TFunction,
	Function = META.New,
	AnyFunction = function()
		return META.New(
			Tuple{VarArg(Any()--[[# as any]])}--[[# as TTuple]],
			Tuple{VarArg(Any()--[[# as any]])}--[[# as TTuple]]
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
