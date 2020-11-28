local nl = require("nattlua")
local path = ...

if path:sub(-4) ~= ".lua" and path:sub(-5) ~= ".nlua" then
    return
end

local function run(path, ...)
    assert(loadfile(path))(...)
end

if path:find("test/") and path:sub(-5) ~= ".nlua" then
    run("test/run.lua", path)
    return
end

if path:find("javascript_emitter") then
    path = "./examples/lua_to_js.lua"
end

if path:find("/nattlua", nil, true) and not path:find("helpers") then
    local f = io.open("test_focus.lua")
    if not f or (f and #f:read("*all") == 0) then
        if f then f:close() end
        if path:find("/nattlua/", nil, true) then
            run("test/run.lua", "nattlua")
        else
            run("test/run.lua")
        end
        return
    else
        path = "./test_focus.lua"
    end
end

if path:find("examples/") and path:sub(-5) ~= ".nlua" then
    run(path)
    return
end

local c = assert(nl.File(path, {annotate = true}))
c:EnableEventDump(true)
if c.code:find("%-%-%s-DISABLE_BASE_ENV") then
    _G.DISABLE_BASE_ENV = true
end

local ok, err = c:Analyze()
if c.code:find("--DISABLE_BASE_ENV", nil, true) then
    _G.DISABLE_BASE_ENV = nil
end
if not ok then
    io.write(err, "\n")
    return
end
local res = assert(c:Emit())
require("nattlua.runtime.base_runtime")
io.write("== code result ==\n")
io.write(res, "\n")
--assert(load(res))()