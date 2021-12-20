local tostring = tostring
local table = require("table")
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

local function analyze_function_signature(analyzer, node, current_function)
	local explicit_arguments = false
	local explicit_return = false
	local args = {}
	local argument_tuple_override
	local return_tuple_override
	
	analyzer:CreateAndPushFunctionScope(current_function:GetData().scope, current_function:GetData().upvalue_position)
	analyzer:PushPreferTypesystem(true)

	if node.kind == "function" or node.kind == "local_function" then
		
		for i, key in ipairs(node.identifiers) do

			-- stem type so that we can allow
			-- function(x: foo<|x|>): nil
			analyzer:CreateLocalValue(key, Any(), "typesystem", i)


			if key.value.value == "..." then
				if key.type_expression then
					explicit_arguments = true
					args[i] = VarArg():SetNode(key)
					args[i]:Set(1, analyzer:AnalyzeExpression(key.type_expression, "typesystem"):GetFirstValue())
				else
					args[i] = VarArg():SetNode(key)
				end
			elseif key.type_expression then
				args[i] = analyzer:AnalyzeExpression(key.type_expression, "typesystem"):GetFirstValue()
				explicit_arguments = true
			else
				args[i] = Any():SetNode(key)
			end

			analyzer:CreateLocalValue(key, args[i], "typesystem", i)
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
			
			if key.identifier then
				args[i] = analyzer:AnalyzeExpression(key, "typesystem"):GetFirstValue()
				analyzer:CreateLocalValue(key.identifier, args[i], "typesystem", i)

			elseif key.type_expression then
				analyzer:CreateLocalValue(key, Any(), "typesystem", i)
				args[i] = analyzer:AnalyzeExpression(key.type_expression, "typesystem")

				if key.value.value == "..." then
					local vararg = VarArg():SetNode(key)
					vararg:Set(1, args[i])
					args[i] = vararg
				end

			elseif key.kind == "value" then
				if key.value.value == "..." then
					args[i] = VarArg():SetNode(key)
				elseif key.value.value == "self" then
					args[i] = analyzer.current_tables[#analyzer.current_tables]

					if not args[i] then
						analyzer:Error(key, "cannot find value self")
					end
				elseif not node.statements then
					local obj = analyzer:AnalyzeExpression(key, "typesystem")
					if i == 1 and obj.Type == "tuple" and #node.identifiers == 1 then
						-- if we pass in a tuple we override the argument type
						-- function(mytuple): string
						argument_tuple_override = obj
						break
					else
						args[i] = obj:GetFirstValue()
					end
				else
					args[i] = Any():SetNode(key)
				end
			else
				args[i] = analyzer:AnalyzeExpression(key, "typesystem"):GetFirstValue()
			end
		end
	
	else
		analyzer:FatalError("unhandled statement " .. tostring(node))
	end

	if node.self_call and node.expression then
		analyzer:PushPreferTypesystem(false)
		local val = analyzer:AnalyzeExpression(node.expression.left, "runtime"):GetFirstValue()
		analyzer:PopPreferTypesystem()

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
			if type_exp.kind == "value" and type_exp.value.value == "..." then
				local tup

				if type_exp.type_expression then
					tup = Tuple(
							{
								analyzer:AnalyzeExpression(type_exp.type_expression, "typesystem"),
							}
						)
						:SetRepeat(math.huge)
				else
					tup = VarArg():SetNode(type_exp)
				end

				ret[i] = tup
			else
				local obj = analyzer:AnalyzeExpression(type_exp, "typesystem")
				if i == 1 and obj.Type == "tuple" and #node.identifiers == 1 then
					-- if we pass in a tuple, we want to override the return type
					-- function(): mytuple
					return_tuple_override = obj
					break
				else
					ret[i] = obj
				end
			end
		end
	end

	analyzer:PopPreferTypesystem()
	analyzer:PopScope()

	return argument_tuple_override or Tuple(args), return_tuple_override or Tuple(ret), explicit_arguments, explicit_return
end

return
	{
		AnalyzeFunction = function(analyzer, node, env)
			if
				node.type == "statement" and
				(node.kind == "local_analyzer_function" or node.kind == "analyzer_function")
			then
				node.type = "expression"
				node.kind = "analyzer_function"
			end


			local obj = Function(
					{
						scope = analyzer:GetScope(),
						upvalue_position = #analyzer:GetScope():GetUpvalues("runtime"),
					}
				)
				:SetNode(node)

			local args, ret, explicit_arguments, explicit_return = analyze_function_signature(analyzer, node, obj)

			local func

			if
				node.statements and
				(node.kind == "analyzer_function" or node.kind == "local_analyzer_function")
			then
				node.analyzer_function = true
	
				--'local analyzer = self;local env = self:GetScopeHelper(scope);'
		
				func = analyzer:CompileLuaAnalyzerDebugCode("return  " .. node:Render({uncomment_types = true, analyzer_function = true}), node)()
			end

			obj.Data.arg = args
			obj.Data.ret = ret
			obj.Data.lua_function = func

			if node.statements then
				obj.function_body_node = node
			end

			obj.explicit_arguments = explicit_arguments
			obj.explicit_return = explicit_return

			if env == "runtime" then
				analyzer:CallMeLater(obj, args, node, true)
			end

			return obj
		end,
	}
