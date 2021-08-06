local ipairs = ipairs
local type = type
local math = math
local table = require("table")
local tostring = tostring
local debug = debug
local print = print
local string = require("string")
local VarArg = require("nattlua.types.tuple").VarArg
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

					if env == "typesystem" then
						self:CreateLocalValue(identifier, arguments:GetWithoutExpansion(argi), env, argi)
					end

					if env == "runtime" then

						if identifier.value.value == "..." then
							self:CreateLocalValue(identifier, arguments:Slice(argi), env, argi)
						else
							self:CreateLocalValue(identifier, arguments:Get(argi) or Nil():SetNode(identifier), env, argi)
						end
					end
				end

				local analyzed_return = self:AnalyzeStatementsAndCollectReturnTypes(function_node)
				self:PopEnvironment(env)
				self:PopScope()
				if analyzed_return.Type ~= "tuple" then
					return Tuple({analyzed_return}):SetNode(analyzed_return:GetNode()), scope
				end
				return analyzed_return, scope
			end

			local function call_lua_type_function(self, obj, function_arguments, arguments, env)
				do
					local ok, reason, a, b, i = arguments:IsSubsetOfTuple(obj:GetArguments())
				
					if not ok then
						if b and b:GetNode() then return type_errors.subset(a, b, {"function argument #", i, " '", b, "': ", reason}) end
						return type_errors.subset(a, b, {"argument #", i, " - ", reason})
					end
				end

				local len = function_arguments:GetLength()

				if len == math.huge and arguments:GetLength() == math.huge then
					len = math.max(function_arguments:GetMinimumLength(), arguments:GetMinimumLength())
				end

				if env == "typesystem" then
					local ret = lua_types_to_tuple(
						obj:GetNode(),
						{
							self:CallLuaTypeFunction(
								self:GetActiveNode(),
								obj:GetData().lua_function,
								obj:GetData().scope or self:GetScope(),
								arguments:UnpackWithoutExpansion()
						)
						})
					return ret
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
				do
					local ok, reason, a, b, i = arguments:IsSubsetOfTuple(obj:GetArguments())

					if not ok then
						if b and b:GetNode() then return type_errors.subset(a, b, {"function argument #", i, " '", b, "': ", reason}) end
						return type_errors.subset(a, b, {"argument #", i, " - ", reason})
					end
				end

				for i, arg in ipairs(arguments:GetData()) do
					if arg.Type == "table" and arg:GetEnvironment() == "runtime" then
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

				-- clear any reference id from the returned arguments
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

				local function check_and_setup_arguments(analyzer, arguments, contracts, function_node, obj)
					analyzer.mutated_types = analyzer.mutated_types or {}
					table.insert(analyzer.mutated_types, 1, {})
					local len = contracts:GetSafeLength(arguments)

					local contract_override = {}

					do -- analyze the type expressions
						
						analyzer:CreateAndPushFunctionScope(obj:GetData().scope, obj:GetData().upvalue_position)
						analyzer:PushPreferTypesystem(true)
						local args = {}

						for i, key in ipairs(function_node.identifiers) do
							if function_node.self_call then
								i = i + 1
							end
							if contracts:Get(i).literal_argument and arguments:Get(i) then
								analyzer:CreateLocalValue(key, arguments:Get(i), "typesystem", i)
							end

							if key.value.value == "..." then
								if key.type_expression then
									args[i] = VarArg():SetNode(key)
									args[i]:Set(1, analyzer:AnalyzeExpression(key.type_expression, "typesystem"):GetFirstValue())
								end
							elseif key.type_expression then
								args[i] = analyzer:AnalyzeExpression(key.type_expression, "typesystem"):GetFirstValue()
							end
				
							if contracts:Get(i).literal_argument and arguments:Get(i) then
								args[i] = arguments:Get(i)
								args[i].literal_argument = true
								local ok, err = args[i]:IsSubsetOf(contracts:Get(i))
								if not ok then
									return type_errors.other({"argument #", i, " ", arg, ": ", err})
								end
							elseif args[i] then
								analyzer:CreateLocalValue(key, args[i], "typesystem", i)
							end
						end
						
						analyzer:PopPreferTypesystem()
						analyzer:PopScope()
						contract_override = args
					end

					do -- coerce untyped functions to constract callbacks
						for i, arg in ipairs(arguments:GetData()) do
							if arg.Type == "function" then
								if contract_override[i] and contract_override[i].Type == "union" and not contract_override[i].literal_argument then
									local merged = contract_override[i]:ShrinkToFunctionSignature()
									arg:SetArguments(merged:GetArguments())
									arg:SetReturnTypes(merged:GetReturnTypes())
								else
									if not arg.explicit_arguments then
										local contract = contract_override[i] or obj:GetArguments():Get(i)
										if contract and not contract.literal_argument then
											if contract.Type == "union" then
												local tup = Tuple({})
												for _, func in ipairs(contract:GetData()) do
													tup:Merge(func:GetArguments())
													arg:SetArguments(tup)
												end									
											else
												arg:SetArguments(contract:GetArguments())
											end
										end
									end
									if not arg.explicit_return then
										local contract =  contract_override[i] or  obj:GetReturnTypes():Get(i)
										if contract and not contract.literal_argument then
											if contract.Type == "union" then
												local tup = Tuple({})
												for _, func in ipairs(contract:GetData()) do
													tup:Merge(func:GetReturnTypes())
												end
												arg:SetReturnTypes(tup)
											else
												arg:SetReturnTypes(contract:GetReturnTypes())
											end
										end
									end
								end
							end
						end
					end

					for i = 1, len do
						local arg = arguments:Get(i)
						local contract = contract_override[i] or contracts:Get(i)

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
							if contract.Type == "union" then
								local shrunk = contract:ShrinkToFunctionSignature()
								if shrunk then
									contract = contract:ShrinkToFunctionSignature()
								end
							end

							ok, reason = arg:IsSubsetOf(contract)
						end

						if not ok then
							restore_mutated_types(analyzer)
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
							table.insert(analyzer.mutated_types[1], {
								original = original,
								modified = modified,
							})
							arguments:Set(i, modified)
						else
							-- if it's a literal argument we pass the incoming value
							if not contract.literal_argument then
								local t = contract:Copy()
								t:SetContract(contract)
								arguments:Set(i, t)
							end
						end
					end

					return true
				end

				local function check_return_result(self, result, contract, env)

					if env == "typesystem" then
						-- in the typesystem we must not unpack tuples when checking
						local ok, reason, a, b, i = result:IsSubsetOfTupleWithoutExpansion(contract)

						if not ok then
							local _, err = type_errors.subset(a, b, {"return #", i, " '", b, "': ", reason})
							self:Error(b and b:GetNode() or self.current_statement, err)
						end

						return
					end

					local original_contract = contract
					if
						contract:GetLength() == 1 and
						contract:Get(1).Type == "union" and
						contract:Get(1):HasType("tuple")
					then
						contract = contract:Get(1)
					end

					if
						result.Type == "tuple" and
						result:GetLength() == 1 and
						result:Get(1) and
						result:Get(1).Type == "union" and
						result:Get(1):HasType("tuple")
					then
						result = result:Get(1)
					end

					if result.Type == "union" then
						-- typically a function with mutliple uncertain returns

						for _, obj in ipairs(result:GetData()) do
							if obj.Type ~= "tuple" then
								-- if the function returns one value it's not in a tuple
								obj = Tuple({obj}):SetNode(obj:GetNode())
							end

							-- check each tuple in the union
							check_return_result(self, obj, original_contract)
						end
					else
						if contract.Type == "union" then
							local errors = {}

							for _, contract in ipairs(contract:GetData()) do
								local ok, reason = result:IsSubsetOfTuple(contract)

								if ok then
									-- something is ok then just return and don't report any errors found
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
								self:Error(result:GetNode(), reason)
							end
						end
					end
				end

				call_lua_function_with_body = function(self, obj, arguments, function_node, env)
					if obj:HasExplicitArguments() then
						if function_node.kind == "local_generics_type_function" or function_node.kind == "generics_type_function" then
							-- otherwise if we're a type function we just do a simple check and arguments are passed as is
							-- local type foo(T: any) return T end
							-- T becomes the type that is passed in, and not "any"
							-- it's the equivalent of function foo<T extends any>(val: T) { return val }
							
							local ok, reason, a, b, i = arguments:IsSubsetOfTupleWithoutExpansion(obj:GetArguments())

							if not ok then
								if b and b:GetNode() then return type_errors.subset(a, b, {"function argument #", i, " '", b, "': ", reason}) end
								return type_errors.subset(a, b, {"argument #", i, " - ", reason})
							end
						elseif env == "runtime" then
							-- if we have explicit arguments, we need to do a complex check against the contract
							-- this might mutate the arguments
							local ok, err = check_and_setup_arguments(self, arguments, obj:GetArguments(), function_node, obj)
							if not ok then return ok, err end
						end
					end
	
					-- crawl the function with the new arguments
					-- return_result is either a union of tuples or a single tuple
					local return_result, scope = self:AnalyzeFunctionBody(obj, function_node, arguments, env)
					
					restore_mutated_types(self)

					-- used for analyzing side effects
					obj:AddScope(arguments, return_result, scope)

					if not obj:HasExplicitArguments() then
						if not obj.arguments_inferred and function_node.identifiers then
							for i in ipairs(obj:GetArguments():GetData()) do
								if function_node.self_call then
									-- we don't count the actual self argument
									local node = function_node.identifiers[i + 1]
	
									if node and not node.type_expression then
										self:Warning(node, "argument is untyped")
									end
								elseif function_node.identifiers[i] and not function_node.identifiers[i].type_expression then
									self:Warning(function_node.identifiers[i], "argument is untyped")
								end
							end
						end

						obj:GetArguments():Merge(arguments:Slice(1, obj:GetArguments():GetMinimumLength()))
					end

					do -- this is for the emitter
						if function_node.identifiers then
							for i, node in ipairs(function_node.identifiers) do
								node.inferred_type = obj:GetArguments():Get(i)
							end
						end

						function_node.inferred_type = obj
					end

					self:FireEvent("function_spec", obj)

					local return_contract = obj:HasExplicitReturnTypes() and obj:GetReturnTypes()

					-- if the function has return type annotations, analyze them and use it as contract
					if not return_contract and function_node.return_types then
						self:CreateAndPushFunctionScope(obj:GetData().scope, obj:GetData().upvalue_position)
						self:PushPreferTypesystem(true)
						return_contract = Tuple(self:AnalyzeExpressions(function_node.return_types, "typesystem"))
						self:PopPreferTypesystem()
						self:PopScope()
					end

					if not return_contract then
						-- if there is no return type 
						obj:GetReturnTypes():Merge(return_result)

						return return_result
					end		

					-- check against the function's return type
					check_return_result(self, return_result, return_contract, env)

					if env == "typesystem" then
						return return_result
					end

					local contract = obj:GetReturnTypes():Copy()

					for _, v in ipairs(contract:GetData()) do
						if v.Type == "table" then
							v:SetReferenceId(nil)
						end
					end

					-- if a return type is marked with literal, it will pass the literal value back to the caller
					-- a bit like generics
					for i, v in ipairs(return_contract:GetData()) do
						if v.literal_argument then
							contract:Set(i, return_result:Get(i))
						end
					end

					return contract
				end
			end

			local function make_callable_union(analyzer, obj)
				local new_union = obj.New()
				local truthy_union = obj.New()
				local falsy_union = obj.New()
			
				for _, v in ipairs(obj.Data) do
					if v.Type ~= "function" and v.Type ~= "table" and v.Type ~= "any" then
						falsy_union:AddType(v)
						analyzer:ErrorAndCloneCurrentScope(analyzer:GetActiveNode(), {
							"union ",
							obj,
							" contains uncallable object ",
							v,
						}, obj)
					else
						truthy_union:AddType(v)
						new_union:AddType(v)
					end
				end
			
				truthy_union:SetUpvalue(obj:GetUpvalue())
				falsy_union:SetUpvalue(obj:GetUpvalue())
				new_union:SetTruthyUnion(truthy_union)
				new_union:SetFalsyUnion(falsy_union)
				
				return truthy_union:SetNode(analyzer:GetActiveNode()):SetTypeSource(new_union):SetTypeSourceLeft(obj)
			end

			local function Call(analyzer, obj, arguments)
				local env = analyzer:GetPreferTypesystem() and "typesystem" or "runtime"

				if obj.Type == "union" then
					-- make sure the union is callable, we pass the analyzer and 
					-- it will throw errors if the union contains something that is not callable
					-- however it will continue and just remove those values from the union
					obj = make_callable_union(analyzer, obj)
				end

				-- if obj is a tuple it will return its first value 
				obj = obj:GetFirstValue()
				
				local function_node = obj.function_body_node

				if obj.Type ~= "function" then
					if obj.Type == "any" then
						-- it's ok to call any types, it will just return any
						
						-- check arguments that can be mutated
						for _, arg in ipairs(arguments:GetData()) do
							if arg.Type == "table" and arg:GetEnvironment() == "runtime" then
								if arg:GetContract() then
									-- error if we call any with tables that have contracts
									-- since anything might happen to them in an any call
									analyzer:Error(analyzer:GetActiveNode(), {
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
					end

					return obj:Call(analyzer, arguments)
				end
				
				-- mark the object as called so the unreachable code step won't call it
				-- TODO: obj:Set/GetCalled()?
				obj:SetCalled(true)

				local function_arguments = obj:GetArguments()

				-- infer any uncalled functions in the arguments to get their return type
				for i, b in ipairs(arguments:GetData()) do
					if b.Type == "function" and not b:IsCalled() and not b:HasExplicitReturnTypes() then
						local a = function_arguments:Get(i)
						if
							a and
							(a.Type == "function" and not a:GetReturnTypes():IsSubsetOf(b:GetReturnTypes())) or
							not a:IsSubsetOf(b)
						then
							b.arguments_inferred = true
							analyzer:Assert(analyzer:GetActiveNode(), analyzer:Call(b, b:GetArguments():Copy()))
						end
					end
				end

				if obj:GetData().lua_function then
					return call_lua_type_function(
						analyzer,
						obj,
						function_arguments,
						arguments,
						env
					)
				elseif function_node then
					return call_lua_function_with_body(analyzer, obj, arguments, function_node, env)
				end

				return call_type_signature_without_body(analyzer, obj, arguments)
			end

			function META:Call(obj, arguments, call_node)
				-- not sure about this, it's used to access the call_node from deeper calls
				-- without resorting to argument drilling
				self:PushActiveNode(call_node or obj:GetNode())

				-- extra protection, maybe only useful during development
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

				do
					-- setup and track the callstack to avoid infinite loops or callstacks that are too big
					self.call_stack = self.call_stack or {}

					for _, v in ipairs(self.call_stack) do
						-- if the callnode is the same, we're doing some infinite recursion
						if v.obj == obj and v.call_node == self:GetActiveNode() then
							if obj.explicit_return then
								-- so if we have explicit return types, just return those
								return obj:GetReturnTypes():Copy()
							else
								-- if not we sadly have to resort to any
								-- TODO: error?
								-- TODO: use VarArg() ?
								return Tuple({}):AddRemainder(Tuple({Any()}):SetRepeat(math.huge))
							end
						end
					end

					table.insert(
						self.call_stack,
						{
							obj = obj,
							function_node = obj.function_body_node,
							call_node = self:GetActiveNode(),
						}
					)
				end

				local ok, err = Call(self, obj, arguments)

				table.remove(self.call_stack)

				self:PopActiveNode()
				return ok, err
			end
		end,
	}
