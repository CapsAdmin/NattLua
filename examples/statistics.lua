local oh = require("oh")
local util = require("oh.util")

local code = oh.Code(assert(util.FetchCode("examples/benchmarks/10mb.lua", "https://gist.githubusercontent.com/CapsAdmin/0bc3fce0624a72d83ff0667226511ecd/raw/b84b097b0382da524c4db36e644ee8948dd4fb20/10mb.lua")), "10mb.lua")

local tokens = assert(code:Lex())
util.CountFields(tokens, "token types", function(a) return a.type end, 30)