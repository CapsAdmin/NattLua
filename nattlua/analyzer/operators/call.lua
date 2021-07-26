local ipairs = ipairs
local type = type
local math = math
local table = require("table")
local tostring = tostring
local debug = debug
local print = print
local string = require("string")
local Tuple = require("nattlua.types.tuple").Tuple
local Union = require("nattlua.types.union").Union
local Nil = require("nattlua.types.symbol").Nil
local Any = require("nattlua.types.any").Any
local Function = require("nattlua.types.function").Function
local LString = require("nattlua.types.string").LString
local LNumber = require("nattlua.types.number").LNumber
local Symbol = require("nattlua.types.symbol").Symbol
local type_errors = require("nattlua.types.error_messages")

local function lua_types_to_tuple(node, tps)
	local tbl = {}

	for i, v in ipairs(tps) do
		if type(v) == "table" and v.Type ~= nil then
			tbl[i] = v
			v:SetNode(node)
		else
			if type(v) == "function" then
				tbl[i] = Function(
						{
							lua_function = v,
							arg = Tuple({}):AddRemainder(Tuple({Any()}):SetRepeat(math.huge)),
							ret = Tuple({}):AddRemainder(Tuple({Any()}):SetRepeat(math.huge)),
						}
					)
					:SetNode(node)
					:SetLiteral(true)

				if node.statements then
					tbl[i].function_body_node = node
				end
			else
				local t = type(v)

				if t == "number" then
					tbl[i] = LNumber(v):SetNode(node)
				elseif t == "string" then
					tbl[i] = LString(v):SetNode(node)
				elseif t == "boolean" then
					tbl[i] = Symbol(v):SetNode(node)
				else
					error("NYI " .. t)
				end
			end
		end
	end

	if tbl[1] and tbl[1].Type == "tuple" and #tbl == 1 then return tbl[1] end
	return Tuple(tbl)
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


return
	{
		Call = function(META)
			function META:AnalyzeFunctionBody(obj, function_node, arguments, env)
				local scope = self:CreateAndPushFunctionScope(obj:GetData().scope, obj:GetData().upvalue_position)
				self:PushEnvironment(function_node, nil, env)

				if function_node.self_call then
					self:CreateLocalValue("self", arguments:Get(1) or Nil():SetNode(function_node), env, "self")
				end

				for i, identifier in ipairs(function_node.identifiers) do
					local argi = function_node.self_call and (i + 1) or i

					if identifier.value.value == "..." then
						self:CreateLocalValue(identifier, arguments:Slice(argi), env, argi)
					else
						self:CreateLocalValue(identifier, arguments:Get(argi) or Nil():SetNode(identifier), env, argi)
					end
				end

				local analyzed_return = self:AnalyzeStatementsAndCollectReturnTypes(function_node)
				self:PopEnvironment(env)
				self:PopScope()
				if analyzed_return.Type ~= "tuple" then
					return Tuple({analyzed_return}), scope
				end
				return analyzed_return, scope
			end

			local function infer_uncalled_functions(self, tuple, function_arguments)
				for i, b in ipairs(tuple:GetData()) do
					if b.Type == "function" and not b.called and not b.explicit_return then
						local a = function_arguments:Get(i)

						if
							a and
							(a.Type == "function" and not a:GetReturnTypes():IsSubsetOf(b:GetReturnTypes())) or
							not a:IsSubsetOf(b)
						then
							b.arguments_inferred = true
							self:Assert(self:GetActiveNode(), self:Call(b, b:GetArguments():Copy()))
						end
					end
				end
			end

			local function call_lua_type_function(self, obj, function_node, function_arguments, arguments)
				local len = function_arguments:GetLength()

				if len == math.huge and arguments:GetLength() == math.huge then
					len = math.max(function_arguments:GetMinimumLength(), arguments:GetMinimumLength())
				end

				local tuples = {}

				for i, arg in ipairs(unpack_union_tuples(obj, {arguments:Unpack(len)}, function_arguments)) do
					tuples[i] = lua_types_to_tuple(
						obj:GetNode(),
						{
							self:CallLuaTypeFunction(
								self:GetActiveNode(),
								obj:GetData().lua_function,
								obj:GetData().scope or self:GetScope(),
								table.unpack(arg)
							),
						}
					)
				end

				local ret = Tuple({})

				for _, tuple in ipairs(tuples) do
					if tuple:GetMinimumLength() == 0 or tuple:GetUnpackable() then
						return tuple
					else
						for i = 1, #tuple:GetData() do
							local v = tuple:Get(i)
							local existing = ret:Get(i)

							if existing then
								if existing.Type == "union" then
									existing:AddType(v)
								else
									ret:Set(i, Union({v, existing}))
								end
							else
								ret:Set(i, v)
							end
						end
					end
				end

				return ret
			end

			local function call_type_signature_without_body(self, obj, arguments)
				for i, arg in ipairs(arguments:GetData()) do
					if arg.Type == "table" and arg:GetEnvironment() == "runtime" then
						for _, keyval in ipairs(arg:GetData()) do
							keyval.key = Union({Any(), keyval.key})
							keyval.val = Union({Any(), keyval.val})
						end

						if self.config.external_mutation then
							self:Warning(self:GetActiveNode(), {
								"argument #",
								i,
								" ",
								arg,
								" can be mutated by external call",
							})
						end
					end
				end

				self:FireEvent("external_call", self:GetActiveNode(), obj)

				local ret = obj:GetReturnTypes():Copy()

				for _, v in ipairs(ret:GetData()) do
					if v.Type == "table" then
						v:SetReferenceId(nil)
					end
				end

				return ret
			end


			local call_lua_function_with_body

			do
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
								arg = Nil()
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

				call_lua_function_with_body = function(self, obj, arguments, function_node, env)
					local use_contract = obj.explicit_arguments and
						env ~= "typesystem" and
						function_node.kind ~= "local_generics_type_function" and
						function_node.kind ~= "generics_type_function" and
						not self:GetActiveNode().type_call

					if use_contract then
						local ok, err = check_and_setup_arguments(self, arguments, obj:GetArguments())
						if not ok then return ok, err end
					end

					local return_result, scope = self:AnalyzeFunctionBody(obj, function_node, arguments, env)
					obj:AddScope(arguments, return_result, scope)
					restore_mutated_types(self)
					local return_contract = obj:HasExplicitReturnTypes() and obj:GetReturnTypes()

					if not return_contract and function_node.return_types then
						self:CreateAndPushFunctionScope(obj:GetData().scope, obj:GetData().upvalue_position)
						self:PushPreferTypesystem(true)
						return_contract = Tuple(self:AnalyzeExpressions(function_node.return_types, "typesystem"))
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

									if node and not node.as_expression then
										self:Warning(node, "argument is untyped")
									end
								elseif function_node.identifiers[i] and not function_node.identifiers[i].as_expression then
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
						self:CreateAndPushFunctionScope(obj:GetData().scope, obj:GetData().upvalue_position)

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
			end

			local function Call(self, obj, arguments)
				local env = self:GetPreferTypesystem() and "typesystem" or "runtime"

				if obj.Type == "union" then
					obj = obj:MakeCallableUnion(self)
				end
				
				obj.called = true				
				local function_node = obj.function_body_node

				if obj.Type ~= "function" then
					if obj.Type == "any" then

						-- any can do anything with mutable arguments

						for _, arg in ipairs(arguments:GetData()) do
							if arg.Type == "table" and arg:GetEnvironment() == "runtime" then
								if arg:GetContract() then
									self:Error(self:GetActiveNode(), {
										"cannot mutate argument with contract ",
										arg:GetContract(),
									})
								else
									for _, keyval in ipairs(arg:GetData()) do
										keyval.key = Union({Any(), keyval.key})
										keyval.val = Union({Any(), keyval.val})
									end
								end
							end
						end
					end

					return obj:Call(self, arguments)
				end

				local function_arguments = obj:GetArguments()
				infer_uncalled_functions(self, arguments, function_arguments)

				do
					local ok, reason, a, b, i = arguments:IsSubsetOfTuple(obj:GetArguments())

					if not ok then
						if b and b:GetNode() then return type_errors.subset(a, b, {"function argument #", i, " '", b, "': ", reason}) end
						return type_errors.subset(a, b, {"argument #", i, " - ", reason})
					end
				end

				if obj:GetData().lua_function then
					return call_lua_type_function(
						self,
						obj,
						function_node,
						function_arguments,
						arguments
					)
				elseif function_node then
					return call_lua_function_with_body(self, obj, arguments, function_node, env)
				end
				
				return call_type_signature_without_body(self, obj, arguments)
			end

			function META:Call(obj, arguments, call_node)
				self:SetActiveNode(call_node or obj:GetNode())

				self.call_stack = self.call_stack or {}

				for _, v in ipairs(self.call_stack) do
					if v.obj == obj and v.call_node == self:GetActiveNode() then
						if obj.explicit_return then
							return obj:GetReturnTypes():Copy()
						else
							return Tuple({}):AddRemainder(Tuple({Any()}):SetRepeat(math.huge))
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
						call_node = self:GetActiveNode(),
					}
				)
				local ok, err = Call(self, obj, arguments, call_node)
				table.remove(self.call_stack)
				return ok, err
			end
		end,
	}
