local ipairs = ipairs
local error = error
local tostring = tostring
local math_huge = math.huge
local Union = require("nattlua.types.union").Union
local Nil = require("nattlua.types.symbol").Nil
local error_messages = require("nattlua.error_messages")
local LString = require("nattlua.types.string").LString
local StringPattern = require("nattlua.types.string").StringPattern
local ConstString = require("nattlua.types.string").ConstString
local Boolean = require("nattlua.types.union").Boolean
local False = require("nattlua.types.symbol").False
local True = require("nattlua.types.symbol").True
local Any = require("nattlua.types.any").Any
local Tuple = require("nattlua.types.tuple").Tuple
local LNumber = require("nattlua.types.number").LNumber
local Number = require("nattlua.types.number").Number
local LNumberRange = require("nattlua.types.range").LNumberRange

local function metatable_function(analyzer, meta_method, obj, node)
	if obj:GetMetaTable() then
		local func = obj:GetMetaTable():Get(ConstString(meta_method))

		if func then
			return analyzer:Assert(analyzer:Call(func, Tuple({obj}), node):GetWithNumber(1))
		end
	end
end

local function Prefix(analyzer, node, r)
	local op = node.value:GetValueString()

	if r.Type == "tuple" then r = r:GetWithNumber(1) or Nil() end

	if analyzer:IsTypesystem() then
		if op == "unique" then
			if r.Type ~= "table" then
				return false, error_messages.unique_must_be_table(r)
			end

			r:MakeUnique(true)
			return r
		elseif op == "mutable" then
			r.mutable = true
			return r
		elseif op == "$" then
			if r.Type ~= "string" or not r:IsLiteral() then
				return false, error_messages.string_pattern_invalid_construction(r)
			end

			return StringPattern(r:GetData())
		end
	end

	if op == "not" or op == "!" then
		if r:IsTruthy() and r:IsFalsy() then
			return Boolean()
		elseif r:IsTruthy() then
			return False()
		elseif r:IsFalsy() then
			return True()
		end
	elseif op == "-" then
		if r.Type == "table" then
			local res = metatable_function(analyzer, "__unm", r, node)

			if res then return res end
		elseif r:IsNumeric() then
			return r:PrefixOperator(op)
		elseif r.Type == "any" then
			return r
		end
	elseif op == "~" then
		if r.Type == "table" then
			local res = metatable_function(analyzer, "__bnot", r, node)

			if res then return res end
		elseif r:IsNumeric() then
			return r:PrefixOperator(op)
		elseif r.Type == "any" then
			return r
		end
	elseif op == "#" then
		if r.Type == "table" then
			local res = metatable_function(analyzer, "__len", r, node)

			if res then return res end

			return r:GetArrayLength()
		elseif r.Type == "string" then
			local str = r:GetData()

			if r:IsLiteral() then return LNumber(#str) end

			return LNumberRange(0, math_huge)
		elseif r.Type == "any" then
			return r
		end
	end

	return false, error_messages.no_operator(op, r)
end

return {
	Prefix = function(analyzer, node)
		if analyzer:IsTypesystem() then
			if node.value.sub_type == "typeof" then
				analyzer:PushAnalyzerEnvironment("runtime")
				analyzer:PushNilAccessAllowed()
				local obj = analyzer:AnalyzeExpression(node.right)
				analyzer:PopNilAccessAllowed()
				analyzer:PopAnalyzerEnvironment()

				if not obj then
					return false, error_messages.typeof_lookup_missing(node.right:Render())
				end

				return obj:GetContract() or obj
			end
		end

		if node.value.sub_type == "not" then analyzer:PushInvertedExpressionContext() end

		local r = analyzer:Assert(analyzer:AnalyzeExpression(node.right))

		if node.value.sub_type == "not" then analyzer:PopInvertedExpressionContext() end

		if node.value.sub_type == "ref" then
			r:SetReferenceType(true)
			return r
		end

		if r.Type == "union" then
			local new_union = Union()
			local truthy_union = Union():SetUpvalue(r:GetUpvalue())
			local falsy_union = Union():SetUpvalue(r:GetUpvalue())

			for _, r in ipairs(r:GetData()) do
				local res, err = Prefix(analyzer, node, r)

				if not res then
					analyzer:Error(err)
				else
					new_union:AddType(res)

					if res:IsTruthy() then truthy_union:AddType(r) end

					if res:IsFalsy() then falsy_union:AddType(r) end
				end
			end

			analyzer:TrackUpvalueUnion(r, truthy_union, falsy_union)
			return new_union
		end

		return Prefix(analyzer, node, r)
	end,
}
