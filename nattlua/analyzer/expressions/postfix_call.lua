local table = _G.table
local NormalizeTuples = require("nattlua.types.tuple").NormalizeTuples
local Union = require("nattlua.types.union").Union
local Tuple = require("nattlua.types.tuple").Tuple
local Nil = require("nattlua.types.symbol").Nil
local AnalyzeImport = require("nattlua.analyzer.expressions.import").AnalyzeImport

local function postfix_call(self, self_arg, node, callable)
	local types = {self_arg}
	self:AnalyzeExpressions(node.expressions, types)
	local arguments

	if self:IsTypesystem() then
		if
			#types == 1 and
			types[1].Type == "tuple" and
			callable:GetInputSignature():GetTupleLength() == math.huge
		then
			arguments = types[1]
		else
			arguments = Tuple(types)
		end
	else
		arguments = NormalizeTuples(types)
	end

	self:PushCurrentExpression(node)
	local ret, err = self:Call(callable, arguments, node)
	self:PopCurrentExpression()

	if not ret then
		self:Error(err)

		if callable.Type == "function" and callable:IsExplicitOutputSignature() then
			return callable:GetOutputSignature():Copy()
		end
	end

	return ret, err
end

return {
	AnalyzePostfixCall = function(self, node)
		if
			node.import_expression and
			node.left.value.value ~= "dofile" and
			node.left.value.value ~= "loadfile"
		then
			return AnalyzeImport(self, node, node.left.value.value == "require" and node.path)
		end

		self:PushAnalyzerEnvironment(node.type_call and "typesystem" or "runtime")
		local callable = self:Assert(self:AnalyzeExpression(node.left))
		local self_arg

		if
			self.self_arg_stack and
			node.left.Type == "expression_binary_operator" and
			node.left.value.value == ":"
		then
			self_arg = table.remove(self.self_arg_stack)

			if self:IsRuntime() then self_arg = self:GetFirstValue(self_arg) end
		end

		local returned_tuple

		if self_arg and self_arg.Type == "union" then
			for _, self_arg in ipairs(self_arg:GetData()) do
				local tup = postfix_call(self, self_arg, node, callable)

				if tup then
					local s = self:GetFirstValue(tup)

					if s and s.IsEmpty and not s:IsEmpty() then
						if returned_tuple then returned_tuple:AddType(s) end

						returned_tuple = returned_tuple or Union({s})
					end
				end
			end
		end

		if not returned_tuple then
			local val, err = postfix_call(self, self_arg, node, callable)

			if not val then return val, err end

			returned_tuple = val
		end

		self:PopAnalyzerEnvironment()

		-- TUPLE UNPACK MESS
		if node.tokens["("] and node.tokens[")"] and returned_tuple.Type == "tuple" then
			returned_tuple = returned_tuple:GetWithNumber(1)
		end

		if self:IsTypesystem() then
			if
				returned_tuple and
				returned_tuple.Type == "tuple" and
				returned_tuple:HasOneValue()
			then
				returned_tuple = returned_tuple:GetWithNumber(1)
			end
		end

		return returned_tuple
	end,
}
