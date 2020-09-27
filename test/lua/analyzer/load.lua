local T = require("test.helpers")
local run = T.RunCode

test("load", function()
    run[[
        type_assert(assert(load("type_assert(1, 1) return 2"))(), 2)
    ]]

    run[[
        type_assert(assert(load("return " .. 2))(), 2)
    ]]
end)

test("file import", function()
    equal(8, require("oh").File("test/lua/analyzer/file_importing/main.oh"):Analyze().AnalyzedResult:Get(1):GetData())
end)

run[[
    type_assert(require("test.lua.analyzer.file_importing.foo.expect5")(5), 1337)
]]

run([[
    -- ERROR1
    loadfile("test/lua/analyzer/file_importing/deep_error.oh")()
]], function(err)
    for i = 1, 4 do
        assert(err:find("ERROR" .. i, nil, true), "cannot find stack trace " .. i)
    end
end)
