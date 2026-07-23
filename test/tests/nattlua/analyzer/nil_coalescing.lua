-- Test basic nil coalescing with nil on left
analyze[[
    local x = nil ?? 42
    attest.equal(x, 42)
]]
-- Test nil coalescing with false on left (should NOT short-circuit like or)
analyze[[
    local x = false ?? 42
    attest.equal(x, false)
]]
-- Test nil coalescing with 0 on left (should NOT short-circuit like or)
analyze[[
    local x = 0 ?? 42
    attest.equal(x, 0)
]]
-- Test nil coalescing with empty string on left (should NOT short-circuit like or)
analyze[[
    local x = "" ?? 42
    attest.equal(x, "")
]]
-- Test nil coalescing with true on left
analyze[[
    local x = true ?? 42
    attest.equal(x, true)
]]
-- Test nil coalescing with both sides having different types
analyze[[
    local x = nil ?? "default"
    attest.equal(x, "default")
]]
-- Test nil coalescing with variable that could be nil
analyze[[
    local a: nil | number
    local b = a ?? 10
    -- When left could be nil, result includes both branches
    attest.equal(b, _ as 10 | nil | number)
]]
-- Test nil coalescing with non-nilable type
analyze[[
    local a: number
    local b = a ?? 10
    attest.equal(b, a)
]]
-- Test nested nil coalescing
analyze[[
    local a = nil
    local b = nil
    local c = a ?? b ?? 42
    attest.equal(c, 42)
]]
-- Test nil coalescing with function calls (requires explicit return type annotations)
analyze[[
    local function getNil() return nil end
    local function getVal() return 42 end
    -- When left is certainly nil, result is right side
    attest.equal(getNil() ?? getVal(), 42)
]]
-- Test nil coalescing in conditional context
analyze[[
    local a: nil | number
    local b = a ?? 10
    
    if b then
        -- b should be narrowed to number here
        attest.equal(b, _ as 10 | number)
    end
]]
