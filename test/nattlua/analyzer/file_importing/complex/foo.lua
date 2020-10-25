local META = {}

require("test.nattlua.analyzer.file_importing.baz")(META)
require("test.nattlua.analyzer.file_importing.baz")(META)
require("test.nattlua.analyzer.file_importing.baz")(META)

return function(config)
   return META
end