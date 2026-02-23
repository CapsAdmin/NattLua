-- Bug: type parameter in return type annotation resolves to _G lookup
-- instead of the enclosing type function's scope.
--
-- When a generic function like ok<|T|> has a return type Result<|T, any|>,
-- where Result is a type function, the T parameter in the return type
-- annotation sometimes fails to resolve and the analyzer tries to look
-- it up in _G, producing "_G has no key T".
--
-- This seems to happen specifically when:
-- 1. The function is exported from a module (assigned to a table field)
-- 2. The function is called from another file / import context
-- 3. The type parameter appears inside a type function call in the
--    return type annotation
-- ============================================================
-- BASELINE: single file, direct call — should work
-- ============================================================
analyze[[
    local type function Wrapper<|T: any, E: any|>
        return {
            ["ok"] = true,
            ["value"] = T,
        } | {
            ["ok"] = false,
            ["error"] = E,
        }
    end

    local function ok<|T: any|>(value: T): Wrapper<|T, any|>
        return {ok = true, value = value}
    end

    local r = ok<|number|>(42)
    attest.equal<|r, Wrapper<|number, any|>|>
]]
-- ============================================================
-- BASELINE: exported through a module table, called in same file
-- ============================================================
analyze[[
    local type function Wrapper<|T: any, E: any|>
        return {
            ["ok"] = true,
            ["value"] = T,
        } | {
            ["ok"] = false,
            ["error"] = E,
        }
    end

    local M = {}

    local function ok<|T: any|>(value: T): Wrapper<|T, any|>
        return {ok = true, value = value}
    end
    M.ok = ok

    -- Call through the module table
    local r = M.ok<|number|>(42)
]]
-- ============================================================
-- BUG: type param in return type annotation of generic function
-- resolves to _G lookup instead of the type function's scope
-- ============================================================
-- Test A: Existing passing test from generics.lua — no return type annotation
analyze[[
    local function foo<|A: any, B: any|>(a: A, b: B)
        return a, b
    end
    local x,y = foo<|number, number|>(1, 2)
    attest.equal(x, _ as number)
    attest.equal(y, _ as number)
]]
-- Test B: Copy of existing passing test from generics.lua — WITH return type
analyze[[
    local function sorted_keys<|A: any, B: any|>(m: {[A] = B}): ({[number] = A})
        local keys = {}
        for k, _ in pairs(m) do
            table.insert(keys, k)
        end
        table.sort(keys)
        return keys
    end

    local keys = sorted_keys<|string, string|>({foo = "123", bar = "123", faz = "123"})
    attest.equal<|keys, {[number] = string}|>
]]
-- Test C: Bare T as return type — FAILS
analyze[[
    local function identity<|T: any|>(value: T): T
        return value
    end
    local x = identity(42)
]]
-- Test D: Parenthesized (T) as return type
analyze[[
    local function identity<|T: any|>(value: T): (T)
        return value
    end
    local x = identity(42)
]]
-- Test E: T inside a table in return type — like sorted_keys
analyze[[
    local function wrap<|T: any|>(value: T): ({["v"] = T})
        return {v = value}
    end
    local x = wrap(42)
]]
-- Test F: Multiple return values with T
analyze[[
    local function dup<|T: any|>(value: T): (T, T)
        return value, value
    end
    local x, y = dup(42)
]]
-- ============================================================
-- Multiple generic params, only some used in return type
-- ============================================================
analyze[[
    local type function Wrapper<|T: any, E: any|>
        return {
            ["ok"] = true,
            ["value"] = T,
        } | {
            ["ok"] = false,
            ["error"] = E,
        }
    end

    local function ok<|T: any|>(value: T): Wrapper<|T, any|>
        return {ok = true, value = value}
    end

    local function err<|E: any|>(error: E): Wrapper<|any, E|>
        return {ok = false, error = error}
    end

    local function unwrap<|T: any, E: any|>(result: Wrapper<|T, E|>): T
        if result.ok then
            return result.value
        end
        error("unwrap failed" as any)
    end

    local r = ok<|number|>(42)
    local val = unwrap<|number, any|>(r)
    attest.equal(val, 42)
]]
-- ============================================================
-- Chaining: generic function that calls another generic function
-- internally, both using type function return types
-- ============================================================
analyze[[
    local type function Wrapper<|T: any, E: any|>
        return {
            ["ok"] = true,
            ["value"] = T,
        } | {
            ["ok"] = false,
            ["error"] = E,
        }
    end

    local function ok<|T: any|>(value: T): Wrapper<|T, any|>
        return {ok = true, value = value}
    end

    -- map calls ok internally with a different type parameter
    local function map<|T: any, U: any, E: any|>(
        result: Wrapper<|T, E|>,
        fn: function=(T)>(U)
    ): Wrapper<|U, E|>
        if result.ok then
            return ok<|U|>(fn(result.value))
        end
        return {ok = false, error = result.error}
    end

    local r = ok<|number|>(42)
    local r2 = map<|number, string, any|>(r, function(n: number): string
        return tostring(n)
    end)
]]-- ============================================================
-- collect: passing multiple generic function results in a table
-- (separate bug: ok<|number|> inside table literal gets confused 
--  with a result value — "has no key __call")
-- ============================================================
--[[ TODO: this is a separate bug to investigate
analyze[[
    local type function Wrapper<|T: any, E: any|>
        return {
            ["ok"] = true,
            ["value"] = T,
        } | {
            ["ok"] = false,
            ["error"] = E,
        }
    end

    local function ok<|T: any|>(value: T): Wrapper<|T, any|>
        return {ok = true, value = value}
    end

    local function collect<|T: any, E: any|>(
        results: {[number] = Wrapper<|T, E|>}
    ): Wrapper<|{[number] = T}, E|>
        local values = {} as {[number] = T}
        for i = 1, #results do
            local r = assert(results[i])
            if not r.ok then
                return {ok = false, error = r.error}
            end
            values[i] = r.value
        end
        return ok<|{[number] = T}|>(values)
    end

    local batch = collect<|number, string|>({
        [1] = ok<|number|>(1),
        [2] = ok<|number|>(2),
        [3] = ok<|number|>(3),
    })
]]
--]]
