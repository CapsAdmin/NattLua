local oh = require("oh.oh")
local test = require("tests.test")
local tprint = require("oh.util").TablePrint

local code = [[

    a = foo:bar()

]]

local ast = assert(oh.TokensToAST(assert(oh.CodeToTokens(code))))

local expr = ast:FindStatementsByType("assignment")[1].expressions_right[1]
tprint(expr:Flatten())

do return end

for l,op,r in expr:Walk() do
    print(l, op, r)
end
