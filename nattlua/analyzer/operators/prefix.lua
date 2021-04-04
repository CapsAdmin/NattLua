local types = require("nattlua.types.types")
local type_errors = require("nattlua.types.error_messages")
local operators = {
		["-"] = function(l)
			return -l
		end,
		["~"] = function(l)
			return bit.bnot(l)
		end,
		["#"] = function(l)
			return #l
		end,
	}

local function metatable_function(self, meta_method, l)
	if l:GetMetaTable() then
		local func = l:GetMetaTable():Get(meta_method)
		if func then return self:Assert(l:GetNode(), self:Call(func, types.Tuple({l})):Get(1)) end
	end
end

local function arithmetic(l, type, operator)
	assert(operators[operator], "cannot map operator " .. tostring(operator))

	if l.Type == type then
		if l:IsLiteral() then
			local obj = types.Number(operators[operator](l:GetData())):SetLiteral(true)

			if l:GetMax() then
				obj:SetMax(arithmetic(l:GetMax(), type, operator))
			end

			return obj
		end

		return types.Number()
	end

	return types.error.prefix(operator, r)
end

return function(META)
	function META:PrefixOperator(node, l, env)
		local op = node.value.value

		if l.Type == "tuple" then
			l = l:Get(1) or types.Nil()
		end

		if l.Type == "union" then
			local new_union = types.Union()
			local truthy_union = types.Union()
			local falsy_union = types.Union()

			for _, l in ipairs(l:GetData()) do
				local res, err = self:PrefixOperator(node, l, env)

				if not res then
					self:ErrorAndCloneCurrentScope(node, err, l)
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

			truthy_union:SetUpvalue(l.upvalue)
			falsy_union:SetUpvalue(l.upvalue)
			new_union.truthy_union = truthy_union
			new_union.falsy_union = falsy_union

			if op == "literal" then
				new_union.literal_argument = true
			end

			return new_union:SetNode(node):SetSource(l)
		end

		if l.Type == "any" then
			local obj = types.Any()

			if op == "literal" then
				obj.literal_argument = true
			end

			return obj
		end

		if env == "typesystem" then
			if op == "typeof" then
				local obj = self:AnalyzeExpression(node.right, "runtime")
				if not obj then return type_errors.other(
					"cannot find '" .. node.right:Render() .. "' in the current typesystem scope"
				) end
				return obj:GetContract() or obj
			elseif op == "supertype" then
				l = l:Copy()
				l:SetData()
				l:SetLiteral(false)
				return l
			elseif op == "unique" then
				local obj = self:AnalyzeExpression(node.right, "typesystem")
				obj:MakeUnique(true)
				return obj
			elseif op == "mutable" then
				local obj = self:AnalyzeExpression(node.right, "typesystem")
				obj.mutable = true
				return obj
			elseif op == "$" then
				local obj = self:AnalyzeExpression(node.right, "typesystem")
				if obj.Type ~= "string" then return type_errors.other("must evaluate to a string") end
				if not obj:IsLiteral() then return type_errors.other("must be a literal") end
				obj:SetPattern(obj:GetData())
				return obj
			end
		end

		if op == "-" then
			local res = metatable_function(self, "__unm", l)
			if res then return res end
		elseif op == "~" then
			local res = metatable_function(self, "__bxor", l)
			if res then return res end
		elseif op == "#" then
			local res = metatable_function(self, "__len", l)
			if res then return res end
		end

		if op == "not" or op == "!" then
			if l:IsTruthy() and l:IsFalsy() then return self:NewType(node, "boolean", nil, false, l):SetNode(node):SetSource(l) end
			if l:IsTruthy() then return self:NewType(node, "boolean", false, true, l):SetNode(node):SetSource(l) end
			if l:IsFalsy() then return self:NewType(node, "boolean", true, true, l):SetNode(node):SetSource(l) end
		end

		if op == "-" then
			return arithmetic(l, "number", op)
		elseif op == "~" then
			return arithmetic(l, "number", op)
		elseif op == "#" then
			if l.Type == "table" then
				return types.Number(l:GetLength()):SetLiteral(l:IsLiteral())
			elseif l.Type == "string" then
				return types.Number(l:GetData() and #l:GetData() or nil):SetLiteral(l:IsLiteral())
			end
		elseif op == "literal" then
			l.literal_argument = true
			return l
		end

		error("unhandled prefix operator in " .. env .. ": " .. op .. tostring(l))
	end

	function META:AnalyzePrefixOperatorExpression(node, env)
		return self:Assert(node, self:PrefixOperator(node, self:AnalyzeExpression(node.right, env), env))
	end
end
