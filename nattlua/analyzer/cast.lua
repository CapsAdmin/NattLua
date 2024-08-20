local Function = require("nattlua.types.function").Function
local LNumber = require("nattlua.types.number").LNumber
local Table = require("nattlua.types.table").Table
local Symbol = require("nattlua.types.symbol").Symbol
local ffi = jit and require("ffi") or nil
local Tuple = require("nattlua.types.tuple").Tuple
local Any = require("nattlua.types.any").Any

local LString = require("nattlua.types.string").LString

local function cast_lua_types_to_types(tps)
    local tbl = {}

    for i, v in ipairs(tps) do
        local t = type(v)

        if t == "table" and v.Type ~= nil then
            tbl[i] = v
        elseif t == "function" then
            local func = Function()
            func:SetAnalyzerFunction(v)
            func:SetInputSignature(Tuple({}):AddRemainder(Tuple({Any()}):SetRepeat(math.huge)))
            func:SetOutputSignature(Tuple({}):AddRemainder(Tuple({Any()}):SetRepeat(math.huge)))
            tbl[i] = func
        elseif t == "number" then
            tbl[i] = LNumber(v)
        elseif t == "string" then
            tbl[i] = LString(v)
        elseif t == "boolean" then
            tbl[i] = Symbol(v)
        elseif t == "table" then
            local t = Table()

            for _, val in ipairs(v) do
                t:Insert(val)
            end

            t:SetContract(t)
            tbl[i] = t
        elseif
            ffi and
            t == "cdata" and
            tostring(ffi.typeof(v)):sub(1, 10) == "ctype<uint" or
            tostring(ffi.typeof(v)):sub(1, 9) == "ctype<int"
        then
            tbl[i] = LNumber(v)
        else
            self:Print(t)
            error(debug.traceback("NYI " .. t))
        end
    end


    return tbl
end

return cast_lua_types_to_types