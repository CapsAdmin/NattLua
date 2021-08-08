local ReadAnalyzerFunctionBody = require("nattlua.parser.statements.typesystem.analyzer_function_body").ReadAnalyzerFunctionBody
local ReadIndexExpression = require("nattlua.parser.expressions.index_expression").ReadIndexExpression
return
	{
		ReadAnalyzerFunction = function(parser)
			if not (parser:IsValue("analyzer") and parser:IsValue("function", 1)) then return end
			local node = parser:Node("statement", "analyzer_function")
			node.tokens["analyzer"] = parser:ExpectValue("analyzer")
			node.tokens["function"] = parser:ExpectValue("function")
			local force_upvalue

			if parser:IsValue("^") then
				force_upvalue = true
				node.tokens["^"] = parser:ReadToken()
			end

			node.expression = ReadIndexExpression(parser)

			do -- hacky
				if node.expression.left then
					node.expression.left.standalone_letter = node
					node.expression.left.force_upvalue = force_upvalue
				else
					node.expression.standalone_letter = node
					node.expression.force_upvalue = force_upvalue
				end

				if node.expression.value.value == ":" then
					node.self_call = true
				end
			end

			ReadAnalyzerFunctionBody(parser, node, true)
			return node:End()
		end,
	}
