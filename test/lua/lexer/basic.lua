local oh = require("oh")
local tprint = require("libraries.tprint")
local function check(code)
   return assert(oh.Code(code):Lex()).Tokens
end

it("lexer basics", function()
    equal(check("")[1].type, "end_of_file")
    equal(check("a")[1].type, "letter")
    equal(check("1")[1].type, "number")
    equal(check("'1'")[1].type, "string")
    equal(check("(")[1].type, "symbol")
end)

it("comment escape", function()
    local tokens = check("a--[[#1]]a")
    equal(tokens[1].type, "letter")
    equal(tokens[2].type, "number")
    equal(tokens[3].type, "letter")
    equal(tokens[4].type, "end_of_file")
end)