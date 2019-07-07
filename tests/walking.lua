local oh = require("oh")
local test = require("tests.test")
local tprint = require("oh.util").TablePrint

local code = [[a = -1^21+2+a(1,2,3)()[1]""++ ÆØÅ]]

local ast = assert(oh.TokensToAST(assert(oh.CodeToTokens(code)), nil, code))

local expr = ast:FindStatementsByType("assignment")[1].right[1]
print(expr:DumpPresedence())