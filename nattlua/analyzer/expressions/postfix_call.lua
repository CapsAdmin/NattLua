local table = require("table")
local NormalizeTuples = require("nattlua.types.tuple").NormalizeTuples
return
	{
		AnalyzePostfixCall = function(analyzer, node, env)
			local is_type_call = node.type_call or
				node.left and
				(
					node.left.kind == "local_generics_type_function" or
					node.left.kind == "generics_type_function"
				)
			local env = is_type_call and "typesystem" or env
			
			local callable = analyzer:AnalyzeExpression(node.left, env)
			local self_arg

			if
				analyzer.self_arg_stack and
				node.left.kind == "binary_operator" and
				node.left.value.value == ":"
			then
				self_arg = table.remove(analyzer.self_arg_stack)
			end

			local types = analyzer:AnalyzeExpressions(node.expressions, env)

			if self_arg then
				table.insert(types, 1, self_arg)
			end

			analyzer:PushPreferTypesystem(is_type_call)
		
			local returned_tuple = analyzer:Assert(node, analyzer:Call(callable, NormalizeTuples(types), node))
			analyzer:PopPreferTypesystem()

			-- TUPLE UNPACK MESS
			
			if node:IsWrappedInParenthesis() then
				returned_tuple = returned_tuple:Get(1)
			end


			return returned_tuple
		end,
	}
