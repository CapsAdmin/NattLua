local ipairs = ipairs
local type = type
local math = math
local table = _G.table
local tostring = tostring
local debug = debug
local print = print
local string = _G.string
local VarArg = require("nattlua.types.tuple").VarArg
local Tuple = require("nattlua.types.tuple").Tuple
local Table = require("nattlua.types.table").Table
local Union = require("nattlua.types.union").Union
local Nil = require("nattlua.types.symbol").Nil
local Any = require("nattlua.types.any").Any
local Function = require("nattlua.types.function").Function
local LString = require("nattlua.types.string").LString
local LNumber = require("nattlua.types.number").LNumber
local Symbol = require("nattlua.types.symbol").Symbol
local type_errors = require("nattlua.types.error_messages")
local unpack_union_tuples

do
	local ipairs = ipairs

	local function should_expand(arg, contract)
		local b = arg.Type == "union"

		if contract.Type == "any" then b = false end

		if contract.Type == "union" then b = false end

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
				if i == arg_length then ys[i] = ys[i] + 1 end

				if ys[i] > lengths[i] then
					ys[i] = 1
					ys[i - 1] = ys[i - 1] + 1
				end
			end
		end

		return out
	end
end

return {
	Call = function(META)
		function META:LuaTypesToTuple(node, tps)
			local tbl = {}

			for i, v in ipairs(tps) do
				if type(v) == "table" and v.Type ~= nil then
					tbl[i] = v

					if not v:GetNode() then v:SetNode(node) end
				else
					if type(v) == "function" then
						tbl[i] = Function(
							{
								lua_function = v,
								arg = Tuple({}):AddRemainder(Tuple({Any()}):SetRepeat(math.huge)),
								ret = Tuple({}):AddRemainder(Tuple({Any()}):SetRepeat(math.huge)),
							}
						):SetNode(node):SetLiteral(true)

						if node.statements then tbl[i].function_body_node = node end
					else
						local t = type(v)

						if t == "number" then
							tbl[i] = LNumber(v):SetNode(node)
						elseif t == "string" then
							tbl[i] = LString(v):SetNode(node)
						elseif t == "boolean" then
							tbl[i] = Symbol(v):SetNode(node)
						elseif t == "table" then
							local tbl = Table()

							for _, val in ipairs(v) do
								tbl:Insert(val)
							end

							tbl:SetContract(tbl)
							return tbl
						else
							if node then print(node:Render(), "!") end

							self:Print(t)
							error(debug.traceback("NYI " .. t))
						end
					end
				end
			end

			if tbl[1] and tbl[1].Type == "tuple" and #tbl == 1 then return tbl[1] end

			return Tuple(tbl)
		end

		function META:AnalyzeFunctionBody(obj, function_node, arguments)
			local scope = self:CreateAndPushFunctionScope(obj:GetData().scope, obj:GetData().upvalue_position)
			self:PushGlobalEnvironment(
				function_node,
				self:GetDefaultEnvironment(self:GetCurrentAnalyzerEnvironment()),
				self:GetCurrentAnalyzerEnvironment()
			)

			if function_node.self_call then
				self:CreateLocalValue("self", arguments:Get(1) or Nil():SetNode(function_node))
			end

			for i, identifier in ipairs(function_node.identifiers) do
				local argi = function_node.self_call and (i + 1) or i

				if self:IsTypesystem() then
					self:CreateLocalValue(identifier.value.value, arguments:GetWithoutExpansion(argi))
				end

				if self:IsRuntime() then
					if identifier.value.value == "..." then
						self:CreateLocalValue(identifier.value.value, arguments:Slice(argi))
					else
						self:CreateLocalValue(identifier.value.value, arguments:Get(argi) or Nil():SetNode(identifier))
					end
				end
			end

			if
				function_node.kind == "local_type_function" or
				function_node.kind == "type_function"
			then
				self:PushAnalyzerEnvironment("typesystem")
			end

			local analyzed_return = self:AnalyzeStatementsAndCollectReturnTypes(function_node)

			if
				function_node.kind == "local_type_function" or
				function_node.kind == "type_function"
			then
				self:PopAnalyzerEnvironment()
			end

			self:PopGlobalEnvironment(self:GetCurrentAnalyzerEnvironment())
			local function_scope = self:PopScope()

			if scope.TrackedObjects then
				for _, obj in ipairs(scope.TrackedObjects) do
					if obj.Type == "upvalue" then
						for i = #obj.mutations, 1, -1 do
							local mut = obj.mutations[i]

							if mut.from_tracking then table.remove(obj.mutations, i) end
						end
					else
						for _, mutations in pairs(obj.mutations) do
							for i = #mutations, 1, -1 do
								local mut = mutations[i]

								if mut.from_tracking then table.remove(mutations, i) end
							end
						end
					end
				end
			end

			if analyzed_return.Type ~= "tuple" then
				return Tuple({analyzed_return}):SetNode(analyzed_return:GetNode()), scope
			end

			return analyzed_return, scope
		end

		local function call_analyzer_function(self, obj, function_arguments, arguments)
			do
				local ok, reason, a, b, i = arguments:IsSubsetOfTuple(obj:GetArguments())

				if not ok then
					if b and b:GetNode() then
						return type_errors.subset(a, b, {"function argument #", i, " '", b, "': ", reason})
					end

					return type_errors.subset(a, b, {"argument #", i, " - ", reason})
				end
			end

			local len = function_arguments:GetLength()

			if len == math.huge and arguments:GetLength() == math.huge then
				len = math.max(function_arguments:GetMinimumLength(), arguments:GetMinimumLength())
			end

			if self:IsTypesystem() then
				local ret = self:LuaTypesToTuple(
					obj:GetNode(),
					{
						self:CallLuaTypeFunction(
							self:GetActiveNode(),
							obj:GetData().lua_function,
							obj:GetData().scope or self:GetScope(),
							arguments:UnpackWithoutExpansion()
						),
					}
				)
				return ret
			end

			local tuples = {}

			for i, arg in ipairs(unpack_union_tuples(obj, {arguments:Unpack(len)}, function_arguments)) do
				tuples[i] = self:LuaTypesToTuple(
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
				if tuple:GetUnpackable() or tuple:GetLength() == math.huge then
					return tuple
				end
			end

			for _, tuple in ipairs(tuples) do
				for i = 1, tuple:GetLength() do
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

			return ret
		end

		local function call_type_signature_without_body(self, obj, arguments)
			do
				local ok, reason, a, b, i = arguments:IsSubsetOfTuple(obj:GetArguments())

				if not ok then
					if b and b:GetNode() then
						return type_errors.subset(a, b, {"function argument #", i, " '", b, "': ", reason})
					end

					return type_errors.subset(a, b, {"argument #", i, " - ", reason})
				end
			end

			for i, arg in ipairs(arguments:GetData()) do
				if arg.Type == "table" and arg:GetAnalyzerEnvironment() == "runtime" then
					if self.config.external_mutation then
						self:Warning(
							self:GetActiveNode(),
							{
								"argument #",
								i,
								" ",
								arg,
								" can be mutated by external call",
							}
						)
					end
				end
			end

			local ret = obj:GetReturnTypes():Copy()

			-- clear any reference id from the returned arguments
			for _, v in ipairs(ret:GetData()) do
				if v.Type == "table" then v:SetReferenceId(nil) end
			end

			return ret
		end

		local call_lua_function_with_body

		do
			local function mutate_type(self, i, arg, contract, arguments)
				local env = self:GetScope():GetNearestFunctionScope()
				env.mutated_types = env.mutated_types or {}
				arg:PushContract(contract)
				arg.argument_index = i
				table.insert(env.mutated_types, arg)
				arguments:Set(i, arg)
			end

			local function restore_mutated_types(self)
				local env = self:GetScope():GetNearestFunctionScope()

				if not env.mutated_types or not env.mutated_types[1] then return end

				for _, arg in ipairs(env.mutated_types) do
					arg:PopContract()
					arg.argument_index = nil
					self:MutateUpvalue(arg:GetUpvalue(), arg)
				end

				env.mutated_types = {}
			end

			local function check_and_setup_arguments(self, arguments, contracts, function_node, obj)
				local len = contracts:GetSafeLength(arguments)
				local contract_override = {}

				do -- analyze the type expressions
					self:CreateAndPushFunctionScope(obj:GetData().scope, obj:GetData().upvalue_position)
					self:PushAnalyzerEnvironment("typesystem")
					local args = {}

					for i, key in ipairs(function_node.identifiers) do
						if function_node.self_call then i = i + 1 end

						-- stem type so that we can allow
						-- function(x: foo<|x|>): nil
						self:CreateLocalValue(key.value.value, Any())
						local arg = arguments:Get(i)
						local contract = contracts:Get(i)

						if not arg then
							arg = Nil()
							arguments:Set(i, arg)
						end

						if contract and contract.ref_argument and arg then
							self:CreateLocalValue(key.value.value, arg)
						end

						if key.type_expression then
							args[i] = self:AnalyzeExpression(key.type_expression):GetFirstValue()
						end

						if contract and contract.ref_argument and arg then
							args[i] = arg
							args[i].ref_argument = true
							local ok, err = args[i]:IsSubsetOf(contract)

							if not ok then
								return type_errors.other({"argument #", i, " ", arg, ": ", err})
							end
						elseif args[i] then
							self:CreateLocalValue(key.value.value, args[i])
						end

						if not self.processing_deferred_calls then
							if contract and contract.literal_argument and arg and not arg:IsLiteral() then
								return type_errors.other({"argument #", i, " ", arg, ": not literal"})
							end
						end
					end

					self:PopAnalyzerEnvironment()
					self:PopScope()
					contract_override = args
				end

				do -- coerce untyped functions to constract callbacks
					for i, arg in ipairs(arguments:GetData()) do
						if arg.Type == "function" then
							if
								contract_override[i] and
								contract_override[i].Type == "union" and
								not contract_override[i].ref_argument
							then
								local merged = contract_override[i]:ShrinkToFunctionSignature()

								if merged then
									arg:SetArguments(merged:GetArguments())
									arg:SetReturnTypes(merged:GetReturnTypes())
								end
							else
								if not arg.explicit_arguments then
									local contract = contract_override[i] or obj:GetArguments():Get(i)

									if contract and not contract.ref_argument then
										if contract.Type == "union" then
											local tup = Tuple({})

											for _, func in ipairs(contract:GetData()) do
												tup:Merge(func:GetArguments())
												arg:SetArguments(tup)
											end
										elseif contract.Type == "function" then
											arg:SetArguments(contract:GetArguments():Copy(nil, true)) -- force copy tables so we don't mutate the contract
										end
									end
								end

								if not arg.explicit_return then
									local contract = contract_override[i] or obj:GetReturnTypes():Get(i)

									if contract and not contract.ref_argument then
										if contract.Type == "union" then
											local tup = Tuple({})

											for _, func in ipairs(contract:GetData()) do
												tup:Merge(func:GetReturnTypes())
											end

											arg:SetReturnTypes(tup)
										elseif contract.Type == "function" then
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

							if shrunk then contract = contract:ShrinkToFunctionSignature() end
						end

						if arg.Type == "function" and contract.Type == "function" then
							ok, reason = arg:IsCallbackSubsetOf(contract)
						else
							ok, reason = arg:IsSubsetOf(contract)
						end
					end

					if not ok then
						restore_mutated_types(self)
						return type_errors.other({"argument #", i, " ", arg, ": ", reason})
					end

					if
						arg.Type == "table" and
						contract.Type == "table" and
						arg:GetUpvalue() and
						not contract.ref_argument
					then
						mutate_type(self, i, arg, contract, arguments)
					else
						-- if it's a literal argument we pass the incoming value
						if not contract.ref_argument then
							local t = contract:Copy()
							t:SetContract(contract)
							arguments:Set(i, t)
						end
					end
				end

				return true
			end

			local function check_return_result(self, result, contract)
				if self:IsTypesystem() then
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

						if not ok then self:Error(result:GetNode(), reason) end
					end
				end
			end

			call_lua_function_with_body = function(self, obj, arguments, function_node)
				if obj:HasExplicitArguments() or function_node.identifiers_typesystem then
					if
						function_node.kind == "local_type_function" or
						function_node.kind == "type_function"
					then
						if function_node.identifiers_typesystem then
							local call_expression = self:GetActiveNode()

							for i, key in ipairs(function_node.identifiers) do
								if function_node.self_call then i = i + 1 end

								local arg = arguments:Get(i)
								local generic_upvalue = function_node.identifiers_typesystem and
									function_node.identifiers_typesystem[i] or
									nil
								local generic_type = call_expression.expressions_typesystem and
									call_expression.expressions_typesystem[i] or
									nil

								if generic_upvalue then
									local T = self:AnalyzeExpression(generic_type)
									self:CreateLocalValue(generic_upvalue.value.value, T)
								end
							end

							local ok, err = check_and_setup_arguments(self, arguments, obj:GetArguments(), function_node, obj)

							if not ok then return ok, err end
						end

						-- otherwise if we're a analyzer function we just do a simple check and arguments are passed as is
						-- local type foo(T: any) return T end
						-- T becomes the type that is passed in, and not "any"
						-- it's the equivalent of function foo<T extends any>(val: T) { return val }
						local ok, reason, a, b, i = arguments:IsSubsetOfTupleWithoutExpansion(obj:GetArguments())

						if not ok then
							if b and b:GetNode() then
								return type_errors.subset(a, b, {"function argument #", i, " '", b, "': ", reason})
							end

							return type_errors.subset(a, b, {"argument #", i, " - ", reason})
						end
					elseif self:IsRuntime() then
						-- if we have explicit arguments, we need to do a complex check against the contract
						-- this might mutate the arguments
						local ok, err = check_and_setup_arguments(self, arguments, obj:GetArguments(), function_node, obj)

						if not ok then return ok, err end
					end
				end

				-- crawl the function with the new arguments
				-- return_result is either a union of tuples or a single tuple
				local return_result, scope = self:AnalyzeFunctionBody(obj, function_node, arguments)
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
							elseif
								function_node.identifiers[i] and
								not function_node.identifiers[i].type_expression
							then
								self:Warning(function_node.identifiers[i], "argument is untyped")
							end
						end
					end

					obj:GetArguments():Merge(arguments:Slice(1, obj:GetArguments():GetMinimumLength()))
				end

				do -- this is for the emitter
					if function_node.identifiers then
						for i, node in ipairs(function_node.identifiers) do
							node:AddType(obj:GetArguments():Get(i))
						end
					end

					function_node:AddType(obj)
				end

				local return_contract = obj:HasExplicitReturnTypes() and obj:GetReturnTypes()

				-- if the function has return type annotations, analyze them and use it as contract
				if not return_contract and function_node.return_types and self:IsRuntime() then
					self:CreateAndPushFunctionScope(obj:GetData().scope, obj:GetData().upvalue_position)
					self:PushAnalyzerEnvironment("typesystem")

					for i, key in ipairs(function_node.identifiers) do
						if function_node.self_call then i = i + 1 end

						self:CreateLocalValue(key.value.value, arguments:Get(i))
					end

					return_contract = Tuple(self:AnalyzeExpressions(function_node.return_types))
					self:PopAnalyzerEnvironment()
					self:PopScope()
				end

				if not return_contract then
					-- if there is no return type 
					if self:IsRuntime() then
						local copy

						for i, v in ipairs(return_result:GetData()) do
							if v.Type == "table" and not v:GetContract() then
								copy = copy or return_result:Copy()
								local tbl = Table()

								for _, kv in ipairs(v:GetData()) do
									tbl:Set(kv.key, self:GetMutatedTableValue(v, kv.key, kv.val))
								end

								copy:Set(i, tbl)
							end
						end

						obj:GetReturnTypes():Merge(copy or return_result)
					end

					return return_result
				end

				-- check against the function's return type
				check_return_result(self, return_result, return_contract)

				if self:IsTypesystem() then return return_result end

				local contract = obj:GetReturnTypes():Copy()

				for _, v in ipairs(contract:GetData()) do
					if v.Type == "table" then v:SetReferenceId(nil) end
				end

				-- if a return type is marked with literal, it will pass the literal value back to the caller
				-- a bit like generics
				for i, v in ipairs(return_contract:GetData()) do
					if v.ref_argument then contract:Set(i, return_result:Get(i)) end
				end

				return contract
			end
		end

		local function make_callable_union(self, obj)
			local new_union = obj.New()
			local truthy_union = obj.New()
			local falsy_union = obj.New()

			for _, v in ipairs(obj.Data) do
				if v.Type ~= "function" and v.Type ~= "table" and v.Type ~= "any" then
					falsy_union:AddType(v)
					self:ErrorAndCloneCurrentScope(
						self:GetActiveNode(),
						{
							"union ",
							obj,
							" contains uncallable object ",
							v,
						},
						obj
					)
				else
					truthy_union:AddType(v)
					new_union:AddType(v)
				end
			end

			truthy_union:SetUpvalue(obj:GetUpvalue())
			falsy_union:SetUpvalue(obj:GetUpvalue())
			return truthy_union:SetNode(self:GetActiveNode())
		end

		local function Call(self, obj, arguments)
			if obj.Type == "union" then
				-- make sure the union is callable, we pass the analyzer and 
				-- it will throw errors if the union contains something that is not callable
				-- however it will continue and just remove those values from the union
				obj = make_callable_union(self, obj)
			end

			-- if obj is a tuple it will return its first value 
			obj = obj:GetFirstValue()
			local function_node = obj.function_body_node

			if obj.Type ~= "function" then
				if obj.Type == "any" then
					-- it's ok to call any types, it will just return any
					-- check arguments that can be mutated
					for _, arg in ipairs(arguments:GetData()) do
						if arg.Type == "table" and arg:GetAnalyzerEnvironment() == "runtime" then
							if arg:GetContract() then
								-- error if we call any with tables that have contracts
								-- since anything might happen to them in an any call
								self:Error(
									self:GetActiveNode(),
									{
										"cannot mutate argument with contract ",
										arg:GetContract(),
									}
								)
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

				return obj:Call(self, arguments)
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
						(
							(
								a.Type == "function" and
								not a:GetReturnTypes():IsSubsetOf(b:GetReturnTypes())
							)
							or
							not a:IsSubsetOf(b)
						)
					then
						local func = a

						if func.Type == "union" then
							func = a:GetType("function")
						end

						b.arguments_inferred = true
						-- TODO: callbacks with ref arguments should not be called
						-- mixed ref args make no sense, maybe ref should be a keyword for the function instead?
						local has_ref_arg = false

						for k, v in ipairs(b:GetArguments():GetData()) do
							if v.ref_argument then
								has_ref_arg = true

								break
							end
						end

						if not has_ref_arg then
							self:Assert(self:GetActiveNode(), self:Call(b, func:GetArguments():Copy(nil, true)))
						end
					end
				end
			end

			if obj.expand then self:GetActiveNode().expand = obj end

			if obj:GetData().lua_function then
				return call_analyzer_function(self, obj, function_arguments, arguments)
			elseif function_node then
				return call_lua_function_with_body(self, obj, arguments, function_node)
			end

			return call_type_signature_without_body(self, obj, arguments)
		end

		function META:Call(obj, arguments, call_node)
			-- not sure about this, it's used to access the call_node from deeper calls
			-- without resorting to argument drilling
			local node = call_node or obj:GetNode() or obj

			-- call_node or obj:GetNode() might be nil when called from tests and other places
			if node.recursively_called then return node.recursively_called:Copy() end

			self:PushActiveNode(node)

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

			-- setup and track the callstack to avoid infinite loops or callstacks that are too big
			self.call_stack = self.call_stack or {}

			if self:IsRuntime() then
				for _, v in ipairs(self.call_stack) do
					-- if the callnode is the same, we're doing some infinite recursion
					if v.call_node == self:GetActiveNode() then
						if obj.explicit_return then
							-- so if we have explicit return types, just return those
							node.recursively_called = obj:GetReturnTypes():Copy()
							return node.recursively_called
						else
							-- if not we sadly have to resort to any
							-- TODO: error?
							-- TODO: use VarArg() ?
							node.recursively_called = Tuple({}):AddRemainder(Tuple({Any()}):SetRepeat(math.huge))
							return node.recursively_called
						end
					end
				end
			end

			table.insert(
				self.call_stack,
				{
					obj = obj,
					function_node = obj.function_body_node,
					call_node = self:GetActiveNode(),
					scope = self:GetScope(),
				}
			)
			local ok, err = Call(self, obj, arguments)
			table.remove(self.call_stack)
			self:PopActiveNode()
			return ok, err
		end

		function META:IsDefinetlyReachable()
			local scope = self:GetScope()
			local function_scope = scope:GetNearestFunctionScope()

			if not scope:IsCertain() then return false, "scope is uncertain" end

			if function_scope.uncertain_function_return == true then
				return false, "uncertain function return"
			end

			if function_scope.lua_silent_error then
				for _, scope in ipairs(function_scope.lua_silent_error) do
					if not scope:IsCertain() then
						return false, "parent function scope can throw an error"
					end
				end
			end

			if self.call_stack then
				for i = #self.call_stack, 1, -1 do
					local scope = self.call_stack[i].scope

					if not scope:IsCertain() then
						return false, "call stack scope is uncertain"
					end

					if scope.uncertain_function_return == true then
						return false, "call stack scope has uncertain function return"
					end
				end
			end

			return true
		end

		function META:IsMaybeReachable()
			local scope = self:GetScope()
			local function_scope = scope:GetNearestFunctionScope()

			if function_scope.lua_silent_error then
				for _, scope in ipairs(function_scope.lua_silent_error) do
					if not scope:IsCertain() then return false end
				end
			end

			if self.call_stack then
				for i = #self.call_stack, 1, -1 do
					local parent_scope = self.call_stack[i].scope

					if
						not parent_scope:IsCertain() or
						parent_scope.uncertain_function_return == true
					then
						if parent_scope:IsCertainFromScope(scope) then return false end
					end
				end
			end

			return true
		end

		function META:UncertainReturn()
			self.call_stack[#self.call_stack].scope:UncertainReturn()
		end
	end,
}
