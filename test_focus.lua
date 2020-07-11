--DISABLE_BASE_TYPE S
local function test(a, b)

end

test(true, false)
test(false, true)
test(1, "")

local type function check(func: any)
    local a = func:GetArguments():Get(1)     -- this is being crawled for some reason
    local b = types.Set({
        types.Number(1),
        types.False,
        types.True
    })

    assert(b:SubsetOf(a))
end

check(test, "!")