local table = _G.table
local math_huge = _G.math.huge
local ipairs = _G.ipairs
local Union = require("nattlua.types.union").Union
local Tuple = require("nattlua.types.tuple").Tuple
local Nil = require("nattlua.types.symbol").Nil
local AnalyzeImport = require("nattlua.analyzer.expressions.import").AnalyzeImport

local function normalize_tuples(self, callable, types)
	local is_typesystem = self:IsTypesystem()

	if
		#types == 1 and
		types[1].Type == "tuple" and
		(
			not is_typesystem or
			callable:GetInputSignature():GetTupleLength() == math_huge
		)
	then
		return types[1]
	end

	if is_typesystem then return Tuple(types) end

	local temp = {}
	local temp_i = 1

	for i, v in ipairs(types) do
		if v.Type == "tuple" then
			if i == #types then
				temp[temp_i] = v
				temp_i = temp_i + 1
			else
				local obj = v:GetWithNumber(1)

				if obj then
					temp[temp_i] = obj
					temp_i = temp_i + 1
				end
			end
		else
			temp[temp_i] = v
			temp_i = temp_i + 1
		end
	end

	if #temp == 1 and temp[1].Type ~= "tuple" and temp[1].Type ~= "union" then
		return Tuple({temp[1]})
	end

	local arguments = Tuple(temp)
	temp = {}

	for i = 1, 128 do
		local v, is_inf = arguments:GetAtTupleIndex(i)

		if v and v.Type == "tuple" or is_inf then
			-- inf tuple
			temp[i] = v or Any()

			break
		end

		if not v then break end

		temp[i] = v
	end

	return Tuple(temp)
end

local function postfix_call(self, self_arg, node, callable)
	local types = {self_arg}
	self:AnalyzeExpressions(node.expressions, types)
	local arguments = normalize_tuples(self, callable, types)
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
			not node.left.value:ValueEquals("dofile") and
			not node.left.value:ValueEquals("loadfile")
		then
			return AnalyzeImport(self, node, node.left.value:ValueEquals("require") and node.path)
		end

		self:PushAnalyzerEnvironment(node.type_call and "typesystem" or "runtime")
		local callable = self:Assert(self:AnalyzeExpression(node.left))
		local self_arg

		if
			self.self_arg_stack and
			node.left.Type == "expression_binary_operator" and
			node.left.value:ValueEquals(":")
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
