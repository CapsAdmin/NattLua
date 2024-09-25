local foo = require("test.tests.nattlua.analyzer.file_importing.complex.foo")()
local bar = require("test.tests.nattlua.analyzer.file_importing.complex.bar")
return foo.get() + bar
