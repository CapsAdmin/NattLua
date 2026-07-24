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
local shared = require("nattlua.types.shared")
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

local function number_comparison(self, l, r, op)
	-- For relational operators, the constraint store now handles narrowing
	-- (both discrete unions and ranges). Skip the old intersect_comparison
	-- system to avoid conflicts.
	local is_relational = op == "<" or op == ">" or op == "<=" or op == ">="

	if is_relational then
		-- Track relational constraint for non-union types (ranges, literals)
		if self.constraint_store then
			local l_upvalue = l:GetUpvalue()
			local r_upvalue = r:GetUpvalue()
			self.constraint_store:TrackRelationalCorrelation(op, l_upvalue, r_upvalue, l, r)
		end

		-- Determine result if both are literals
		local l_val = l:IsLiteral() and l:GetData()
		local r_val = r:IsLiteral() and r:GetData()

		if
			l_val ~= nil and
			r_val ~= nil and
			type(l_val) == "number" and
			type(r_val) == "number"
		then
			if op == "<" then
				return l_val < r_val and True() or False()
			elseif op == ">" then
				return l_val > r_val and True() or False()
			elseif op == "<=" then
				return l_val <= r_val and True() or False()
			elseif op == ">=" then
				return l_val >= r_val and True() or False()
			end
		end

		-- Range-based constant folding: determine if comparison is always true/false
		local function get_range_bounds(t)
			if t.Type == "range" then
				return t:GetMin(), t:GetMax()
			elseif t:IsLiteral() and type(t:GetData()) == "number" then
				local v = t:GetData()
				return v, v
			end

			return nil, nil
		end

		local l_min, l_max = get_range_bounds(l)
		local r_min, r_max = get_range_bounds(r)

		if l_min ~= nil and l_max ~= nil and r_min ~= nil and r_max ~= nil then
			-- Both sides have known bounds, check if result is determinable
			local always_true, always_false = false, false

			if op == "<" then
				-- l < r: always true if l_max < r_min, always false if l_min >= r_max
				if l_max < r_min then
					always_true = true
				elseif l_min >= r_max then
					always_false = true
				end
			elseif op == ">" then
				-- l > r: always true if l_min > r_max, always false if l_max <= r_min
				if l_min > r_max then
					always_true = true
				elseif l_max <= r_min then
					always_false = true
				end
			elseif op == "<=" then
				-- l <= r: always true if l_max <= r_min, always false if l_min > r_max
				if l_max <= r_min then
					always_true = true
				elseif l_min > r_max then
					always_false = true
				end
			elseif op == ">=" then
				-- l >= r: always true if l_min >= r_max, always false if l_max < r_min
				if l_min >= r_max then
					always_true = true
				elseif l_max < r_min then
					always_false = true
				end
			end

			if always_true then return True() end

			if always_false then return False() end
		end

		return Boolean()
	end

	-- Track equality correlation for == and ~= (non-union path: ranges, literals)
	if (op == "==" or op == "~=") and self.constraint_store then
		local l_upvalue = l:GetUpvalue()
		local r_upvalue = r:GetUpvalue()
		self.constraint_store:TrackEqualityCorrelation(op, l_upvalue, r_upvalue, l, r)
	end

	-- Old tracking system still needed for GetTrackedUpvalue to find narrowed values
	local intersect_comparison = require("nattlua.analyzer.intersect_comparison")
	local invert = op == "~=" or op == "!="
	local nl, nr, nl2, nr2 = intersect_comparison(l, r, op, invert)

	if nl and nr then self.narrowing_store:TrackUpvalueUnion(l, nl, nr, nil, self) end

	if nl2 and nr2 then
		self.narrowing_store:TrackUpvalueUnion(r, nl2, nr2, nil, self)
	end

	-- NaN handling: NaN == NaN is false, NaN ~= NaN is true
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
	elseif op == "??" then
		if l.Type == "any" or r.Type == "any" then return Any() end

		if l:IsCertainlyNil() then return r:Copy() end

		if l:IsCertainlyNotNil() then return l:Copy() end

		return Union({l, r}):Simplify()
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
			local val, err = shared.LogicalComparison(l, r, "==", self:GetCurrentAnalyzerEnvironment())

			if val ~= nil then val = not val end

			return logical_cmp_cast(val, err)
		end

		return logical_cmp_cast(shared.LogicalComparison(l, r, op, self:GetCurrentAnalyzerEnvironment()))
	elseif op == "." or op == ":" then
		return self:IndexOperator(l, r)
	elseif op == "?." then
		-- Safe navigation: if l is nil, return nil; otherwise, index into l
		if l.Type == "any" then return Any() end

		if l:IsCertainlyNil() then return Nil() end

		local result = self:IndexOperator(l, r)

		if result then return result end

		return Nil()
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

		return logical_cmp_cast(shared.LogicalComparison(l, r, op))
	end

	return false, error_messages.binary(op, l, r)
end

local function BinaryWithUnion(self, node, l, r, op)
	if l.Type == "any" or r.Type == "any" then return Any() end

	if l.Type == "deferred" then l = l:Unwrap() end

	if r.Type == "deferred" then r = r:Unwrap() end

	if self:IsTypesystem() then
		if op == "==" then
			return shared.Equal(l, r) and True() or False()
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
			return shared.IsSubsetOf(r, l) and True() or False()
		elseif op == "subsetof" then
			return shared.IsSubsetOf(l, r) and True() or False()
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
			new_union:SetLeftRightSource(l, r, op)
			local truthy_union = Union():SetUpvalue(upvalue)
			local falsy_union = Union():SetUpvalue(upvalue)

			if upvalue then upvalue:SetTruthyFalsyUnion(truthy_union, falsy_union) end

			-- Store truthy/falsy on the left value for table field narrowing
			-- through stored checks (e.g., local check = t.x ~= nil; if check then)
			if l:GetParentTable() then l:SetStoredTruthyFalsy(truthy_union, falsy_union) end

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

				self.narrowing_store:TrackTableIndexUnion(type_checked, truthy_union, falsy_union, nil, self)
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

			if op == "and" or op == "or" or op == "??" then
				return new_union
			elseif op == "==" or op == "!=" or op == "~=" then
				self.narrowing_store:TrackTableIndexUnion(l, truthy_union, falsy_union, nil, self)
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

					self.narrowing_store:TrackUpvalueUnion(union, truthy_union_lr, falsy_union_lr, op == "==", self)
					return new_union
				end

				self.narrowing_store:TrackUpvalueUnion(l, truthy_union, falsy_union, op ~= "==", self)
				self.narrowing_store:TrackUpvalueUnion(r, truthy_union, falsy_union, op ~= "==", self)
				-- Track correlation between upvalues when comparing with == or ~=
				self.constraint_store:TrackEqualityCorrelation(op, original_l:GetUpvalue(), original_r:GetUpvalue(), l, r)
				return new_union
			elseif op == "<" or op == ">" or op == "<=" or op == ">=" then
				-- Relational narrowing is fully handled by the constraint store
				-- (both discrete unions and ranges). Skip TrackUpvalueUnion to avoid conflicts.
				self.constraint_store:TrackRelationalCorrelation(op, original_l:GetUpvalue(), original_r:GetUpvalue(), l, r)
				return new_union
			else
				-- General handling for other operators with unions
				local cs = self.constraint_store
				local tag_info = cs:QueryCorrelatedComputation(original_l, original_r, l, r, ARITHMETIC_OPS, op)

				if tag_info then
					local new_union = Union()
					local source_map = {}

					for _, l_elem in ipairs(l:GetData()) do
						for _, r_elem in ipairs(r:GetData()) do
							if tag_info.predicate(l_elem, r_elem) then
								local res, err = Binary(self, node, l_elem, r_elem, op)

								if res then
									new_union:AddType(res)

									if tag_info.track_sources then source_map[res] = l_elem end
								else
									self:Error(err)
								end
							end
						end
					end

					cs:TagCorrelatedResult(new_union, tag_info, source_map)
					self.narrowing_store:TrackTableIndexUnion(l, truthy_union, falsy_union, nil, self)
					self.narrowing_store:TrackUpvalueUnion(l, truthy_union, falsy_union, nil, self)
					self.narrowing_store:TrackUpvalueUnion(r, truthy_union, falsy_union, nil, self)
					return new_union:Simplify()
				end

				self.narrowing_store:TrackTableIndexUnion(l, truthy_union, falsy_union, nil, self)

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
					self.narrowing_store:TrackUpvalueUnion(l, truthy_union, falsy_union, nil, self)
				end

				self.narrowing_store:TrackUpvalueUnion(r, truthy_union, falsy_union, nil, self)
				return new_union
			end
		end
	end

	-- No unions detected, use regular binary operation
	return Binary(self, node, l, r, op)
end

local function is_condition_expression(node)
	-- walk up through nested binary operators to find if we're
	-- inside a conditional statement's expression (if/while/repeat)
	local n = node

	while n do
		local parent = n.parent

		if not parent then break end

		local pt = parent.Type

		if pt == "statement_if" or pt == "statement_while" or pt == "statement_repeat" then
			return true
		end

		-- keep walking up through nested binary/prefix operators
		if pt == "expression_binary_operator" or pt == "expression_prefix_operator" then
			n = parent
		else
			break
		end
	end

	return false
end

return {
	BinaryCustom = BinaryWithUnion,
	BinaryInner = Binary,
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
				self.narrowing_store:TrackUpvalueUnion(l, l:GetTruthy(), l:GetFalsy(), nil, self)
			end

			-- attest.equal(nil and 1, nil)
			if l:IsCertainlyFalse() then
				r = Nil()
			else
				-- right hand side of and is the "true" part
				-- create a conditional scope so narrowing is visible inside function calls
				-- but only when not already inside a conditional statement (if/while/repeat handle their own scopes)
				local tracked, scope

				if not is_condition_expression(node) then
					tracked = self.narrowing_store:GetTrackedObjects(nil, nil, self)
					scope = self:PushConditionalScope(node, l:IsTruthy(), l:IsFalsy())
					scope:SetTrackedNarrowings(tracked)
					self.narrowing_store:ApplyMutationsInIf(tracked, self)
				end

				-- Fork constraint store for disjunction handling
				-- Left branch (falsy): left was false, result is false
				-- Right branch (truthy): left was true, right side evaluates here
				-- Skip fork when left side is pure boolean (no mixed upvalue types to preserve)
				local forked_store
				local skip_fork = (l.Type == "union") and (l.GetData ~= nil) and (#l:GetData() <= 2)

				if self.constraint_store then
					if not skip_fork then forked_store = self.constraint_store:Fork() end

					-- Apply relational narrowing so the right side sees narrowed values
					self.constraint_store:ApplyRelationalNarrowing(self)
				end

				self.narrowing_store:PushTruthyExpressionContext()
				r = self:Assert(self:AnalyzeExpression(node.right))
				self.narrowing_store:PopTruthyExpressionContext()

				if r.Type == "union" then
					self.narrowing_store:TrackUpvalueUnion(r, r:GetTruthy(), r:GetFalsy(), nil, self)
				end

				-- Merge: union domains from both branches of the and-expression
				if forked_store and self.constraint_store then
					self.constraint_store:Merge(forked_store)
					-- Re-apply relational narrowing after merge (merge may have widened domains)
					self.constraint_store:ApplyRelationalNarrowing(self)
				end

				if scope then
					self.narrowing_store:ClearScopedTrackedObjects(scope)
					self:PopConditionalScope()
				end
			end
		elseif op == "??" then
			l = self:Assert(self:AnalyzeExpression(node.left)):GetFirstValue()

			if l.Type == "union" then
				self.narrowing_store:TrackUpvalueUnion(l, l:GetTruthy(), l:GetFalsy(), nil, self)
			end

			if l:IsCertainlyNil() then
				r = self:Assert(self:AnalyzeExpression(node.right)):GetFirstValue()
				return r
			elseif l:IsCertainlyNotNil() then
				return l
			else
				local tracked, scope

				if not is_condition_expression(node) then
					tracked = self.narrowing_store:GetTrackedObjects(nil, nil, self)
					scope = self:PushConditionalScope(node, l:CanBeNil(), not l:CanBeNil())
					scope:SetTrackedNarrowings(tracked)
					self.narrowing_store:ApplyMutationsInIf(tracked, self)
				end

				self.narrowing_store:PushTruthyExpressionContext()
				r = self:Assert(self:AnalyzeExpression(node.right)):GetFirstValue()
				self.narrowing_store:PopTruthyExpressionContext()

				if scope then
					self.narrowing_store:ClearScopedTrackedObjects(scope)
					self:PopConditionalScope()
				end

				if r.Type == "union" then
					self.narrowing_store:TrackUpvalueUnion(r, r:GetTruthy(), r:GetFalsy(), nil, self)
				end

				return Union({l, r}):Simplify()
			end
		elseif op == "or" then
			self.narrowing_store:PushFalsyExpressionContext()
			l = self:Assert(self:AnalyzeExpression(node.left))
			self.narrowing_store:PopFalsyExpressionContext()

			if l.Type == "union" then
				self.narrowing_store:TrackUpvalueUnion(l, l:GetTruthy(), l:GetFalsy(), nil, self)
			end

			if l:IsCertainlyFalse() then
				self.narrowing_store:PushFalsyExpressionContext()
				r = self:Assert(self:AnalyzeExpression(node.right))
				self.narrowing_store:PopFalsyExpressionContext()
			elseif l:IsCertainlyTrue() then
				r = Nil()
			else
				-- right hand side of or is the "false" part
				-- create a conditional scope so narrowing is visible inside function calls
				-- but only when not already inside a conditional statement (if/while/repeat handle their own scopes)
				local tracked, scope

				if not is_condition_expression(node) then
					tracked = self.narrowing_store:GetTrackedObjects(nil, nil, self)
					scope = self:PushConditionalScope(node, l:IsTruthy(), l:IsFalsy())
					scope:SetTrackedNarrowings(tracked)
					scope:SetElseConditionalScope(true)
				-- NOTE: We intentionally skip ApplyMutationsInIfElse here.
				-- The constraint store handles narrowing via fork/merge semantics
				-- for or-conditions. Applying mutations here would narrow upvalues
				-- before the fork, corrupting the disjunction handling.
				end

				-- Fork constraint store for disjunction handling
				-- The forked store represents the right branch (left side was falsy)
				-- The main store represents the left branch (left side was truthy)
				local forked_store

				if self.constraint_store then
					forked_store = self.constraint_store:Fork()
					-- Clear equality constraints from the forked store.
					-- Equality constraints from the left side (e.g., x == 1) should
					-- only apply in the left branch. The right branch may have its own
					-- equality constraints (e.g., y == 2) that get added during analysis.
					forked_store:ClearEqualityConstraints()
					-- Apply equality narrowing on the forked store so the right branch
					-- sees correct narrowings from its own constraints (added during right-side eval)
					forked_store:ApplyEqualityNarrowing(self)

					-- Mark arithmetic constraints dirty and propagate on forked store
					for _, c in pairs(forked_store.constraints) do
						if c.type == "arithmetic" then c.dirty = true end
					end

					forked_store:PropagateUntilFixedPoint(self)
				end

				self.LEFT_SIDE_OR = l
				self.narrowing_store:PushFalsyExpressionContext()
				r = self:Assert(self:AnalyzeExpression(node.right))
				self.narrowing_store:PopFalsyExpressionContext()
				self.LEFT_SIDE_OR = false

				if r.Type == "union" then
					self.narrowing_store:TrackUpvalueUnion(r, r:GetTruthy(), r:GetFalsy(), nil, self)
				end

				-- Merge: union domains from both branches of the or-expression
				-- Main store has left-branch state; forked store has right-branch state
				if forked_store and self.constraint_store then
					self.constraint_store:Merge(forked_store)
				end

				if scope then
					self.narrowing_store:ClearScopedTrackedObjects(scope)
					self:PopConditionalScope()
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
