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
	-- ranges are expanded, so with 1..5, the function is called with 1 and 5 respectively
	if arg.Type == "range" then return true end

	if arg.Type == "union" then
		if contract.Type == "union" then return contract:IsNil() end

		return contract.Type ~= "any"
	end

	return false
end

-- Helper to extract all possible values for an argument
local function get_all_values(val)
	if val.Type == "range" then
		return {val:GetMinNumber(), val:GetMaxNumber()}
	else
		return val:GetData()
	end
end

-- Generate Cartesian product recursively
local function generate_combinations(packed_args, argument_options, arg_index)
	if arg_index > #packed_args then
		return {{}} -- Base case: one empty combination
	end

	local rest_combinations = generate_combinations(packed_args, argument_options, arg_index + 1)
	local all_combinations = {}

	for _, value in ipairs(argument_options[arg_index]) do
		for _, rest in ipairs(rest_combinations) do
			local combination = {value}

			for _, v in ipairs(rest) do
				table.insert(combination, v)
			end

			table.insert(all_combinations, combination)
		end
	end

	return all_combinations
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

	return generate_combinations(packed_args, argument_options, 1)
end

local function call_and_collect(analyzer, obj, input, arguments, ret)
	local tuple = analyzer:LuaTypesToTuple(
		{
			analyzer:CallLuaTypeFunction(obj:GetAnalyzerFunction(), obj:GetScope() or analyzer:GetScope(), arguments),
		}
	)

	if tuple:HasInfiniteValues() then return tuple end

	for i = 1, tuple:GetElementCount() do
		local v = assert(tuple:GetWithNumber(i))
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
					type_errors.context("argument #" .. i .. ":", type_errors.because(type_errors.subset(a, b), reason))
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

	-- if you call print(SOMEFUNCTION()), SOMEFUNCTION is not defined and thus returns any, which when called
	-- results in ((any,)*inf,)
	-- when the input signature is also ((TYPE,)*inf,) both will result in safe length being 0
	-- so no arguments are passed. This feels wrong, maybe at least 1 argument? (however technically this is also wrong?)
	if
		input:GetElementCount() == math.huge and
		input_signature:GetElementCount() == math.huge
	then
		input = Tuple({input:GetWithNumber(1)})
	end

	local ret = Tuple()

	for i, arguments in ipairs(unpack_union_tuples(obj, input)) do
		local range_deal = false

		for i, v in ipairs(arguments) do
			if v.Type == "range" then
				range_deal = true

				break
			end
		end

		if range_deal then
			local min_args = {}
			local max_args = {}
			local index = nil

			for i, v in ipairs(arguments) do
				if v.Type == "range" then
					index = index or i
					table.insert(min_args, v:GetMinNumber())
				else
					table.insert(min_args, v)
				end
			end

			local min = Tuple()
			local t = call_and_collect(analyzer, obj, input, min_args, min)

			if t then return t end

			for i, v in ipairs(arguments) do
				if v.Type == "range" then
					table.insert(max_args, v:GetMaxNumber())
				else
					table.insert(max_args, v)
				end
			end

			local max = Tuple()
			local t = call_and_collect(analyzer, obj, input, max_args, max)

			if t then return t end

			local min_num = min:GetWithNumber(index)
			local max_num = max:GetWithNumber(index)

			if min_num and max_num then
				local v = LNumberRange(min_num:GetData(), max_num:GetData())
				local existing = ret:GetWithNumber(index)

				if existing then
					if existing.Type == "union" then
						existing:AddType(v)
					else
						ret:Set(index, Union({v, existing}))
					end
				else
					ret:Set(index, v)
				end
			else
				local t = call_and_collect(analyzer, obj, input, arguments, ret)

				if t then return t end
			end
		else
			local t = call_and_collect(analyzer, obj, input, arguments, ret)

			if t then return t end
		end
	end

	if not output_signature:IsEmpty() then
		local new_tup, err = ret:SubsetOrFallbackWithTuple(output_signature)

		if err then
			for i, v in ipairs(err) do
				local reason, a, b, i = table.unpack(v)
				analyzer:Error(
					type_errors.context("return #" .. i .. ":", type_errors.because(type_errors.subset(a, b), reason))
				)
			end
		end

		ret = new_tup
	end

	return ret
end
