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
    local a = require("test.tests.nattlua.analyzer.file_importing.require_cache.returns_nil")
    local b = require("test.tests.nattlua.analyzer.file_importing.require_cache.returns_nil")
    attest.equal(a, true)
    attest.equal(b, true)
    attest.equal(package.loaded["test.tests.nattlua.analyzer.file_importing.require_cache.returns_nil"], true)
]]
analyze[[
    local a = require("test.tests.nattlua.analyzer.file_importing.require_cache.returns_false")
    local b = require("test.tests.nattlua.analyzer.file_importing.require_cache.returns_false")
    attest.equal(a, false)
    attest.equal(b, false)
    attest.equal(package.loaded["test.tests.nattlua.analyzer.file_importing.require_cache.returns_false"], false)
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

do
    local path_util = require("nattlua.other.path")
    local old_resolve_require = path_util.ResolveRequire
    path_util.ResolveRequire = function(str)
        if str == "alias.one" or str == "alias.two" then
            return "test/tests/nattlua/analyzer/file_importing/require_cache/alias_shared.lua"
        end

        return old_resolve_require(str)
    end

    local ok, err = pcall(function()
        analyze[[
            local a = require("alias.one")
            local b = require("alias.two")
            a.foo = 1
            b.foo = 2
            attest.equal(a.foo, 1)
            attest.equal(b.foo, 2)
            attest.equal(package.loaded["alias.one"].foo, 1)
            attest.equal(package.loaded["alias.two"].foo, 2)
        ]]
    end)

    path_util.ResolveRequire = old_resolve_require
    assert(ok, err)
end
