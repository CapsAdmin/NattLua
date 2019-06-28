local oh = require("oh.oh")

local code = [[
    while true do 
            dadokok {} 
            asdaw
    end
]]

local tokens, errors = oh.CodeToTokens(code)
local ast, errors = oh.TokensToAST(tokens, "prop_generic.lua", code)
print(errors)