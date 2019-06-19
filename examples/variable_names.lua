local oh = require("oh.oh")
local util = require("oh.util")

local code = io.open("oh/tokenizer.lua"):read("*all")

codew = [[
    local function test(a,b,c)
        do return false end
        for i = 1, 10 do 
            if i == 2 then return i else return 2 end
        end
        return true
    end
]]

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
                if l:IsValue("n") then
                    l:SetValue("x")
                end
                if r:IsValue("n") then
                    r:SetValue("x")
                end
                op:SetValue("/")
            end
        end
    end
end

print(ast:Render())