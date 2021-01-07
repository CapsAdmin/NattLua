local types = require("nattlua.types.types")

local META = {}
META.Type = "any"
require("nattlua.types.base")(META)

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
    return types.Tuple({}):AddRemainder(types.Tuple({types.Any()}):SetRepeat(math.huge))
end

function META.Equal(a, b)
    return a.Type == b.Type
end

return META