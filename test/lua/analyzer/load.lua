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
    equal(8, require("nl").File("test/lua/analyzer/file_importing/main.nl"):Analyze().AnalyzedResult:Get(1):GetData())
end)

run[[
    type_assert(require("test.lua.analyzer.file_importing.foo.expect5")(5), 1337)
]]

run([[
    -- ERROR1
    loadfile("test/lua/analyzer/file_importing/deep_error.nl")()
]], function(err)
    for i = 1, 4 do
        assert(err:find("ERROR" .. i, nil, true), "cannot find stack trace " .. i)
    end
end)

run[[
    type_assert(require("table.new"), table.new)
]]

run[[
    type_assert(require("string"), string)
    type_assert(require("io"), io)
]]

run[[
    local type test = function(name: string)
         return analyzer:GetEnvironmentValue(name.data, "typesystem")
    end
    local type lol = {}
    type_assert(test("lol"), lol)
]]

run[[
    local type lol = {}
    type_assert(require("lol"), lol)
]]