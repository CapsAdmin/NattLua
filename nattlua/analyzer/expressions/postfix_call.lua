local table = require("table")
local tostring = tostring
local ipairs = ipairs
local Tuple = require("nattlua.types.tuple").Tuple
local Any = require("nattlua.types.any").Any
return
	{
		AnalyzePostfixCall = function(analyzer, node, env)
			local env = node.type_call and "typesystem" or env
			local callable = analyzer:AnalyzeExpression(node.left, env)
			local self_arg

			if
				analyzer.self_arg_stack and
				node.left.kind == "binary_operator" and
				node.left.value.value == ":"
			then
				self_arg = table.remove(analyzer.self_arg_stack)
			end

			if callable.Type == "tuple" then
				callable = analyzer:Assert(node, callable:Get(1))
			end

			if callable.Type == "symbol" then
				analyzer:Error(node, tostring(node.left:Render()) .. " is " .. tostring(callable:GetData()))
				return Tuple({Any()})
			end

			local types = analyzer:AnalyzeExpressions(node.expressions, env)

			if self_arg then
				table.insert(types, 1, self_arg)
			end

			analyzer:PushPreferTypesystem(
				node.type_call or
				callable:GetNode() and
				(
					callable:GetNode().kind == "local_generics_type_function" or
					callable:GetNode().kind == "generics_type_function"
				)
			)
			local arguments

			if #types == 1 and types[1].Type == "tuple" then
				arguments = types[1]
			else
				local temp = {}

				for i, v in ipairs(types) do
					if v.Type == "tuple" then
						if i == #types then
							table.insert(temp, v)
						else
							local obj = v:Get(1)

							if obj then
								table.insert(temp, obj)
							end
						end
					else
						table.insert(temp, v)
					end
				end

				arguments = Tuple(temp)
			end

			local returned_tuple = analyzer:Assert(node, analyzer:Call(callable, arguments, node))
			analyzer:PopPreferTypesystem()

			if node:IsWrappedInParenthesis() then
				returned_tuple = returned_tuple:Get(1)
			end

			if
				env == "runtime" and
				returned_tuple.Type == "tuple" and
				returned_tuple:GetLength() == 1
			then
				returned_tuple = returned_tuple:Get(1)
			end

			return returned_tuple
		end,
	}
