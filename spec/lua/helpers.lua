local oh = require("oh")
local types = require("oh.typesystem.types")

local C = oh.Code

types.Initialize()

local Object = function(...) return types.Object:new(...) end

local function cast(...)
    local ret = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        local t = type(v)
        if t == "number" or t == "string" or t == "boolean" then
            ret[i] = Object(t, v, true)
        else
            ret[i] = v
        end
    end

    return ret
end

local function run(code, expect_error)
    local code_data = oh.Code(code, nil, nil, 3)
    local ok, err = code_data:Analyze()

    if expect_error then
        if not err or err == "" then
            error("expected error, got\n\n\n[" .. tostring(ok) .. ", " .. tostring(err) .. "]")
        elseif type(expect_error) == "string" and not err:find(expect_error) then
            error("expected error '" .. expect_error .. "' got\n\n\n" .. err)
        end
    else
        if not ok then
            code_data = C(code_data.code)
            local ok, err2 = code_data:Analyze(true)
            io.write(code_data.code, "\n")
            error(err)
        end
    end

    return code_data.Analyzer
end

return {
    Set = function(...) return types.Set:new(cast(...)) end,
    Tuple = function(...) return types.Tuple:new({...}) end,
    Number = function(n) return Object("number", n, true) end,
    String = function(n) return Object("string", n, true) end,
    Object = Object,
    Table = function(data) return types.Table:new(data or {}) end,
    RunCode = run,
}