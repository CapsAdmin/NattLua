local nl = require("nattlua")

local function check(config, input, expect)
    expect = expect:gsub("    ", "\t")
    local new_lua_code = assert(nl.Code(input, nil, config)):Emit()
    if new_lua_code ~= expect then
        diff(new_lua_code, expect)
    end
    equal(new_lua_code, expect, 2)
end

check({ preserve_whitespace = false },
    [[x = "" -- foo]], [[x = "" -- foo]]
)

check({ string_quote = "'" },
    [[x = "foo"]], [[x = 'foo']]
)

check({ string_quote = '"' },
    [[x = 'foo']], [[x = "foo"]]
)

check({ string_quote = '"' },
    [[x = '"foo"']], [[x = "\"foo\""]]
)

check({ preserve_whitespace = false },
    [[x         = 
    
    1]], [[x = 1]]
)

check({ no_semicolon = true },
    [[x = 1;]], [[x = 1]]
)

check({ no_semicolon = true },
[[
x = 1;
x = 2;--lol
x = 3;
]], 
[[
x = 1
x = 2--lol
x = 3
]]
)

check({ extra_indent = {StartSomething = true, EndSomething = false}, preserve_whitespace = false },
[[
x = 1
StartSomething()
x = 2
x = 3
EndSomething()
x = 4
]], 
[[
x = 1
StartSomething()
    x = 2
    x = 3
EndSomething()
x = 4]]
)

check({ extra_indent = {StartSomething = true, EndSomething = false}, preserve_whitespace = false },
[[
x = 1
pac.StartSomething()
x = 2
x = 3
pac.EndSomething()
x = 4
]], 
[[
x = 1
pac.StartSomething()
    x = 2
    x = 3
pac.EndSomething()
x = 4]]
)

check({preserve_whitespace = false}, [[local tbl = {foo = true,foo = true,foo = true,foo = true,foo = true}]], 
[[local tbl = {
    foo = true,
    foo = true,
    foo = true,
    foo = true,
    foo = true,
}]])

-- not ready yet
if false then
    local input = assert(nl.File("test/nattlua/emitter/quine.lua", {})):Emit()
    local expect = assert(nl.File("test/nattlua/emitter/quine.lua", {preserve_whitespace = false})):Emit()

    equal(input, expect)
end