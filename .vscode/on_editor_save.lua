local nl = require("nattlua")

local did_something = false

local function run_lua(path, ...)
    did_something = true
    assert(loadfile(path))(...)
end

local function run_nattlua(path)
    did_something = true
    local c = assert(nl.File(path, {annotate = true}))

    if c.code:find("%-%-%s-EVENT_DUMP") then
        c:EnableEventDump(true)
    end

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
    if not c.code:find("%-%-%s-DISABLE_CODE_RESULT") then
        io.write("== code result ==\n")
        io.write(res, "\n")
    end
    --assert(load(res))()
end

local function has_test_focus()
    local f = io.open("test_focus.lua")
    if not f or (f and #f:read("*all") == 0) then
        if f then f:close() end
        return false
    end

    return true
end

local path = ...

if path:find("on_editor_save.lua", nil, true) then return end

if path:lower():find("/nattlua/", nil, true) then
    if not path then
        error("no path")
    end

    local is_lua = path:sub(-4) == ".lua"
    local is_nattlua = path:sub(-5) == ".nlua"

    if not is_lua and not is_nattlua then
        return
    end

    if is_nattlua then
        run_nattlua(path)
    elseif path:find("test/", nil, true) then
        run_lua("test/run.lua", path)  
    elseif path:find("javascript_emitter") then
        run_lua("./examples/lua_to_js.lua")
    elseif path:find("examples/", nil, true) then
        run_lua(path)
    elseif has_test_focus() then
        run_nattlua("./test_focus.lua")
    elseif (path:find("/nattlua/nattlua/", nil, true) or path:find("/nattlua/nattlua.lua", nil, true)) and not path:find("helpers") then
        run_lua("test/run.lua")  
    end
end

if not did_something then
    print("not sure how to run " .. path)
    print("running as normal lua")
    run_lua(path)
end