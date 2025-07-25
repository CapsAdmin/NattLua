-- load
analyze[[
        attest.equal(assert(load("attest.equal(1, 1) return 2"))(), 2)
    ]]
analyze[[
        attest.equal(assert(load("return " .. 2))(), 2)
    ]]
analyze[[
    attest.equal(require("test.tests.nattlua.analyzer.file_importing.expect_5")(5, nil, nil, nil), 1337)
]]
-- file import
equal(
	8,
	assert(require("nattlua").File("test/tests/nattlua/analyzer/file_importing/test/main.nlua")):Analyze().AnalyzedResult:GetFirstValue():GetData()
)
--[=[
	run([[
    -- ERROR1
    loadfile("test/tests/nattlua/analyzer/file_importing/deep_error/main.nlua")()
]], function(err)
		for i = 1, 4 do
			assert(err:find("ERROR" .. i, nil, true), "cannot find stack trace " .. i)
		end
	end)
]=]
analyze([[
    attest.equal(loadfile("test/tests/nattlua/analyzer/file_importing/complex/main.nlua")(1), 14)
]])
analyze[[
    attest.equal(require("test.tests.nattlua.analyzer.file_importing.complex.adapter"), 14)
]]
analyze[[
    attest.equal(require("table.new"), _ as function=(number, number)>({[number] = any}))
]]
analyze[[
    attest.equal(require("string"), string)
    attest.equal(require("io"), io)
]]
analyze[[
    local type test = analyzer function(name: string)
         return analyzer:GetLocalOrGlobalValue(name)
    end
    local type lol = {}
    attest.equal(test("lol"), lol)
]]
analyze[[
    type lol = {}
    attest.equal(require("lol"), lol)
    type lol = nil
]]
--[=[
    analyze[[
        require("test.tests.nattlua.analyzer.file_importing.env_leak.main")
    ]]
]=]
analyze[[
    loadfile("test/tests/nattlua/analyzer/file_importing/require_cache/main.nlua")()
]]
