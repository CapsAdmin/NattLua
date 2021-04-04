local nl = require("nattlua")

local did_something = false

local function run_lua(path, ...)
    did_something = true
    assert(loadfile(path))(...)
end

local function run_nattlua(path)
    did_something = true

    if io.open(path, "r"):read("*all"):find("%-%-%s-PLAIN_LUA") then
        return assert(loadfile(path))()
    end

   
    local c = assert(nl.File(path, {annotate = true}))
    
    local preserve_whitespace = nil
    if c.code:find("%-%-%s-PRETTY_PRINT") then
        preserve_whitespace = false
    end

    if c.code:find("%-%-%s-EVENT_DUMP") then
        c:EnableEventDump(true)
    end

    if c.code:find("%-%-%s-VERBOSE_STACKTRACE") then
        c.debug = true
    end

    if c.code:find("%-%-%s-DISABLE_BASE_ENV") then
        _G.DISABLE_BASE_ENV = true
    end

    if c.code:find("%-%-%s-PROFILE") then
        require("jit.p").start("Flp")
    end

    local ok, err
    
    if not c.code:find("%-%-%s-DISABLE_ANALYSIS") then
        ok, err = c:Analyze()
    end


    if c.code:find("--DISABLE_BASE_ENV", nil, true) then
        _G.DISABLE_BASE_ENV = nil
    end

    if c.code:find("%-%-%s-PROFILE") then
        require("jit.p").stop()
    end

    if not ok and err then
        io.write(err, "\n")
        return
    end

    local res = assert(c:Emit({
        preserve_whitespace = preserve_whitespace, 
        string_quote = "\"",
        no_semicolon = true,
        use_comment_types = true,
        annotate = true,
        extra_indent = {
            StartStorableVars = {
                to = "EndStorableVars",
            },
    
            Start2D = {
                to = "End2D"
            },

            Start2D = {
                to = "End3D"
            },
    
            Start = {
                to = {
                    SendToServer = true,
                    Send = true,
                    Broadcast = true,
                }
            },
                
            SetPropertyGroup = "toggle",
        }
    }))
    require("nattlua.runtime.base_runtime")
    if c.code:find("%-%-%s-ENABLE_CODE_RESULT") then
        io.write("== code result ==\n")
        if c.code:find("%-%-%s-SHOW_NEWLINES") then
            res = res:gsub("\n", "⏎\n")
        end
        io.write(res, "\n")
        io.write("=================\n")
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

    if path:find("example_project/", nil, true) or path:find("cparser.lua", nil, true) then
        run_lua("example_project/build.lua", path)  
    elseif is_nattlua then
        run_nattlua(path)
    elseif path:find("test/", nil, true) then
        run_lua("test/run.lua", path)  
    elseif path:find("javascript_emitter") then
        run_lua("./examples/lua_to_js.lua")
    elseif path:find("examples/", nil, true) then
        run_lua(path)
    elseif has_test_focus() then
        run_nattlua("./test_focus.lua")
    elseif (path:find("/nattlua/nattlua/", nil, true) or path:find("/nattlua/nattlua.lua", nil, true)) and not path:find("nattlua/other") then
        if path:find("lexer.lua", nil, true) then
            run_lua("test/run.lua", "test/nattlua/lexer.lua")
            run_lua("test/run.lua", "test/performance/lexer.lua")
        elseif path:find("parser.lua", nil, true) then
            run_lua("test/run.lua", "test/nattlua/parser.lua")
            run_lua("test/run.lua", "test/performance/parser.lua")
        else
            run_lua("test/run.lua")  
        end
    end
end

if not did_something then
    print("not sure how to run " .. path)
    print("running as normal lua")
    run_lua(path)
end