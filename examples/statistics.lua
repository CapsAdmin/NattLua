local nl = require("nattlua")
local util = require("examples.util")

local code = nl.Compiler(assert(util.FetchCode("examples/benchmarks/temp/10mb.lua", "https://gist.githubusercontent.com/CapsAdmin/0bc3fce0624a72d83ff0667226511ecd/raw/b84b097b0382da524c4db36e644ee8948dd4fb20/10mb.lua")), "10mb.lua")

local tokens = assert(code:Lex())

util.CountFields(tokens.Tokens, "token types", function(a) return a.type end, 30)