local nl = require("nattlua")
local lua = nl.File("nattlua.lua", {
    on_statement = function(parser, node, out)
        print(parser, node)
    end    
}):Parse()