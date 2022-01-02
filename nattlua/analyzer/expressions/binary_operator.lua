local table = require("table")
local Binary = require("nattlua.analyzer.operators.binary").Binary
local Nil = require("nattlua.types.symbol").Nil
local assert = _G.assert
return
	{
		AnalyzeBinaryOperator = function(analyzer, node)
			local left
			local right

			if node.value.value == "and" then
				left = analyzer:AnalyzeExpression(node.left)
		
				if left:IsCertainlyFalse() then
					right = Nil():SetNode(node.right)
				else
					local obj, key
					-- if index is uncertain, we need to temporary mutate the value
					if left.Type == "union" and node.left.kind == "binary_operator" and node.left.value.value == "." then
						obj = analyzer:AnalyzeExpression(node.left.left)
						key = analyzer:AnalyzeExpression(node.left.right)
						analyzer:MutateValue(obj, key, left:Copy():DisableFalsy())
					end

					-- right hand side of and is the "true" part
					analyzer:PushTruthyExpressionContext()
					right = analyzer:AnalyzeExpression(node.right)
					analyzer:PopTruthyExpressionContext()

					if obj and key then
						analyzer:MutateValue(obj, key, left:Copy())
					end
				end
			elseif node.value.value == "or" then
				analyzer:PushFalsyExpressionContext()
				left = analyzer:AnalyzeExpression(node.left)
				analyzer:PopFalsyExpressionContext()
				
				if left:IsCertainlyFalse() then
					analyzer:PushFalsyExpressionContext()
					right = analyzer:AnalyzeExpression(node.right)
					analyzer:PopFalsyExpressionContext()
				elseif left:IsCertainlyTrue() then
					right = Nil():SetNode(node.right)
				else
					-- right hand side of or is the "false" part
					analyzer:PushFalsyExpressionContext()
					right = analyzer:AnalyzeExpression(node.right)
					analyzer:PopFalsyExpressionContext()
				end
			else
				left = analyzer:AnalyzeExpression(node.left)
				right = analyzer:AnalyzeExpression(node.right)
			end

			assert(left)
			assert(right)

			-- TODO: more elegant way of dealing with self?
			if node.value.value == ":" then
				analyzer.self_arg_stack = analyzer.self_arg_stack or {}
				table.insert(analyzer.self_arg_stack, left)
			end

			return analyzer:Assert(node, Binary(analyzer, node, left, right))
		end,
	}
