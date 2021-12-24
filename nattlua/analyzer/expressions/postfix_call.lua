local table = require("table")
local NormalizeTuples = require("nattlua.types.tuple").NormalizeTuples
local Tuple = require("nattlua.types.tuple").Tuple
return
	{
		AnalyzePostfixCall = function(analyzer, node)
			local is_type_call = node.type_call or
				node.left and
				(
					node.left.kind == "local_generics_type_function" or
					node.left.kind == "generics_type_function"
				)
			
			analyzer:PushAnalyzerEnvironment(is_type_call and "typesystem" or "runtime")
			
			local callable = analyzer:AnalyzeExpression(node.left)
			local self_arg

			if
				analyzer.self_arg_stack and
				node.left.kind == "binary_operator" and
				node.left.value.value == ":"
			then
				self_arg = table.remove(analyzer.self_arg_stack)
			end

			local types = analyzer:AnalyzeExpressions(node.expressions)

			if self_arg then
				table.insert(types, 1, self_arg)
			end

			local arguments
			
			if analyzer:IsTypesystem() then
				arguments = Tuple(types)
			else
				arguments = NormalizeTuples(types)
			end

			local returned_tuple = analyzer:Assert(node, analyzer:Call(callable, arguments, node))

			-- TUPLE UNPACK MESS
			
			if node.tokens["("] and node.tokens[")"] then
				returned_tuple = returned_tuple:Get(1)
			end

			analyzer:PopAnalyzerEnvironment()

			return returned_tuple
		end,
	}
