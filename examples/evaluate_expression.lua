local oh = require("oh.oh")

local env = {foo = {bar = {value = 10, baz = {1,2,3}, func = function(num) return 5+num end }}}
local code = [[
    return 1+2+3 * 5 + foo.bar.func(5+5) ^ 2 + #foo.bar.baz
]]

local func = loadstring(code)
setfenv(func, env)
local expect = func()

local ast = assert(oh.TokensToAST(assert(oh.CodeToTokens(code))))
local exp = ast:FindStatementsByType("return")[1].expressions[1]

local function eval(node, stack, env_lookup)
    if node.kind == "value" then
        if node.value.type == "letter" then
            return node.value.value, node.upvalue_or_global
        elseif node.value.type == "number" then
            return tonumber(node.value.value)
        end
    elseif node.kind == "binary_operator" then
        local r, l = table.remove(stack), table.remove(stack)
        local op = node.value.value

        if l.env_lookup then
            --print("_G", ".", l)
            l = env[l.value]
            r = r.value
        else
            l = l.value
            r = r.value
        end

        --print(l,op,r)

        if op == "+" then
            return l + r
        elseif op == "*" then
            return l * r
        elseif op == "." then
            return l[r]
        elseif op == "^" then
            return l ^ r
        end
    elseif node.kind == "prefix_operator" then
        local r = table.remove(stack).value
        local op = node.value.value

        --print(op, r)

        if op == "#" then
            return #r
        end
    elseif node.kind == "postfix_call" then
        local r = table.remove(stack).value
        local args = {}
        for i,v in ipairs(node.expressions) do
            args[i] = v:Evaluate(eval).value
        end
        return r(unpack(args))
    end
end

print(exp:Evaluate(eval).value, " should be ", expect)