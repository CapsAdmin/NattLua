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
local type_errors = require("nattlua.types.error_messages")

local function metatable_function(self, node, meta_method, l, r)
	meta_method = ConstString(meta_method)
	local r_metatable = (r.Type == "table" or r.Type == "string") and r:GetMetaTable()
	local l_metatable = (l.Type == "table" or l.Type == "string") and l:GetMetaTable()

	if r_metatable or l_metatable then
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

local function operator(self, node, l, r, op, meta_method)
	if op == ".." then
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
	end

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

	if
		(
			l.Type == "number" or
			l.Type == "range"
		)
		and
		(
			r.Type == "number" or
			r.Type == "range"
		)
	then
		return l:BinaryOperator(r, op)
	else
		local res = metatable_function(self, node, meta_method, l, r)

		if res then return res end
	end

	return false, type_errors.binary(op, l, r)
end

local function logical_cmp_cast(val--[[#: boolean | nil]], err--[[#: string | nil]])
	if not val and err then return val, type_errors.plain_error(err) end

	if val == nil then
		return Boolean()
	elseif val == true then
		return True()
	elseif val == false then
		return False()
	end
end

local intersect_comparison = require("nattlua.analyzer.intersect_comparison")

local function number_comparison(self, l, r, op, invert)
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

local function Binary(self, node, l, r, op)
	op = op or node.value.value
	local cur_union

	if op == "|" and self:IsTypesystem() then
		cur_union = Union()
		self:PushCurrentType(cur_union, "union")
	end

	if not l and not r then
		if node.value.value == "and" then
			l = self:AnalyzeExpression(node.left)

			if l:IsCertainlyFalse() then
				r = Nil()
			else
				-- if a and a.foo then
				-- ^ no binary operator means that it was just checked simply if it was truthy
				if node.left.kind ~= "binary_operator" or node.left.value.value ~= "." then
					if l.Type == "union" then
						self:TrackUpvalueUnion(l, l:GetTruthy(), l:GetFalsy())
					else
						self:TrackUpvalue(l)
					end
				end

				-- right hand side of and is the "true" part
				self:PushTruthyExpressionContext(true)
				r = self:AnalyzeExpression(node.right)
				self:PopTruthyExpressionContext()

				if node.right.kind ~= "binary_operator" or node.right.value.value ~= "." then
					if r.Type == "union" then
						self:TrackUpvalueUnion(r, r:GetTruthy(), r:GetFalsy())
					else
						self:TrackUpvalue(r)
					end
				end
			end
		elseif node.value.value == "or" then
			self:PushFalsyExpressionContext(true)
			l = self:AnalyzeExpression(node.left)
			self:PopFalsyExpressionContext()

			if l:IsCertainlyFalse() then
				self:PushFalsyExpressionContext(true)
				r = self:AnalyzeExpression(node.right)
				self:PopFalsyExpressionContext()
			elseif l:IsCertainlyTrue() then
				r = Nil()
			else
				-- right hand side of or is the "false" part
				self.LEFT_SIDE_OR = l
				self:PushFalsyExpressionContext(true)
				r = self:AnalyzeExpression(node.right)
				self:PopFalsyExpressionContext()
				self.LEFT_SIDE_OR = nil

				if node.right.kind ~= "binary_operator" or node.right.value.value ~= "." then
					if r.Type == "union" then
						self:TrackUpvalueUnion(r, r:GetTruthy(), r:GetFalsy())
					else
						self:TrackUpvalue(r)
					end
				end
			end
		else
			l = self:Assert(self:AnalyzeExpression(node.left))
			r = self:Assert(self:AnalyzeExpression(node.right))
		end

		self:TrackUpvalue(l)
		self:TrackUpvalue(r)

		-- TODO: more elegant way of dealing with self?
		if op == ":" then
			self.self_arg_stack = self.self_arg_stack or {}
			table.insert(self.self_arg_stack, l)
		end
	end

	if cur_union then self:PopCurrentType("union") end

	if self:IsTypesystem() then
		if op == "|" then
			cur_union:AddType(l)
			cur_union:AddType(r)
			return cur_union
		elseif op == "==" then
			return l:Equal(r) and True() or False()
		elseif op == "~" then
			if l.Type == "union" then return l:RemoveType(r) end

			return l
		elseif op == "&" or op == "extends" then
			if l.Type ~= "table" then
				return false, "type " .. tostring(l) .. " cannot be extended"
			end

			return l:Extend(r)
		elseif op == ".." then
			if l.Type == "tuple" and r.Type == "tuple" then
				return l:Copy():Concat(r)
			elseif l.Type == "string" and r.Type == "string" then
				if l:IsLiteral() and r:IsLiteral() then
					return LString(l:GetData() .. r:GetData())
				end

				return false, type_errors.binary(op, l, r)
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
		elseif op == ">" or op == "supersetof" then
			return Symbol((r:IsSubsetOf(l)))
		elseif op == "<" or op == "subsetof" then
			return Symbol((l:IsSubsetOf(r)))
		elseif op == "+" then
			if l.Type == "table" and r.Type == "table" then return l:Union(r) end
		end
	end

	-- adding two tuples at runtime in lua will basically do this
	if self:IsRuntime() then
		if l.Type == "tuple" then l = self:GetFirstValue(l) or Nil() end

		if r.Type == "tuple" then r = self:GetFirstValue(r) or Nil() end
	end

	do -- union unpacking
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
			local type_checked = self.type_checked

			-- the return value from type(x)
			if type_checked then self.type_checked = false end

			for _, l in ipairs(l:GetData()) do
				for _, r in ipairs(r:GetData()) do
					local res, err = Binary(self, node, l, r, op)

					if not res then
						self:Error(err)
					else
						if res:IsTruthy() then
							if type_checked then
								for _, t in ipairs(type_checked:GetData()) do
									if t:GetLuaType() == l:GetData() then
										truthy_union:AddType(t)
									end
								end
							else
								truthy_union:AddType(l)
							end
						end

						if res:IsFalsy() then
							if type_checked then
								for _, t in ipairs(type_checked:GetData()) do
									if t:GetLuaType() == l:GetData() then
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

			if op ~= "or" and op ~= "and" then
				local tbl_key = l:GetParentTable() or type_checked and type_checked:GetParentTable()

				if tbl_key then
					self:TrackTableIndexUnion(tbl_key.table, tbl_key.key, truthy_union, falsy_union)
				elseif l.Type == "union" then
					for _, l in ipairs(l:GetData()) do
						if l.Type == "union" then
							local tbl_key = l:GetParentTable()

							if tbl_key then
								self:TrackTableIndexUnion(tbl_key.table, tbl_key.key, truthy_union, falsy_union)
							end
						end
					end
				end

				local left_right = l:GetLeftRightSource()

				if (op == "==" or op == "~=") and left_right then
					local key = left_right.right
					local union = left_right.left
					local expected = r
					local truthy_union = Union():SetUpvalue(upvalue)
					local falsy_union = Union():SetUpvalue(upvalue)

					for k, v in ipairs(union.Data) do
						local val = v:Get(key)

						if val then
							local res = Binary(self, node, val, expected, op)

							if res:IsTruthy() then truthy_union:AddType(v) end

							if res:IsFalsy() then falsy_union:AddType(v) end
						end
					end

					if not truthy_union:IsEmpty() or not falsy_union:IsEmpty() then
						self:TrackUpvalueUnion(union, truthy_union, falsy_union, op == "~=")
						return new_union
					end
				end

				if
					node.parent.kind == "binary_operator" and
					(
						node.parent.value.value == "==" or
						node.parent.value.value == "~="
					)
				then

				else
					self:TrackUpvalueUnion(l, truthy_union, falsy_union, op == "~=")
				end

				self:TrackUpvalueUnion(r, truthy_union, falsy_union, op == "~=")
			end

			if upvalue then upvalue:SetTruthyFalsyUnion(truthy_union, falsy_union) end

			return new_union
		end
	end

	if l.Type == "any" or r.Type == "any" then return Any() end

	do -- arithmetic operators
		if op == "." or op == ":" then
			return self:IndexOperator(l, r)
		elseif op == "+" then
			return operator(self, node, l, r, op, "__add")
		elseif op == "-" then
			return operator(self, node, l, r, op, "__sub")
		elseif op == "*" then
			return operator(self, node, l, r, op, "__mul")
		elseif op == "/" then
			return operator(self, node, l, r, op, "__div")
		elseif op == "/idiv/" then
			return operator(self, node, l, r, op, "__idiv")
		elseif op == "%" then
			return operator(self, node, l, r, op, "__mod")
		elseif op == "^" then
			return operator(self, node, l, r, op, "__pow")
		elseif op == "&" then
			return operator(self, node, l, r, op, "__band")
		elseif op == "|" then
			return operator(self, node, l, r, op, "__bor")
		elseif op == "~" then
			return operator(self, node, l, r, op, "__bxor")
		elseif op == "<<" then
			return operator(self, node, l, r, op, "__lshift")
		elseif op == ">>" then
			return operator(self, node, l, r, op, "__rshift")
		elseif op == ".." then
			return operator(self, node, l, r, op, "__concat")
		end
	end

	do -- logical operators
		if op == "==" then
			local res = metatable_function(self, node, "__eq", l, r)

			if res then return res end

			if l:IsNumeric() and r:IsNumeric() then
				local res = number_comparison(self, l, r, op)

				if res then return res end
			end

			if l.Type ~= r.Type then return False() end

			return logical_cmp_cast(l.LogicalComparison(l, r, op, self:GetCurrentAnalyzerEnvironment()))
		elseif op == "~=" or op == "!=" then
			local res = metatable_function(self, node, "__eq", l, r)

			if res then
				if res:IsLiteral() then
					res = not res:GetData() and True() or False()
				end

				return res
			end

			if l:IsNumeric() and r:IsNumeric() then
				local res = number_comparison(self, l, r, op, true)

				if res then return res end
			end

			if l.Type ~= r.Type then return True() end

			local val, err = l.LogicalComparison(l, r, "==", self:GetCurrentAnalyzerEnvironment())

			if val ~= nil then val = not val end

			return logical_cmp_cast(val, err)
		elseif op == "<" then
			local res = metatable_function(self, node, "__lt", l, r)

			if res then return res end

			if l:IsNumeric() and r:IsNumeric() then
				local res = number_comparison(self, l, r, op)

				if res then return res end
			end

			return logical_cmp_cast(l.LogicalComparison(l, r, op))
		elseif op == "<=" then
			local res = metatable_function(self, node, "__le", l, r)

			if res then return res end

			if l:IsNumeric() and r:IsNumeric() then
				local res = number_comparison(self, l, r, op)

				if res then return res end
			end

			return logical_cmp_cast(l.LogicalComparison(l, r, op))
		elseif op == ">" then
			local res = metatable_function(self, node, "__lt", l, r)

			if res then return res end

			if l:IsNumeric() and r:IsNumeric() then
				local res = number_comparison(self, l, r, op)

				if res then return res end
			end

			return logical_cmp_cast(l.LogicalComparison(l, r, op))
		elseif op == ">=" then
			local res = metatable_function(self, node, "__le", l, r)

			if res then return res end

			if l:IsNumeric() and r:IsNumeric() then
				local res = number_comparison(self, l, r, op)

				if res then return res end
			end

			return logical_cmp_cast(l.LogicalComparison(l, r, op))
		elseif op == "or" or op == "||" then
			-- boolean or boolean
			if l:IsUncertain() or r:IsUncertain() then return Union({l, r}) end

			-- true or boolean
			if l:IsTruthy() then return l:Copy() end

			-- false or true
			if r:IsTruthy() then return r:Copy() end

			return r:Copy()
		elseif op == "and" or op == "&&" then
			-- true and false
			if l:IsTruthy() and r:IsFalsy() then
				if l:IsFalsy() or r:IsTruthy() then return Union({l, r}) end

				return r:Copy()
			end

			-- false and true
			if l:IsFalsy() and r:IsTruthy() then
				if l:IsTruthy() or r:IsFalsy() then return Union({l, r}) end

				return l:Copy()
			end

			-- true and true
			if l:IsTruthy() and r:IsTruthy() then
				if l:IsFalsy() and r:IsFalsy() then return Union({l, r}) end

				return r:Copy()
			else
				-- false and false
				if l:IsTruthy() and r:IsTruthy() then return Union({l, r}) end

				return l:Copy()
			end
		end
	end

	return false, type_errors.binary(op, l, r)
end

return {Binary = Binary}
