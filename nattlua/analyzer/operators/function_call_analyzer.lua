local ipairs = ipairs
local math = math
local ipairs = ipairs
local type = type
local math = math
local table = _G.table
local debug = debug
local Tuple = require("nattlua.types.tuple").Tuple
local Table = require("nattlua.types.table").Table
local Union = require("nattlua.types.union").Union
local Any = require("nattlua.types.any").Any
local Function = require("nattlua.types.function").Function
local LString = require("nattlua.types.string").LString
local LNumber = require("nattlua.types.number").LNumber
local LNumberRange = require("nattlua.types.range").LNumberRange
local Symbol = require("nattlua.types.symbol").Symbol
local type_errors = require("nattlua.types.error_messages")

local function should_expand(arg, contract)
	local b = arg.Type == "union"

	if contract.Type == "any" then b = false end

	if contract.Type == "union" then b = false end

	if arg.Type == "union" and contract.Type == "union" and contract:IsNil() then
		b = true
	end

	if arg.Type == "range" then b = true end

	return b
end

local function unpack_union_tuples(obj, input)
	local input_signature = obj:GetInputSignature()
	local out = {}
	local lengths = {}
	local max = 1
	local ys = {}
	local arg_length = #input

	for i, val in ipairs(input) do
		if
			not obj:GetPreventInputArgumentExpansion() and
			should_expand(val, input_signature:GetWithNumber(i))
		then
			if val.Type == "number" or val.Type == "range" then
				lengths[i] = 2 -- min max
			else
				lengths[i] = #val:GetData()
			end

			max = max * lengths[i]
		else
			lengths[i] = 0
		end

		ys[i] = 1
	end

	for i = 1, max do
		local args = {}
		local sub_index = i

		for i, val in ipairs(input) do
			if lengths[i] == 0 then
				args[i] = val
			else
				if val.Type == "range" then
					if sub_index == 1 then
						args[i] = LNumber(val:GetMin())
					else
						args[i] = LNumber(val:GetMax())
					end
				else
					args[i] = val:GetData()[ys[i]]
				end
			end
		end

		out[i] = args
		local carry = true

		for arg_index = arg_length, 1, -1 do
			if carry and lengths[arg_index] > 0 then
				ys[arg_index] = ys[arg_index] + 1

				if ys[arg_index] <= lengths[arg_index] then
					carry = false
				else
					ys[arg_index] = 1
				end
			end
		end
	end

	return out
end

return function(analyzer, obj, input)
	local signature_arguments = obj:GetInputSignature()
	local output_signature = obj:GetOutputSignature()

	do
		local ok, reason, a, b, i = input:IsSubsetOfTuple(signature_arguments)

		if not ok then
			return false,
			type_errors.context("argument #" .. i .. ":", type_errors.because(type_errors.subset(a, b), reason))
		end
	end

	if obj:IsLiteralFunction() then
		for _, v in ipairs(input:GetData()) do
			if v.Type ~= "function" and not v:IsLiteral() then
				return output_signature:Copy()
			end
		end
	end

	if analyzer:IsTypesystem() then
		return analyzer:LuaTypesToTuple(
			{
				analyzer:CallLuaTypeFunction(
					obj:GetAnalyzerFunction(),
					obj:GetScope() or analyzer:GetScope(),
					input:UnpackWithoutExpansion()
				),
			}
		)
	end

	-- if you call print(SOMEFUNCTION()), SOMEFUNCTION is not defined and thus returns any, which when called
	-- results in ((any,)*inf,)
	-- when the input signature is also ((TYPE,)*inf,) both will result in safe length being 0
	-- so no arguments are passed. This feels wrong, maybe at least 1 argument? (however technically this is also wrong?)
	if input:GetElementCount() == math.huge and signature_arguments:GetElementCount() == math.huge then
		input = Tuple({input:GetWithNumber(1)})
	end

	local len = signature_arguments:GetSafeLength(input)
	local packed_args = {input:Unpack(len)}

	if #packed_args == 0 and len == 1 then
		local first = analyzer:GetFirstValue(signature_arguments)

		if first and first.Type == "any" or first.Type == "nil" then
			packed_args = {first:Copy()}
		end
	end

	local tuples = {}

	for i, arguments in ipairs(unpack_union_tuples(obj, packed_args)) do
		tuples[i] = analyzer:LuaTypesToTuple(
			{
				analyzer:CallLuaTypeFunction(
					obj:GetAnalyzerFunction(),
					obj:GetScope() or analyzer:GetScope(),
					table.unpack(arguments)
				),
			}
		)
	end

	local ret = Tuple()

	for _, tuple in ipairs(tuples) do
		if tuple:GetUnpackable() or tuple:HasInfiniteValues() then return tuple end
	end

	for _, tuple in ipairs(tuples) do
		for i = 1, tuple:GetElementCount() do
			local v, err = tuple:GetWithNumber(i)

			if not v then return v, err end

			local existing = ret:GetWithNumber(i)

			if existing then
				local handled = false

				if existing.Type == "number" and v.Type == "number" then
					local range = input:GetWithNumber(i)

					if range and range.Type == "range" then
						ret:Set(i, LNumberRange(existing:GetData(), v:GetData()))
						handled = true
					end
				end

				if not handled then
					if existing.Type == "union" then
						existing:AddType(v)
					else
						ret:Set(i, Union({v, existing}))
					end
				end
			else
				ret:Set(i, v)
			end
		end
	end

	if not output_signature:IsEmpty() then
		local ok, err = ret:IsSubsetOfTuple(output_signature)

		if not ok then return ok, err end
	end

	return ret
end
