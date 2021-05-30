local generics_type_function_body = require("nattlua.parser.statements.typesystem.function_generics_body").ReadFunctionGenericsBody
local function_body = require("nattlua.parser.statements.function_body").ReadFunctionBody
local index_expression = require("nattlua.parser.expressions.index_expression").ReadIndexExpression
return
	{
		ReadFunction = function(self)
			if not self:IsValue("function") then return end
			local node = self:Node("statement", "function")
			node.tokens["function"] = self:ReadValue("function")
			node.expression = index_expression(self)

			if node.expression.kind == "binary_operator" then
				node.self_call = node.expression.right.self_call
			end

			if self:IsValue("<|") then
				node.kind = "generics_type_function"
				generics_type_function_body(self, node)
			else
				function_body(self, node)
			end

			return node:End()
		end,
	}
