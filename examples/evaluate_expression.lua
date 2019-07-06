local oh = require("oh.oh")

local env = {foo = {bar = {value = 10, baz = {1,2,3}, func = function(self, num) return {[5] = 5+num+self.value} end }}}
local code = [[
    return 1+2+3 * 5 + foo.bar:func(5+5)[3+2] ^ 2 + #foo.bar.baz - 10
]]

local func = loadstring(code)
setfenv(func, env)
local expect = func()

local ast = assert(oh.TokensToAST(assert(oh.CodeToTokens(code))))
local exp = ast:FindStatementsByType("return")[1].expressions[1]

local self_arg

local function eval(node, stack)
    if node.kind == "binary_operator" then
        local r, l = stack:Pop(), stack:Pop()
        local op = node.value.value

        if op == "." then
            stack:Push(l[r])
        elseif op == ":" then
            self_arg = l
            stack:Push(l[r])
        elseif oh.syntax.CompiledBinaryOperatorFunctions[op] then
            stack:Push(oh.syntax.CompiledBinaryOperatorFunctions[op](l,r))
        else
            error("unhandled binary operator " .. op)
        end
    elseif node.kind == "prefix_operator" then
        local r = stack:Pop()
        local op = node.value.value

        if oh.syntax.CompiledPrefixOperatorFunctions[op] then
            stack:Push(oh.syntax.CompiledPrefixOperatorFunctions[op](r))
        else
            error("unhandled prefix operator " .. op)
        end
    elseif node.kind == "postfix_operator" then
        local r = stack:Pop()
        local op = node.value.value

        if oh.syntax.CompiledPrefixOperatorFunctions[op] then
            stack:Push(oh.syntax.CompiledPrefixOperatorFunctions[op](r))
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

print(exp:Evaluate(eval, env), " should be ", expect)