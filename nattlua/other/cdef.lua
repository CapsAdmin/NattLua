
local ffi = require("ffi")
local lua = require("nattlua.other.luajit")

local function check_error(state, ok)
    if ok ~= 0 then
        error(ffi.string(lua.tolstring(state, -1, nil)))
        lua.close(state)
    end
end

local cdef = {}

function cdef.CreateEnvironment()
    local state = lua.L.newstate()
    lua.L.openlibs(state)
    return state
end

function cdef.Declare(state, str)

    local code = [[
        local reflect = require("nattlua.other.reflect")
        local ffi = require("ffi")
        
        return pcall(function() ffi.cdef([==[]]..str..[[]==]) end)
    ]]
    check_error(state, lua.L.loadbuffer(state, code, #code, ""))
    check_error(state, lua.pcall(state, 0, 2, 0))

    local ok = lua.toboolean(state, -2) == 1
    local chr = lua.tolstring(state, -1, nil)
    local err = chr ~= nil and ffi.string(chr) or nil

    if err then
        err = err:match(".-%d:(.+)")
    end

    return ok, err
end

function cdef.CloseEnvironment(state)
    lua.close(state)
end

local state = cdef.CreateEnvironment()

print(cdef.Declare(state, "struct foo {};"))

