local util = require("oh.util")
local oh = require("oh.oh")
local path = "oh/parser.lua"
local code = assert(io.open(path)):read("*all")

local tk = oh.Tokenizer(code)
local ps = oh.Parser({record_nodes = true})

local tokens = tk:GetTokens()
local ast = ps:BuildAST(tokens)

ps.globals = nil ps.scope = nil

local function callback(node, statements, expressions, assignments)
    local declare_self = false

    if assignments and node.kind == "function" then
        for _, assignment in ipairs(assignments) do
            for _, value in ipairs(assignment[1]:GetUpvaluesAndGlobals()) do
                if value.kind == "binary_operator" and value.value.value == ":" then
                    declare_self = assignment[1]
                end
                ps:RecordEvent("mutate", value.left or value, assignment[1], assignment[2])
            end
        end
    elseif expressions then
        for _, expression in ipairs(expressions) do
            for _, value in ipairs(expression:GetUpvaluesAndGlobals()) do
                ps:RecordEvent("handle", value, value.upvalue_or_global)
            end
        end
    end

    if statements then
        ps:PushScope(node)
    end

    if declare_self then
        ps:DeclareUpvalue("self", declare_self)
    end

    if assignments and node.kind ~= "function" then
        for _, assignment in ipairs(assignments) do

            if node.is_local then
                ps:DeclareUpvalue(assignment[1], assignment[2])
            else
                for _, value in ipairs(assignment[1]:GetUpvaluesAndGlobals()) do
                    ps:RecordEvent("mutate", value.left or value, assignment[1], assignment[2])
                end
            end
        end
    end

    if statements then
        for _, statement in ipairs(statements) do
            statement:Walk(callback)
        end

        ps:PopScope()
    end
end

ast:Walk(callback)
print(ps:DumpScope())