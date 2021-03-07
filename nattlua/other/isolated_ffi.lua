local ffi = require("ffi")

local lua = require("nattlua.other.luajit")
local msgpack = require("nattlua.other.msgpack")
local helpers = require("nattlua.other.helpers")

local function throw_error(L, id, code)
    local msg = ffi.string(lua.tolstring(L, -1, nil))
    if not id then
        lua.close(L)
    end

    local line, msg = msg:match("^.-:(%d+): (.+)$")
    line = tonumber(line)
    
    local start = helpers.LinePositionToSubPosition(code, line, 0)

    error(helpers.FormatError(code, "format_error.lua", msg, start, start), 2)
end

local states = {}

local function run_isolated_lua(code, id, ...)
    local L
    
    if id and states[id] then
        L = states[id]
    else
        L = lua.L.newstate()
        lua.L.openlibs(L)
    end

    if lua.L.loadstring(L, [[
        local msgpack = require('nattlua.other.msgpack')
        local msg = ...
        local args = msgpack.decode(msg)

        local function code(...)
            ]]..code..[[
        end

        return msgpack.encode(code(unpack(args)))
    ]]) ~= 0 then
        throw_error(L, id, code)
    end

    -- i think this will crash if luajit decides to garbage collect msg in the middle of the call
    local msg = msgpack.encode(({...}))
    lua.pushstring(L, msg)
    
    if lua.pcall(L, 1, 1, 0) ~= 0 then
        throw_error(L, id, code)
    end

    local len = ffi.new("size_t[1]")
    local ptr = lua.L.checklstring(L, -1, len)
    
    local tbl = msgpack.decode(ffi.string(ptr, len[0]))

    if id then
        states[id] = L
    else
        lua.close(L)
    end

    return tbl
end

local isolated_ffi = {}

function isolated_ffi.cdef(id, cdef, ...)
    return run_isolated_lua([==[
        local cdef, args = ...

        local ffi = require("ffi")
        local reflect = require("nattlua.other.reflect")

        _G.internal = _G.internal or {}

        if not _G.internal[1] then
            for i = 1, 512 do
                if not ffi.typeinfo(i) then break end
                _G.internal[i] = true
            end
        end
        
        ffi.cdef(cdef, unpack(args))

        local function iter(self, func)
            local out = {}
            for child in func(self) do
                table.insert(out, child)
            end
            return out
        end

        local out = {}

        for i = #_G.internal, 512 do
            if not ffi.typeinfo(i) then break end
            if _G.internal[i] then
                --print("skipping", reflect.typeof_id(i).what, reflect.typeof_id(i).name)
            else
                local info = reflect.typeof_id(i)

                if info.what == "struct" then
                    info.children = iter(info, info.members)
                       
                    _G.typeid2ctype = _G.typeid2ctype or {}
                    _G.typeid2ctype[info.typeid] = ffi.typeof(info.what .." " .. info.name)
                elseif info.what == "func" then
                    info.children = iter(info, info.arguments)

                       
                    _G.typeid2ctype = _G.typeid2ctype or {}
                    _G.typeid2ctype[info.typeid] = ffi.typeof(ffi.C[info.name])
                elseif info.what == "enum" then
                    info.children = iter(info, info.values)
                end

                if info.children then
                    table.insert(out, info) 
                end
            end
        end
    
        return out
    ]==], id, cdef, {...})
end

function isolated_ffi.typeof(id, cdef, ...)
    return run_isolated_lua([==[
        local cdef, args = ...

        local ffi = require("ffi")
        local tprint = require("nattlua.other.tprint")
        local reflect = require("nattlua.other.reflect")

        for i, num_id in ipairs(args) do
            args[i] = assert(_G.typeid2ctype[num_id], "unable to cast typeid " .. num_id)
        end

        local ctype = ffi.typeof(cdef, unpack(args))
    
        local function iter(self, func)
            local out = {}
            for child in func(self) do
                table.insert(out, child)
            end
            return out
        end

        local info = reflect.typeof(ctype)

        _G.typeid2ctype = _G.typeid2ctype or {}
        _G.typeid2ctype[info.typeid] = ctype

        if info.what == "struct" then
            info.children = iter(info, info.members)
        elseif info.what == "func" then
            info.children = iter(info, info.arguments)
        elseif info.what == "enum" then
            info.children = iter(info, info.values)
        end

        return info
    ]==], id, cdef, {...})
end

return isolated_ffi