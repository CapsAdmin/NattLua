local oh = require("oh")
local code = io.open("oh.lua"):read("*all")
local lua = oh.Code(code, "oh.lua", {
    on_statement = function(parser, node)
        print(parser, node)
    end    
}):Emit()

--print(lua)