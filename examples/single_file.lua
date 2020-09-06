local oh = require("oh")
local lua = oh.File("oh.lua", {
    on_statement = function(parser, node, out)
        print(parser, node)
    end    
}):Parse()