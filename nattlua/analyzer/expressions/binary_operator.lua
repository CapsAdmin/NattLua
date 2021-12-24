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

				if left:IsFalsy() and left:IsTruthy() then
					-- if it's uncertain, remove uncertainty while analysing
					if left.Type == "union" then
						left:DisableFalsy()

						if node.left.kind == "binary_operator" then
							local obj = analyzer:AnalyzeExpression(node.left.left)
							analyzer:MutateValue(obj, node.left.right, left)
						end
					end

					right = analyzer:AnalyzeExpression(node.right)

					if analyzer.current_statement.checks and right:GetUpvalue() then
						local checks = analyzer.current_statement.checks[right:GetUpvalue()]

						if checks then
							right = checks[#checks]:GetTruthyUnion()
						end
					end

					if left.Type == "union" then
						left:EnableFalsy()

						if node.left.kind == "binary_operator" then
							local obj = analyzer:AnalyzeExpression(node.left.left)
							analyzer:MutateValue(obj, node.left.right, left)
						end
					end
				elseif left:IsFalsy() and not left:IsTruthy() then
					-- if it's really false do nothing
					right = Nil():SetNode(node.right)
				else
					right = analyzer:AnalyzeExpression(node.right)
				end
			elseif node.value.value == "or" then
				left = analyzer:AnalyzeExpression(node.left)

				if left:IsTruthy() and not left:IsFalsy() then
					right = Nil():SetNode(node.right)
				elseif left:IsFalsy() and not left:IsTruthy() then
					right = analyzer:AnalyzeExpression(node.right)
				else
					right = analyzer:AnalyzeExpression(node.right)
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
