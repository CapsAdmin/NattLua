local ipairs = ipairs
local math = math
local unpack_union_tuples
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
local Symbol = require("nattlua.types.symbol").Symbol
local type_errors = require("nattlua.types.error_messages")

do
	local ipairs = ipairs

	local function should_expand(arg, contract)
		local b = arg.Type == "union"

		if contract.Type == "any" then b = false end

		if contract.Type == "union" then b = false end

		if arg.Type == "union" and contract.Type == "union" and contract:CanBeNil() then
			b = true
		end

		return b
	end

	function unpack_union_tuples(func_obj, arguments, function_arguments)
		local out = {}
		local lengths = {}
		local max = 1
		local ys = {}
		local arg_length = #arguments

		for i, obj in ipairs(arguments) do
			if not func_obj.no_expansion and should_expand(obj, function_arguments:Get(i)) then
				lengths[i] = #obj:GetData()
				max = max * lengths[i]
			else
				lengths[i] = 0
			end

			ys[i] = 1
		end

		for i = 1, max do
			local args = {}

			for i, obj in ipairs(arguments) do
				if lengths[i] == 0 then
					args[i] = obj
				else
					args[i] = obj:GetData()[ys[i]]
				end
			end

			out[i] = args

			for i = arg_length, 2, -1 do
				if i == arg_length then ys[i] = ys[i] + 1 end

				if ys[i] > lengths[i] then
					ys[i] = 1
					ys[i - 1] = ys[i - 1] + 1
				end
			end
		end

		return out
	end
end

return {
	Call = function(META)
		function META:LuaTypesToTuple(tps)
			local tbl = {}

			for i, v in ipairs(tps) do
				if type(v) == "table" and v.Type ~= nil then
					tbl[i] = v
				else
					if type(v) == "function" then
						tbl[i] = Function(
							{
								lua_function = v,
								arg = Tuple({}):AddRemainder(Tuple({Any()}):SetRepeat(math.huge)),
								ret = Tuple({}):AddRemainder(Tuple({Any()}):SetRepeat(math.huge)),
							}
						):SetLiteral(true)
					else
						local t = type(v)

						if t == "number" then
							tbl[i] = LNumber(v)
						elseif t == "string" then
							tbl[i] = LString(v)
						elseif t == "boolean" then
							tbl[i] = Symbol(v)
						elseif t == "table" then
							local tbl = Table()

							for _, val in ipairs(v) do
								tbl:Insert(val)
							end

							tbl:SetContract(tbl)
							return tbl
						else
							self:Print(t)
							error(debug.traceback("NYI " .. t))
						end
					end
				end
			end

			if tbl[1] and tbl[1].Type == "tuple" and #tbl == 1 then return tbl[1] end

			return Tuple(tbl)
		end

		function META:CallAnalyzerFunction(obj, function_arguments, arguments)
			do
				local ok, reason, a, b, i = arguments:IsSubsetOfTuple(obj:GetArguments())

				if not ok then
					return type_errors.subset(a, b, {"argument #", i, " - ", reason})
				end
			end

			local len = function_arguments:GetLength()

			if len == math.huge and arguments:GetLength() == math.huge then
				len = math.max(function_arguments:GetMinimumLength(), arguments:GetMinimumLength())
			end

			if self:IsTypesystem() then
				local ret = self:LuaTypesToTuple(
					{
						self:CallLuaTypeFunction(
							obj:GetData().lua_function,
							obj:GetData().scope or self:GetScope(),
							arguments:UnpackWithoutExpansion()
						),
					}
				)
				return ret
			end

			local tuples = {}

			for i, arg in ipairs(unpack_union_tuples(obj, {arguments:Unpack(len)}, function_arguments)) do
				tuples[i] = self:LuaTypesToTuple(
					{
						self:CallLuaTypeFunction(
							obj:GetData().lua_function,
							obj:GetData().scope or self:GetScope(),
							table.unpack(arg)
						),
					}
				)
			end

			local ret = Tuple({})

			for _, tuple in ipairs(tuples) do
				if tuple:GetUnpackable() or tuple:GetLength() == math.huge then
					return tuple
				end
			end

			for _, tuple in ipairs(tuples) do
				for i = 1, tuple:GetLength() do
					local v = tuple:Get(i)
					local existing = ret:Get(i)

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

			return ret
		end
	end,
}
