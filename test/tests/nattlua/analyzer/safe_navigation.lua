-- Test safe navigation operator type analysis
-- Test 1: a?.field where a is nil
analyze[[
    local a: nil
    local x = a?.field
    attest.equal(x, nil)
]]
-- Test 2: a?.field where a is not nil
analyze[[
    local a: {field = number}
    local x = a?.field
    attest.equal(x, _ as number)
]]
-- Test 3: a?.field where a is union of nil and table
analyze[[
    local a: nil | {field = number}
    local x = a?.field
    attest.equal(x, _ as nil | number)
]]
-- Test 4: Chained safe navigation a?.b?.c where a is nil
analyze[[
    local a: nil
    local x = a?.b?.c
    attest.equal(x, nil)
]]
-- Test 5: Chained safe navigation a?.b?.c where all are non-nil
analyze[[
    local a: {b = {c = number}}
    local x = a?.b?.c
    attest.equal(x, _ as number)
]]
-- Test 6: Safe navigation call f?.(...) where f is nil
analyze[[
    local f: nil
    local x = f?.(1, 2)
    attest.equal(x, nil)
]]
-- Test 7: Safe navigation with and/or operators
analyze[[
    local a: nil | {field = number}
    local b: nil | {other = string}
    local x = a?.field or b?.other
    attest.equal(x, _ as nil | number | string)
]]
-- Test 8: Safe navigation with ?? operator
analyze[[
    local a: nil | {field = number}
    local x = a?.field ?? 99
    attest.equal(x, _ as 99 | nil | number)
]]
