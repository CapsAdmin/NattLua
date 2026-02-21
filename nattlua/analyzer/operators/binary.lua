local tostring = tostring
local ipairs = ipairs
local tonumber = tonumber
local table = _G.table
local LString = require("nattlua.types.string").LString
local ConstString = require("nattlua.types.string").ConstString
local String = require("nattlua.types.string").String
local Any = require("nattlua.types.any").Any
local Tuple = require("nattlua.types.tuple").Tuple
local Union = require("nattlua.types.union").Union
local True = require("nattlua.types.symbol").True
local Boolean = require("nattlua.types.union").Boolean
local Symbol = require("nattlua.types.symbol").Symbol
local False = require("nattlua.types.symbol").False
local Nil = require("nattlua.types.symbol").Nil
local LNumber = require("nattlua.types.number").LNumber
local LNumberRange = require("nattlua.types.range").LNumberRange
local error_messages = require("nattlua.error_messages")
local ARITHMETIC_OPS = {
	["+"] = "__add",
	["-"] = "__sub",
	["*"] = "__mul",
	["/"] = "__div",
	["/idiv/"] = "__idiv",
	["%"] = "__mod",
	["^"] = "__pow",
	["&"] = "__band",
	["|"] = "__bor",
	["~"] = "__bxor",
	["<<"] = "__lshift",
	[">>"] = "__rshift",
}
local COMPARISON_OPS = {
	["<"] = "__lt",
	["<="] = "__le",
	[">"] = "__lt",
	[">="] = "__le",
}

local function metatable_function(self, node, meta_method, l, r)
	local r_metatable = (r.Type == "table" or r.Type == "string") and r:GetMetaTable()
	local l_metatable = (l.Type == "table" or l.Type == "string") and l:GetMetaTable()

	if r_metatable or l_metatable then
		meta_method = ConstString(meta_method)
		local func = (
				l_metatable and
				l_metatable:Get(meta_method)
			) or
			(
				r_metatable and
				r_metatable:Get(meta_method)
			)

		if not func then return end

		if func.Type ~= "function" then return func end

		local tup, err = self:Call(func, Tuple({l, r}), node)

		if tup then return tup:GetWithNumber(1) end

		return self:Assert(tup, err)
	end
end

local function logical_cmp_cast(val--[[#: boolean | nil]], err--[[#: string | nil]])
	if not val and err then return val, error_messages.plain_error(err) end

	if val == nil then
		return Boolean()
	elseif val == true then
		return True()
	elseif val == false then
		return False()
	end
end

local intersect_comparison = require("nattlua.analyzer.intersect_comparison")

local function number_comparison(self, l, r, op)
	local invert = op == "~=" or op == "!=" or op == ">" or op == ">="
	local nl, nr, nl2, nr2 = intersect_comparison(l, r, op, invert)

	if nl and nr then self:TrackUpvalueUnion(l, nl, nr) end

	if nl2 and nr2 then self:TrackUpvalueUnion(r, nl2, nr2) end

	if nl and nr then
		if nl:IsNan() or nr:IsNan() then
			if op == "~=" then return logical_cmp_cast(true) end

			return logical_cmp_cast(false)
		end

		return logical_cmp_cast(nil)
	elseif nl then
		return logical_cmp_cast(true)
	end

	return logical_cmp_cast(false)
end

local Binary

local function coerce_number(l, r)
	if l:IsLiteral() and r:IsLiteral() then
		if (l.Type == "number" or l.Type == "range") and r.Type == "string" then
			local num = tonumber(r:GetData())

			if num then r = LNumber(num) end
		elseif l.Type == "string" and (r.Type == "number" or r.Type == "range") then
			local num = tonumber(l:GetData())

			if num then l = LNumber(num) end
		elseif l.Type == "string" and r.Type == "string" then
			local lnum = tonumber(l:GetData())
			local rnum = tonumber(r:GetData())

			if lnum and rnum then
				l = LNumber(lnum)
				r = LNumber(rnum)
			end
		end
	end

	return l, r
end

function Binary(self, node, l, r, op)
	if l.Type == "any" or r.Type == "any" then return Any() end

	if op == "and" then
		-- boolean and boolean
		if l:IsUncertain() or r:IsUncertain() then return Union({l, r}) end

		-- true and false
		if l:IsTruthy() and r:IsFalsy() then return r:Copy() end

		-- false and true
		if l:IsFalsy() and r:IsTruthy() then return l:Copy() end

		-- true and true
		if l:IsTruthy() and r:IsTruthy() then return r:Copy() end

		-- false and false
		return l:Copy()
	elseif op == "or" then
		-- boolean or boolean
		if l:IsUncertain() or r:IsUncertain() then return Union({l, r}) end

		-- true or boolean
		if l:IsTruthy() then return l:Copy() end

		-- false or true
		if r:IsTruthy() then return r:Copy() end

		return r:Copy()
	elseif op == "==" or op == "!=" or op == "~=" then
		local is_not_equal = op == "~=" or op == "!="
		local meta_method = "__eq"
		local res = metatable_function(self, node, meta_method, l, r)

		if res then
			if is_not_equal and res:IsLiteral() then
				res = not res:GetData() and True() or False()
			end

			return res
		end

		if l:IsNumeric() and r:IsNumeric() then
			local res = number_comparison(self, l, r, op)

			if res then return res end
		end

		if l.Type ~= r.Type then return is_not_equal and True() or False() end

		if is_not_equal then
			local val, err = l.LogicalComparison(l, r, "==", self:GetCurrentAnalyzerEnvironment())

			if val ~= nil then val = not val end

			return logical_cmp_cast(val, err)
		end

		return logical_cmp_cast(l.LogicalComparison(l, r, op, self:GetCurrentAnalyzerEnvironment()))
	elseif op == "." or op == ":" then
		return self:IndexOperator(l, r)
	elseif op == ".." then
		if
			(
				l.Type == "string" and
				r.Type == "string"
			)
			or
			(
				(
					l.Type == "number" or
					l.Type == "range"
				)
				and
				r.Type == "string"
			)
			or
			(
				(
					l.Type == "number" or
					l.Type == "range"
				)
				and
				r.Type == "number"
			)
			or
			(
				l.Type == "string" and
				(
					r.Type == "number" or
					r.Type == "range"
				)
			)
		then
			if l:IsLiteral() and r:IsLiteral() then
				if l.Type == "range" and r.Type == "range" then
					return LString(l:GetMin() .. r:GetMax())
				elseif l.Type == "range" then
					return LString(l:GetMin() .. r:GetData())
				elseif r.Type == "range" then
					return LString(l:GetData() .. r:GetMax())
				else
					return LString(l:GetData() .. r:GetData())
				end
			end

			return String()
		end

		local res = metatable_function(self, node, "__concat", l, r)

		if res then return res end
	elseif ARITHMETIC_OPS[op] then
		do -- arithmetic can be coerced to a number
			local nl, nr = coerce_number(l, r)

			if nl:IsNumeric() and nr:IsNumeric() then return nl:BinaryOperator(nr, op) end
		end

		local res = metatable_function(self, node, ARITHMETIC_OPS[op], l, r)

		if res then return res end
	elseif COMPARISON_OPS[op] then
		if l:IsNumeric() and r:IsNumeric() then
			local res = number_comparison(self, l, r, op)

			if res then return res end
		end

		local res = metatable_function(self, node, COMPARISON_OPS[op], l, r)

		if res then return res end

		return logical_cmp_cast(l.LogicalComparison(l, r, op))
	end

	return false, error_messages.binary(op, l, r)
end

local function BinaryWithUnion(self, node, l, r, op)
	if l.Type == "any" or r.Type == "any" then return Any() end

	if l.Type == "deferred" then l = l:Unwrap() end

	if r.Type == "deferred" then r = r:Unwrap() end

	if self:IsTypesystem() then
		if op == "==" then
			return l:Equal(r) and True() or False()
		elseif op == "~" then
			if l.Type == "union" then return l:Copy():RemoveType(r):Simplify() end

			return l
		elseif op == "&" or op == "extends" then
			if l.Type == "union" then l = l:Simplify() end

			if l.Type ~= "table" then
				return false, {"type " .. tostring(l) .. " cannot be extended"}
			end

			return l:Extend(r)
		elseif op == "supersetof" then
			return r:IsSubsetOf(l) and True() or False()
		elseif op == "subsetof" then
			return l:IsSubsetOf(r) and True() or False()
		elseif op == ".." then
			if l.Type == "tuple" and r.Type == "tuple" then
				return l:Copy():Concat(r)
			elseif l.Type == "string" and r.Type == "string" then
				if l:IsLiteral() and r:IsLiteral() then
					return LString(l:GetData() .. r:GetData())
				end

				return false, error_messages.binary(op, l, r)
			elseif l.Type == "number" and r.Type == "number" then
				if l:IsLiteral() and r:IsLiteral() then
					if l:GetData() == r:GetData() then return LNumber(l:GetData()) end

					return LNumberRange(l:GetData(), r:GetData())
				end

				return l:Copy()
			end
		elseif op == "*" then
			if l.Type == "tuple" and r.Type == "number" and r:IsLiteral() then
				return l:Copy():SetRepeat(r:GetData())
			end
		elseif op == "+" then
			if l.Type == "table" and r.Type == "table" then return l:Union(r) end
		end
	end

	if l.Type == "union" or r.Type == "union" then
		local upvalue = l:GetUpvalue()
		local original_l = l
		local original_r = r

		-- normalize l and r to be both unions to reduce complexity
		if l.Type ~= "union" and r.Type == "union" then l = Union({l}) end

		if l.Type == "union" and r.Type ~= "union" then r = Union({r}) end

		if l.Type == "union" and r.Type == "union" then
			local new_union = Union()
			new_union:SetLeftRightSource(l, r)
			local truthy_union = Union():SetUpvalue(upvalue)
			local falsy_union = Union():SetUpvalue(upvalue)

			if upvalue then upvalue:SetTruthyFalsyUnion(truthy_union, falsy_union) end

			-- special case for type(x) ==/~=
			if self.type_checked and (op == "==" or op == "!=" or op == "~=") then
				local type_checked = self.type_checked
				self.type_checked = false

				for _, l_elem in ipairs(l:GetData()) do
					for _, r_elem in ipairs(r:GetData()) do
						local res, err = Binary(self, node, l_elem, r_elem, op)

						if not res then
							self:Error(err)
						else
							if res:IsTruthy() then
								for _, t in ipairs(type_checked:GetData()) do
									if t:GetLuaType() == l_elem:GetData() then
										truthy_union:AddType(t)
									end
								end
							end

							if res:IsFalsy() then
								for _, t in ipairs(type_checked:GetData()) do
									if t:GetLuaType() == l_elem:GetData() then falsy_union:AddType(t) end
								end
							end

							new_union:AddType(res)
						end
					end
				end

				self:TrackTableIndexUnion(type_checked, truthy_union, falsy_union)
			else
				self.type_checked = false -- this could happen with something like print(type("foo")) so clear it in case
				for _, l_elem in ipairs(l:GetData()) do
					for _, r_elem in ipairs(r:GetData()) do
						local res, err = Binary(self, node, l_elem, r_elem, op)

						if not res then
							self:Error(err)
						else
							if res:IsTruthy() then truthy_union:AddType(l_elem) end

							if res:IsFalsy() then falsy_union:AddType(l_elem) end

							new_union:AddType(res)
						end
					end
				end
			end

			-- Operator-specific union handling
			if op == "and" or op == "or" then
				return new_union
			elseif op == "==" or op == "!=" or op == "~=" then
				self:TrackTableIndexUnion(l, truthy_union, falsy_union)
				local left_right = l:GetLeftRightSource()

				if left_right then
					local key = left_right.right
					key = key.Type == "union" and key:Simplify() or key
					local union = left_right.left
					local expected = original_r
					local truthy_union_lr = Union():SetUpvalue(upvalue)
					local falsy_union_lr = Union():SetUpvalue(upvalue)

					for _, v in ipairs(union:GetData()) do
						local val, err = self:IndexOperator(v, key)

						if val then
							local l = val
							local r = expected
							local res = BinaryWithUnion(self, node, l, r, op)

							if res:IsTruthy() then truthy_union_lr:AddType(v) end

							if res:IsFalsy() then falsy_union_lr:AddType(v) end
						end
					end

					self:TrackUpvalueUnion(union, truthy_union_lr, falsy_union_lr, op == "==")
					return new_union
				end

				self:TrackUpvalueUnion(l, truthy_union, falsy_union, op ~= "==")
				self:TrackUpvalueUnion(r, truthy_union, falsy_union, op ~= "==")
				return new_union
			else
				-- General handling for other operators with unions
				self:TrackTableIndexUnion(l, truthy_union, falsy_union)

				if
					node.parent.Type ~= "expression_binary_operator" or
					(
						node.parent.value.sub_type ~= (
							"=="
						)
						and
						node.parent.value.sub_type ~= (
							"~="
						)
					)
				then
					self:TrackUpvalueUnion(l, truthy_union, falsy_union)
				end

				self:TrackUpvalueUnion(r, truthy_union, falsy_union)
				return new_union
			end
		end
	end

	-- No unions detected, use regular binary operation
	return Binary(self, node, l, r, op)
end

return {
	BinaryCustom = BinaryWithUnion,
	Binary = function(self, node)
		local op = node.value:GetValueString()
		local l = nil
		local r = nil

		if op == "|" and self:IsTypesystem() then
			local cur_union = Union()
			self:PushCurrentTypeUnion(cur_union)
			local l = self:Assert(self:AnalyzeExpression(node.left))
			local r = self:Assert(self:AnalyzeExpression(node.right))
			self:PopCurrentTypeUnion()
			cur_union:AddType(l)
			cur_union:AddType(r)
			return cur_union
		end

		if op == "and" then
			l = self:Assert(self:AnalyzeExpression(node.left))

			if l.Type == "union" then
				self:TrackUpvalueUnion(l, l:GetTruthy(), l:GetFalsy())
			end

			-- attest.equal(nil and 1, nil)
			if l:IsCertainlyFalse() then
				r = Nil()
			else
				-- right hand side of and is the "true" part
				self:PushTruthyExpressionContext()
				r = self:Assert(self:AnalyzeExpression(node.right))
				self:PopTruthyExpressionContext()

				if r.Type == "union" then
					self:TrackUpvalueUnion(r, r:GetTruthy(), r:GetFalsy())
				end
			end
		elseif op == "or" then
			self:PushFalsyExpressionContext()
			l = self:Assert(self:AnalyzeExpression(node.left))
			self:PopFalsyExpressionContext()

			if l:IsCertainlyFalse() then
				self:PushFalsyExpressionContext()
				r = self:Assert(self:AnalyzeExpression(node.right))
				self:PopFalsyExpressionContext()
			elseif l:IsCertainlyTrue() then
				r = Nil()
			else
				-- right hand side of or is the "false" part
				self.LEFT_SIDE_OR = l
				self:PushFalsyExpressionContext()
				r = self:Assert(self:AnalyzeExpression(node.right))
				self:PopFalsyExpressionContext()
				self.LEFT_SIDE_OR = false

				if r.Type == "union" then
					self:TrackUpvalueUnion(r, r:GetTruthy(), r:GetFalsy())
				end
			end
		else
			l = self:Assert(self:AnalyzeExpression(node.left))
			r = self:Assert(self:AnalyzeExpression(node.right))

			-- TODO: more elegant way of dealing with self?
			if op == ":" then
				self.self_arg_stack = self.self_arg_stack or {}
				table.insert(self.self_arg_stack, l)
			end
		end

		if self:IsRuntime() then
			if l.Type == "tuple" then l = self:GetFirstValue(l) or Nil() end

			if r.Type == "tuple" then r = self:GetFirstValue(r) or Nil() end
		end

		local ok, err = BinaryWithUnion(self, node, l, r, op)

		if not ok and not err then
			print("Binary operator failed without error message", node, op, l, r)
		end

		return ok, err
	end,
}
