--[[
    Edge case tests for mutation tracking, narrowing through stored conditions,
    and/or scope unification, and LeftRightSource chain traversal.
    
    Created after unifying:
      - upvalue and table tracking into shared tracked_objects
      - expression-level and/or with statement-level if/else scopes
      - LeftRightSource chain traversal for stored conditions
]]

-- ==========================================================================
-- Stored condition narrowing (single variable)
-- ==========================================================================

-- simple stored ~= nil
analyze[[
    local x = 1 as number | nil
    local check = x ~= nil
    if check then
        attest.equal(x, 1 as number)
    end
]]

-- stored == nil with negated if (inverted stored condition)
analyze[[
    local x = 1 as number | nil
    local check = x == nil
    if not check then
        attest.equal(x, 1 as number)
    end
]]

-- stored truthy check
analyze[[
    local x = 1 as number | nil
    local check = x
    if check then
        attest.equal(check, 1 as number)
    end
]]

-- ==========================================================================
-- Compound stored conditions (and)
-- ==========================================================================

-- two variables via and
analyze[[
    local a = 1 as number | nil
    local b = 1 as string | nil
    local check = (a ~= nil) and (b ~= nil)
    if check then
        attest.equal(a, 1 as number)
        attest.equal(b, 1 as string)
    end
]]

-- three variables via and chain
analyze[[
    local a = 1 as number | nil
    local b = 1 as string | nil
    local c = 1 as boolean | nil
    local check = (a ~= nil) and (b ~= nil) and (c ~= nil)
    if check then
        attest.equal(a, 1 as number)
        attest.equal(b, 1 as string)
        attest.equal(c, 1 as boolean)
    end
]]

-- ==========================================================================
-- and/or narrowing inside function calls (expression scope unification)
-- ==========================================================================

-- function called in and branch sees narrowed upvalue
analyze[[
    local x: number | nil
    local function check_x()
        attest.equal(x, _ as number)
    end
    local res = x and check_x()
]]

-- function called in or branch sees narrowed (falsy) upvalue
analyze[[
    local x: number | false
    local function check_x()
        attest.equal(x, false)
    end
    local res = x or check_x()
]]
-- nested and with function call
analyze[[
    local a: number | nil
    local b: string | nil
    local function check()
        attest.equal(a, _ as number)
        attest.equal(b, _ as string)
    end
    local res = a and b and check()
]]

-- ==========================================================================
-- and/or inside condition expressions (should NOT create extra scopes)
-- ==========================================================================

-- and inside if condition
analyze[[
    local x: number | nil
    local y: string | nil
    if x and y then
        attest.equal(x, _ as number)
        attest.equal(y, _ as string)
    end
]]

-- or inside if condition preserves narrowing
analyze[[
    local x: 1 | 2 | 3
    if x == 1 or x == 2 then
        attest.equal(x, _ as 1 | 2)
    else
        attest.equal(x, _ as 3)
    end
]]

-- nested and/or inside if condition
analyze[[
    local a: nil | 1
    if a or true and a or false then
        attest.equal(a, _ as 1)
    end
    attest.equal(a, _ as 1 | nil)
]]

-- ==========================================================================
-- Dependent type narrowing (discriminated unions)
-- should NOT be broken by LeftRightSource traversal
-- ==========================================================================

-- basic discriminant narrowing
analyze([[
    local type A = {Type = "human", name = string}
    local type B = {Type = "cat", lives = number}
    local x: A | B
    if x.Type == "cat" then
        attest.equal(x.Type, "cat")
    end
    if x.Type == "human" then
        attest.equal(x.Type, "human")
    end
]])

-- discriminant with else
analyze([[
    local type A = {kind = "a", val = number}
    local type B = {kind = "b", val = string}
    local x: A | B
    if x.kind == "a" then
        attest.equal(x.kind, "a")
    else
        attest.equal(x.kind, "b")
    end
]])

-- ==========================================================================
-- Local alias narrowing
-- ==========================================================================

-- alias narrows the local, original union is unchanged
analyze[[
    local x: number | nil
    local val = x
    if val then
        attest.equal(val, _ as number)
    end
    attest.equal(x, _ as number | nil)
]]

-- ==========================================================================
-- Table field narrowing (direct, not through stored checks)
-- ==========================================================================

-- direct truthiness check on table field
analyze[[
    local t: {foo = nil | number}
    if t.foo then
        attest.equal(t.foo, _ as number)
    end
]]

-- direct ~= nil check on table field
analyze[[
    local t: {foo = nil | number}
    if t.foo ~= nil then
        attest.equal(t.foo, _ as number)
    end
]]

-- early return narrows remainder
analyze[[
    local t: {foo = nil | number}
    if not t.foo then return end
    attest.equal(t.foo, _ as number)
]]

-- ==========================================================================
-- Combined expression and statement narrowing
-- ==========================================================================

-- and expression assigns narrowed value
analyze[[
    local x: nil | number
    local y: nil | string
    local result = x and y
    attest.equal(result, _ as nil | string)
]]

-- or expression assigns narrowed value
analyze[[
    local x: false | number
    local result = x or "fallback"
    attest.equal(result, _ as number | "fallback")
]]

-- and/or with literals
analyze[[
    local a: 1, b: 2
    local result = a and b
    attest.equal(result, 2)
]]

analyze[[
    local a = false
    local result = a or 42
    attest.equal(result, 42)
]]

-- ==========================================================================
-- Edge cases: multiple narrowing in sequence
-- ==========================================================================

-- sequential if blocks don't interfere
analyze[[
    local x: number | nil
    local y: string | nil
    if x then
        attest.equal(x, _ as number)
    end
    if y then
        attest.equal(y, _ as string)
    end
    attest.equal(x, _ as number | nil)
    attest.equal(y, _ as string | nil)
]]

-- narrowing same variable in nested ifs
analyze[[
    local x: 1 | 2 | 3
    if x == 1 then
        attest.equal(x, 1)
    else
        attest.equal(x, _ as 2 | 3)
        if x == 2 then
            attest.equal(x, 2)
        else
            attest.equal(x, 3)
        end
    end
]]

-- ==========================================================================
-- Edge cases: not operator interactions
-- ==========================================================================

-- not with stored condition
analyze[[
    local x: number | nil
    local is_nil = x == nil
    if is_nil then
        attest.equal(x, nil)
    end
]]

-- double negation narrowing
analyze[[
    local x: number | nil
    if not not x then
        attest.equal(x, _ as number)
    end
]]

-- ==========================================================================
-- while loop condition narrowing
-- ==========================================================================

analyze[[
    local x: number | nil
    while x do
        attest.equal(x, _ as number)
        break
    end
]]

-- ==========================================================================
-- and/or result type combinations
-- ==========================================================================

-- or with certainly-false left
analyze[[
    local result = false or 42
    attest.equal(result, 42)
]]

-- and with certainly-true left
analyze[[
    local result = true and "hello"
    attest.equal(result, "hello")
]]

-- and with certainly-false left
analyze[[
    local result = nil and "hello"
    attest.equal(result, nil)
]]

-- chained or with mixed types (a and b are always falsy, so result is c)
analyze[[
    local a: nil | false
    local b: nil | false
    local c: number
    local result = a or b or c
    attest.equal(result, _ as number)
]]

-- ==========================================================================
-- Future / harder edge cases (pending)
-- ==========================================================================

-- narrowing table fields through stored checks
analyze[[
    local t = {x = 1 as number | nil}
    local check = t.x ~= nil
    if check then
        attest.equal(t.x, 1 as number)
    end
]]

-- narrowing table field via local alias back-propagation
analyze[[
    local t = {foo = 1 as number | nil}
    local val = t.foo
    if val then
        attest.equal(t.foo, 1 as number)
    end
]]

-- TODO: and/or in else branches of stored conditions
pending[[
    local a: number | nil
    local b: string | nil
    local check = (a ~= nil) and (b ~= nil)
    if not check then
        -- at least one is nil, but we can't know which
        attest.equal(a, _ as number | nil)
        attest.equal(b, _ as string | nil)
    end
]]

-- stored condition with type() check
analyze[[
    local x: number | string
    local is_num = type(x) == "number"
    if is_num then
        attest.equal(x, _ as number)
    end
]]

-- stored condition reused in multiple branches
analyze[[
    local x: number | nil
    local ok = x ~= nil
    if ok then
        attest.equal(x, _ as number)
    end
    -- later, same check reused
    if ok then
        attest.equal(x, _ as number)
    end
]]
