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

local function prefix_operator(analyzer, node, l, env)
	local op = node.value.value

	if l.Type == "tuple" then
		l = l:Get(1) or Nil()
	end

	if l.Type == "union" then
		local new_union = Union()
		local truthy_union = Union()
		local falsy_union = Union()

		for _, l in ipairs(l:GetData()) do
			local res, err = prefix_operator(analyzer, node, l, env)

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

		truthy_union:SetUpvalue(l:GetUpvalue())
		falsy_union:SetUpvalue(l:GetUpvalue())
		new_union:SetTruthyUnion(truthy_union)
		new_union:SetFalsyUnion(falsy_union)

		if op == "literal" then
			new_union.literal_argument = true
		end

		return new_union:SetNode(node):SetTypeSource(l)
	end

	if l.Type == "any" then
		local obj = Any()

		if op == "literal" then
			obj.literal_argument = true
		end

		return obj
	end

	if env == "typesystem" then
		if op == "typeof" then
			local obj = analyzer:AnalyzeExpression(node.right, "runtime")
			if not obj then return type_errors.other(
				"cannot find '" .. node.right:Render() .. "' in the current typesystem scope"
			) end
			return obj:GetContract() or obj
		elseif op == "unique" then
			local obj = analyzer:AnalyzeExpression(node.right, "typesystem")
			obj:MakeUnique(true)
			return obj
		elseif op == "mutable" then
			local obj = analyzer:AnalyzeExpression(node.right, "typesystem")
			obj.mutable = true
			return obj
		elseif op == "$" then
			local obj = analyzer:AnalyzeExpression(node.right, "typesystem")
			if obj.Type ~= "string" then return type_errors.other("must evaluate to a string") end
			if not obj:IsLiteral() then return type_errors.other("must be a literal") end
			obj:SetPattern(obj:GetData())
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
		if l:IsTruthy() and l:IsFalsy() then return Boolean():SetNode(node):SetTypeSource(l) end
		if l:IsTruthy() then return False():SetNode(node):SetTypeSource(l) end
		if l:IsFalsy() then return True():SetNode(node):SetTypeSource(l) end
	end

	if op == "-" or op == "~" or op == "#" then
		return l:PrefixOperator(op)
	elseif op == "literal" then
		l.literal_argument = true
		return l
	end

	error("unhandled prefix operator in " .. env .. ": " .. op .. tostring(l))
end

return {Prefix = prefix_operator}
