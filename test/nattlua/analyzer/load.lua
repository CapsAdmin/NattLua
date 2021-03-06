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

run[[
    type_assert(require("test.nattlua.analyzer.file_importing.expect_5")(5), 1337)
]]

test("file import", function()
    equal(8, assert(require("nattlua").File("test/nattlua/analyzer/file_importing/test/main.nlua")):Analyze().AnalyzedResult:Get(1):GetData())
end)

pending([[
    -- ERROR1
    loadfile("test/nattlua/analyzer/file_importing/deep_error/main.nlua")()
]], function(err)
    for i = 1, 4 do
        assert(err:find("ERROR" .. i, nil, true), "cannot find stack trace " .. i)
    end
end)

run([[
    type_assert(loadfile("test/nattlua/analyzer/file_importing/complex/main.nlua")(), 14)
]])

run[[
    type_assert(require("test.nattlua.analyzer.file_importing.complex.adapter"), 14)
]]

run[[
    type_assert(require("table.new"), table.new)
]]

run[[
    type_assert(require("string"), string)
    type_assert(require("io"), io)
]]

run[[
    local type test = function(name: string)
         return analyzer:GetLocalOrEnvironmentValue(name:GetData(), "typesystem")
    end
    local type lol = {}
    type_assert(test("lol"), lol)
]]

run[[
    type lol = {}
    type_assert(require("lol"), lol)
    type lol = nil
]]