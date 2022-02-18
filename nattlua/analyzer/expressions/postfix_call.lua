local table = require("table")
local NormalizeTuples = require("nattlua.types.tuple").NormalizeTuples
local Tuple = require("nattlua.types.tuple").Tuple
return {
	AnalyzePostfixCall = function(self, node)
		local is_type_call = node.type_call or
			node.left and
			(
				node.left.kind == "local_generics_type_function" or
				node.left.kind == "generics_type_function"
			)
		self:PushAnalyzerEnvironment(is_type_call and "typesystem" or "runtime")
		local callable = self:AnalyzeExpression(node.left)
		local self_arg

		if
			self.self_arg_stack and
			node.left.kind == "binary_operator" and
			node.left.value.value == ":"
		then
			self_arg = table.remove(self.self_arg_stack)
		end

		local types = self:AnalyzeExpressions(node.expressions)

		if self_arg then table.insert(types, 1, self_arg) end

		local arguments

		if self:IsTypesystem() then
			arguments = Tuple(types)
		else
			arguments = NormalizeTuples(types)
		end

		local returned_tuple = self:Assert(node, self:Call(callable, arguments, node))

		-- TUPLE UNPACK MESS
		if node.tokens["("] and node.tokens[")"] and returned_tuple.Type == "tuple" then
			returned_tuple = returned_tuple:Get(1)
		end

		if self:IsTypesystem() then
			if returned_tuple.Type == "tuple" and returned_tuple:GetLength() == 1 then
				returned_tuple = returned_tuple:Get(1)
			end
		end

		self:PopAnalyzerEnvironment()
		return returned_tuple
	end,
}
