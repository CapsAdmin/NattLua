function _G.it(name, cb)
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

function _G.equal(a, b)
    if a ~= b then
        error(tostring(a) .. " ~= " .. tostring(b), 2)
    end
end


local path = ...
if path then
    assert(loadfile(path))()
else
    for path in io.popen("find test/lua"):lines() do
        if path:sub(-4) == ".lua" then
            assert(loadfile(path))()
        end
    end
end

io.write("\n")