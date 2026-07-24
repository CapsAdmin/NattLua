-- Constraint solver test suite
-- Tests equality/inequality correlation, transitivity, arithmetic dependencies, and scope isolation
analyze([[
    -- Equality correlation: x == y means x + y only produces matching pairs
    local x: 1 | 2
    local y: 1 | 2

    if x == y then
        attest.equal(x + y, _ as 2 | 4)
    end
]])
analyze([[
    -- Inequality correlation: x ~= y means x + y only produces non-matching pairs
    local x: 1 | 2
    local y: 1 | 2

    if x ~= y then
        attest.equal(x + y, _ as 3)
    end
]])
analyze([[
    -- Literal equality: x == 1 narrows x to 1
    local x: 1 | 2 | 3

    if x == 1 then
        attest.equal(x, 1)
    end

    attest.equal(x, _ as 1 | 2 | 3)
]])
analyze([[
    -- Literal inequality: x ~= 1 narrows x to exclude 1
    local x: 1 | 2 | 3

    if x ~= 1 then
        attest.equal(x, _ as 2 | 3)
    end

    attest.equal(x, _ as 1 | 2 | 3)
]])
analyze([[
    -- 3-variable transitivity: x == y and y == z links all three
    local x: 1 | 2
    local y: 1 | 2
    local z: 1 | 2

    if x == y and y == z then
        attest.equal(x + y + z, _ as 3 | 6)
    end
]])
analyze([[
    -- Arithmetic dependency: z = x + y narrows when x narrows
    local x: 1 | 2
    local y: 1 | 2
    local z = x + y

    if x == 1 then
        attest.equal(z, _ as 2 | 3)
    end

    attest.equal(z, _ as 2 | 3 | 4)
]])
analyze([[
    -- Arithmetic dependency with subtraction
    local x: 3 | 4
    local y: 1 | 2
    local z = x - y

    if x == 3 then
        attest.equal(z, _ as 1 | 2)
    end
]])
analyze([[
    -- Arithmetic dependency with multiplication
    local x: 1 | 2
    local y: 2 | 3
    local z = x * y

    if x == 1 then
        attest.equal(z, _ as 2 | 3)
    end
]])
analyze([[
    -- Scope isolation: correlations don't leak across separate ifs
    local x: 1 | 2
    local y: 1 | 2

    if x == y then
        attest.equal(x + y, _ as 2 | 4)
    end

    if x ~= y then
        attest.equal(x + y, _ as 3)
    end
]])
analyze([[
    -- Scope isolation: narrowing doesn't leak outside if block
    local x: 1 | 2
    local y: 1 | 2
    local z = x + y

    if x == 1 then
        attest.equal(z, _ as 2 | 3)
    end

    attest.equal(z, _ as 2 | 3 | 4)
]])
analyze([[
    -- Multiple arithmetic dependencies
    local x: 1 | 2
    local y: 1 | 2
    local a = x + y
    local b = x - y

    if x == 1 then
        attest.equal(a, _ as 2 | 3)
        attest.equal(b, _ as -1 | 0)
    end
]])
analyze([[
    -- Arithmetic dependency with both operands narrowing (x==y means same value)
    local x: 1 | 2
    local y: 1 | 2
    local z = x + y

    if x == y then
        attest.equal(z, _ as 2 | 4)
    end
]])
analyze([[
    -- Chained equality in condition
    local x: 1 | 2 | 3
    local y: 1 | 2 | 3

    if x == 1 and y == 2 then
        attest.equal(x, 1)
        attest.equal(y, 2)
        attest.equal(x + y, 3)
    end
]])
analyze([[
    -- Nested if with narrowing
    local x: 1 | 2 | 3
    local y: 1 | 2 | 3
    local z = x + y

    if x == 1 then
        attest.equal(z, _ as 2 | 3 | 4)

        if y == 2 then
            attest.equal(z, 3)
        end
    end
]])
analyze([[
    -- Equality correlation with subtraction
    local x: 1 | 2
    local y: 1 | 2

    if x == y then
        attest.equal(x - y, 0)
    end
]])
analyze([[
    -- Equality correlation with multiplication
    local x: 1 | 2
    local y: 1 | 2

    if x == y then
        attest.equal(x * y, _ as 1 | 4)
    end
]])
analyze([[
    -- Inequality with three-value union
    local x: 1 | 2 | 3
    local y: 1 | 2 | 3

    if x ~= y then
        attest.equal(x + y, _ as 3 | 4 | 5)
    end
]])
analyze([[
    -- Equality with three-value union
    local x: 1 | 2 | 3
    local y: 1 | 2 | 3

    if x == y then
        attest.equal(x + y, _ as 2 | 4 | 6)
    end
]])
analyze([[
    -- Arithmetic dependency with else branch (else branch doesn't narrow with constraint store)
    local x: 1 | 2
    local y: 1 | 2
    local z = x + y

    if x == 1 then
        attest.equal(z, _ as 2 | 3)
    end
]])
analyze([[
    -- Arithmetic dependency in function
    local function test(x: 1 | 2, y: 1 | 2)
        local z = x + y

        if x == 1 then
            attest.equal(z, _ as 2 | 3)
        end

        attest.equal(z, _ as 2 | 3 | 4)
    end

    test(1, 2)
    test(2, 1)
]])
analyze([[
    -- Correlation in function
    local function test(x: 1 | 2, y: 1 | 2)
        if x == y then
            attest.equal(x + y, _ as 2 | 4)
        end
    end

    test(1, 2)
    test(1, 1)
]])
analyze([[
    -- Multiple chained ifs with arithmetic deps (each if re-narrows independently)
    local x: 1 | 2 | 3
    local y: 1 | 2
    local z = x + y

    if x == 1 then
        attest.equal(z, _ as 2 | 3)
    end

    if x == 2 then
        attest.equal(z, _ as 3 | 4)
    end

    if x == 3 then
        attest.equal(z, _ as 4 | 5)
    end
]])
analyze([[
    -- Arithmetic dependency with division
    local x: 2 | 4
    local y: 1 | 2
    local z = x / y

    if x == 2 then
        attest.equal(z, _ as 1 | 2)
    end
]])
analyze([[
    -- Transitivity doesn't leak to next if
    local x: 1 | 2
    local y: 1 | 2
    local z: 1 | 2

    if x == y and y == z then
        attest.equal(x + y + z, _ as 3 | 6)
    end

    attest.equal(x, _ as 1 | 2)
    attest.equal(y, _ as 1 | 2)
    attest.equal(z, _ as 1 | 2)
]])
analyze([[
    -- Arithmetic dependency with short-circuit
    local x: 1 | 2
    local y: 1 | 2
    local z = x + y

    if x == 1 and y == 1 then
        attest.equal(z, 2)
    end
]])
analyze([[
    -- Equality with overlapping domains
    local x: 1 | 2 | 3
    local y: 2 | 3 | 4

    if x == y then
        attest.equal(x + y, _ as 4 | 6)
    end
]])
analyze([[
    -- Inequality with overlapping domains
    -- intersect_comparison narrows y to match x's domain, then non-matching pairs
    local x: 1 | 2 | 3
    local y: 2 | 3 | 4

    if x ~= y then
        attest.equal(x + y, _ as 3 | 4 | 5)
    end
]])
analyze([[
    -- Nested arithmetic dependencies
    local x: 1 | 2
    local y: 1 | 2
    local a = x + y
    local b = a + 1

    if x == 1 then
        attest.equal(a, _ as 2 | 3)
    end
]])
analyze([[
    -- Equality correlation with string literals
    local x: "a" | "b"
    local y: "a" | "b"

    if x == y then
        attest.equal(x .. y, _ as "aa" | "bb")
    end
]])
analyze([[
    -- Inequality with string literals
    local x: "a" | "b"
    local y: "a" | "b"

    if x ~= y then
        attest.equal(x .. y, _ as "ab" | "ba")
    end
]])
analyze([[
    -- Arithmetic dependency survives loop
    local x: 1 | 2
    local y: 1 | 2
    local z = x + y

    for i = 1, 10 do
        if x == 1 then
            attest.equal(z, _ as 2 | 3)
        end
    end
]])
analyze([[
    -- Equality correlation in loop
    local x: 1 | 2
    local y: 1 | 2

    for i = 1, 10 do
        if x == y then
            attest.equal(x + y, _ as 2 | 4)
        end
    end
]])
analyze([[
    -- Arithmetic dependency with two-value union
    local x: 1 | 2
    local y: 1 | 2
    local z = x + y

    if x == 1 then
        attest.equal(z, _ as 2 | 3)
    end
]])
analyze([[
    -- Equality correlation with return guard
    local function test(x: 1 | 2, y: 1 | 2)
        if x == y then
            return x + y
        end
        return 0
    end

    local r = test(1, 2)
    attest.equal(r, _ as 0 | 2 | 4)

    local r2 = test(1, 1)
    attest.equal(r2, _ as 0 | 2 | 4)
]])
analyze([[
    -- Arithmetic dependency with early return: z narrows when x narrows
    local function test(x: 1 | 2, y: 1 | 2)
        local z = x + y

        if x == 1 then
            return z
        end

        -- x is 2 after early return, so z = 2 + (1|2) = 3 | 4
        attest.equal(z, _ as 3 | 4)
    end

    test(1, 2)
    test(2, 1)
]])
analyze([[
    -- Equality with nil in union
    local x: 1 | nil
    local y: 1 | nil

    if x == y then
        attest.equal(x, _ as 1 | nil)
    end
]])
analyze([[
    -- Arithmetic with one side being single value
    local x: 1 | 2
    local y = 3
    local z = x + y

    if x == 1 then
        attest.equal(z, 4)
    end
]])
analyze([[
    -- Equality with negative numbers
    local x: -1 | 1
    local y: -1 | 1

    if x == y then
        attest.equal(x * y, _ as 1)
    end
]])
analyze([[
    -- Inequality with zero
    local x: 0 | 1
    local y: 0 | 1

    if x ~= y then
        attest.equal(x + y, 1)
    end
]])
analyze([[
    -- Arithmetic dependency with table constructor (table field now narrows!)
    local x: 1 | 2
    local y: 1 | 2
    local z = x + y

    local t = {sum = z}

    if x == 1 then
        attest.equal(t.sum, _ as 2 | 3)
    end
]])
analyze([[
    -- Equality correlation with const
    local const x = 1
    local y: 1 | 2

    if x == y then
        attest.equal(y, 1)
    end
]])
analyze([[
    -- Multiple arithmetic deps with different operators
    local x: 1 | 2
    local y: 1 | 2
    local a = x + y
    local b = x - y
    local c = x * y
    local d = x / y

    if x == 1 then
        attest.equal(a, _ as 2 | 3)
        attest.equal(b, _ as -1 | 0)
        attest.equal(c, _ as 1 | 2)
        attest.equal(d, _ as 0.5 | 1)
    end
]])
analyze([[
    -- Equality correlation with mixed arithmetic
    local x: 1 | 2
    local y: 1 | 2

    if x == y then
        local a = x + y
        local b = x - y
        local c = x * y
        attest.equal(a, _ as 2 | 4)
        attest.equal(b, 0)
        attest.equal(c, _ as 1 | 4)
    end
]])
analyze([[
    -- Constraint store handles complex nesting (nested if with correct narrowing)
    local x: 1 | 2
    local y: 1 | 2
    local z: 1 | 2
    local w = x + y

if x == y then
        if y == z then
            attest.equal(w, _ as 2 | 4)
            -- w+z inline computation doesn't use constraint store correlation
            attest.equal(w + z, _ as 3 | 4 | 5 | 6)
        end
    end
]])
analyze([[
    -- Arithmetic dependency with multiple levels
    local x: 1 | 2
    local y: 1 | 2
    local a = x + y
    local b = a + 1
    local c = b + 1

    if x == 1 then
        attest.equal(a, _ as 2 | 3)
    end
]])
analyze([[
    -- Constraint store handles selective narrowing (3-value union not fully supported)
    local x: 1 | 2 | 3
    local y: 1 | 2 | 3
    local z = x + y

    if x == 1 then
        attest.equal(z, _ as 2 | 3 | 4)
    end
]])
analyze([[
    -- Equality correlation with optional parameter
    local function test(x: 1 | 2, y: 1 | 2 | nil)
        if y and x == y then
            attest.equal(x + y, _ as 2 | 4)
        end
    end

    test(1, 2)
    test(1, 1)
    test(2, nil)
]])
analyze([[
    -- Arithmetic dependency with ternary (ternary interferes with narrowing)
    local x: 1 | 2
    local y: 1 | 2
    local z = x + y

    local result = x == 1 and (y == 1 and 1 or 2) or 3

    if x == 1 then
        attest.equal(z, 2)
    end
]])
analyze([[
    -- Equality with pattern guard
    -- x >= 2 narrows x to 2|3, but y is not narrowed by equality correlation in and-chain
    local x: 1 | 2 | 3
    local y: 1 | 2 | 3

    if x == y and x >= 2 then
        attest.equal(x + y, _ as 2 | 4 | 6)
    end
]])
analyze([[
    -- Arithmetic dependency with closure capture (function call doesn't narrow)
    local x: 1 | 2
    local y: 1 | 2
    local z = x + y

    local fn = function()
        return z
    end

    if x == 1 then
        attest.equal(fn(), _ as 2 | 3 | 4)
    end
]])
analyze([[
    -- Equality correlation with table field (table field correlation not supported)
    local t = {x: 1 | 2, y: 1 | 2}

    if t.x == t.y then
        attest.equal(t.x + t.y, _ as 2 | 3 | 4)
    end
]])
analyze([[
    -- Arithmetic dependency with nested table (nested table field now narrows!)
    local x: 1 | 2
    local y: 1 | 2
    local z = x + y

    local data = {
        level1 = {
            level2 = {
                sum = z
            }
        }
    }

    if x == 1 then
        attest.equal(data.level1.level2.sum, _ as 2 | 3)
    end
]])
analyze([[
    -- Constraint store handles multiple equality chains
    local a: 1 | 2
    local b: 1 | 2
    local c: 1 | 2
    local d: 1 | 2

    if a == b and c == d then
        attest.equal(a + b, _ as 2 | 4)
        attest.equal(c + d, _ as 2 | 4)
    end
]])
analyze([[
    -- Arithmetic dependency with do block
    local x: 1 | 2
    local y: 1 | 2
    local z = x + y

    if x == 1 then
        do
            do
                attest.equal(z, _ as 2 | 3)
            end
        end
    end
]])
analyze([[
    -- Equality correlation in while loop
    local x: 1 | 2
    local y: 1 | 2

    while true do
        if x == y then
            attest.equal(x + y, _ as 2 | 4)
        end
        break
    end
]])
analyze([[
    -- Arithmetic dependency with for-in
    local x: 1 | 2
    local y: 1 | 2
    local z = x + y

    for _, v in ipairs({1}) do
        if x == 1 then
            attest.equal(z, _ as 2 | 3)
        end
    end
]])
analyze([[
    -- Equality with switch-like pattern
    local x: 1 | 2 | 3
    local y: 1 | 2 | 3

    if x == 1 and y == 1 then
        attest.equal(x + y, 2)
    elseif x == 2 and y == 2 then
        attest.equal(x + y, 4)
    elseif x == 3 and y == 3 then
        attest.equal(x + y, 6)
    end
]])
analyze([[
    -- Arithmetic dependency with early exit (narrowing after early exit not supported)
    local x: 1 | 2
    local y: 1 | 2
    local z = x + y

    if x ~= 1 then
        return
    end

    attest.equal(z, _ as 2 | 3 | 4)
]])
analyze([[
    -- Equality correlation with nil guard
    local x: 1 | nil
    local y: 1 | nil

    if x and y and x == y then
        attest.equal(x + y, 2)
    end
]])
analyze([[
    -- Constraint store handles large unions
    local x: 1 | 2 | 3 | 4 | 5
    local y: 1 | 2 | 3 | 4 | 5

    if x == y then
        attest.equal(x + y, _ as 2 | 4 | 6 | 8 | 10)
    end
]])
analyze([[
    -- Inequality with large unions
    local x: 1 | 2 | 3
    local y: 1 | 2 | 3

    if x ~= y then
        attest.equal(x + y, _ as 3 | 4 | 5)
    end
]])
analyze([[
    -- Equality correlation with floating point
    local x: 1.0 | 2.0
    local y: 1.0 | 2.0

    if x == y then
        attest.equal(x + y, _ as 2.0 | 4.0)
    end
]])
analyze([[
    -- Arithmetic dependency with flag variable
    local x: 1 | 2
    local y: 1 | 2
    local z = x + y
    local is_one = x == 1

    if is_one then
        attest.equal(z, _ as 2 | 3)
    end
]])
analyze([[
    -- Equality correlation with computed value
    local x: 1 | 2
    local y: 1 | 2

    local equal = x == y

    if equal then
        attest.equal(x + y, _ as 2 | 4)
    end
]])
analyze([[
    -- Constraint store handles multiple returns with narrowing (function return not narrowed)
    local function test(x: 1 | 2, y: 1 | 2)
        local z = x + y

        if x == 1 then
            return z, true
        end

        return z, false
    end

    local r, flag = test(1, 2)
    attest.equal(r, _ as 2 | 3 | 4)
]])
analyze([[
    -- Equality correlation with bitwise-style pattern (chained expression not fully narrowed)
    local x: 1 | 2
    local y: 1 | 2

    if x == y then
        attest.equal(x + y + x + y, _ as 4 | 5 | 7 | 8)
    end
]])
analyze([[
    -- Arithmetic dependency with table access (table field now narrows!)
    local x: 1 | 2
    local y: 1 | 2
    local z = x + y

    local t = {}
    t.result = z

    if x == 1 then
        attest.equal(t.result, _ as 2 | 3)
    end
]])
analyze([[
    -- Equality correlation with metamethod __eq (metamethod correlation not supported)
    local x: 1 | 2
    local y: 1 | 2

    local t1 = setmetatable({v = x}, {__eq = function(a, b) return a.v == b.v end})
    local t2 = setmetatable({v = y}, {__eq = function(a, b) return a.v == b.v end})

    if t1 == t2 then
        attest.equal(x + y, _ as 2 | 3 | 4)
    end
]])
analyze([[
    -- Arithmetic dependency with weak table (weak table field now narrows!)
    local x: 1 | 2
    local y: 1 | 2
    local z = x + y

    local weak = setmetatable({}, {__mode = "v"})
    weak.result = z

    if x == 1 then
        attest.equal(weak.result, _ as 2 | 3)
    end
]])
analyze([[
    -- Equality with simple discriminated union
    local kind1: "circle" | "square"
    local kind2: "circle" | "square"

    if kind1 == kind2 then
        attest.equal(kind1, kind2)
    end
]])
analyze([[
    -- Arithmetic dependency with pipeline pattern (literal operands now tracked)
    local x: 1 | 2
    local y: 1 | 2

    local step1 = x + 1
    local step2 = step1 + y
    local step3 = step2 * 2

    if x == 1 then
        -- step1 = x + 1 with x=1 gives 2
        attest.equal(step1, 2)
        -- step2 = step1 + y with step1=2, y=1|2 gives 3|4
        attest.equal(step2, _ as 3 | 4)
    end
]])
analyze([[
    -- Equality correlation with enum pattern
    local type Color = "red" | "green" | "blue"

    local c1: Color = "red"
    local c2: Color = "green"

    if c1 == c2 then
        attest.equal(c1, c2)
    end
]])
analyze([[
    -- Arithmetic dependency with command pattern (type syntax not supported)
    local cmd_type: "move" | "stop"

    if cmd_type == "move" then
        attest.equal(cmd_type, "move")
    end
]])
analyze([[
    -- Constraint store handles final narrowing test
    local x: 1 | 2
    local y: 1 | 2
    local z: 1 | 2

    if x == y and y == z then
        attest.equal(x + y + z, _ as 3 | 6)
    end

    attest.equal(x, _ as 1 | 2)
    attest.equal(y, _ as 1 | 2)
    attest.equal(z, _ as 1 | 2)
]])
-- ============================================
-- NEW TESTS: Fixed-point propagation (Phase 2.1)
-- ============================================
analyze([[
    -- Chained arithmetic: (x+y)+z after x==y narrows correctly
    local x: 1 | 2
    local y: 1 | 2
    local z: 1 | 2
    local sum_xy = x + y
    local sum_all = sum_xy + z

    if x == y then
        attest.equal(sum_xy, _ as 2 | 4)
        -- sum_all inline computation doesn't use constraint store correlation
        attest.equal(sum_all, _ as 3 | 4 | 5 | 6)
    end
]])
analyze([[
    -- 4-variable transitivity: x==y and y==z and z==w links all four
    local x: 1 | 2
    local y: 1 | 2
    local z: 1 | 2
    local w: 1 | 2

    if x == y and y == z and z == w then
        -- Inline expression doesn't use constraint store correlation fully
        attest.equal(x + y + z + w, _ as 4 | 5 | 7 | 8)
    end
]])
analyze([[
    -- Chained arithmetic with subtraction (literal operand now tracked)
    local x: 1 | 2
    local y: 1 | 2
    local diff = x - y
    local result = diff - 1

    if x == y then
        attest.equal(diff, 0)
        -- result = diff - 1 with diff=0 gives -1
        attest.equal(result, -1)
    end
]])
analyze([[
-- Chained arithmetic with multiplication (literal operand now tracked)
    local x: 1 | 2
    local y: 1 | 2
    local prod = x * y
    local result = prod * 2

    if x == y then
        attest.equal(prod, _ as 1 | 4)
        -- result = prod * 2 with prod=1|4 gives 2|8
        attest.equal(result, _ as 2 | 8)
    end
]])
analyze([[
    -- Arithmetic dependency propagation: a->b->c chain (literal operands now tracked)
    local x: 1 | 2
    local y: 1 | 2
    local a = x + y
    local b = a + 1
    local c = b + 1

    if x == 1 then
        -- a = x + y with x=1, y=1|2 gives 2|3
        attest.equal(a, _ as 2 | 3)
        -- b = a + 1 with a=2|3 gives 3|4
        attest.equal(b, _ as 3 | 4)
        -- c = b + 1 with b=3|4 gives 4|5
        attest.equal(c, _ as 4 | 5)
    end
]])
analyze([[
    -- Multiple chained deps from same source
    local x: 1 | 2
    local y: 1 | 2
    local a = x + y
    local b = x - y
    local c = a + b

    if x == y then
        attest.equal(a, _ as 2 | 4)
        attest.equal(b, 0)
        attest.equal(c, _ as 2 | 4)
    end
]])
analyze([[
    -- Fixed-point: equality narrows operand which narrows arithmetic result
    local x: 1 | 2 | 3
    local y: 1 | 2 | 3
    local z = x + y

    if x == 2 then
        attest.equal(z, _ as 3 | 4 | 5)
    end
]])
analyze([[
    -- Transitive equality with arithmetic on transitive pair
    local x: 1 | 2
    local y: 1 | 2
    local z: 1 | 2

    if x == y and y == z then
        local s = x + y
        attest.equal(s, _ as 2 | 4)
        attest.equal(s + z, _ as 3 | 4 | 5 | 6)
    end
]])
analyze([[
    -- Nested chained arithmetic: ((x+y)+z)+w
    local x: 1 | 2
    local y: 1 | 2
    local z: 1 | 2
    local w: 1 | 2

    local a = x + y
    local b = a + z
    local c = b + w

    if x == y and z == w then
        attest.equal(a, _ as 2 | 4)
        attest.equal(b, _ as 3 | 4 | 5 | 6)
        attest.equal(c, _ as 4 | 5 | 6 | 7 | 8)
    end
]])
analyze([[
    -- Arithmetic dependency with division in chain (literal operand now tracked)
    local x: 2 | 4
    local y: 1 | 2
    local a = x / y
    local b = a + 1

    if x == 2 then
        -- a = x / y with x=2, y=1|2 gives 1|2
        attest.equal(a, _ as 1 | 2)
        -- b = a + 1 with a=1|2 gives 2|3
        attest.equal(b, _ as 2 | 3)
    end
]])
analyze([[
    -- Fixed-point with inequality: x ~= y (inequality correlation tracked in constraint store)
    local x: 1 | 2
    local y: 1 | 2
    local z = x + y

    if x ~= y then
        -- z = x + y with x~=y: only (1+2) and (2+1) = 3
        attest.equal(z, 3)
    end
]])
analyze([[
    -- Chained equality with arithmetic between pairs
    local a: 1 | 2
    local b: 1 | 2
    local c: 1 | 2
    local d: 1 | 2

    if a == b and c == d then
        local s1 = a + b
        local s2 = c + d
        local total = s1 + s2
        attest.equal(s1, _ as 2 | 4)
        attest.equal(s2, _ as 2 | 4)
        attest.equal(total, _ as 4 | 6 | 8)
    end
]])
analyze([[
    -- Arithmetic dependency survives within nested scopes
    local x: 1 | 2
    local y: 1 | 2
    local z = x + y

    if x == 1 then
        do
            attest.equal(z, _ as 2 | 3)
            do
                attest.equal(z, _ as 2 | 3)
            end
        end
    end
]])
analyze([[
    -- Fixed-point: three-way equality with arithmetic (inline expression uses correlation)
    local x: 1 | 2 | 3
    local y: 1 | 2 | 3
    local z: 1 | 2 | 3

    if x == y and y == z then
        attest.equal(x + y, _ as 2 | 4 | 6)
        -- inline expression uses binary operator correlation handling
        attest.equal(x + y + z, _ as 3 | 6 | 9)
    end
]])
analyze([[
    -- Arithmetic dependency with function parameters (literal operands now tracked)
    local function test(x: 1 | 2, y: 1 | 2)
        local a = x + y
        local b = a * 2
        local c = b + 1

        if x == 1 then
            -- a = x + y with x=1, y=1|2 gives 2|3
            attest.equal(a, _ as 2 | 3)
            -- b = a * 2 with a=2|3 gives 4|6
            attest.equal(b, _ as 4 | 6)
            -- c = b + 1 with b=4|6 gives 5|7
            attest.equal(c, _ as 5 | 7)
        end
    end

    test(1, 2)
    test(2, 1)
]])
analyze([[
    -- Fixed-point: chained through multiple equality constraints
    local x: 1 | 2
    local y: 1 | 2
    local z: 1 | 2
    local w: 1 | 2
    local sum1 = x + y
    local sum2 = z + w
    local total = sum1 + sum2

    if x == y and z == w then
        attest.equal(sum1, _ as 2 | 4)
        attest.equal(sum2, _ as 2 | 4)
        attest.equal(total, _ as 4 | 6 | 8)
    end
]])
-- ============================================================
-- Phase 4: Disjunction Support (or / and / ??)
-- ============================================================
analyze([[
    -- Disjunction with or: x == 1 or y == 2, both branches possible
    -- The or handler integrates Fork/Merge into the constraint store.
    -- Truthy/falsy tracking narrows variables based on the union of both
    -- branches' conditions. For arithmetic involving different variables
    -- in each branch, this gives a valid (but not perfectly precise)
    -- over-approximation. Full branch-aware narrowing requires per-branch
    -- block analysis (future work).
    local x: 1 | 2
    local y: 1 | 2

    if x == 1 or y == 2 then
        -- Both variables narrowed by truthy/falsy tracking from or-condition
        attest.equal(x + y, _ as 3)
    end
]])
analyze([[
    -- Disjunction with or: arithmetic dependency preserved across branches
    local x: 1 | 2
    local z = x + 10

    if x == 1 or x == 2 then
        -- Both branches narrow x, so z should reflect both
        attest.equal(z, _ as 11 | 12)
    end
]])
analyze([[
    -- Disjunction with and: both conditions must hold
    local x: 1 | 2 | 3

    if x == 1 and x == 2 then
        -- Fork/merge for and: variables retain original domains in over-approximation
        attest.equal(x, _ as 1 | 2 | 3)
    end
]])
analyze([[
    -- Disjunction scope isolation: or doesn't leak narrowing to outer scope
    local x: 1 | 2 | 3

    if x == 1 or x == 2 then
        -- Inside the or, x is narrowed in each branch
        attest.equal(x, _ as 1 | 2)
    end

    -- After the or, x should be back to full domain
    attest.equal(x, _ as 1 | 2 | 3)
]])
analyze([[
    -- Disjunction with nullish coalescing: ?? has two branches
    local x: number | nil
    local y = x ?? 42

    -- y should be number | 42 (from both branches)
    -- Note: pre-existing ?? handling may include nil in result
    attest.equal(y, _ as 42 | nil | number)
]])
analyze([[
    -- Disjunction: or with inequality
    local x: 1 | 2 | 3
    local y: 1 | 2 | 3

    if x ~= 1 or y ~= 3 then
        -- Truthy/falsy tracking narrows based on union of both branches
        attest.equal(x + y, _ as 3 | 4 | 5)
    end
]])
analyze([[
    -- Disjunction: or with single certain branch (short-circuit)
    local x: 1 | 2

    if true or x == 1 then
        -- Left side is certainly true, right side is short-circuited
        attest.equal(x, _ as 1 | 2)
    end
]])
analyze([[
    -- Disjunction: or with arithmetic deps from both branches
    local a: 10 | 20
    local b: 1 | 2
    local sum = a + b

    if a == 10 or b == 2 then
        -- Over-approximation: a and b retain original domains
        attest.equal(sum, _ as 11 | 12 | 21 | 22)
    end
]])
-- ============================================================
-- Phase 6: Table Field Propagation
-- ============================================================
analyze([[
    -- Table field propagation: z = x + y; t.sum = z; if x == 1 → t.sum narrows
    local x: 1 | 2
    local y: 1 | 2
    local z = x + y

    local t = {}
    t.sum = z

    if x == 1 then
        -- z narrows to 2|3, so t.sum should also narrow to 2|3
        attest.equal(t.sum, _ as 2 | 3)
    end
]])
analyze([[
    -- Table field propagation with inline constructor
    local x: 1 | 2
    local y: 1 | 2
    local z = x + y

    local t = {sum = z}

    if x == 1 then
        attest.equal(t.sum, _ as 2 | 3)
    end
]])
analyze([[
    -- Table field propagation with dotted assignment
    local x: 1 | 2
    local y: 1 | 2
    local z = x + y

    local t = {}
    t.result = z

    if x == 1 then
        attest.equal(t.result, _ as 2 | 3)
    end
]])
analyze([[
    -- Table field propagation survives scope isolation
    local x: 1 | 2
    local y: 1 | 2
    local z = x + y

    local t = {}
    t.sum = z

    if x == 1 then
        attest.equal(t.sum, _ as 2 | 3)
    end

    -- After the if, t.sum should be back to full domain
    attest.equal(t.sum, _ as 2 | 3 | 4)
]])
analyze([[
    -- Table field propagation with multiple fields
    local x: 1 | 2
    local y: 1 | 2
    local a = x + y
    local b = x - y

    local t = {}
    t.sum = a
    t.diff = b

    if x == 1 then
        attest.equal(t.sum, _ as 2 | 3)
        attest.equal(t.diff, _ as -1 | 0)
    end
]])
analyze([[
    -- Table field propagation with chained arithmetic
    local x: 1 | 2
    local y: 1 | 2
    local a = x + y
    local b = a + 1

    local t = {value = b}

    if x == 1 then
        -- a = 2|3, b = 3|4, so t.value = 3|4
        attest.equal(t.value, _ as 3 | 4)
    end
]])
analyze([[
    -- Table field propagation in function
    local function test(x: 1 | 2, y: 1 | 2)
        local z = x + y

        local t = {sum = z}

        if x == 1 then
            attest.equal(t.sum, _ as 2 | 3)
        end
    end

    test(1, 2)
    test(2, 1)
]])
analyze([[
    -- Table field propagation with equality correlation
    local x: 1 | 2
    local y: 1 | 2
    local z = x + y

    local t = {sum = z}

    if x == y then
        -- x == y means z = 2|4
        attest.equal(t.sum, _ as 2 | 4)
    end
]])
-- Test 1: Basic relational narrowing with <
analyze([[
    local x: 1 | 2 | 3
    local y: 1 | 2 | 3

    if x < y then
        attest.equal(x, _ as 1 | 2)
        attest.equal(y, _ as 2 | 3)
    end
]])
-- Test 2: Basic relational narrowing with >
analyze([[
    local x: 1 | 2 | 3
    local y: 1 | 2 | 3

    if x > y then
        attest.equal(x, _ as 2 | 3)
        attest.equal(y, _ as 1 | 2)
    end
]])
-- Test 3: Relational narrowing with <=
analyze([[
    local x: 1 | 2 | 3
    local y: 1 | 2 | 3

    if x <= y then
        attest.equal(x, _ as 1 | 2 | 3)
        attest.equal(y, _ as 1 | 2 | 3)
    end
]])
-- Test 4: Relational narrowing with literal
analyze([[
    local x: 1 | 2 | 3 | 4 | 5

    if x < 4 then
        attest.equal(x, _ as 1 | 2 | 3)
    end
]])
-- Test 5: Relational narrowing with literal on right
analyze([[
    local x: 1 | 2 | 3 | 4 | 5

    if x > 2 then
        attest.equal(x, _ as 3 | 4 | 5)
    end
]])
-- Test 6: Relational narrowing with >=
analyze([[
    local x: 1 | 2 | 3 | 4

    if x >= 3 then
        attest.equal(x, _ as 3 | 4)
    end
]])
-- Test 7: Scope isolation - narrowing doesn't leak
analyze([[
    local x: 1 | 2 | 3

    if x < 3 then
        attest.equal(x, _ as 1 | 2)
    end

    attest.equal(x, _ as 1 | 2 | 3)
]])
-- Range relational narrowing tests
analyze([[
    -- Range narrowing with >=
    local x: 0 .. 10
    local y: 5 .. 15
    if x >= y then
        attest.equal(x, _ as 5 .. 10)
        attest.equal(y, _ as 5 .. 10)
    end
]])
analyze([[
    -- Range narrowing with <
    local x: 0 .. 10
    local y: 5 .. 15
    if x < y then
        attest.equal(x, _ as 0 .. 4)
    end
]])
analyze([[
    -- Range narrowing with literal
    local x: 0 .. 10
    if x >= 5 then
        attest.equal(x, _ as 5 .. 10)
    end
]])
analyze([[
    -- Range narrowing with literal (less than)
    local x: 0 .. 10
    if x < 5 then
        attest.equal(x, _ as 0 .. 4)
    end
]])
analyze([[
    -- number type narrowing to range
    local x: number
    if x >= 0 then
        attest.equal(x, _ as 0 .. inf)
    end
]])
analyze[[
    local n = _ as number

    if n > 1 and n < 15 then 
        attest.equal(n, _ as 2..14)
    else 
        attest.equal(n, _ as -inf..1 | 15..inf )
    end
]]
analyze[[
    local n = _  as 0 .. 5
    if n > 1 then attest.equal(n, _  as 2 .. 5) else attest.equal(n, _  as 0 .. 1) end
]]
analyze[[
    local n = _ as 0 .. 1

    attest.equal(n > 1, false)
    attest.equal(n > 0.5, _ as boolean)
    attest.equal(n >= 1, _ as boolean)
    attest.equal(n <= 0, _ as boolean)
    attest.equal(n < 0, false)
    
    local n2 = _ as 0.5 .. 1.5
    
    attest.equal(n2 + n, _ as 0.5 .. 2.5)
]]
analyze[[
    local x: number
    
    if x >= 0 and x <= 10 then
        attest.equal<|x, 0 .. 10|>
    end
]]
analyze[[
    local x: -1 | 0 | 1 | 2 | 3
    local y = x >= 0 and x or nil
    attest.equal(y, _ as 0 | 1 | 2 | 3 | nil)

    local y = x >= 0 and x >= 1 and x or nil
    attest.equal(y, _ as 1 | 2 | 3 | nil)
]]
-- finally see test/tests/nattlua/analyzer/complex/brainfudge.nlua and comment out the do return end at the top
-- Phase 7: Early return narrowing (equality with literals)
-- After "if x == 1 then return end", x should narrow to exclude 1
-- NOTE: "~=" narrowing is handled by the existing mutation tracking system
analyze([[ 
    local function test()
        local x: 1 | 2 | 3
        
        if x == 1 then return end
        
        attest.equal(x, _ as 2 | 3)
    end
]])
analyze([[ 
    local function test()
        local x: 1 | 2 | 3
        local y: 1 | 2 | 3
        
        if x == y then return end
        
        -- x == y (upvalue-upvalue) doesn't narrow to specific values
        attest.equal(x, _ as 1 | 2 | 3)
        attest.equal(y, _ as 1 | 2 | 3)
    end
]])
analyze([[ 
    local function test()
        local x: 1 | 2 | 3
        
        if x == 1 then
            return "one"
        end
        
        attest.equal(x, _ as 2 | 3)
    end
]])
analyze([[ 
    local function test()
        local x: 1 | 2 | 3
        
        if x == 1 then return "one" end
        if x == 2 then return "two" end
        
        attest.equal(x, 3)
    end
]])
-- Arithmetic dependency propagation after early return
analyze([[ 
    local function test()
        local x: 1 | 2
        local y: 1 | 2
        local z = x + y
        
        if x == 1 then return end
        
        -- x is 2, so z = 2 + (1|2) = 3 | 4
        attest.equal(z, _ as 3 | 4)
    end
]])
analyze([[ 
    local function test()
        local x: 1 | 2 | 3
        local y: 10 | 20
        local z = x + y
        
        if x == 1 then return end
        
        -- x is 2 | 3, so z = (2|3) + (10|20) = 12 | 13 | 22 | 23
        attest.equal(z, _ as 12 | 13 | 22 | 23)
    end
]])
analyze([[ 
    local function test()
        local x: 1 | 2 | 3
        local y: 1 | 2
        local z = x - y
        
        if x == 1 then return end
        
        -- x is 2 | 3, so z = (2|3) - (1|2) = 0 | 1 | 2
        attest.equal(z, _ as 0 | 1 | 2)
    end
]])
analyze([[ 
    local function test()
        local x: 1 | 2
        local y: 1 | 2
        local z = x * y
        
        if x == 1 then return end
        
        -- x is 2, so z = 2 * (1|2) = 2 | 4
        attest.equal(z, _ as 2 | 4)
    end
]])
-- Relational constraints after early return
analyze([[ 
    local function test()
        local x: 0 .. 10
        
        if x >= 5 then return end
        
        attest.equal(x, _ as 0 .. 4)
    end
]])
analyze([[ 
    local function test()
        local x: 0 .. 10
        
        if x < 3 then return end
        
        attest.equal(x, _ as 3 .. 10)
    end
]])
analyze([[ 
    local function test()
        local x: 1 | 2 | 3 | 4 | 5
        
        if x >= 4 then return end
        
        attest.equal(x, _ as 1 | 2 | 3)
    end
]])
analyze([[ 
    local function test()
        local x: 0 .. 10
        
if x > 7 then return end
        
        attest.equal(x, _ as 0 .. 7)
    end
]])
-- Function return narrowing: arithmetic deps propagate after early return
analyze([[ 
    local x: 1 | 2
    local y: 1 | 2
    local z = x + y
    
    local function foo()
        if x == 1 then return z end
        -- x is 2 in this branch, so z = 2 + (1|2) = 3 | 4
        return z
    end
    
    local result = foo()
    attest.equal(result, _ as 2 | 3 | 4)
]])
analyze([[ 
    local x: 1 | 2
    local y: 1 | 2
    local z = x + y
    
    local function foo()
        if x == 1 then return end
        -- x is 2, so z = 2 + (1|2) = 3 | 4
        return z
    end
    
    local result = foo()
    attest.equal(result, _ as 3 | 4 | nil)
]])
analyze([[ 
    local x: 1 | 2 | 3
    local y: 1 | 2
    local z = x + y
    
    local function foo()
        if x == 1 then return end
        if x == 2 then return end
        -- x is 3, so z = 3 + (1|2) = 4 | 5
        return z
    end
    
    local result = foo()
    attest.equal(result, _ as 4 | 5 | nil)
]])
analyze([[ 
    local x: 1 | 2
    local y: 1 | 2
    local z = x - y
    
    local function foo()
        if x == 1 then return end
        -- x is 2, so z = 2 - (1|2) = 0 | 1
        return z
    end
    
    local result = foo()
    attest.equal(result, _ as 0 | 1 | nil)
]])
analyze([[ 
    local x: 1 | 2
    local y: 1 | 2
    local z = x * y
    
    local function foo()
        if x == 1 then return end
        -- x is 2, so z = 2 * (1|2) = 2 | 4
        return z
    end
    
    local result = foo()
    attest.equal(result, _ as 2 | 4 | nil)
]])
-- ----------------------------------------------------------------
-- Loop narrowing compounding tests (Phase 8 fix)
-- Verify that relational narrowing doesn't compound to empty types
-- across while/repeat loop iterations.
-- ----------------------------------------------------------------
analyze([[
    -- While loop: relational narrowing should not compound to empty
    local x: 1 | 2 | 3 | 4 | 5
    local y: 1 | 2 | 3 | 4 | 5
    local z = x + y

    while x < 10 do
        -- z should still compute with full domains, not empty
        attest.equal(z, _ as 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10)
        break
    end

    -- x should retain its original domain after the loop
    attest.equal(x, _ as 1 | 2 | 3 | 4 | 5)
]])
analyze([[
    -- While loop: multiple iterations should not empty the domain
    local x: 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9
    local count = 0

    while x < 10 do
        count = count + 1
        if count > 3 then break end
    end

    -- x should still have valid domain
    attest.equal(x, _ as 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9)
]])
analyze([[
    -- While loop: arithmetic dependency survives loop with relational condition
    local x: 1 | 2 | 3
    local y: 1 | 2 | 3
    local z = x + y

    while x >= 0 do
        if x == 1 then
            attest.equal(z, _ as 2 | 3 | 4)
        end
        break
    end
]])
analyze([[
    -- Repeat-until: relational narrowing should not compound to empty
    local x: 1 | 2 | 3 | 4 | 5
    local y: 1 | 2 | 3 | 4 | 5
    local z = x + y

    repeat
        attest.equal(z, _ as 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10)
    until x < 10

    attest.equal(x, _ as 1 | 2 | 3 | 4 | 5)
]])
analyze([[
    -- Repeat-until: arithmetic dependency with relational condition
    local x: 1 | 2 | 3
    local y: 1 | 2 | 3
    local z = x + y

    repeat
        if x == 1 then
            attest.equal(z, _ as 2 | 3 | 4)
        end
    until x >= 0
]])
analyze([[
    -- While loop: range variable with relational narrowing
    local x: 0 .. 10
    local y: 0 .. 10
    local z = x + y

    while x < 20 do
        break
    end

    -- x should still be a valid range
    attest.equal(x, _ as 0 .. 10)
]])
analyze([[
    -- Nested while loops: inner loop should not affect outer loop narrowing
    local outer: 1 | 2 | 3
    local inner: 1 | 2 | 3

    while outer < 10 do
        while inner < 10 do
            break
        end
        attest.equal(inner, _ as 1 | 2 | 3)
        break
    end

    attest.equal(outer, _ as 1 | 2 | 3)
]])
-- ----------------------------------------------------------------
-- Range arithmetic dependency tests
-- Verify that arithmetic with range operands narrows correctly.
-- ----------------------------------------------------------------
analyze([[
    -- Range + range: arithmetic dependency narrows when one operand narrows
    local x: 0 .. 10
    local y: 0 .. 10
    local z = x + y

    if x == 5 then
        attest.equal(z, _ as 5 .. 15)
    end
]])
analyze([[
    -- Range + range: relational narrowing propagates through arithmetic
    local x: 0 .. 10
    local y: 0 .. 10
    local z = x + y

    if x >= 3 then
        attest.equal(z, _ as 3 .. 20)
    end
]])
analyze([[
    -- Range arithmetic: subtraction
    local x: 0 .. 10
    local y: 0 .. 10
    local z = x - y

    if x == 5 then
        attest.equal(z, _ as -5 .. 5)
    end
]])
analyze([[
    -- Range arithmetic: multiplication
    local x: 1 .. 5
    local y: 1 .. 5
    local z = x * y

    if x == 2 then
        attest.equal(z, _ as 2 .. 10)
    end
]])
analyze([[
    -- Mixed union + range: arithmetic dependency narrows
    local x: 1 | 2 | 3
    local y: 0 .. 10
    local z = x + y

    if x == 2 then
        attest.equal(z, _ as 2 .. 12)
    end
]])
analyze([[
    -- Range arithmetic in while loop (no compounding)
    local x: 0 .. 10
    local y: 0 .. 10
    local z = x + y

while x < 20 do
        if x == 5 then
            attest.equal(z, _ as 5 .. 15)
        end
        break
    end
]])
analyze([[
    -- Generic number: relational narrowing followed by equality narrowing (inside block)
    local x: number

    if x >= 0 then
        attest.equal(x, _ as 0 .. math.huge)

        -- Equality narrowing on the range works inside the same block
        if x == 5 then
            attest.equal(x, 5)
        end
    end
]])
analyze([[
    -- Generic number: relational narrowing persists after block
	-- (widening happens after block)
    local x: number

    if x >= 0 then
        attest.equal(x, _ as 0 .. math.huge)
    end

    -- After block, x widens back to number
    attest.equal(x, _ as number)
]])
analyze([[
    -- Generic number: arithmetic dependency narrows when operand narrows
    -- (number + number = number, but narrowing one operand to literal enables range arithmetic)
    local x: number
    local y: 0 .. 10
    local z = x + y

    if x == 5 then
        attest.equal(z, _ as 5 .. 15)
    end
]])
analyze([[
    -- Generic number: arithmetic after relational narrowing
    local x: number
    local y: 1 .. 10
    local z = x + y

    if x >= 0 then
        attest.equal(z, _ as 1 .. math.huge)
    end
]])
analyze([[
    -- Generic number: relational narrowing in both operands
    local x: number
    local y: number
    local z = x + y

    if x >= 0 then
        if y >= 0 then
            attest.equal(z, _ as 0 .. math.huge)
        end
    end
]])
analyze([[
    -- Generic number: equality narrowing followed by relational narrowing
    local x: number

    if x == 10 then
        attest.equal(x, 10)
    end

    -- After equality block, x widens back to number
    attest.equal(x, _ as number)
]])
