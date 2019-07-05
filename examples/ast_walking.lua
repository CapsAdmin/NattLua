local oh = require("oh.oh")
local code = io.open("oh/parser.lua"):read("*all")

local ast = assert(oh.TokensToAST(assert(oh.CodeToTokens(code))))

print("==================================================")
print("all while statements:")
for i,v in ipairs(ast:FindStatementsByType("while")) do
    print(i, v:Render())
end

print("==================================================")
print("find ^node%.tokens%b[]")
for i,v in ipairs(ast:FindStatementsByType("assignment")) do
    if v.expressions_left then
        for _, expression in ipairs(v.expressions_left) do
            if expression:Render():find("^node%.tokens%b[]") then
                print(expression:Render())
            end
        end
    end
end

print("==================================================")
print("walk statements and expressions")
do
    local code = [[
        a.b.c[1] = 1+2+-3
        a.b.c[2] = a.b:c() + (1+2+3)()
    ]]

    local ast = assert(oh.TokensToAST(assert(oh.CodeToTokens(code))))

    local function callback(node, self, statements, expressions, start_token)
        local assignments = node:GetAssignments()

        if assignments then
            print("----------------------------------------")
            for _, assignment in ipairs(assignments) do
                assignment[1]:WalkValues(function(val, op)
                    print(val:Render() .. " = ")
                end)

                assignment[2]:WalkValues(function(val, op)
                    print(val:Render(), op.value.value)

                    if val.left then
                        return val
                    end
                end)
            end
        end

        if statements then
            for _, statement in ipairs(statements) do
                statement:Walk(callback, self)
            end
        end
    end

    ast:Walk(callback)
end