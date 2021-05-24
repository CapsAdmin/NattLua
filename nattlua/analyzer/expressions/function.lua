local tostring = tostring
local table = require("table")
local types = require("nattlua.types.types")
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
				if key.explicit_type then
					args[i] = analyzer:NewType(key, "...")
					args[i]:Set(1, analyzer:AnalyzeExpression(key.explicit_type, "typesystem"))
				else
					args[i] = analyzer:NewType(key, "...")
				end
			elseif key.explicit_type then
				args[i] = analyzer:AnalyzeExpression(key.explicit_type, "typesystem")
				explicit_arguments = true
			else
				args[i] = analyzer:GuessTypeFromIdentifier(key)
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
			elseif key.explicit_type then
				args[i] = analyzer:AnalyzeExpression(key.explicit_type, "typesystem")

				if key.value.value == "..." then
					local vararg = analyzer:NewType(key, "...")
					vararg:Set(1, args[i])
					args[i] = vararg
				end

				explicit_arguments = true
			elseif key.kind == "value" then
				if key.value.value == "..." then
					args[i] = analyzer:NewType(key, "...")
				elseif key.value.value == "self" then
					args[i] = analyzer.current_tables[#analyzer.current_tables]

					if not args[i] then
						analyzer:Error(key, "cannot find value self")
					end
				elseif not node.statements then
					args[i] = analyzer:AnalyzeExpression(key, "typesystem")
				else
					args[i] = analyzer:NewType(key, "any")
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
				table.insert(args, 1, types.Union({types.Any(), val}))
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

				if type_exp.explicit_type then
					tup = types.Tuple(
							{
								analyzer:AnalyzeExpression(type_exp.explicit_type, "typesystem"),
							}
						)
						:SetRepeat(math.huge)
				else
					tup = analyzer:NewType(type_exp, "...")
				end

				ret[i] = tup
			else
				ret[i] = analyzer:AnalyzeExpression(type_exp, "typesystem")
			end
		end

		analyzer:PopPreferTypesystem()
		analyzer:PopScope()
	end

	args = types.Tuple(args)
	ret = types.Tuple(ret)
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

	local obj = analyzer:NewType(
		node,
		"function",
		{
			arg = args,
			ret = ret,
			lua_function = func,
			scope = analyzer:GetScope(),
			upvalue_position = #analyzer:GetScope():GetUpvalues("runtime"),
		}
	)
	obj.explicit_arguments = explicit_arguments
	obj.explicit_return = explicit_return

	if env == "runtime" then
		analyzer:CallMeLater(obj, args, node, true)
	end

	return obj
end
