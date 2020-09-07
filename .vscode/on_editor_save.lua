local oh = require("oh")
local path = ...
if path:sub(-4) ~= ".lua" and path:sub(-3) ~= ".oh" then
    return
end

if path:find("test/") then
    os.execute("luajit test/run.lua " .. path)
    return
end

if path:find("javascript_emitter") then
    path = "./examples/lua_to_js.lua"
end

if path:find("oh/oh", nil, true) and not path:find("helpers") then
    local f = io.open("test_focus.lua")
    if not f or (f and #f:read("*all") == 0) then
        if f then f:close() end
        if path:find("/lua/") then
            os.execute("luajit test/run.lua lua")
        elseif path:find("/c_preprocessor/") then
            os.execute("luajit test/run.lua c_preprocessor")
        elseif path:find("/c/") then
            os.execute("luajit test/run.lua c")
        else
            os.execute("luajit test/run.lua")
        end
        return
    else
        path = "./test_focus.lua"
    end
end

if path:find("examples/") and path:sub(-3) ~= ".oh" then
    os.execute("luajit " .. path)
    return
end

local c = assert(oh.File(path, {annotate = true}))
if c.code:find("--DISABLE_BASE_TYPES", nil, true) then
    _G.DISABLE_BASE_TYPES = true
end

local ok, err = c:Analyze()
if c.code:find("--DISABLE_BASE_TYPES", nil, true) then
    _G.DISABLE_BASE_TYPES = nil
end
if not ok then
    io.write(err, "\n")
    return
end
local res = assert(c:Emit())
require("oh.lua.base_runtime")
io.write(res, "\n")
--assert(load(res))()