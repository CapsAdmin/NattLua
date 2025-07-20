local foo = require("test.tests.nattlua.analyzer.file_importing.complex.foo")(1)
local bar = require("test.tests.nattlua.analyzer.file_importing.complex.bar")
return foo.get() + bar
