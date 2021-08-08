local T = require("test.helpers")
local run = T.RunCode

test("load", function()
    run[[
        types.assert(assert(load("types.assert(1, 1) return 2"))(), 2)
    ]]

    run[[
        types.assert(assert(load("return " .. 2))(), 2)
    ]]
end)

run[[
    types.assert(require("test.nattlua.analyzer.file_importing.expect_5")(5), 1337)
]]

test("file import", function()
    equal(8, assert(require("nattlua").File("test/nattlua/analyzer/file_importing/test/main.nlua")):Analyze().AnalyzedResult:GetData())
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
    types.assert(loadfile("test/nattlua/analyzer/file_importing/complex/main.nlua")(), 14)
]])

run[[
    types.assert(require("test.nattlua.analyzer.file_importing.complex.adapter"), 14)
]]

run[[
    types.assert(require("table.new"), table.new)
]]

run[[
    types.assert(require("string"), string)
    types.assert(require("io"), io)
]]

run[[
    local type test = analyzer function(name: string)
         return analyzer:GetLocalOrEnvironmentValue(name:GetData(), "typesystem")
    end
    local type lol = {}
    types.assert(test("lol"), lol)
]]

run[[
    type lol = {}
    types.assert(require("lol"), lol)
    type lol = nil
]]