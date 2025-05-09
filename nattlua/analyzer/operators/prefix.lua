local ipairs = ipairs
local error = error
local tostring = tostring
local Union = require("nattlua.types.union").Union
local Nil = require("nattlua.types.symbol").Nil
local type_errors = require("nattlua.types.error_messages")
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
	local op = node.value.value

	if node.right.kind ~= "binary_operator" or node.right.value.value ~= "." then
		if r.Type ~= "union" then analyzer:TrackUpvalue(r) end
	end

	if op == "ref" then
		r:SetReferenceType(true)
		return r
	end

	if r.Type == "tuple" then r = r:GetWithNumber(1) or Nil() end

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

	if analyzer:IsTypesystem() then
		if op == "typeof" then
			analyzer:PushAnalyzerEnvironment("runtime")
			local obj = analyzer:AnalyzeExpression(node.right)
			analyzer:PopAnalyzerEnvironment()

			if not obj then
				return false, type_errors.typeof_lookup_missing(node.right:Render())
			end

			return obj:GetContract() or obj
		elseif op == "unique" then
			if r.Type ~= "table" then
				return false, type_errors.unique_must_be_table(r)
			end

			r:MakeUnique(true)
			return r
		elseif op == "mutable" then
			r.mutable = true
			return r
		elseif op == "$" then
			if r.Type ~= "string" or not r:IsLiteral() then
				return false, type_errors.string_pattern_invalid_construction(r)
			end

			return StringPattern(r:GetData())
		end
	end

	if r.Type == "any" then
		return r
	elseif r.Type == "table" then
		if op == "-" then
			local res = metatable_function(analyzer, "__unm", r, node)

			if res then return res end
		elseif op == "~" then
			local res = metatable_function(analyzer, "__bxor", r, node)

			if res then return res end
		elseif op == "#" then
			local res = metatable_function(analyzer, "__len", r, node)

			if res then return res end

			return r:GetArrayLength()
		end
	elseif r:IsNumeric() then
		if op == "-" or op == "~" then return r:PrefixOperator(op) end
	elseif r.Type == "string" then
		if op == "#" then
			local str = r:GetData()

			if r:IsLiteral() then return LNumber(#str) end

			return LNumberRange(0, math.huge)
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
	end

	return false, type_errors.no_operator(op, r)
end

return {Prefix = Prefix}
