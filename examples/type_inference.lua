local util = require("oh.util")
local oh = require("oh.oh")
local path = "oh/parser.lua"
local code = assert(io.open(path)):read("*all")

code = [[
    local a = 1
    local b = a + c > 2
]]

local tk = oh.Tokenizer(code)
local ps = oh.Parser()

local tokens = tk:GetTokens()
local ast = ps:BuildAST(tokens)
local anl = oh.Analyzer()

do
    local self_arg

    local function walk_expression(node, stack)
        print("EXPRESSION: ", node)

        if node.kind == "value" then
            if node.value.type == "letter" then
                if node.upvalue_or_global then
                    local upvalue = anl:GetUpvalue(node)
                    if upvalue then
                        stack:Push(upvalue.data)
                    elseif _G[node.value.value] ~= nil then
                        stack:Push(oh.Type(type(_G[node.value.value]), node))
                    else
                        stack:Push(oh.Type("any", node))
                    end
                else
                    stack:Push(oh.Type("string", node))
                end
            elseif node.value.type == "number" then
                stack:Push(oh.Type("number", node))
            elseif node.value.type == "string" then
                stack:Push(oh.Type("string", node))
            else
                error("unhandled value type " .. node.value.type)
            end
        elseif node.kind == "function" then
            stack:Push(oh.Type("function", node))
        elseif node.kind == "table" then
            stack:Push(oh.Type("table", node))
        elseif node.kind == "binary_operator" then
            local r, l = stack:Pop(), stack:Pop()
            local op = node.value.value

            stack:Push(r:BinaryOperator(op, l, node))
        elseif node.kind == "prefix_operator" then
            local r = stack:Pop()
            local op = node.value.value

            stack:Push(r:PrefixOperator(op, node))
        elseif node.kind == "postfix_operator" then
            local r = stack:Pop()
            local op = node.value.value

            stack:Push(r:PostfixOperator(op, node))
        elseif node.kind == "postfix_expression_index" then
            local r = stack:Pop()
            local index = node.expression:Evaluate(walk_expression)

            stack:Push(r:BinaryOperator(".", index))
        elseif node.kind == "postfix_call" then
            local r = stack:Pop()
            local args = {}
            for i,v in ipairs(node.expressions) do
                args[i] = v:Evaluate(walk_expression)
            end

            if self_arg then
                stack:Push(r:Call(node, self_arg, unpack(args)))
                self_arg = nil
            else
                stack:Push(r:Call(node, unpack(args)))
            end
        else
            error("unhandled expression " .. node.kind)
        end
    end

    local function walk_statement(node, self, statements, expressions)
        print("STATEMENT: ", node, self, statements, expressions, start_token)

        if node.kind == "assignment" then
            for _, data in ipairs(node:GetAssignments()) do
                local l, r = unpack(data)
                if node.is_local then
                    anl:DeclareUpvalue(l, r:Evaluate(walk_expression))
                else
                    l:Evaluate(walk_expression)
                end

                --print(r:Evaluate(walk_expression))
            end
        end

        if statements then
            for _, statement in ipairs(statements) do
                statement:Walk(walk_statement, self)
            end
        end
    end

    anl:PushScope(ast)
    ast:Walk(walk_statement, self)
    anl:PopScope(ast)
end


--anl:Walk(ast)
print(anl:DumpScope())