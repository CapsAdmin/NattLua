local oh = require("oh")
local em = require("oh.lua_emitter")
oh.Analyze([[local exp = false and (nil).somevalue or "some_default"]])

local ast = oh.Analyze([[
local lib = {}

function lib.foo1(a, b)
    return lib.foo2(a, b)
end

function lib.main()
    return lib.foo1(1, 2)
end

function lib.foo2(a, b)
    return a + b
end

return lib
]], true)

print("====")

print(em():BuildCode(ast))