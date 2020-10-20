local nl = require("nl")
local types = require("nattlua.typesystem.types")

local C = nl.Code

types.Initialize()

local function cast(...)
    local ret = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        local t = type(v)
        if t == "number" then
            ret[i] = types.Number(v):MakeLiteral(true)
        elseif t == "string" then
            ret[i] = types.String(v):MakeLiteral(true)
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
    local code_data = nl.Code(code, nil, nil, 3)
    local ok, err = code_data:Analyze()
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
            code_data = C(code_data.code)
            code_data:EnableEventDump(true)
            local ok, err2 = code_data:Analyze()
            io.write(code_data.code, "\n")
            error(err)
        end
    end

    return code_data.analyzer, code_data.SyntaxTree
end

return {
    Union = function(...) return types.Union(cast(...)) end,
    Tuple = function(...) return types.Tuple(cast(...)) end,
    Number = function(n) return types.Number(n):MakeLiteral(n ~= nil) end,
    Function = function(d) return types.Function(d) end,
    String = function(n) return types.String(n):MakeLiteral(n ~= nil) end,
    Table = function(data) return types.Table(data or {}) end,
    Symbol = function(data) return types.Symbol(data) end,
    Any = function() return types.Any() end,
    RunCode = run,
}