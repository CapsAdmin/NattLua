local util = require("examples.util")

local lua_code = assert(util.FetchCode("examples/benchmarks/temp/10mb.lua", "https://gist.githubusercontent.com/CapsAdmin/0bc3fce0624a72d83ff0667226511ecd/raw/b84b097b0382da524c4db36e644ee8948dd4fb20/10mb.lua"))

util.LoadGithub("GitSparTV/LLLua/master/0.1/util.lua", "util")
local Lexer = util.LoadGithub("GitSparTV/LLLua/master/0.1/lexer.lua", "lllua-lexer")

local sec = util.MeasureFunction(function()
    util.Measure("Lexer(lua_code)", function() tokens = Lexer(lua_code) end)
end)

print("lexing only took " ..  sec .. " seconds")

