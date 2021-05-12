--local Parser = require("nattlua.transpiler.transpiler")

local type Token = {
    foo = string,
    bar = string,
    ok = nil | boolean,
}

local type Token2 = {
    foo = string,
    bar = string,
}
local function lol(a: Token) 

end

lol(_ as Token2)