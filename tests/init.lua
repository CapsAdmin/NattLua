

local map --= {}

if map then
    debug.sethook(function(evt)
        if evt ~= "line" then return end
        local info = debug.getinfo(2)
        local src = info.source:sub(2)
        map[src] = map[src] or {}
        map[src][info.currentline] = (map[src][info.currentline] or 0) + 1
    end, "l")
end

local test = require("tests.test")

io.write("TESTING") io.flush()
if not map then
    assert(loadfile("tests/random_tokens.lua"))(test)
end
assert(loadfile("tests/transpile_equal.lua"))(test)
assert(loadfile("tests/errors.lua"))(test)
if not map and (jit.os == "Linux" or jit.os == "OSX") then
    for path in io.popen("find ."):lines() do
        if path:sub(-4) == ".lua" and not path:find("10mb") then
          -- print(path)
            --test.dofile(path, {name = path})
        end
    end
end
io.write(" - OK\n")

if map then
    for k,v in pairs(map) do
        if k:find("oh/", 1, true) then
            local f = io.open(k .. ".coverage", "w")

            local i = 1
            for line in io.open(k):lines() do
                if map[k][i] then
                    f:write("\n")
                else
                    f:write(line, "\n")
                end
                i = i + 1
            end

            f:close()
        end
    end
end