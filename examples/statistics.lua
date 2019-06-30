local oh = require("oh.oh")
local util = require("oh.util")

local code = util.FetchCode("benchmarks/10mb.lua", "https://gist.githubusercontent.com/CapsAdmin/0bc3fce0624a72d83ff0667226511ecd/raw/b84b097b0382da524c4db36e644ee8948dd4fb20/10mb.lua")

local tokens = assert(oh.CodeToTokens(code))
util.CountFields(tokens, "token types", function(a) return a.type end, 30)
local ast, parser = assert(oh.TokensToAST(tokens, nil, nil, {record_nodes = true}))
util.CountFields(parser.NodeRecord, "parser types", function(a) return a.kind end, 30)