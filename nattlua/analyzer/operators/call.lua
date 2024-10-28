local Tuple = require("nattlua.types.tuple").Tuple
local ConstString = require("nattlua.types.string").ConstString
local Union = require("nattlua.types.union").Union
local Any = require("nattlua.types.any").Any
local type_errors = require("nattlua.types.error_messages")

local function union_call(self, analyzer, input, call_node)
	if false--[[# as true]] then return end

	if self:IsEmpty() then
		return false, type_errors.operation("call", nil, "union")
	end

	do
		-- make sure the union is callable, we pass the analyzer and 
		-- it will throw errors if the union contains something that is not callable
		-- however it will continue and just remove those values from the union
		local truthy_union = Union()

		for _, v in ipairs(self.Data) do
			if analyzer:IsRuntime() then
				if v.Type == "tuple" then v = v:GetFirstValue() end
			end

			if v.Type ~= "function" and v.Type ~= "table" and v.Type ~= "any" then
				analyzer:ErrorAndCloneCurrentScope(type_errors.union_contains_non_callable(self, v), self--[[# as any]])
			else
				truthy_union:AddType(v)
			end
		end

		truthy_union:SetUpvalue(self:GetUpvalue())
		self = truthy_union
	end

	local is_overload = true

	for _, obj in ipairs(self.Data) do
		if obj.Type ~= "function" or obj:GetFunctionBodyNode() then
			is_overload = false

			break
		end
	end

	if is_overload then
		local errors = {}

		for _, obj in ipairs(self.Data) do
			if
				obj.Type == "function" and
				input:GetElementCount() < obj:GetInputSignature():GetMinimumLength()
			then
				table.insert(
					errors,
					{
						"invalid amount of arguments: ",
						input,
						" ~= ",
						obj:GetInputSignature(),
					}
				)
			else
				local res, reason = analyzer:Call(obj, input:Copy(), call_node, true)

				if res then return res end

				table.insert(errors, reason)
			end
		end

		return false, errors
	end

	local new = Union()

	for _, obj in ipairs(self:GetData()) do
		local val = analyzer:Assert(analyzer:Call(obj, input:Copy(), call_node, true))

		-- TODO
		if val.Type == "tuple" and val:GetElementCount() == 1 then
			val = val:Unpack(1)
		elseif val.Type == "union" and val:GetMinimumLength() == 1 then
			val = val:GetAtTupleIndex(1)
		end

		new:AddType(val)
	end

	return Tuple({new--[[# as any]]})
end

local function tuple_call(self, analyzer, input, call_node)
	return analyzer:Call((self:GetFirstValue()--[[# as any]]), input, call_node, true)
end

local function table_call(self, analyzer, input, call_node)
	if not self:GetMetaTable() then
		return false,
		type_errors.because(type_errors.table_index(self, "__call"), "it has no metatable")
	end

	local __call, reason = self:GetMetaTable():Get(ConstString("__call"))

	if __call then
		local new_input = {self}

		for _, v in ipairs(input:GetData()) do
			table.insert(new_input, v)
		end

		return analyzer:Call(__call, Tuple(new_input), call_node, true)
	end

	return false,
	type_errors.because(type_errors.table_index(self, "__call"), reason)
end

local function_call

do
	local call_analyzer = require("nattlua.analyzer.operators.function_call_analyzer")
	local call_body = require("nattlua.analyzer.operators.function_call_body")
	local call_function_signature = require("nattlua.analyzer.operators.function_call_function_signature")

	local function call_function_internal(self, obj, input)
		-- mark the object as called so the unreachable code step won't call it
		obj:SetCalled(true)

		-- infer any uncalled functions in the arguments to get their return type
		for i, b in ipairs(input:GetData()) do
			if b.Type == "function" and not b:IsCalled() and not b:IsExplicitOutputSignature() then
				local a = obj:GetInputSignature():GetWithNumber(i)

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
					if not b:HasReferenceTypes() and func then
						self:Assert(self:Call(b, func:GetInputSignature():Copy(nil, true)))
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

	function function_call(self, analyzer, input, call_node, not_recursive_call)
		if
			analyzer:IsRuntime() and
			self:IsCalled() and
			not self:HasReferenceTypes()
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
			not self:HasReferenceTypes()
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

		local function_node = self:GetFunctionBodyNode()
		local is_type_function = function_node and
			(
				function_node.kind == "local_type_function" or
				function_node.kind == "type_function"
			)

		if is_type_function then analyzer:PushAnalyzerEnvironment("typesystem") end

		local ok, err = call_function_internal(analyzer, self, input)

		if is_type_function then analyzer:PopAnalyzerEnvironment() end

		analyzer:PopCallFrame()
		return ok, err
	end
end

local function base_call(self, analyzer, input, call_node)
	return false, type_errors.invalid_type_call(self.Type, self)
end

local function any_call(self, analyzer, input, call_node)
	-- it's ok to call any types, it will just return any
	-- check arguments that can be mutated
	for _, arg in ipairs(input:GetData()) do
		if arg.Type == "table" and arg:GetAnalyzerEnvironment() == "runtime" then
			if arg:GetContract() then
				-- error if we call any with tables that have contracts
				-- since anything might happen to them in an any call
				analyzer:Error({
					"cannot mutate argument with contract ",
					arg:GetContract(),
				})
			else
				-- if we pass a table without a contract to an any call, we add any to its key values
				for _, keyval in ipairs(arg:GetData()) do
					keyval.key = Union({Any(), keyval.key})
					keyval.val = Union({Any(), keyval.val})
				end
			end
		end
	end

	return Tuple():AddRemainder(Tuple({Any()}):SetRepeat(math.huge))
end

return {
	Call = function(META)
		function META:Call(obj, input, call_node, not_recursive_call)
			if obj.Type == "any" then
				return any_call(obj, self, input, call_node)
			elseif obj.Type == "function" then
				return function_call(obj, self, input, call_node, not_recursive_call)
			elseif obj.Type == "tuple" then
				return tuple_call(obj, self, input, call_node)
			elseif obj.Type == "union" then
				return union_call(obj, self, input, call_node)
			elseif obj.Type == "table" then
				return table_call(obj, self, input, call_node)
			end

			return base_call(obj, self, input, call_node)
		end
	end,
}
