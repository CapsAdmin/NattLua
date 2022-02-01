local META = dofile("nattlua/types/base.lua")
META.Type = "any"

function META:Get(key)
	return self
end

function META:Set(key, val)
	return true
end

function META:Copy()
	return self
end

function META.IsSubsetOf(A, B)
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

function META:Call()
	local Tuple = require("nattlua.types.tuple").Tuple
	return Tuple({Tuple({}):AddRemainder(Tuple({META.New()}):SetRepeat(math.huge))})
end

function META.Equal(a, b)
	return a.Type == b.Type
end

return {Any = function() return META.New() end}
