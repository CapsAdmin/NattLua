local oh = require("oh.oh")

if false then
    local env = {a = {b = {c = {[2] = "YES"}}}}
    local code = [[
        return a.b.c[2]
    ]]

    local ast = assert(oh.TokensToAST(assert(oh.CodeToTokens(code))))

    local exp = ast:FindStatementsByType("return")[1].expressions[1]

    print(exp:Evaluate(function(op, r, val)
        if not op then
            return env[r:Render()]
        end
        if op.kind == "binary_operator" then
            local op = op.value.value
            if op == "." then
                return val[r:Render()]
            end
        elseif op.kind == "postfix_expression_index" then
            return val[tonumber(op.expression:Render())]
        end
    end))
end

do
    local env = {foo = {bar = 10, baz = {1,2,3}}}
    local code = [[
        return 1+2+3 * 5 + foo.bar() ^ 2 + #foo.baz
    ]]

    --[[
        1 2 +
        tree addition? google basic expression eval
    ]]

    local ast = assert(oh.TokensToAST(assert(oh.CodeToTokens(code))))
    local exp = ast:FindStatementsByType("return")[1].expressions[1]

    print(exp:Evaluate2(function(node)
        print(node:Render())
    end))

    do return end

    print(exp:Evaluate(function(op, r, val)
        print(op and op:Render(), "\t\t", r:Render())
        do return end
        if not op then
            if r.value.type == "number" then
                return tonumber(r:Render())
            elseif r.value.type == "letter" then
                return env[r:Render()]
            end
        end

        if op.kind == "binary_operator" then
            local op = op.value.value
            if op == "." then
                return val[r:Render()]
            elseif op == "+" then
                print(op, r:Render())
                return val
            end
        elseif op.kind == "postfix_expression_index" then
            return val[tonumber(op.expression:Render())]
        end
    end))
end