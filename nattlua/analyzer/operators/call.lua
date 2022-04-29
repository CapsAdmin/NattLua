local ipairs = ipairs
local Union = require("nattlua.types.union").Union
local Any = require("nattlua.types.any").Any
return {
	Call = function(META)
		require("nattlua.analyzer.operators.call_analyzer")(META)
		require("nattlua.analyzer.operators.call_body")(META)
		require("nattlua.analyzer.operators.call_function_signature")(META)

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

		local function call(self, obj, arguments)
			if obj.Type == "union" then
				-- make sure the union is callable, we pass the analyzer and 
				-- it will throw errors if the union contains something that is not callable
				-- however it will continue and just remove those values from the union
				obj = make_callable_union(self, obj)
			end

			-- if obj is a tuple it will return its first value
			-- (myfunc,otherfunc)(1) will always
			obj = obj:GetFirstValue()

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
			elseif obj.function_body_node then
				return self:CallBodyFunction(obj, arguments, obj.function_body_node)
			end

			return self:CallFunctionSignature(obj, arguments)
		end

		function META:Call(obj, arguments, call_node, not_recursive_call)
			local ok, err = self:PushCallFrame(obj, call_node, not_recursive_call)

			if not ok == false then return ok, err end
			if ok then return ok end

			local ok, err = call(self, obj, arguments)

			self:PopCallFrame()

			return ok, err
		end
	end,
}
