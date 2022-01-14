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

local function Prefix(self, node, r)
	local op = node.value.value

	if not r then
		if op == "not" then
			self.notlol = true
		end
		r = self:AnalyzeExpression(node.right)	
		if node.right.kind ~= "binary_operator" or node.right.value.value ~= "." then
			if r.Type ~= "union" then
				self:TrackUpvalue(r, nil, nil, op == "not")
			end
		end
		if op == "not" then
			self.notlol = nil
		end
	end

	if op == "literal" then
		r.literal_argument = true
		return r
	end

	if op == "ref" then
		r.ref_argument = true
		return r
	end

	if r.Type == "tuple" then
		r = r:Get(1) or Nil()
	end

	if r.Type == "union" then
		local new_union = Union()
		local truthy_union = Union():SetUpvalue(r:GetUpvalue())
		local falsy_union = Union():SetUpvalue(r:GetUpvalue())

		for _, r in ipairs(r:GetData()) do
			local res, err = Prefix(self, node, r)

			if not res then
				self:ErrorAndCloneCurrentScope(node, err, r)
				falsy_union:AddType(r)
			else
				new_union:AddType(res)

				if res:IsTruthy() then
					truthy_union:AddType(r)
				end

				if res:IsFalsy() then
					falsy_union:AddType(r)
				end
			end
		end

		self:TrackUpvalue(r, truthy_union, falsy_union, op == "not")

		return new_union:SetNode(node):SetTypeSource(r)
	end

	if r.Type == "any" then
		return Any():SetNode(node)
	end

	if self:IsTypesystem() then
		if op == "typeof" then
			self:PushAnalyzerEnvironment("runtime")
			local obj = self:AnalyzeExpression(node.right)
			self:PopAnalyzerEnvironment()
			if not obj then return type_errors.other(
				"cannot find '" .. node.right:Render() .. "' in the current typesystem scope"
			) end
			return obj:GetContract() or obj
		elseif op == "unique" then
			r:MakeUnique(true)
			return r
		elseif op == "mutable" then
			r.mutable = true
			return r
		elseif op == "expand" then
			r.expand = true
			return r
		elseif op == "$" then
			if r.Type ~= "string" then return type_errors.other("must evaluate to a string") end
			if not r:IsLiteral() then return type_errors.other("must be a literal") end
			r:SetPatternContract(r:GetData())
			return r
		end
	end

	if op == "-" then
		local res = metatable_function(self, "__unm", r)
		if res then return res end
	elseif op == "~" then
		local res = metatable_function(self, "__bxor", r)
		if res then return res end
	elseif op == "#" then
		local res = metatable_function(self, "__len", r)
		if res then return res end
	end

	if op == "not" or op == "!" then
		if r:IsTruthy() and r:IsFalsy() then 
			return Boolean():SetNode(node):SetTypeSource(r) 
		elseif r:IsTruthy() then 
			return False():SetNode(node):SetTypeSource(r) 
		elseif r:IsFalsy() then 
			return True():SetNode(node):SetTypeSource(r) 
		end
	end

	if op == "-" or op == "~" or op == "#" then
		return r:PrefixOperator(op)
	end

	error("unhandled prefix operator in " .. self:GetCurrentAnalyzerEnvironment() .. ": " .. op .. tostring(r))
end

return {Prefix = Prefix}
