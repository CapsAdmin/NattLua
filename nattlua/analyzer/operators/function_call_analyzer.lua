local ipairs = _G.ipairs
local math = _G.math
local ipairs = _G.ipairs
local type = _G.type
local math = _G.math
local table = _G.table
local debug = _G.debug
local assert = _G.assert
local Tuple = require("nattlua.types.tuple").Tuple
local Table = require("nattlua.types.table").Table
local Union = require("nattlua.types.union").Union
local Any = require("nattlua.types.any").Any
local Function = require("nattlua.types.function").Function
local LString = require("nattlua.types.string").LString
local LNumber = require("nattlua.types.number").LNumber
local Number = require("nattlua.types.number").Number
local LNumberRange = require("nattlua.types.range").LNumberRange
local Symbol = require("nattlua.types.symbol").Symbol
local type_errors = require("nattlua.types.error_messages")

local function should_expand(arg, contract)
	-- ranges are expanded into their min/max values
	if arg.Type == "range" then return true end

	if arg.Type == "union" then
		if contract.Type == "union" and contract:IsNil() then return true end

		return contract.Type ~= "any"
	end

	return false
end

local function get_all_values(val)
	if val.Type == "range" then
		-- extract min and max as separate values like a union, not as a range
		-- TODO: also include Number, because we have no idea what's between the range
		return {val:GetMinNumber(), val:GetMaxNumber(), Number()}
	else
		local out = {}

		for i, v in ipairs(val:GetData()) do
			if v.Type == "range" then
				table.insert(out, v:GetMinNumber())
				table.insert(out, v:GetMaxNumber())
				-- this is important. we cannot assume the output of the funciton given a numeric range corresponds linearly to that range
				table.insert(out, Number())
			else
				table.insert(out, v)
			end
		end

		return out
	end
end

local function generate_combinations_iterative(argument_options)
	local result = {{}}
	
	for arg_index = 1, #argument_options do
		local new_result = {}
		local new_index = 1
		
		for _, combination in ipairs(result) do
			for _, value in ipairs(argument_options[arg_index]) do
				local new_combination = {}
				for i, v in ipairs(combination) do
					new_combination[i] = v
				end
				new_combination[#combination + 1] = value
				
				new_result[new_index] = new_combination
				new_index = new_index + 1
			end
		end
		
		result = new_result
	end
	
	return result
end

local max_combinations = 1000

local function is_above_limit(argument_options)
	local total = 1
	for i = 1, #argument_options do
		total = total * #argument_options[i]
		if total > max_combinations then 
			return total, true
		end
	end
	return total, false
end

local function unpack_union_tuples(obj, input)
	local input_signature = obj:GetInputSignature()
	local len = input_signature:GetSafeLength(input)
	local packed_args = input:ToTable(len)

	if #packed_args == 0 and len == 1 then
		local first = assert(input_signature:GetFirstValue())

		if first and first.Type == "any" or first.Type == "nil" then
			packed_args = {first:Copy()}
		end
	end

	if obj:GetPreventInputArgumentExpansion() then return {packed_args} end

	-- Build a list of all possible values for each argument
	local argument_options = {}
	local has_expandable_args = false

	for i, val in ipairs(packed_args) do
		if should_expand(val, input_signature:GetWithNumber(i)) then
			argument_options[i] = get_all_values(val)
			has_expandable_args = true
		else
			argument_options[i] = {val} -- Single option for non-expandable args
		end
	end

	-- If nothing needs expansion, return original arguments
	if not has_expandable_args then return {packed_args} end

	local total_combinations, is_above_limit = is_above_limit(argument_options)
	if is_above_limit then
		return nil, "too many argument combinations (" .. total_combinations .. " > " .. max_combinations .. ")"
	end

	return generate_combinations_iterative(argument_options)
end

local function call_and_collect(analyzer, obj, arguments, ret)
	local tuple = analyzer:LuaTypesToTuple(
		{
			analyzer:CallLuaTypeFunction(
				obj:GetAnalyzerFunction(),
				obj:GetScope() or analyzer:GetScope(),
				arguments
			),
		}
	)

	if tuple:HasInfiniteValues() then return tuple end

	for i = 1, tuple:GetElementCount() do
		local v = assert(tuple:GetWithNumber(i))
		local existing = ret:GetWithNumber(i)

		if existing then
			if existing.Type == "union" then
				existing:AddType(v)
			else
				ret:Set(i, Union({v, existing}))
			end
		else
			ret:Set(i, v)
		end
	end
end

return function(analyzer, obj, input)
	local input_signature = obj:GetInputSignature()
	local output_signature = obj:GetOutputSignature()

	do
		local new_tup, errors

		if analyzer:IsTypesystem() then
			new_tup, errors = input:SubsetOrFallbackWithTuple(input_signature)
		else
			new_tup, errors = input:SubsetWithoutExpansionOrFallbackWithTuple(input_signature)
		end

		if errors then
			for _, error in ipairs(errors) do
				local reason, a, b, i = table.unpack(error)
				analyzer:Error(
					type_errors.context(
						"argument #" .. i .. ":",
						type_errors.because(type_errors.subset(a, b), reason)
					)
				)
			end
		end

		input = new_tup
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
					input:ToTableWithoutExpansion()
				),
			}
		)
	end

	-- Handle infinite tuples
	if
		input:GetElementCount() == math.huge and
		input_signature:GetElementCount() == math.huge
	then
		input = Tuple({input:GetWithNumber(1)})
	end

	local ret = Tuple()
	
	local combinations, error_msg = unpack_union_tuples(obj, input)
	
	if not combinations then
		analyzer:Error({error_msg})
		return output_signature:Copy()
	end
	
	for _, arguments in ipairs(combinations) do
		local t = call_and_collect(analyzer, obj, arguments, ret)

		if t then return t end
	end

	-- Check against output signature
	if not output_signature:IsEmpty() then
		local new_tup, err = ret:SubsetOrFallbackWithTuple(output_signature)

		if err then
			for i, v in ipairs(err) do
				local reason, a, b, i = table.unpack(v)
				analyzer:Error(
					type_errors.context(
						"return #" .. i .. ":",
						type_errors.because(type_errors.subset(a, b), reason)
					)
				)
			end
		end

		ret = new_tup
	end

	return ret
end
