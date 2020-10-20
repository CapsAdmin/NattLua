local nl = require("nl")
local path = ...
if path:sub(-4) ~= ".lua" and path:sub(-3) ~= ".nl" then
    return
end

local function run(path, ...)
    assert(loadfile(path))(...)
end

if path:find("test/") and path:sub(-3) ~= ".nl" then
    run("test/run.lua", path)
    return
end

if path:find("javascript_emitter") then
    path = "./examples/lua_to_js.lua"
end

if path:find("nl/nl", nil, true) and not path:find("helpers") then
    local f = io.open("test_focus.lua")
    if not f or (f and #f:read("*all") == 0) then
        if f then f:close() end
        if path:find("/lua/") then
            run("test/run.lua", "lua")
        elseif path:find("/c_preprocessor/") then
            run("test/run.lua", "c_preprocessor")
        elseif path:find("/c/") then
            run("test/run.lua", "c")
        else
            run("test/run.lua")
        end
        return
    else
        path = "./test_focus.lua"
    end
end

if path:find("examples/") and path:sub(-3) ~= ".nl" then
    run(path)
    return
end

local c = assert(nl.File(path, {annotate = true}))
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
require("nattlua.runtime.base_runtime")
io.write(res, "\n")
--assert(load(res))()