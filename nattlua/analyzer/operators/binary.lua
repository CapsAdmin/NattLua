local math = math
local assert = assert
local tostring = tostring
local ipairs = ipairs
local table = require("table")
local types = require("nattlua.types.types")
local type_errors = require("nattlua.types.error_messages")
local bit = _G.bit or require("bit32")
local operators = {
		["+"] = function(l, r)
			return l + r
		end,
		["-"] = function(l, r)
			return l - r
		end,
		["*"] = function(l, r)
			return l * r
		end,
		["/"] = function(l, r)
			return l / r
		end,
		["/idiv/"] = function(l, r)
			return (math.modf(l / r))
		end,
		["%"] = function(l, r)
			return l % r
		end,
		["^"] = function(l, r)
			return l ^ r
		end,
		[".."] = function(l, r)
			return l .. r
		end,
		["&"] = function(l, r)
			return bit.band(l, r)
		end,
		["|"] = function(l, r)
			return bit.bor(l, r)
		end,
		["~"] = function(l, r)
			return bit.bxor(l, r)
		end,
		["<<"] = function(l, r)
			return bit.lshift(l, r)
		end,
		[">>"] = function(l, r)
			return bit.rshift(l, r)
		end,
	}

local function metatable_function(self, meta_method, l, r, swap)
	if swap then
		l, r = r, l
	end

	if r:GetMetaTable() or l:GetMetaTable() then
		local func = (l:GetMetaTable() and l:GetMetaTable():Get(meta_method)) or
			(r:GetMetaTable() and r:GetMetaTable():Get(meta_method))
		if not func then return end
		if func.Type ~= "function" then return func end
		return
			self:Assert(self.current_expression, self:Call(func, types.Tuple({l, r}))):Get(1)
	end
end

local function arithmetic(node, l, r, type, operator)
	assert(operators[operator], "cannot map operator " .. tostring(operator))

	if type and l.Type == type and r.Type == type then
		if l:IsLiteral() and r:IsLiteral() then
			local obj = types.Number(operators[operator](l:GetData(), r:GetData())):SetLiteral(true)

			if r:GetMax() then
				obj:SetMax(arithmetic(node, l:GetMax() or l, r:GetMax(), type, operator))
			end

			if l:GetMax() then
				obj:SetMax(arithmetic(node, l:GetMax(), r:GetMax() or r, type, operator))
			end

			return obj:SetNode(node):SetTypeSourceLeft(l):SetTypeSourceRight(r)
		end

		return types.Number():SetNode(node):SetTypeSourceLeft(l):SetTypeSourceRight(r)
	end

	return type_errors.binary(operator, l, r)
end

local function logical_cmp_cast(val--[[#: boolean | nil]])
	if val == nil then
		return types.Boolean()
	elseif val == true then
		return types.True()
	elseif val == false then
		return types.False()
	end
end

local function binary_operator(analyzer, node, l, r, env, op)
	op = op or node.value.value

	-- adding two tuples at runtime in lua will practically do this
	if env == "runtime" then
		if l.Type == "tuple" then
			l = analyzer:Assert(node, l:Get(1))
		end

		if r.Type == "tuple" then
			r = analyzer:Assert(node, r:Get(1))
		end
	end

	-- normalize l and r to be both sets to reduce complexity
	if l.Type ~= "union" and r.Type == "union" then
		l = types.Union({l})
	end

	if l.Type == "union" and r.Type ~= "union" then
		r = types.Union({r})
	end

	if l.Type == "union" and r.Type == "union" then
		if op == "|" and env == "typesystem" then
			return types.Union({l, r}):SetNode(node):SetTypeSourceLeft(l):SetTypeSourceRight(r)
		elseif op == "==" and env == "typesystem" then
			return l:Equal(r) and types.True() or types.False()
		elseif op == "~" and env == "typesystem" then
			return l:RemoveType(r):Copy()
		else
			local new_union = types.Union()
			local truthy_union = types.Union()
			local falsy_union = types.Union()
			local condition = l

			for _, l in ipairs(l:GetData()) do
				for _, r in ipairs(r:GetData()) do
					local res, err = binary_operator(
						analyzer,
						node,
						l,
						r,
						env,
						op
					)

					if not res then
						analyzer:ErrorAndCloneCurrentScope(node, err, condition)
					else
						if res:IsTruthy() then
							if analyzer.type_checked then
								for _, t in ipairs(analyzer.type_checked:GetData()) do
									if t.GetLuaType and t:GetLuaType() == l:GetData() then
										truthy_union:AddType(t)
									end
								end
							else
								truthy_union:AddType(l)
							end
						end

						if res:IsFalsy() then
							if analyzer.type_checked then
								for _, t in ipairs(analyzer.type_checked:GetData()) do
									if t.GetLuaType and t:GetLuaType() == l:GetData() then
										falsy_union:AddType(t)
									end
								end
							else
								falsy_union:AddType(l)
							end
						end

						new_union:AddType(res)
					end
				end
			end

			if analyzer.type_checked then
				new_union.type_checked = analyzer.type_checked
				analyzer.type_checked = nil
			end

			local upvalue = condition.upvalue or
				new_union.type_checked and
				new_union.type_checked.upvalue

			if upvalue then
				analyzer.current_statement.checks = analyzer.current_statement.checks or {}
				analyzer.current_statement.checks[upvalue] = analyzer.current_statement.checks[upvalue] or {}
				table.insert(analyzer.current_statement.checks[upvalue], new_union)
			end

			if op == "~=" then
				new_union.inverted = true
			end

			truthy_union:SetUpvalue(condition.upvalue)
			falsy_union:SetUpvalue(condition.upvalue)
			new_union:SetTruthyUnion(truthy_union)
			new_union:SetFalsyUnion(falsy_union)
			return
				new_union:SetNode(node):SetTypeSource(new_union):SetTypeSourceLeft(l):SetTypeSourceRight(r)
		end
	end

	if env == "typesystem" then
		if op == "|" then
			return types.Union({l, r})
		elseif op == "==" then
			return l:Equal(r) and types.True() or types.False()
		elseif op == "~" then
			return l:RemoveType(r)
		elseif op == "&" or op == "extends" then
			if l.Type ~= "table" then return false, "type " .. tostring(l) .. " cannot be extended" end
			return l:Extend(r)
		elseif op == ".." then
			if l.Type == "string" and r.Type == "string" then
				return types.String(l:GetData() .. r:GetData()):SetLiteral(true)
			else
				return l:Copy():SetMax(r)
			end
		elseif op == ">" then
			return types.Symbol((r:IsSubsetOf(l)))
		elseif op == "<" then
			return types.Symbol((l:IsSubsetOf(r)))
		elseif op == "+" then
			if l.Type == "table" and r.Type == "table" then return l:Union(r) end
		end
	end

	if op == "." or op == ":" then return analyzer:IndexOperator(node, l, r, env) end
	if l.Type == "any" or r.Type == "any" then return types.Any() end

	if op == "+" then
		local res = metatable_function(analyzer, "__add", l, r)
		if res then return res end
	elseif op == "-" then
		local res = metatable_function(analyzer, "__sub", l, r)
		if res then return res end
	elseif op == "*" then
		local res = metatable_function(analyzer, "__mul", l, r)
		if res then return res end
	elseif op == "/" then
		local res = metatable_function(analyzer, "__div", l, r)
		if res then return res end
	elseif op == "/idiv/" then
		local res = metatable_function(analyzer, "__idiv", l, r)
		if res then return res end
	elseif op == "%" then
		local res = metatable_function(analyzer, "__mod", l, r)
		if res then return res end
	elseif op == "^" then
		local res = metatable_function(analyzer, "__pow", l, r)
		if res then return res end
	elseif op == "&" then
		local res = metatable_function(analyzer, "__band", l, r)
		if res then return res end
	elseif op == "|" then
		local res = metatable_function(analyzer, "__bor", l, r)
		if res then return res end
	elseif op == "~" then
		local res = metatable_function(analyzer, "__bxor", l, r)
		if res then return res end
	elseif op == "<<" then
		local res = metatable_function(analyzer, "__lshift", l, r)
		if res then return res end
	elseif op == ">>" then
		local res = metatable_function(analyzer, "__rshift", l, r)
		if res then return res end
	end

	if l.Type == "number" and r.Type == "number" then
		if op == "~=" or op == "!=" then
			if l:GetMax() and l:GetMax():GetData() then return
				(not (r:GetData() >= l:GetData() and r:GetData() <= l:GetMax():GetData())) and
				types.True() or
				types.Boolean() end
			if r:GetMax() and r:GetMax():GetData() then return
				(not (l:GetData() >= r:GetData() and l:GetData() <= r:GetMax():GetData())) and
				types.True() or
				types.Boolean() end
		elseif op == "==" then
			if l:GetMax() and l:GetMax():GetData() then return
				r:GetData() >= l:GetData() and
				r:GetData() <= l:GetMax():GetData() and
				types.Boolean() or
				types.False() end
			if r:GetMax() and r:GetMax():GetData() then return
				l:GetData() >= r:GetData() and
				l:GetData() <= r:GetMax():GetData() and
				types.Boolean() or
				types.False() end
		end
	end

	if op == "==" then
		local res = metatable_function(analyzer, "__eq", l, r)
		if res then return res end

		if l:IsLiteral() and r:IsLiteral() and l.Type == r.Type then
			if l.Type == "table" and r.Type == "table" then
				if env == "runtime" then
					if l:GetReferenceId() and r:GetReferenceId() then return l:GetReferenceId() == r:GetReferenceId() and types.True() or types.False() end
				end

				if env == "typesystem" then return l:IsSubsetOf(r) and r:IsSubsetOf(l) and types.True() or types.False() end
				return types.Boolean()
			end

			return l:GetData() == r:GetData() and types.True() or types.False()
		end

		if l.Type == "table" and r.Type == "table" then
			if env == "typesystem" then return l:IsSubsetOf(r) and r:IsSubsetOf(l) and types.True() or types.False() end
		end

		if
			l.Type == "symbol" and
			r.Type == "symbol" and
			l:GetData() == nil and
			r:GetData() == nil
		then
			return types.True()
		end

		if l.Type ~= r.Type then return types.False() end
		if l == r then return types.True() end
		return types.Boolean()
	elseif op == "~=" then
		local res = metatable_function(analyzer, "__eq", l, r)

		if res then
			if res:IsLiteral() then
				res:SetData(not res:GetData())
			end

			return res
		end

		if l:IsLiteral() and r:IsLiteral() then return l:GetData() ~= r:GetData() and types.True() or types.False() end
		if l == types.Nil() and r == types.Nil() then return types.True() end
		if l.Type ~= r.Type then return types.True() end
		if l == r then return types.False() end
		return types.Boolean()
	elseif op == "<" then
		local res = metatable_function(analyzer, "__lt", l, r)
		if res then return res end

		if
			(l.Type == "string" and r.Type == "string") or
			(l.Type == "number" and r.Type == "number")
		then
			if l:IsLiteral() and r:IsLiteral() then return logical_cmp_cast(l.LogicalComparison(l, r, op)) end
			return types.Boolean()
		end

		return type_errors.binary(op, l, r)
	elseif op == "<=" then
		local res = metatable_function(analyzer, "__le", l, r)
		if res then return res end

		if
			(l.Type == "string" and r.Type == "string") or
			(l.Type == "number" and r.Type == "number")
		then
			if l:IsLiteral() and r:IsLiteral() then return logical_cmp_cast(l.LogicalComparison(l, r, op)) end
			return types.Boolean()
		end

		return type_errors.binary(op, l, r)
	elseif op == ">" then
		local res = metatable_function(analyzer, "__lt", l, r)
		if res then return res end

		if
			(l.Type == "string" and r.Type == "string") or
			(l.Type == "number" and r.Type == "number")
		then
			if l:IsLiteral() and r:IsLiteral() then return logical_cmp_cast(l.LogicalComparison(l, r, op)) end
			return types.Boolean()
		end

		return type_errors.binary(op, l, r)
	elseif op == ">=" then
		local res = metatable_function(analyzer, "__le", l, r)
		if res then return res end

		if
			(l.Type == "string" and r.Type == "string") or
			(l.Type == "number" and r.Type == "number")
		then
			if l:IsLiteral() and r:IsLiteral() then return logical_cmp_cast(l.LogicalComparison(l, r, op)) end
			return types.Boolean()
		end

		return type_errors.binary(op, l, r)
	elseif op == "or" or op == "||" then
		if l:IsUncertain() or r:IsUncertain() then return types.Union({l, r}):SetNode(node):SetTypeSourceLeft(l):SetTypeSourceRight(r) end

		-- when true, or returns its first argument
		if l:IsTruthy() then return
			l:Copy():SetNode(node):SetTypeSource(l):SetTypeSourceLeft(l):SetTypeSourceRight(r) end
		if r:IsTruthy() then return
			r:Copy():SetNode(node):SetTypeSource(r):SetTypeSourceLeft(l):SetTypeSourceRight(r) end
		return r:Copy():SetNode(node):SetTypeSource(r)
	elseif op == "and" or op == "&&" then
		if l:IsTruthy() and r:IsFalsy() then
			if l:IsFalsy() or r:IsTruthy() then return types.Union({l, r}):SetNode(node):SetTypeSourceLeft(l):SetTypeSourceRight(r) end
			return
				r:Copy():SetNode(node):SetTypeSource(r):SetTypeSourceLeft(l):SetTypeSourceRight(r)
		end

		if l:IsFalsy() and r:IsTruthy() then
			if l:IsTruthy() or r:IsFalsy() then return types.Union({l, r}):SetNode(node):SetTypeSourceLeft(l):SetTypeSourceRight(r) end
			return
				l:Copy():SetNode(node):SetTypeSource(l):SetTypeSourceLeft(l):SetTypeSourceRight(r)
		end

		if l:IsTruthy() and r:IsTruthy() then
			if l:IsFalsy() and r:IsFalsy() then return types.Union({l, r}):SetNode(node):SetTypeSourceLeft(l):SetTypeSourceRight(r) end
			return
				r:Copy():SetNode(node):SetTypeSource(r):SetTypeSourceLeft(l):SetTypeSourceRight(r)
		else
			if l:IsTruthy() and r:IsTruthy() then return types.Union({l, r}):SetNode(node):SetTypeSourceLeft(l):SetTypeSourceRight(r) end
			return
				l:Copy():SetNode(node):SetTypeSource(l):SetTypeSourceLeft(l):SetTypeSourceRight(r)
		end
	end

	if op == ".." then
		if
			(l.Type == "string" and r.Type == "string") or
			(l.Type == "number" and r.Type == "string") or
			(l.Type == "number" and r.Type == "number") or
			(l.Type == "string" and r.Type == "number")
		then
			if l:IsLiteral() and r:IsLiteral() then return analyzer:NewType(node, "string", l:GetData() .. r:GetData(), true) end
			return analyzer:NewType(node, "string")
		end

		return type_errors.binary(op, l, r)
	end

	if op == "+" then
		return arithmetic(node, l, r, "number", op)
	elseif op == "-" then
		return arithmetic(node, l, r, "number", op)
	elseif op == "*" then
		return arithmetic(node, l, r, "number", op)
	elseif op == "/" then
		return arithmetic(node, l, r, "number", op)
	elseif op == "/idiv/" then
		return arithmetic(node, l, r, "number", op)
	elseif op == "%" then
		return arithmetic(node, l, r, "number", op)
	elseif op == "^" then
		return arithmetic(node, l, r, "number", op)
	elseif op == "&" then
		return arithmetic(node, l, r, "number", op)
	elseif op == "|" then
		return arithmetic(node, l, r, "number", op)
	elseif op == "~" then
		return arithmetic(node, l, r, "number", op)
	elseif op == "<<" then
		return arithmetic(node, l, r, "number", op)
	elseif op == ">>" then
		return arithmetic(node, l, r, "number", op)
	end

	return type_errors.binary(op, l, r)
end

return binary_operator
