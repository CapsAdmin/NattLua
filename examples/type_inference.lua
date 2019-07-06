local util = require("oh.util")
local oh = require("oh.oh")
local path = "oh/parser.lua"
local code = assert(io.open(path)):read("*all")

code = [[
    local a = 1
    local b = a > 2

    if b then
        local a = 1

        local function test(a,b,c)

        end

        local a = function(lol, foo) 
            if true then
                return true
            end


            if false then
                return ""
            end

            if foo then
                return {}
            end
        
        end


    end
]]

local tk = oh.Tokenizer(code)
local ps = oh.Parser()

local tokens = tk:GetTokens()
local ast = ps:BuildAST(tokens)
local anl = oh.Analyzer()

do
    local walk_statement
    local walk_assignments

    local function handle_upvalue(node, set)
        if node.kind == "function" then
            anl:PushScope(node)

            local flat = {}
            for i,v in ipairs(node.identifiers) do
                flat[i] = {v}
            end

            node.is_local = true
            walk_assignments(anl, node, flat, true)

            for _, statement in ipairs(node.statements) do
                statement:Walk(walk_statement, anl)
            end
            anl:PopScope()

            return oh.Type("function", node)
        elseif node.kind == "table"  then
        else
            local upvalue = anl:GetUpvalue(node)
            
            if upvalue then
                return upvalue.data
            elseif _G[node.value.value] ~= nil then
                return oh.Type(type(_G[node.value.value]), node)
            end

            return oh.Type("any", node)
        end
    end

    walk_assignments = function(self, node, assignments, statement)
        if assignments then
            for _, data in ipairs(assignments) do
                local l, r = data[1], data[2]

                if node.is_local then
                    if r then
                        if r.type == "statement" and r.kind == "function" then
                            anl:DeclareUpvalue(l, oh.Type("function", node))
                        else
                            anl:DeclareUpvalue(l, r:Evaluate(oh.TypeWalk, handle_upvalue))
                        end
                    else
                        anl:DeclareUpvalue(l, oh.Type("any", l))
                    end
                else
                    local upvalue = self:GetUpvalue(l)
                    if upvalue then
                        anl:RecordUpvalueEvent("newindex", l, r:Evaluate(oh.TypeWalk, handle_upvalue))
                    else
                        local t = l:Evaluate(oh.TypeWalk, handle_upvalue, true)
                        --print(t.)
                    end
                end
            end
        end
    end

    local function walk_expressions(self, node, expressions)
        if expressions then
            for _, exp in ipairs(expressions) do
                exp:Evaluate(oh.TypeWalk, handle_upvalue)
            end
        end
    end

    walk_statement = function(node, self, statements, expressions, start_token)
        walk_assignments(self, node, node:GetAssignments())

        if node.kind ~= "repeat" then
            walk_expressions(self, node, expressions)
        end

        if statements then
            self:PushScope(node, start_token)

            walk_assignments(self, node, node:GetStatementAssignments(), true)

            for _, statement in ipairs(statements) do
                statement:Walk(walk_statement, self)
            end

            if node.kind == "repeat" then
                walk_expressions(self, node, expressions)
            end

            self:PopScope()
        end
    end

    ast:Walk(walk_statement, anl)
end


--anl:Walk(ast)
print(anl:DumpScope())