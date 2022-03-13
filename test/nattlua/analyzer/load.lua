local T = require("test.helpers")
local run = T.RunCode

test("load", function()
	run[[
        attest.equal(assert(load("attest.equal(1, 1) return 2"))(), 2)
    ]]
	run[[
        attest.equal(assert(load("return " .. 2))(), 2)
    ]]
end)

run[[
    attest.equal(require("test.nattlua.analyzer.file_importing.expect_5")(5), 1337)
]]

test("file import", function()
	equal(
		8,
		assert(require("nattlua").File("test/nattlua/analyzer/file_importing/test/main.nlua")):Analyze().AnalyzedResult:GetData()
	)
end)

pending(function()
	run([[
    -- ERROR1
    loadfile("test/nattlua/analyzer/file_importing/deep_error/main.nlua")()
]], function(err)
		for i = 1, 4 do
			assert(err:find("ERROR" .. i, nil, true), "cannot find stack trace " .. i)
		end
	end)
end)

run([[
    attest.equal(loadfile("test/nattlua/analyzer/file_importing/complex/main.nlua")(), 14)
]])
run[[
    attest.equal(require("test.nattlua.analyzer.file_importing.complex.adapter"), 14)
]]
run[[
    attest.equal(require("table.new"), table.new)
]]
run[[
    attest.equal(require("string"), string)
    attest.equal(require("io"), io)
]]
run[[
    local type test = analyzer function(name: string)
         return analyzer:GetLocalOrGlobalValue(name)
    end
    local type lol = {}
    attest.equal(test("lol"), lol)
]]
run[[
    type lol = {}
    attest.equal(require("lol"), lol)
    type lol = nil
]]
pending[[
    require("test.nattlua.analyzer.file_importing.env_leak.main")
]]
run[[
    loadfile("test/nattlua/analyzer/file_importing/require_cache/main.nlua")()
]]
