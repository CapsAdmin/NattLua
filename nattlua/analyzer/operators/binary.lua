local tostring = tostring
local ipairs = ipairs
local table = require("table")
local LString = require("nattlua.types.string").LString
local String = require("nattlua.types.string").String
local Any = require("nattlua.types.any").Any
local Tuple = require("nattlua.types.tuple").Tuple
local Union = require("nattlua.types.union").Union
local True = require("nattlua.types.symbol").True
local Boolean = require("nattlua.types.symbol").Boolean
local Symbol = require("nattlua.types.symbol").Symbol
local False = require("nattlua.types.symbol").False
local Nil = require("nattlua.types.symbol").Nil
local type_errors = require("nattlua.types.error_messages")

local function metatable_function(self, node, meta_method, l, r)
	meta_method = LString(meta_method)

	if r:GetMetaTable() or l:GetMetaTable() then
		local func = (l:GetMetaTable() and l:GetMetaTable():Get(meta_method)) or
			(r:GetMetaTable() and r:GetMetaTable():Get(meta_method))
		if not func then return end
		if func.Type ~= "function" then return func end
		return self:Assert(node, self:Call(func, Tuple({l, r}))):Get(1)
	end
end

local function operator(self, node, l, r, op, meta_method)
	if op == ".." then
		if
			(l.Type == "string" and r.Type == "string") or
			(l.Type == "number" and r.Type == "string") or
			(l.Type == "number" and r.Type == "number") or
			(l.Type == "string" and r.Type == "number")
		then
			if l:IsLiteral() and r:IsLiteral() then return LString(l:GetData() .. r:GetData()):SetNode(node) end
			return String():SetNode(node)
		end
	end

	if l.Type == "number" and r.Type == "number" then
		return l:ArithmeticOperator(r,op):SetNode(node)
	else
		return metatable_function(self, node, meta_method, l, r)
	end

	return type_errors.binary(op, l, r)
end

local function logical_cmp_cast(val--[[#: boolean | nil]], err--[[#: string | nil]])
	if err then
		return val, err
	end

	if val == nil then
		return Boolean()
	elseif val == true then
		return True()
	elseif val == false then
		return False()
	end
end

local function Binary(self, node, l, r, op)
	op = op or node.value.value

	if not l and not r then
		if node.value.value == "and" then
			l = self:AnalyzeExpression(node.left)
	
			if l:IsCertainlyFalse() then
				r = Nil():SetNode(node.right)
			else
				-- if a and a.foo then
				-- ^ no binary operator means that it was just checked simply if it was truthy
				if node.left.kind ~= "binary_operator" or node.left.value.value ~= "." then
					self:TrackUpvalue(l)
				end

				-- right hand side of and is the "true" part
				self:PushTruthyExpressionContext()
				r = self:AnalyzeExpression(node.right)				
				self:PopTruthyExpressionContext()

				if node.right.kind ~= "binary_operator" or node.right.value.value ~= "." then
					self:TrackUpvalue(r)
				end
			end
		elseif node.value.value == "or" then
			self:PushFalsyExpressionContext()
			l = self:AnalyzeExpression(node.left)
			self:PopFalsyExpressionContext()
			
			if l:IsCertainlyFalse() then
				self:PushFalsyExpressionContext()
				r = self:AnalyzeExpression(node.right)
				self:PopFalsyExpressionContext()
			elseif l:IsCertainlyTrue() then
				r = Nil():SetNode(node.right)
			else
				-- right hand side of or is the "false" part
				self:PushFalsyExpressionContext()
				r = self:AnalyzeExpression(node.right)
				self:PopFalsyExpressionContext()
			end
		else
			l = self:AnalyzeExpression(node.left)
			r = self:AnalyzeExpression(node.right)
		end

		-- TODO: more elegant way of dealing with self?
		if op == ":" then
			self.self_arg_stack = self.self_arg_stack or {}
			table.insert(self.self_arg_stack, l)
		end
	end

	if self:IsTypesystem() then
		if op == "|" then
			return Union({l, r})
		elseif op == "==" then
			return l:Equal(r) and True() or False()
		elseif op == "~" then
			if l.Type == "union" then
				return l:RemoveType(r)
			end
			return l
		elseif op == "&" or op == "extends" then
			if l.Type ~= "table" then return false, "type " .. tostring(l) .. " cannot be extended" end
			return l:Extend(r)
		elseif op == ".." then
			if l.Type == "tuple" and r.Type == "tuple" then
				return l:Copy():Concat(r)
			elseif l.Type == "string" and r.Type == "string" then
				return LString(l:GetData() .. r:GetData())
			else
				return l:Copy():SetMax(r)
			end
		elseif op == ">" then
			return Symbol((r:IsSubsetOf(l)))
		elseif op == "<" then
			return Symbol((l:IsSubsetOf(r)))
		elseif op == "supersetof" then
			return Symbol((r:IsSubsetOf(l)))
		elseif op == "subsetof" then
			return Symbol((l:IsSubsetOf(r)))
		elseif op == "+" then
			if l.Type == "table" and r.Type == "table" then return l:Union(r) end
		end
	end

	-- adding two tuples at runtime in lua will basically do this
	if self:IsRuntime() then
		if l.Type == "tuple" then
			l = self:Assert(node, l:GetFirstValue())
		end

		if r.Type == "tuple" then
			r = self:Assert(node, r:GetFirstValue())
		end
	end

	do -- union unpacking
		-- normalize l and r to be both unions to reduce complexity
		if l.Type ~= "union" and r.Type == "union" then
			l = Union({l})
		end

		if l.Type == "union" and r.Type ~= "union" then
			r = Union({r})
		end

		if l.Type == "union" and r.Type == "union" then
			local new_union = Union()
			local truthy_union = Union():SetUpvalue(l:GetUpvalue())
			local falsy_union = Union():SetUpvalue(l:GetUpvalue())
			
			for _, l in ipairs(l:GetData()) do
				for _, r in ipairs(r:GetData()) do
					local res, err = Binary(
						self,
						node,
						l,
						r,
						op
					)

					if not res then
						self:ErrorAndCloneCurrentScope(node, err, l) -- TODO, only left side?
					else
						if res:IsTruthy() then
							if self.type_checked then
								for _, t in ipairs(self.type_checked:GetData()) do
									if t.GetLuaType and t:GetLuaType() == l:GetData() then
										truthy_union:AddType(t)
									end
								end
							else
								truthy_union:AddType(l)
							end
						end

						if res:IsFalsy() then
							if self.type_checked then
								for _, t in ipairs(self.type_checked:GetData()) do
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

			-- the return value from type(x)
			if self.type_checked then
				new_union.type_checked = self.type_checked
				self.type_checked = nil
			end

			if op == "~=" then
				self.notlol = true
			end

			if op ~= "or" and op ~= "and" then
				self:TrackUpvalue(l, truthy_union, falsy_union)
				self:TrackUpvalue(r, truthy_union, falsy_union)
			end

			if op == "~=" then
				self.notlol = nil
			end

			return
				new_union:SetNode(node):SetTypeSource(new_union):SetTypeSourceLeft(l):SetTypeSourceRight(r)
		end
	end

	if l.Type == "any" or r.Type == "any" then return Any() end

	do -- arithmetic operators
		if op == "." or op == ":" then
			return self:IndexOperator(node, l, r) 
		elseif op == "+" then
			local val = operator(self, node, l, r, op, "__add")
			if val then return val end
		elseif op == "-" then
			local val = operator(self, node, l, r, op, "__sub")
			if val then return val end
		elseif op == "*" then
			local val = operator(self, node, l, r, op, "__mul")
			if val then return val end
		elseif op == "/" then
			local val = operator(self, node, l, r, op, "__div")
			if val then return val end
		elseif op == "/idiv/" then
			local val = operator(self, node, l, r, op, "__idiv")
			if val then return val end
		elseif op == "%" then
			local val = operator(self, node, l, r, op, "__mod")
			if val then return val end
		elseif op == "^" then
			local val = operator(self, node, l, r, op, "__pow")
			if val then return val end
		elseif op == "&" then
			local val = operator(self, node, l, r, op, "__band")
			if val then return val end
		elseif op == "|" then
			local val = operator(self, node, l, r, op, "__bor")
			if val then return val end
		elseif op == "~" then
			local val = operator(self, node, l, r, op, "__bxor")
			if val then return val end
		elseif op == "<<" then
			local val = operator(self, node, l, r, op, "__lshift")
			if val then return val end
		elseif op == ">>" then
			local val = operator(self, node, l, r, op, "__rshift")
			if val then return val end
		elseif op == ".." then
			local val = operator(self, node, l, r, op, "__concat")
			if val then return val end
		end
	end

	do -- logical operators
		if op == "==" then
			local res = metatable_function(self, node, "__eq", l, r)
			if res then return res end
			
			if l == r then return True() end
			if l.Type ~= r.Type then return False() end

			return logical_cmp_cast(l.LogicalComparison(l, r, op, self:GetCurrentAnalyzerEnvironment()))
		elseif op == "~=" or op == "!=" then
			local res = metatable_function(self, node, "__eq", l, r)

			if res then
				if res:IsLiteral() then res:SetData(not res:GetData()) end
				return res
			end

			if l.Type ~= r.Type then return True() end

			local val, err = l.LogicalComparison(l, r, "==", self:GetCurrentAnalyzerEnvironment())
			if val ~= nil then val = not val end
			return logical_cmp_cast(val, err)
		elseif op == "<" then
			local res = metatable_function(self, node, "__lt", l, r)
			if res then return res end
			return logical_cmp_cast(l.LogicalComparison(l, r, op))
		elseif op == "<=" then
			local res = metatable_function(self, node, "__le", l, r)
			if res then return res end
			return logical_cmp_cast(l.LogicalComparison(l, r, op))
		elseif op == ">" then
			local res = metatable_function(self, node, "__lt", l, r)
			if res then return res end
			 return logical_cmp_cast(l.LogicalComparison(l, r, op)) 
		elseif op == ">=" then
			local res = metatable_function(self, node, "__le", l, r)
			if res then return res end
			return logical_cmp_cast(l.LogicalComparison(l, r, op))
		elseif op == "or" or op == "||" then
			-- boolean or boolean
			if l:IsUncertain() or r:IsUncertain() then return Union({l, r}):SetNode(node):SetTypeSourceLeft(l):SetTypeSourceRight(r) end

			-- true or boolean
			if l:IsTruthy() then return l:Copy():SetNode(node):SetTypeSource(l):SetTypeSourceLeft(l):SetTypeSourceRight(r) end
			
			-- false or true
			if r:IsTruthy() then return r:Copy():SetNode(node):SetTypeSource(r):SetTypeSourceLeft(l):SetTypeSourceRight(r) end
			return r:Copy():SetNode(node):SetTypeSource(r)
		elseif op == "and" or op == "&&" then

			-- true and false
			if l:IsTruthy() and r:IsFalsy() then
				if l:IsFalsy() or r:IsTruthy() then return Union({l, r}):SetNode(node):SetTypeSourceLeft(l):SetTypeSourceRight(r) end
				return
					r:Copy():SetNode(node):SetTypeSource(r):SetTypeSourceLeft(l):SetTypeSourceRight(r)
			end

			-- false and true
			if l:IsFalsy() and r:IsTruthy() then
				if l:IsTruthy() or r:IsFalsy() then return Union({l, r}):SetNode(node):SetTypeSourceLeft(l):SetTypeSourceRight(r) end
				return
					l:Copy():SetNode(node):SetTypeSource(l):SetTypeSourceLeft(l):SetTypeSourceRight(r)
			end

			-- true and true
			if l:IsTruthy() and r:IsTruthy() then
				if l:IsFalsy() and r:IsFalsy() then return Union({l, r}):SetNode(node):SetTypeSourceLeft(l):SetTypeSourceRight(r) end
				return
					r:Copy():SetNode(node):SetTypeSource(r):SetTypeSourceLeft(l):SetTypeSourceRight(r)
			else
				-- false and false
				if l:IsTruthy() and r:IsTruthy() then return Union({l, r}):SetNode(node):SetTypeSourceLeft(l):SetTypeSourceRight(r) end
				return
					l:Copy():SetNode(node):SetTypeSource(l):SetTypeSourceLeft(l):SetTypeSourceRight(r)
			end
		end
	end

	return type_errors.binary(op, l, r)
end

return {Binary = Binary}
