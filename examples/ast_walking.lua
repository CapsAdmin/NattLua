local oh = require("oh.oh")
local code = io.open("oh/parser.lua"):read("*all")

local ast = assert(oh.TokensToAST(assert(oh.CodeToTokens(code))))

print("all while statements:")
for i,v in ipairs(ast:FindStatementsByType("while")) do
    print(i, v:Render())
end

print("find all *.tokens* =   ")
for i,v in ipairs(ast:FindStatementsByType("assignment")) do
    if v.expressions_left then
        for _, expression in ipairs(v.expressions_left) do 
            if  
                expression.suffixes and 
                expression.suffixes[1] and 
                expression.suffixes[1].value and
                expression.suffixes[1].value.value == "tokens" 
            then 
                print(expression:Render())
            end
        end
    end
end