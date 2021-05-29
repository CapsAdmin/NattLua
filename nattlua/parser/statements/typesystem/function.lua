local ReadFunctionBody = require("nattlua.parser.statements.typesystem.function_body").ReadFunctionBody
local ReadIndexExpression = require("nattlua.parser.expressions.index_expression").ReadIndexExpression
return
	{
		ReadFunction = function(parser)
			if not (parser:IsCurrentValue("type") and parser:IsValue("function", 1)) then return end
			local node = parser:Node("statement", "type_function")
			node.tokens["type"] = parser:ReadValue("type")
			node.tokens["function"] = parser:ReadValue("function")
			local force_upvalue

			if parser:IsCurrentValue("^") then
				force_upvalue = true
				node.tokens["^"] = parser:ReadTokenLoose()
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

			ReadFunctionBody(parser, node, true)
			return node
		end,
	}
