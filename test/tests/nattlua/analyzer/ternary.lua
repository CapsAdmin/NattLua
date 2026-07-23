-- Test basic ternary type inference with constant true condition
analyze[[
    local x = true ? 1 : 'hello'
    attest.equal(x, 1)
]]
-- Test basic ternary type inference with constant false condition
analyze[[
    local x = false ? 1 : 'hello'
    attest.equal(x, "hello")
]]
-- Test ternary with same types
analyze[[
    local x = true ? 1 : 2
    attest.equal(x, 1)
]]
-- Test ternary with nil/false (the key pitfall case)
analyze[[
    local x = true ? false : 42
    attest.equal(x, false)
]]
-- Test ternary with nil in true branch
analyze[[
    local x = true ? nil : 42
    attest.equal(x, nil)
]]
-- Test ternary with 0 in true branch
analyze[[
    local x = true ? 0 : 42
    attest.equal(x, 0)
]]
-- Test nested ternary (right-associative) with constant conditions
analyze[[
    local a, b, c, d, e = true, 'B', false, 'D', 'E'
    local x = a ? b : c ? d : e
    attest.equal(x, 'B')
]]
analyze[[
    local a, b, c, d, e = false, 'B', false, 'D', 'E'
    local x = a ? b : c ? d : e
    attest.equal(x, 'E')
]]
-- Test ternary with boolean condition (non-constant)
analyze[[
    local flag: boolean
    local x = flag ? 1 : 2
    attest.equal(x, _ as 1 | 2)
]]
-- Test ternary with table types
analyze[[
    local t: {a = 1} | {b = 2}
    local x = true ? t.a : t.b
    attest.equal(x, _ as 1 | nil)
]]
