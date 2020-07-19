function _G.test(name, cb)
    local ok, err = pcall(cb)
    if ok then
        io.write(".")
        io.output():flush()
    else
        io.write("\n")
        io.write("FAIL: ",  name, ": ", err, "\n")
    end
end

function pending()

end

function _G.equal(a, b, level)
    level = level or 1
    if a ~= b then
        error(tostring(a) .. " ~= " .. tostring(b), level + 1)
    end
end


local path = ...

if path and path:sub(-4) == ".lua" then
    assert(loadfile(path))()
else
    local what = path
    local path = "test/" .. ((what and what .. "/") or "lua/")
    for path in io.popen("find " .. path):lines() do
        if path:sub(-4) == ".lua" then
            assert(loadfile(path))()
        end
    end
end

io.write("\n")