local ipairs = ipairs
local error = error
local tostring = tostring
local Union = require("nattlua.types.union").Union
local Nil = require("nattlua.types.symbol").Nil
local type_errors = require("nattlua.types.error_messages")
local LString = require("nattlua.types.string").LString
local Boolean = require("nattlua.types.symbol").Boolean
local False = require("nattlua.types.symbol").False
local True = require("nattlua.types.symbol").True
local Any = require("nattlua.types.any").Any
local Tuple = require("nattlua.types.tuple").Tuple

local function metatable_function(self, meta_method, l)
	if l:GetMetaTable() then
		meta_method = LString(meta_method)
		local func = l:GetMetaTable():Get(meta_method)
		if func then return self:Assert(l:GetNode(), self:Call(func, Tuple({l})):Get(1)) end
	end
end

local function prefix_operator(analyzer, node, l)
	local op = node.value.value

	if l.Type == "tuple" then
		l = l:Get(1) or Nil()
	end

	if l.Type == "union" then
		local new_union = Union()
		local truthy_union = Union()
		local falsy_union = Union()

		for _, l in ipairs(l:GetData()) do
			local res, err = prefix_operator(analyzer, node, l)

			if not res then
				analyzer:ErrorAndCloneCurrentScope(node, err, l)
				falsy_union:AddType(l)
			else
				new_union:AddType(res)

				if res:IsTruthy() then
					truthy_union:AddType(l)
				end

				if res:IsFalsy() then
					falsy_union:AddType(l)
				end
			end
		end


		local l_upvalue = l:GetUpvalue()

		if l_upvalue then
			l_upvalue.exp_stack = l_upvalue.exp_stack or {}
			table.insert(l_upvalue.exp_stack, {truthy = truthy_union, falsy = falsy_union})

			analyzer.affected_upvalues = analyzer.affected_upvalues or {}
			table.insert(analyzer.affected_upvalues, l_upvalue)
		end

		truthy_union:SetUpvalue(l:GetUpvalue())
		falsy_union:SetUpvalue(l:GetUpvalue())
		new_union:SetTruthyUnion(truthy_union)
		new_union:SetFalsyUnion(falsy_union)

		if op == "ref" then
			new_union.ref_argument = true
		end

		return new_union:SetNode(node):SetTypeSource(l)
	end

	if l.Type == "any" then
		local obj = Any()

		if op == "ref" then
			obj.ref_argument = true
		end

		return obj
	end

	if analyzer:IsTypesystem() then
		if op == "typeof" then
			analyzer:PushAnalyzerEnvironment("runtime")
			local obj = analyzer:AnalyzeExpression(node.right)
			analyzer:PopAnalyzerEnvironment()
			if not obj then return type_errors.other(
				"cannot find '" .. node.right:Render() .. "' in the current typesystem scope"
			) end
			return obj:GetContract() or obj
		elseif op == "unique" then
			local obj = analyzer:AnalyzeExpression(node.right)
			obj:MakeUnique(true)
			return obj
		elseif op == "mutable" then
			local obj = analyzer:AnalyzeExpression(node.right)
			obj.mutable = true
			return obj
		elseif op == "expand" then
			local obj = analyzer:AnalyzeExpression(node.right)
			obj.expand = true
			return obj
		elseif op == "$" then
			local obj = analyzer:AnalyzeExpression(node.right)
			if obj.Type ~= "string" then return type_errors.other("must evaluate to a string") end
			if not obj:IsLiteral() then return type_errors.other("must be a literal") end
			obj:SetPatternContract(obj:GetData())
			return obj
		end
	end

	if op == "-" then
		local res = metatable_function(analyzer, "__unm", l)
		if res then return res end
	elseif op == "~" then
		local res = metatable_function(analyzer, "__bxor", l)
		if res then return res end
	elseif op == "#" then
		local res = metatable_function(analyzer, "__len", l)
		if res then return res end
	end

	if op == "not" or op == "!" then
		local truthy
		local falsy
		local union

		if l:IsTruthy() and l:IsFalsy() then 
			union = Boolean():SetNode(node):SetTypeSource(l) 
		elseif l:IsTruthy() then 
			truthy = False():SetNode(node):SetTypeSource(l) 
		elseif l:IsFalsy() then 
			falsy = True():SetNode(node):SetTypeSource(l) 
		end

		local l_upvalue = l:GetUpvalue()

		if l_upvalue then
			l_upvalue.exp_stack = l_upvalue.exp_stack or {}
			table.insert(l_upvalue.exp_stack, {truthy = truthy or union, falsy = falsy or union})

			analyzer.affected_upvalues = analyzer.affected_upvalues or {}
			table.insert(analyzer.affected_upvalues, l_upvalue)
		end

		return union or truthy or falsy
	end

	if op == "-" or op == "~" or op == "#" then
		return l:PrefixOperator(op)
	elseif op == "ref" then
		l.ref_argument = true
		return l
	elseif op == "literal" then
		l.literal_argument = true
		return l
	end

	error("unhandled prefix operator in " .. analyzer:GetCurrentAnalyzerEnvironment() .. ": " .. op .. tostring(l))
end

return {Prefix = prefix_operator}
