
local types = require("oh.types")
local T = types.Type

local META = {}
META.__index = META

local table_insert = table.insert

local function hash(val)
    assert(val ~= nil, "expected something")

    if type(val) == "table" then
        return val.value.value
    end

    return val
end


local Table
do
    local META = {}
    META.__index = META

    function META:__tostring()
        if self.in_tostring then
            return " * self reference *"
        end
        self.in_tostring = true

        local str = "table{"
        for k,v in pairs(self.tbl) do
            str = str .. "[" .. tostring(k) .. "] = " .. tostring(v) .. ", "
        end
        str = str .. "}"

        self.in_tostring = false

        return str
    end

    function META:SetValue(key, val)
        self.tbl[hash(key)] = val
    end

    function META:GetValue(key, val)
        return self.tbl[key]
    end

    Table = function(node)
        return setmetatable({node = node, tbl = {}}, META)
    end
end

do

    function META:Hash(token)
        return hash(token)
    end

    function META:PushScope()
        self:FireEvent("enter_scope")
        self.env = self.env or {}
        local parent = self.scope

        local scope = {
            children = {},
            parent = parent,
            upvalues = {},
            upvalue_map = {},
        }

        if parent then
            table_insert(parent.children, scope)
        end

        self.scope = scope
    end

    function META:DeclareUpvalue(key, data)
        local upvalue = {
            key = key,
            data = data,
            scope = self.scope,
            events = {},
            shadow = self:GetUpvalue(key),
        }

        table_insert(self.scope.upvalues, upvalue)
        self.scope.upvalue_map[hash(key)] = upvalue

        self:FireEvent("upvalue", key, data)

        return upvalue
    end

    function META:GetUpvalue(key)
        local key_hash = hash(key)

        if self.scope.upvalue_map[key_hash] then
            return self.scope.upvalue_map[key_hash]
        end

        local scope = self.scope.parent
        while scope do
            if scope.upvalue_map[key_hash] then
                return scope.upvalue_map[key_hash]
            end
            scope = scope.parent
        end
    end

    function META:MutateUpvalue(key, val)
        local upvalue = self:GetUpvalue(key)
        if upvalue then
            upvalue.data = val
            self:FireEvent("mutate_upvalue", key, val)
            return true
        end
        return false
    end

    function META:GetValue(key)
        local upvalue = self:GetUpvalue(key)

        if upvalue then
            return upvalue.data
        end

        return self.env[hash(key)]
    end

    function META:SetGlobal(key, val)
        self:FireEvent("set_global", key, val)

        self.env[hash(key)] = val
    end

    function META:PopScope()
        self:FireEvent("leave_scope")
        local scope = self.scope.parent
        if scope then
            self.scope = scope
        end
    end

    function META:GetScope()
        return self.scope
    end
end

local t = 0

function META:FireEvent(what, ...)
    if what == "create_global" then
        io.write(("\t"):rep(t))
        io.write(what, " - ")
        local key, val = ...
        io.write(key:Render())
        if val then
            io.write(" = ")
            io.write(tostring(val))
        end
        io.write("\n")
    elseif what == "newindex" then
        io.write(("\t"):rep(t))
        io.write(what, " - ")
        local key, val = ...
        io.write(tostring(key))
        if val then
            io.write(" = ")
            io.write(tostring(val))
        end
        io.write("\n")
    elseif what == "upvalue" then
        io.write(("\t"):rep(t))
        io.write(what, " - ")
        local key, val = ...
        io.write(key:Render())
        if val then
            io.write(" = ")
            if type(val) == "table" then
                io.write("(")

                if val.type then
                    io.write(tostring(val))
                else
                    for i,v in ipairs(val) do
                        io.write(tostring(v), ", ")
                    end
                end
                io.write(")")
            else
                io.write(tostring(val))
            end
        end
        io.write("\n")
    elseif what == "enter_scope" then
        io.write(("\t"):rep(t))
        t = t + 1
        io.write(what, " - ")
        local guard = ...
        if guard ~= nil then
            io.write(tostring(guard))
        end
        io.write("\n")
    elseif what == "leave_scope" then
        t = t - 1
        io.write(("\t"):rep(t))
        io.write(what, " - ")
        local guard = ...
        if guard ~= nil then
            io.write(tostring(guard))
        end
        io.write("\n")
    elseif what == "call" then
        io.write(("\t"):rep(t))
        io.write(what, " - ")
        local exp, return_values = ...
        io.write(exp:Render(), " = ")
        if return_values then
            for i,v in ipairs(return_values) do
                io.write("(")
                for i,v in ipairs(v) do
                    io.write(tostring(v), ", ")
                end
                io.write(") | ")
            end
        end
        io.write("\n")
    elseif what == "return" then
        io.write(("\t"):rep(t))
        io.write(what, " - ")
        local values = ...
        if values then
            for i,v in ipairs(values) do
                io.write(tostring(v), ", ")
            end
        end
        io.write("\n")
    else
        io.write(("\t"):rep(t))
        print(what .. " - ", ...)
    end
end

local code = [[
    local a = {}
    a.foo = {}

    function a:bar()

    end

    local function test()

    end

    repeat

    until false

    for i = 1, 10, 2 do
        if i == 1 then
            break
        end
    end

    for k,v in pairs(a) do

    end

    while true do

    end

    do
    end

    if true() then
    elseif false() then
        return false
    else

    end
]]

code = [[
    local function lol(a,b,c)
        if true then
            return a+b+c
        elseif true then
            return true
        end
        a = 0
        return a
    end
    local a = lol(1,2,3)
]]

code = [[
    local a = 1+2+3+4
    a = false

    local function print(foo)
        return foo
    end

    if a then
        local b = print(a)
    end
]]

code = [[
    local a
    a = 2

    if true then
        local function foo(lol)
            return foo(lol)
        end
        foo(a)
    end
]]

code = [[
    b = {}
    b.lol = 1

    local a = b

    local function foo(tbl)
        return tbl.lol + 1
    end

    local c = foo(a)
]]

code = [[
    local META = {}
    META.__index = META

    function META:Test()
        return 1,2,3
    end

    local a,b,c = META:Test()

    --local w = false

    if w then
        local c = true
    end

]]

function META:CrawlStatements(statements, return_values)
    for _, val in ipairs(statements) do
        self:CrawlStatement(val, return_values)
    end
end

--[[
    function META:IsWhileStatement()
        ...
    end

    function META:ReadWhileStatement()
        ...
    end

    function META:FireWhileStatement()
        self:FireEvent("enter_scope", statement.expression)
        self:CrawlStatements(statement.statements)
        self:FireEvent("leave_scope")
    end
]]

local evaluate_expression

function META:CrawlStatement(statement, return_values)
    if statement.kind == "root" then
        self:PushScope()
        self:CrawlStatements(statement.statements, return_values)
        self:PopScope()
    elseif statement.kind == "local_assignment" then
        local last_ret
        for i, node in ipairs(statement.left) do
            local key = node
            local val = statement.right and statement.right[i] and self:CrawlExpression(statement.right[i]) or nil
            if not val and last_ret then
                val = last_ret[i]
            end
            last_ret = last_ret or val
            if val and not val.type then
                val = val[1]
            end
            self:DeclareUpvalue(key, val)
        end
    elseif statement.kind == "assignment" then
        for i, node in ipairs(statement.left) do
            local val = statement.right and statement.right[i] and self:CrawlExpression(statement.right[i] or nil)

            if node.kind == "value" then
                if not self:MutateUpvalue(node, val) then
                    local key = self:CrawlExpression(node)
                    self:SetGlobal(node, val)
                end
            else
                local key = node.right
                local obj = self:CrawlExpression(node.left)

                if obj.type ~= "any" then
                    obj.val:SetValue(key, val)
                    self:FireEvent("newindex", key, obj, val)
                end
            end
        end
    elseif statement.kind == "function" then
        --self:FireEvent("newindex", statement.expression, statement)
        local node = statement.expression
        local val = T(statement, statement, nil, "function")

        if node.kind == "value" then
            if not self:MutateUpvalue(node, val) then
                local key = self:CrawlExpression(node)
                self:SetGlobal(node, val)
            end
        else
            local key = node.right
            node.left.upvalue_or_global = node -- HACK
            local obj,c,d = self:CrawlExpression(node.left)

            if obj.type ~= "any" then
                obj.val:SetValue(key, val)
                self:FireEvent("newindex", key, obj, val)
            end
        end

    elseif statement.kind == "local_function" then

        local key = statement.identifier
        local val = T(statement, statement, nil, "function")
        self:DeclareUpvalue(key, val)

    elseif statement.kind == "if" then
        for i, statements in ipairs(statement.statements) do
            if self:CrawlExpression(statement.expressions[i]):Truthy() then
                self:PushScope()
                self:CrawlStatements(statements, return_values)
                self:PopScope()
            end
        end
    elseif statement.kind == "while" then
        if self:CrawlExpression(statement.expression):Truthy() then
            self:PushScope()
            self:CrawlStatements(statement.statements, return_values)
            self:PopScope()
        end
    elseif statement.kind == "do" then
        self:PushScope()
        self:CrawlStatements(statement.statements, return_values)
        self:PopScope()
    elseif statement.kind == "repeat" then
        self:PushScope()
        self:CrawlStatements(statement.statements, return_values)
        if self:CrawlExpression(statement.expression):Truthy() then
            self:FireEvent("break")
        end
        self:PopScope()
    elseif statement.kind == "return" then
        local evaluated = {}
        for i,v in ipairs(statement.expressions) do
            evaluated[i] = self:CrawlExpression(v)
        end
        self:FireEvent("return", evaluated)
        if return_values then
            table.insert(return_values, evaluated)
        end
    elseif statement.kind == "break" then
        self:FireEvent("break")
    elseif statement.kind == "expression" then
        self:FireEvent("call", statement.value, {self:CrawlExpression(statement.value)})
    elseif statement.kind == "for" then
        if statement.fori then
            self:PushScope()
            self:FireEvent("upvalue", statement.identifiers[1], self:CrawlExpression(statement.expressions[1]))
            for i = 2, 3 do
                if statement.expressions[i] then
                    self:CrawlExpression(statement.expressions[i])
                end
            end
            self:CrawlStatements(statement.statements, return_values)
            self:PopScope()
        else
            self:PushScope()
            for i,v in ipairs(statement.identifiers) do
                self:FireEvent("upvalue", v, statement.expressions[i] and self:CrawlExpression(statement.expressions[i]))
            end
            self:CrawlStatements(statement.statements)
            self:PopScope()
        end
    elseif statement.kind ~= "end_of_file" then
        error("unhandled statement " .. tostring(statement))
    end
end

do
    local syntax = require("oh.syntax")

    local self_arg

    evaluate_expression = function(node, stack, self)
        if node.kind == "value" then
            if node.value.type == "letter" then
                if node.upvalue_or_global then
                    stack:Push(self:GetValue(node) or T(node, node, nil, "any"))
                else
                    stack:Push(T(node.value.value), node)
                end
            elseif node.value.type == "number" then
                stack:Push(T(tonumber(node.value.value), node))
            elseif node.value.value == "true" then
                stack:Push(T(true, node))
            elseif node.value.value == "false" then
                stack:Push(T(false, node))
            elseif node.value.type == "string" then
                stack:Push(T(node.value.value, node))
            else
                error("unhandled value type " .. node.value.type)
            end
        elseif node.kind == "function" then
            stack:Push(T(node, node, nil, "function"))
        elseif node.kind == "table" then
            stack:Push(T(Table(node), node, nil, "table"))
        elseif node.kind == "binary_operator" then
            local r, l = stack:Pop(), stack:Pop()
            local op = node.value.value
            print(l,r)
            if (op == "." or op == ":") and l.type == "table" then
                stack:Push(l.val:GetValue(r.val))
                return
            end

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
            local index = self:CrawlExpression(node.expression)

            stack:Push(r:BinaryOperator(".", index, node))
        elseif node.kind == "postfix_call" then
            local r = stack:Pop()

            if r.type == "any" then
                stack:Push({T(r.val, r.node, nil, "any")})
            else
                local func_expr = r.val

                if self.calling_function == r then
                    stack:Push(T(r.val, r.node, nil, "any"))
                    return
                end

                self.calling_function = r

                self:PushScope()

                if self_arg then
                    self:DeclareUpvalue("self", self_arg)
                end

                for i, v in ipairs(func_expr.identifiers) do
                    self:DeclareUpvalue(v, node.expressions[i] and self:CrawlExpression(node.expressions[i]) or nil)
                end

                local ret = {}
                self:CrawlStatements(func_expr.statements, ret)
                self:PopScope()

                for _, values in ipairs(ret) do
                    stack:Push(values)
                end

                self.calling_function = nil
            end
        else
            error("unhandled expression " .. node.kind)
        end
    end

    function META:CrawlExpression(exp)
        return exp:Evaluate(evaluate_expression, self)
    end
end

local function Crawler()
    return setmetatable({}, META)
end

do
    local Lexer = require("oh.lexer")
    local Parser = require("oh.parser")

    --local path = "oh/parser.lua"
    --local code = assert(io.open(path)):read("*all")

    local tk = Lexer(code)
    local ps = Parser()

    local tokens = tk:GetTokens()
    local ast = ps:BuildAST(tokens)

    local crawler = Crawler()
    crawler:CrawlStatement(ast)
end