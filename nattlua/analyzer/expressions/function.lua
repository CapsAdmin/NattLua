local tostring = tostring
local table = require("table")
local Union = require("nattlua.types.union").Union
local Any = require("nattlua.types.any").Any
local Tuple = require("nattlua.types.tuple").Tuple
local Function = require("nattlua.types.function").Function
local VarArg = require("nattlua.types.tuple").VarArg
local ipairs = _G.ipairs
local locals = ""

for k, v in pairs(_G) do
	locals = locals .. "local " .. tostring(k) .. " = _G." .. k .. ";"
end

return function(analyzer, node, env)
	if
		node.type == "statement" and
		(node.kind == "local_type_function" or node.kind == "type_function")
	then
		node = node:ToExpression("type_function")
	end

	local explicit_arguments = false
	local explicit_return = false
	local args = {}

	if node.kind == "function" or node.kind == "local_function" then
		for i, key in ipairs(node.identifiers) do
			if key.value.value == "..." then
				if key.as_expression then
					args[i] = VarArg():SetNode(key)
					args[i]:Set(1, analyzer:AnalyzeExpression(key.as_expression, "typesystem"))
				else
					args[i] = VarArg():SetNode(key)
				end
			elseif key.as_expression then
				args[i] = analyzer:AnalyzeExpression(key.as_expression, "typesystem")
				explicit_arguments = true
			else
				args[i] = Any():SetNode(key)
			end
		end
	elseif
		node.kind == "type_function" or
		node.kind == "local_type_function" or
		node.kind == "local_generics_type_function" or
		node.kind == "generics_type_function"
	then
		for i, key in ipairs(node.identifiers) do
			if key.identifier then
				args[i] = analyzer:AnalyzeExpression(key, "typesystem")
				explicit_arguments = true
			elseif key.as_expression then
				args[i] = analyzer:AnalyzeExpression(key.as_expression, "typesystem")

				if key.value.value == "..." then
					local vararg = VarArg():SetNode(key)
					vararg:Set(1, args[i])
					args[i] = vararg
				end

				explicit_arguments = true
			elseif key.kind == "value" then
				if key.value.value == "..." then
					args[i] = VarArg():SetNode(key)
				elseif key.value.value == "self" then
					args[i] = analyzer.current_tables[#analyzer.current_tables]

					if not args[i] then
						analyzer:Error(key, "cannot find value self")
					end
				elseif not node.statements then
					args[i] = analyzer:AnalyzeExpression(key, "typesystem")
				else
					args[i] = Any():SetNode(key)
				end
			else
				args[i] = analyzer:AnalyzeExpression(key, "typesystem")
			end
		end
	else
		analyzer:FatalError("unhandled statement " .. tostring(node))
	end

	if node.self_call and node.expression then
		local val = analyzer:AnalyzeExpression(node.expression.left, "runtime")

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
		analyzer:CreateAndPushFunctionScope()
		analyzer:PushPreferTypesystem(true)

		for i, key in ipairs(node.identifiers) do
			if key.kind == "value" and args[i] then
				analyzer:CreateLocalValue(key, args[i], "typesystem", true)
			end
		end

		for i, type_exp in ipairs(node.return_types) do
			if type_exp.kind == "value" and type_exp.value.value == "..." then
				local tup

				if type_exp.as_expression then
					tup = Tuple(
							{
								analyzer:AnalyzeExpression(type_exp.as_expression, "typesystem"),
							}
						)
						:SetRepeat(math.huge)
				else
					tup = VarArg():SetNode(type_exp)
				end

				ret[i] = tup
			else
				ret[i] = analyzer:AnalyzeExpression(type_exp, "typesystem")
			end
		end

		analyzer:PopPreferTypesystem()
		analyzer:PopScope()
	end

	args = Tuple(args)
	ret = Tuple(ret)
	local func

	if env == "typesystem" then
		if
			node.statements and
			(node.kind == "type_function" or node.kind == "local_type_function")
		then
			node.lua_type_function = true
			func = analyzer:CompileLuaTypeCode(locals .. "\nreturn " .. node:Render({uncomment_types = true, lua_type_function = true}), node)()
		end
	end

	local obj = Function(
			{
				arg = args,
				ret = ret,
				lua_function = func,
				scope = analyzer:GetScope(),
				upvalue_position = #analyzer:GetScope():GetUpvalues("runtime"),
			}
		)
		:SetNode(node)

	if node.statements then
		obj.function_body_node = node
	end

	obj.explicit_arguments = explicit_arguments
	obj.explicit_return = explicit_return

	if env == "runtime" then
		analyzer:CallMeLater(obj, args, node, true)
	end

	return obj
end
