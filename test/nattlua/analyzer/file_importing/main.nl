local liba = assert(loadfile("test/lua/analyzer/file_importing/a.nl"))()
local libb = assert(loadfile("test/lua/analyzer/file_importing/b.nl"))()
local libc = assert(loadfile("test/lua/analyzer/file_importing/foo/c.lua"))()

return liba.Foo() + libb.Foo() + libc.Foo()