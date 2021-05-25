local nl = require("nattlua")
local types = require("nattlua.types.types")
types.Initialize()
local C = nl.Compiler

local function cast(...)
    local ret = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        local t = type(v)
        if t == "number" then
            ret[i] = types.LNumber(v)
        elseif t == "string" then
            ret[i] = types.LString(v)
        elseif t == "boolean" then
            ret[i] = types.Symbol(v)
        else
            ret[i] = v
        end
    end

    return ret
end

local function run(code, expect_error)
    _G.TEST = true
    local compiler = nl.Compiler(code, nil, nil, 3)
    local ok, err = compiler:Analyze()
    _G.TEST = false

    if expect_error then
        if not err or err == "" then
            error("expected error, got\n\n\n[" .. tostring(ok) .. ", " .. tostring(err) .. "]")
        elseif type(expect_error) == "string" then
            if not err:find(expect_error) then
                error("expected error '" .. expect_error .. "' got\n\n\n" .. err)
            end
        elseif type(expect_error) == "function" then
            local ok, msg = pcall(expect_error, err)
            if not ok then
                error("error did not pass: " .. msg .. "\n\nthe error message was:\n" .. err)
            end
        else
            error("invalid expect_error argument", 2)
        end
    else
        if not ok then
            _G.TEST = true
            compiler = C(compiler.code)
            compiler:EnableEventDump(true)
            local ok, err2 = compiler:Analyze()
            _G.TEST = false
            io.write(compiler.code, "\n")
            error(err, 3)
        end
    end

    return compiler
end

local function internalProtectedEquals(o1, o2, ignore_mt, callList)
    if o1 == o2 then return true end
    local o1Type = type(o1)
    local o2Type = type(o2)
    if o1Type ~= o2Type then return false end
    if o1Type ~= 'table' then return false end

    -- add only when objects are tables, cache results
    local oComparisons = callList[o1]
    if not oComparisons then
        oComparisons = {}
        callList[o1] = oComparisons
    end
    -- false means that comparison is in progress
    oComparisons[o2] = false

    if not ignore_mt then
        local mt1 = getmetatable(o1)
        if mt1 and mt1.__eq then
            --compare using built in method
            return o1 == o2
        end
    end

    local keySet = {}
    for key1, value1 in pairs(o1) do
        local value2 = o2[key1]
        if value2 == nil then return false end

        local vComparisons = callList[value1]
        if not vComparisons or vComparisons[value2] == nil then
            if not internalProtectedEquals(value1, value2, ignore_mt, callList) then
                return false
            end
        end

        keySet[key1] = true
    end

    for key2, _ in pairs(o2) do
        if not keySet[key2] then
            return false
        end
    end

    -- comparison finished - objects are equal do not compare again
    oComparisons[o2] = true
    return true
end

return {
    Union = function(...) return types.Union(cast(...)) end,
    Tuple = function(...) return types.Tuple(cast(...)) end,
    Number = function(n) return types.Number(n):SetLiteral(n ~= nil) end,
    Function = function(d) return types.Function(d) end,
    String = function(n) return types.String(n):SetLiteral(n ~= nil) end,
    Table = function(data) return types.Table(data or {}) end,
    Symbol = function(data) return types.Symbol(data) end,
    Any = function() return types.Any() end,
    RunCode = function(code, expect_error)
        local compiler = run(code, expect_error)
        return compiler.analyzer, compiler.SyntaxTree
    end,
    Transpile = function(code)
        return run(code):Emit({annotate = true})
    end,
    TableEqual = function(o1, o2, ignore_mt)
        return internalProtectedEquals(o1, o2, ignore_mt, {})
    end,
}