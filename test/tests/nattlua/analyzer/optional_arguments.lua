local LString = require("nattlua.types.string").LString

test("untyped optional arguments", function()
	local analyzer = analyze[[
        local function foo(a, b, c)
            return a, b, c
        end

        local r1, r2, r3 = foo(1)
        attest.equal(r1, 1)
        attest.equal(r2, _ as nil)
        attest.equal(r3, _ as nil)

        local r4, r5, r6 = foo(1, 2)
        attest.equal(r4, 1)
        attest.equal(r5, 2)
        attest.equal(r6, _ as nil)
    ]]
end)

test("explicitly optional arguments", function()
	local analyzer = analyze[[
        local function foo(a: number, b: string | nil, c: boolean | nil)
            return a, b, c
        end

        local r1, r2, r3 = foo(1)
        -- no error means success for the missing arguments
    ]]
end)

test("required arguments should still warn", function()
	local analyzer = analyze[[
        local function foo(a: number, b: number)
            return a, b
        end

        -- attest.expect_diagnostic uses string.find, so we can use patterns
        attest.expect_diagnostic("error", "nil is not a subset of number")
        foo(1)

        -- Example of using a pattern
        attest.expect_diagnostic("error", ".-not a subset of.-")
        foo(1)
    ]]
end)

test("signature inference with missing arguments", function()
	local analyzer = analyze[[
        local function foo(a, b)
            return a, b
        end

        foo(1)
        foo(1, 2)
    ]]
end)

test("any arguments should be optional", function()
	local analyzer = analyze[[
        local function foo(a: any, b: any)
            return a, b
        end

        foo(1)
    ]]
end)

test("type functions with optional arguments", function()
	local analyzer = analyze[[
        local type foo = analyzer function(a, b)
            return a, b
        end

        foo(1)
    ]]
end)

test("verifying untyped argument warning", function()
	local analyzer = analyze[[
        -- First verify it warns
        attest.expect_diagnostic("warning", "argument is untyped")
        local function foo(arg) end
    ]]
end)
