local ipairs = ipairs
local math = math
local table = _G.table
local debug = debug
local Tuple = require("nattlua.types.tuple").Tuple
local Union = require("nattlua.types.union").Union
local Any = require("nattlua.types.any").Any
return {
	Call = function(META)
		require("nattlua.analyzer.operators.call_analyzer").Call(META)
		require("nattlua.analyzer.operators.call_body").Call(META)
		require("nattlua.analyzer.operators.call_function_signature").Call(META)

		local function make_callable_union(self, obj)
			local truthy_union = obj.New()

			for _, v in ipairs(obj.Data) do
				if v.Type ~= "function" and v.Type ~= "table" and v.Type ~= "any" then
					self:ErrorAndCloneCurrentScope(
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
				end
			end

			truthy_union:SetUpvalue(obj:GetUpvalue())
			return truthy_union
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

				return obj:Call(self, arguments, self:GetCallStack()[1].call_node, true)
			end

			-- mark the object as called so the unreachable code step won't call it
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

						if func.Type == "union" then func = a:GetType("function") end

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
							self:Assert(self:Call(b, func:GetArguments():Copy(nil, true)))
						end
					end
				end
			end

			if obj:GetData().lua_function then
				return self:CallAnalyzerFunction(obj, function_arguments, arguments)
			elseif function_node then
				return self:CallBodyFunction(obj, arguments, function_node)
			end

			return self:CallFunctionSignature(obj, arguments)
		end

		function META:Call(obj, arguments, call_node, not_recursive_call)
			-- extra protection, maybe only useful during development
			if debug.getinfo(300) then
				debug.trace()
				return false, "call stack is too deep"
			end

			-- setup and track the callstack to avoid infinite loops or callstacks that are too big
			self.call_stack = self.call_stack or {}

			if self:IsRuntime() and call_node and not not_recursive_call then
				for _, v in ipairs(self.call_stack) do
					-- if the callnode is the same, we're doing some infinite recursion
					if v.call_node == call_node then
						if obj.explicit_return then
							-- so if we have explicit return types, just return those
							obj.recursively_called = obj:GetReturnTypes():Copy()
							return obj.recursively_called
						else
							-- if not we sadly have to resort to any
							-- TODO: error?
							obj.recursively_called = Tuple({}):AddRemainder(Tuple({Any()}):SetRepeat(math.huge))
							return obj.recursively_called
						end
					end
				end
			end

			table.insert(
				self.call_stack,
				1,
				{
					obj = obj,
					call_node = call_node,
					scope = self:GetScope(),
				}
			)
			local ok, err = Call(self, obj, arguments)
			table.remove(self.call_stack, 1)
			return ok, err
		end

		function META:GetCallStack()
			return self.call_stack or {}
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

			for _, frame in ipairs(self:GetCallStack()) do
				local scope = frame.scope

				if not scope:IsCertain() then
					return false, "call stack scope is uncertain"
				end

				if scope.uncertain_function_return == true then
					return false, "call stack scope has uncertain function return"
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

			for _, frame in ipairs(self:GetCallStack()) do
				local parent_scope = frame.scope

				if
					not parent_scope:IsCertain() or
					parent_scope.uncertain_function_return == true
				then
					if parent_scope:IsCertainFromScope(scope) then return false end
				end
			end

			return true
		end

		function META:UncertainReturn()
			self.call_stack[1].scope:UncertainReturn()
		end
	end,
}
