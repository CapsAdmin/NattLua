local oh = require("oh")
local em = require("oh.lua_emitter")
--oh.Code([[local exp = false and (nil).somevalue or "some_default"]])

local code = assert(oh.Code([[
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

lib.main()

return lib
]], "test", {annotate = true, dump_analyzer_events = true}):Analyze()):BuildLua()

print("====")

print(code)