local generics_type_function_body = require("nattlua.parser.statements.typesystem.function_generics_body")
local function_body = require("nattlua.parser.statements.function_body")
local index_expression = require("nattlua.parser.expressions.index_expression")
return function(self)
	if not self:IsCurrentValue("function") then return end
	local node = self:Statement("function")
	node.tokens["function"] = self:ReadValue("function")
	node.expression = index_expression(self)

	if node.expression.kind == "binary_operator" then
		node.self_call = node.expression.right.self_call
	end

	if self:IsCurrentValue("<|") then
		node.kind = "generics_type_function"
		generics_type_function_body(self, node)
	else
		function_body(self, node)
	end

	return node:End()
end
