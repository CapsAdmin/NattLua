local oh = require("oh.oh")
local util = require("oh.util")

local code = [[
    function foo(a,b,c,d)
        return a + b - c * (-d) + (function(a) return a+2 end)(1)
    end
]]

local ast = assert(oh.TokensToAST(assert(oh.CodeToTokens(code))))

for _, statement in ipairs(ast:GetChildren()) do
    if statement:IsType("function") then
        for _, exp in ipairs(statement:FindStatementsByType("return")[1]:GetChildren()) do
            for l, op, r in exp:ExpandExpression() do
                if l:IsValue("c") then
                    l:SetValue("x")
                end
                if r:IsValue("b") then
                    r:SetValue("x")
                end
                op:SetValue("/")
            end
        end
    end
end

print(ast:Render())