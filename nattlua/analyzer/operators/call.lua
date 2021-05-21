local ipairs = ipairs
local type = type
local math = math
local table = require("table")
local tostring = tostring
local debug = debug
local print = print
local string = require("string")
local types = require("nattlua.types.types")
local type_errors = require("nattlua.types.error_messages")
return function(META)
	function META:LuaTypesToTuple(node, tps)
		local tbl = {}

		for i, v in ipairs(tps) do
			if types.IsTypeObject(v) then
				tbl[i] = v
				v:SetNode(node)
			else
				if type(v) == "function" then
					tbl[i] = self:NewType(
						node,
						"function",
						{
							lua_function = v,
							arg = types.Tuple({}):AddRemainder(types.Tuple({types.Any()}):SetRepeat(math.huge)),
							ret = types.Tuple({}):AddRemainder(types.Tuple({types.Any()}):SetRepeat(math.huge)),
						},
						true
					)
				else
					tbl[i] = self:NewType(node, type(v), v, true)
				end
			end
		end

		if tbl[1] and tbl[1].Type == "tuple" and #tbl == 1 then return tbl[1] end
		return types.Tuple(tbl)
	end

	function META:AnalyzeFunctionBody(function_node, arguments, env)
		local scope = self:CreateAndPushFunctionScope(function_node)
		scope.scope_is_being_called = true
		self:PushEnvironment(function_node, nil, env)

		if function_node.self_call then
			self:CreateLocalValue("self", arguments:Get(1) or self:NewType(function_node, "nil"), env, "self")
		end

		for i, identifier in ipairs(function_node.identifiers) do
			local argi = function_node.self_call and (i + 1) or i

			if identifier.value.value == "..." then
				self:CreateLocalValue(identifier, arguments:Slice(argi), env, argi)
			else
				self:CreateLocalValue(identifier, arguments:Get(argi) or self:NewType(identifier, "nil"), env, argi)
			end
		end

		local analyzed_return = self:AnalyzeStatementsAndCollectReturnTypes(function_node)
		scope.scope_is_being_called = false
		self:PopEnvironment(env)
		self:PopScope()
		return analyzed_return, scope
	end

	local unpack_union_tuples

	do
		local ipairs = ipairs

		local function should_expand(arg, contract)
			local b = arg.Type == "union"

			if contract.Type == "any" then
				b = false
			end

			if contract.Type == "union" then
				b = false
			end

			if arg.Type == "union" and contract.Type == "union" and contract:CanBeNil() then
				b = true
			end

			return b
		end

		function unpack_union_tuples(func_obj, arguments, function_arguments)
			local out = {}
			local lengths = {}
			local max = 1
			local ys = {}
			local arg_length = #arguments

			for i, obj in ipairs(arguments) do
				if not func_obj.no_expansion and should_expand(obj, function_arguments:Get(i)) then
					lengths[i] = #obj:GetData()
					max = max * lengths[i]
				else
					lengths[i] = 0
				end

				ys[i] = 1
			end

			for i = 1, max do
				local args = {}

				for i, obj in ipairs(arguments) do
					if lengths[i] == 0 then
						args[i] = obj
					else
						args[i] = obj:GetData()[ys[i]]
					end
				end

				out[i] = args

				for i = arg_length, 2, -1 do
					if i == arg_length then
						ys[i] = ys[i] + 1
					end

					if ys[i] > lengths[i] then
						ys[i] = 1
						ys[i - 1] = ys[i - 1] + 1
					end
				end
			end

			return out
		end
	end

	local function infer_uncalled_functions(self, call_node, tuple, function_arguments)
		for i, b in ipairs(tuple:GetData()) do
			if b.Type == "function" and not b.called and not b.explicit_return then
				local a = function_arguments:Get(i)

				if
					a and
					(a.Type == "function" and not a:GetReturnTypes():IsSubsetOf(b:GetReturnTypes())) or
					not a:IsSubsetOf(b)
				then
					b.arguments_inferred = true
					self:Assert(call_node, self:Call(b, b:GetArguments():Copy()))
				end
			end
		end
	end

	local function call_type_function(self, obj, call_node, function_node, function_arguments, arguments)
		local len = function_arguments:GetLength()

		if len == math.huge and arguments:GetLength() == math.huge then
			len = math.max(function_arguments:GetMinimumLength(), arguments:GetMinimumLength())
		end

		local tuples = {}

		for i, arg in ipairs(unpack_union_tuples(obj, {arguments:Unpack(len)}, function_arguments)) do
			tuples[i] = self:LuaTypesToTuple(
				obj:GetNode(),
				{
					self:CallLuaTypeFunction(
						call_node,
						obj:GetData().lua_function,
						function_node and
						function_node.function_scope or
						self:GetScope(),
						table.unpack(arg)
					),
				}
			)
		end

		local ret = types.Tuple({})

		for _, tuple in ipairs(tuples) do
			local len = tuple:GetMinimumLength()

			if len == 0 then
				return tuple
			else
				for i = 1, len do
					local v = tuple:Get(i)
					local existing = ret:Get(i)

					if existing then
						if existing.Type == "union" then
							existing:AddType(v)
						else
							ret:Set(i, types.Union({v, existing}))
						end
					else
						ret:Set(i, v)
					end
				end
			end
		end

		return ret
	end

	local function restore_mutated_types(self)
		if not self.mutated_types or not self.mutated_types[1] then return end
		local mutated_types = table.remove(self.mutated_types)

		for _, data in ipairs(mutated_types) do
			local original = data.original
			local modified = data.modified
			modified:SetContract(original:GetContract())
			self:MutateValue(original:GetUpvalue(), original:GetUpvalue().key, modified, "runtime")
		end
	end

	local function check_and_setup_arguments(self, arguments, contracts)
		self.mutated_types = self.mutated_types or {}
		table.insert(self.mutated_types, 1, {})
		local len = contracts:GetSafeLength(arguments)

		for i = 1, len do
			local arg = arguments:Get(i)
			local contract = contracts:Get(i)
			local ok, reason

			if not arg then
				if contract:IsFalsy() then
					arg = types.Nil()
					ok = true
				else
					ok, reason = type_errors.other(
						{
							"argument #",
							i,
							" expected ",
							contract,
							" got nil",
						}
					)
				end
			elseif arg.Type == "table" and contract.Type == "table" then
				ok, reason = arg:FollowsContract(contract)
			else
				ok, reason = arg:IsSubsetOf(contract)
			end

			if not ok then
				restore_mutated_types(self)
				return type_errors.other({"argument #", i, " ", arg, ": ", reason})
			end

			if
				arg.Type == "table" and
				contract.Type == "table" and
				arg:GetUpvalue() and
				not contract.literal_argument
			then
				local original = arg
				local modified = arg:Copy()
				modified:SetContract(contract)
				modified.argument_index = i
				table.insert(self.mutated_types[1], {
					original = original,
					modified = modified,
				})
				arguments:Set(i, modified)
			else
                -- if it's a const argument we pass the incoming value
                if not contract.literal_argument then
					local t = contract:Copy()
					t:SetContract(contract)
					arguments:Set(i, t)
				end
			end
		end

		return true
	end

	local function check_return_result(self, result, contract)
		if
			contract and
			contract:GetLength() == 1 and
			contract:Get(1).Type == "union" and
			contract:Get(1):HasType("tuple")
		then
			contract = contract:Get(1)
		end

		if
			result and
			result:GetLength() == 1 and
			result:Get(1) and
			result:Get(1).Type == "union" and
			result:Get(1):HasType("tuple")
		then
			result = result:Get(1)
		end

		if result.Type == "union" then
			for _, tuple in ipairs(result:GetData()) do
				check_return_result(self, tuple, contract)
			end
		else
			if contract.Type == "union" then
				local errors = {}

				for _, contract in ipairs(contract:GetData()) do
					local ok, reason = result:IsSubsetOfTuple(contract)

					if ok then
						return
					else
						table.insert(errors, {contract = contract, reason = reason})
					end
				end

				for _, error in ipairs(errors) do
					self:Error(result:GetNode(), error.reason)
				end
			else
				local ok, reason, a, b, i = result:IsSubsetOfTuple(contract)

				if not ok then
					if result:Get(i) then
						self:Error(result:Get(i):GetNode(), reason)
					else
						self:Error(result:GetNode(), reason)
					end
				end
			end
		end
	end

	local function Call(self, obj, arguments, call_node)
		call_node = call_node or obj:GetNode()
		local function_node = obj.function_body_node-- or obj:GetNode()
    
        obj.called = true
		local env = self:GetPreferTypesystem() and "typesystem" or "runtime"

		if obj.Type == "union" then
			obj = obj:MakeCallableUnion(self, call_node)
		end

		if obj.Type ~= "function" then
			if obj.Type == "any" then

                -- any can do anything with mutable arguments

                for _, arg in ipairs(arguments:GetData()) do
					if arg.Type == "table" and arg:GetEnvironment() == "runtime" then
						if arg:GetContract() then
							self:Error(call_node, "cannot mutate argument with contract " .. tostring(arg:GetContract()))
						else
							for _, keyval in ipairs(arg:GetData()) do
								keyval.key = types.Union({types.Any(), keyval.key})
								keyval.val = types.Union({types.Any(), keyval.val})
							end
						end
					end
				end
			end

			return obj:Call(self, arguments, call_node)
		end

		local function_arguments = obj:GetArguments()
		infer_uncalled_functions(self, call_node, arguments, function_arguments)

		do
			local ok, reason, a, b, i = arguments:IsSubsetOfTuple(obj:GetArguments())

			if not ok then
				if b and b:GetNode() then return type_errors.subset(a, b, {"function argument #", i, " '", b, "': ", reason}) end
				return type_errors.subset(a, b, {"argument #", i, " - ", reason})
			end
		end

		if obj:GetData().lua_function then
			return call_type_function(
				self,
				obj,
				call_node,
				function_node,
				function_arguments,
				arguments
			)
		elseif not function_node or function_node.kind == "type_function" then
			for i, arg in ipairs(arguments:GetData()) do
				if arg.Type == "table" and arg:GetEnvironment() == "runtime" then
					for _, keyval in ipairs(arg:GetData()) do
						keyval.key = types.Union({types.Any(), keyval.key})
						keyval.val = types.Union({types.Any(), keyval.val})
					end

					if self.config.external_mutation then
						self:Warning(
							call_node,
							"argument #" .. i .. " " .. tostring(arg) .. " can be mutated by external call"
						)
					end
				end
			end

			self:FireEvent("external_call", call_node, obj)
		else
			local use_contract = obj.explicit_arguments and
				env ~= "typesystem" and
				function_node.kind ~= "local_generics_type_function" and
				function_node.kind ~= "generics_type_function" and
				not call_node.type_call

			if use_contract then
				local ok, err = check_and_setup_arguments(self, arguments, obj:GetArguments())
				if not ok then return ok, err end
			end

			local return_result, scope = self:AnalyzeFunctionBody(function_node, arguments, env)
			obj:AddScope(arguments, return_result, scope)
			restore_mutated_types(self)
			local return_contract = obj:HasExplicitReturnTypes() and obj:GetReturnTypes()

			if not return_contract and function_node.return_types then
				self:CreateAndPushFunctionScope(function_node)
				self:PushPreferTypesystem(true)
				return_contract = types.Tuple(self:AnalyzeExpressions(function_node.return_types, "typesystem"))
				self:PopPreferTypesystem()
				self:PopScope()
			end

			if return_contract then
				check_return_result(self, return_result, return_contract)
			else
				obj:GetReturnTypes():Merge(return_result)

				if not obj.arguments_inferred and function_node.identifiers then
					for i in ipairs(obj:GetArguments():GetData()) do
						if function_node.self_call then
                            -- we don't count the actual self argument
                            local node = function_node.identifiers[i + 1]

							if node and not node.explicit_type then
								self:Warning(node, "argument is untyped")
							end
						elseif function_node.identifiers[i] and not function_node.identifiers[i].explicit_type then
							self:Warning(function_node.identifiers[i], "argument is untyped")
						end
					end
				end
			end

			if not use_contract then
				obj:GetArguments():Merge(arguments:Slice(1, obj:GetArguments():GetMinimumLength()))
			end

			self:FireEvent("function_spec", obj)

			if return_contract then
                -- this is so that the return type of a function can access its arguments, to generics
                -- local function foo(a: number, b: number): Foo(a, b) return a + b end
                self:CreateAndPushFunctionScope(function_node)

				for i, key in ipairs(function_node.identifiers) do
					local arg = arguments:Get(i)

					if arg then
						self:CreateLocalValue(key, arguments:Get(i), "typesystem", i)
					end
				end

				self:PopScope()
			end

			do -- this is for the emitter
                if function_node.identifiers then
					for i, node in ipairs(function_node.identifiers) do
						node.inferred_type = obj:GetArguments():Get(i)
					end
				end

				function_node.inferred_type = obj
			end

			if not return_contract then return return_result end
			local contract = obj:GetReturnTypes():Copy()

			for _, v in ipairs(contract:GetData()) do
				if v.Type == "table" then
					v:SetReferenceId(nil)
				end
			end

			for i, v in ipairs(return_contract:GetData()) do
				if v.literal_argument then
					contract:Set(i, return_result:Get(i))
				end
			end

			return contract
		end

		local ret = obj:GetReturnTypes():Copy()

		for _, v in ipairs(ret:GetData()) do
			if v.Type == "table" then
				v:SetReferenceId(nil)
			end
		end

		return ret
	end

	function META:Call(obj, arguments, call_node)
		self.call_stack = self.call_stack or {}

		for _, v in ipairs(self.call_stack) do
			if v.obj == obj and v.call_node == call_node then
				if obj.explicit_return then
					return obj:GetReturnTypes():Copy()
				else
					return types.Tuple({}):AddRemainder(types.Tuple({types.Any()}):SetRepeat(math.huge))
				end
			end
		end

		if debug.getinfo(300) then
			local level = 1
			print("Trace:")

			while true do
				local info = debug.getinfo(level, "Sln")
				if not info then break end

				if info.what == "C" then
					print(string.format("\t%i: C function\t\"%s\"", level, info.name))
				else
					local path = info.source

					if path:sub(1, 1) == "@" then
						path = path:sub(2)
					else
						path = info.short_src
					end

					print(string.format("%i: %s\t%s:%s\t", level, info.name, path, info.currentline))
				end

				level = level + 1
			end

			print("")
			return false, "call stack is too deep"
		end

		table.insert(
			self.call_stack,
			{
				obj = obj,
				function_node = obj.function_body_node,
				call_node = call_node,
			}
		)
		local ok, err = Call(self, obj, arguments, call_node)
		table.remove(self.call_stack)
		return ok, err
	end
end
