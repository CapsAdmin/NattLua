local lib = {}

function lib.Foo()
    local a = nil
    return assert(loadfile("test/nattlua/analyzer/file_importing/foo/d.lua"))()
end

return lib