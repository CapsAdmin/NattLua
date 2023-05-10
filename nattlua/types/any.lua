local type_errors = require("nattlua.types.error_messages")
local META = dofile("nattlua/types/base.lua")
--[[#local type TBaseType = META.TBaseType]]
--[[#type META.@Name = "TAny"]]
--[[#type TAny = META.@Self]]
META.Type = "any"

function META:Get(key--[[#: TBaseType]])
	return self
end

function META:Set(key--[[#: TBaseType]], val--[[#: TBaseType]])
	return true
end

function META:Copy()
	return self
end

function META.IsSubsetOf(A--[[#: TAny]], B--[[#: TBaseType]])
	return true
end

function META:__tostring()
	return "any"
end

function META:IsFalsy()
	return true
end

function META:IsTruthy()
	return true
end

function META:CanBeNil()
	return true
end

function META.Equal(a--[[#: TAny]], b--[[#: TBaseType]])
	return a.Type == b.Type
end

function META.LogicalComparison(l--[[#: TAny]], r--[[#: TBaseType]], op--[[#: string]])
	if op == "==" then return true -- TODO: should be nil (true | false)?
	end

	return false, type_errors.binary(op, l, r)
end

function META:Call(analyzer, input, call_node)
	local Tuple = require("nattlua.types.tuple").Tuple
	local Union = require("nattlua.types.union").Union

	-- it's ok to call any types, it will just return any
	-- check arguments that can be mutated
	for _, arg in ipairs(input:GetData()) do
		if arg.Type == "table" and arg:GetAnalyzerEnvironment() == "runtime" then
			if arg:GetContract() then
				-- error if we call any with tables that have contracts
				-- since anything might happen to them in an any call
				analyzer:Error(
					{
						"cannot mutate argument with contract ",
						arg:GetContract(),
					}
				)
			else
				-- if we pass a table without a contract to an any call, we add any to its key values
				for _, keyval in ipairs(arg:GetData()) do
					keyval.key = Union({META.New(), keyval.key})
					keyval.val = Union({META.New(), keyval.val})
				end
			end
		end
	end

	return Tuple({Tuple({}):AddRemainder(Tuple({META.New()}):SetRepeat(math.huge))})
end

return {
	Any = function()
		return META.New()
	end,
}