local tostring = tostring
local table = _G.table
local Union = require("nattlua.types.union").Union
local Any = require("nattlua.types.any").Any
local Tuple = require("nattlua.types.tuple").Tuple
local Function = require("nattlua.types.function").Function
local Any = require("nattlua.types.any").Any
local VarArg = require("nattlua.types.tuple").VarArg
local ipairs = _G.ipairs
local locals = ""
locals = locals .. "local nl=require(\"nattlua\");"
locals = locals .. "local types=require(\"nattlua.types.types\");"

for k, v in pairs(_G) do
	locals = locals .. "local " .. tostring(k) .. "=_G." .. k .. ";"
end

local function analyze_function_signature(self, node, current_function)
	local explicit_arguments = false
	local explicit_return = false
	local args = {}
	local argument_tuple_override
	local return_tuple_override
	self:CreateAndPushFunctionScope(current_function)
	self:PushAnalyzerEnvironment("typesystem")

	if node.kind == "function" or node.kind == "local_function" then
		for i, key in ipairs(node.identifiers) do
			-- stem type so that we can allow
			-- function(x: foo<|x|>): nil
			self:CreateLocalValue(key.value.value, Any())

			if key.type_expression then
				args[i] = self:AnalyzeExpression(key.type_expression)
				explicit_arguments = true
			elseif key.value.value == "..." then
				args[i] = VarArg(Any())
			else
				args[i] = Any():SetNode(key)
			end

			self:CreateLocalValue(key.value.value, args[i])
		end
	elseif
		node.kind == "analyzer_function" or
		node.kind == "local_analyzer_function" or
		node.kind == "local_type_function" or
		node.kind == "type_function" or
		node.kind == "function_signature"
	then
		explicit_arguments = true

		for i, key in ipairs(node.identifiers) do
			local generic_type = node.identifiers_typesystem and node.identifiers_typesystem[i]

			if generic_type then
				if generic_type.identifier and generic_type.identifier.value ~= "..." then
					self:CreateLocalValue(generic_type.identifier.value, self:AnalyzeExpression(key):GetFirstValue())
				elseif generic_type.type_expression then
					self:CreateLocalValue(generic_type.value.value, Any(), i)
				end
			end

			if key.identifier and key.identifier.value ~= "..." then
				args[i] = self:AnalyzeExpression(key):GetFirstValue()
				self:CreateLocalValue(key.identifier.value, args[i])
			elseif key.kind == "vararg" then
				args[i] = self:AnalyzeExpression(key)
			elseif key.type_expression then
				self:CreateLocalValue(key.value.value, Any(), i)
				args[i] = self:AnalyzeExpression(key.type_expression)
			elseif key.kind == "value" then
				if not node.statements then
					local obj = self:AnalyzeExpression(key)

					if i == 1 and obj.Type == "tuple" and #node.identifiers == 1 then
						-- if we pass in a tuple we override the argument type
						-- function(mytuple): string
						argument_tuple_override = obj

						break
					else
						local val = self:Assert(node, obj)

						-- in case the tuple is empty
						if val then args[i] = val end
					end
				else
					args[i] = Any():SetNode(key)
				end
			else
				local obj = self:AnalyzeExpression(key)

				if i == 1 and obj.Type == "tuple" and #node.identifiers == 1 then
					-- if we pass in a tuple we override the argument type
					-- function(mytuple): string
					argument_tuple_override = obj

					break
				else
					local val = self:Assert(node, obj)

					-- in case the tuple is empty
					if val then args[i] = val end
				end
			end
		end
	else
		self:FatalError("unhandled statement " .. tostring(node))
	end

	if node.self_call and node.expression then
		self:PushAnalyzerEnvironment("runtime")
		local val = self:AnalyzeExpression(node.expression.left):GetFirstValue()
		self:PopAnalyzerEnvironment()

		if val then
			if val:GetContract() or val.Self then
				table.insert(args, 1, val.Self or val)
			else
				table.insert(args, 1, Union({Any(), val}))
			end
		end
	end

	local ret = {}

	if node.return_types then
		explicit_return = true

		-- TODO:
		-- somethings up with function(): (a,b,c)
		-- when doing this vesrus function(): a,b,c
		-- the return tuple becomes a tuple inside a tuple
		for i, type_exp in ipairs(node.return_types) do
			local obj = self:AnalyzeExpression(type_exp)

			if i == 1 and obj.Type == "tuple" and #node.identifiers == 1 and not obj.Repeat then
				-- if we pass in a tuple, we want to override the return type
				-- function(): mytuple
				return_tuple_override = obj

				break
			else
				ret[i] = obj
			end
		end
	end

	self:PopAnalyzerEnvironment()
	self:PopScope()
	return argument_tuple_override or Tuple(args),
	return_tuple_override or Tuple(ret),
	explicit_arguments,
	explicit_return
end

return {
	AnalyzeFunction = function(self, node)
		local obj = Function(
			{
				scope = self:GetScope(),
				upvalue_position = #self:GetScope():GetUpvalues("runtime"),
			}
		):SetNode(node)
		self:PushCurrentType(obj, "function")
		local args, ret, explicit_arguments, explicit_return = analyze_function_signature(self, node, obj)
		local func
		self:PopCurrentType("function")

		if
			node.statements and
			(
				node.kind == "analyzer_function" or
				node.kind == "local_analyzer_function"
			)
		then
			local Emitter = require("nattlua.transpiler.emitter").New
			local em = Emitter({type_annotations = false})

			em:EmitFunctionBody(node)

			func = self:CompileLuaAnalyzerDebugCode(
				"return function " .. em:Concat(),
				node
			)()
		end

		obj.Data.arg = args
		obj.Data.ret = ret
		obj.Data.lua_function = func

		if node.statements then obj.function_body_node = node end

		obj.explicit_arguments = explicit_arguments
		obj.explicit_return = explicit_return

		if self:IsRuntime() then self:CallMeLater(obj, args, node, true) end

		return obj
	end,
}
