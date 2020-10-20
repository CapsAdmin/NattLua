local lib = {}

function lib.Foo()
    local a = nil
    return assert(loadfile("test/lua/analyzer/file_importing/foo/d.lua"))()
end

return lib