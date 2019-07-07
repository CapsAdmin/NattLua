local oh = require("oh")
local syntax = require("oh.syntax")

local env = {foo = {bar = {value = 10, baz = {1,2,3}, func = function(self, num) return {[5] = 5+num+self.value} end }}}
local code = [[
    return 1+2+3 * 5 + foo.bar:func(5+5)[3+2] ^ 2 + #foo.bar.baz - 10
]]

local func = loadstring(code)
setfenv(func, env)
local expect = func()

local ast = assert(oh.TokensToAST(assert(oh.CodeToTokens(code))))
local exp = ast:FindStatementsByType("return")[1].expressions[1]

local function env_lookup(key)
    return env[key]
end

local self_arg

local function eval(node, stack)
    if node.kind == "value" then
        if node.value.type == "letter" then
            if node.upvalue_or_global then
                stack:Push(env_lookup(node.value.value))
            else
                stack:Push(node.value.value)
            end
        elseif node.value.type == "number" then
            stack:Push(tonumber(node.value.value))
        else
            error("unhandled value type " .. node.value.type)
        end
    elseif node.kind == "binary_operator" then
        local r, l = stack:Pop(), stack:Pop()
        local op = node.value.value

        if op == "." then
            stack:Push(l[r])
        elseif op == ":" then
            self_arg = l
            stack:Push(l[r])
        elseif syntax.CompiledBinaryOperatorFunctions[op] then
            stack:Push(syntax.CompiledBinaryOperatorFunctions[op](l,r))
        else
            error("unhandled binary operator " .. op)
        end
    elseif node.kind == "prefix_operator" then
        local r = stack:Pop()
        local op = node.value.value

        if syntax.CompiledPrefixOperatorFunctions[op] then
            stack:Push(syntax.CompiledPrefixOperatorFunctions[op](r))
        else
            error("unhandled prefix operator " .. op)
        end
    elseif node.kind == "postfix_operator" then
        local r = stack:Pop()
        local op = node.value.value

        if syntax.CompiledPrefixOperatorFunctions[op] then
            stack:Push(syntax.CompiledPrefixOperatorFunctions[op](r))
        else
            error("unhandled postfix operator " .. op)
        end
    elseif node.kind == "postfix_expression_index" then
        local r = stack:Pop()
        local index = node.expression:Evaluate(eval)

        stack:Push(r[index])
    elseif node.kind == "postfix_call" then
        local r = stack:Pop()
        local args = {}
        for i,v in ipairs(node.expressions) do
            args[i] = v:Evaluate(eval)
        end

        if self_arg then
            stack:Push(r(self_arg, unpack(args)))
            self_arg = nil
        else
            stack:Push(r(unpack(args)))
        end
    else
        error("unhandled expression " .. node.kind)
    end
end

print(exp:Evaluate(eval), " should be ", expect)