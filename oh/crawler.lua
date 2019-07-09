
local types = require("oh.types")
local T = types.Type
local Table = types.Table
local hash = types.Hash

local META = {}
META.__index = META

local table_insert = table.insert

do
    function META:Hash(token)
        return hash(token)
    end
    
    --[[
        local a = b -- this works and shouldn't work
        local b = 2
        print(a)
        >> 2

        ability to create a temporary scope based on some other scope
        
        maybe don't try and declare and collect functions if they aren't called
        collect function behavior only when called, and mark dead paths in function

        when a function is defined, it returns any and and takes any until it's actaully called, then it becomes refined
    ]]

    function META:CreateScope()
        local scope = {
            children = {},
            parent = parent,
            upvalues = {},
            upvalue_map = {},

            node = node,
            extra_node = extra_node,
        }
        
        self.scope = scope
    end

    function META:PushScope(node, extra_node)
        assert(type(node) == "table" and node.kind, "expected an associated ast node")

        self:FireEvent("enter_scope", node, extra_node)

        local parent = self.scope

        local scope = {
            children = {},
            parent = parent,
            upvalues = {},
            upvalue_map = {},

            node = node,
            extra_node = extra_node,
        }

        if parent then
            table_insert(parent.children, scope)
        end

        self.scope = scope
    end

    function META:PopScope(discard)
        self:FireEvent("leave_scope", self.scope.node, self.scope.extra_node)

        local scope = self.scope.parent
        if scope then
            self.scope = scope
        end
    end

    function META:GetScope()
        return self.scope
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
        self.scope.upvalue_map[self:Hash(key)] = upvalue

        self:FireEvent("upvalue", key, data)

        return upvalue
    end

    function META:DeclareGlobal(key, data)
        self.env[self:Hash(key)] = data
    end

    function META:GetUpvalue(key)
        if not self.scope then return end

        local key_hash = self:Hash(key)

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

        return self.env[self:Hash(key)]
    end

    function META:SetGlobal(key, val)
        self:FireEvent("set_global", key, val)

        self.env[self:Hash(key)] = val
    end

    function META:NewIndex(obj, key, val)
        assert(obj)
        assert(key)
        assert(val)
        local key = self:CrawlExpression(key)
        local obj = self:CrawlExpression(obj)

        if obj.type ~= "any" then
            if type(obj.val) == "table" and obj.val.SetValue then
                obj.val:SetValue(key, val)
            end
            self:FireEvent("newindex", obj, key, val)
        end
    end

    function META:Assign(node, val)
        if node.kind == "value" then
            if not self:MutateUpvalue(node.value, val) then
                self:SetGlobal(node.value, val)
            end
        elseif node.kind == "postfix_expression_index" then
            self:NewIndex(node.left, node.expression, val)
        else
            self:NewIndex(node.left, node.right, val)
        end
    end

    function META:UnpackExpressions(expressions)
        local ret = {}

        if not expressions then return ret end

        for i, exp in ipairs(expressions) do
            for _, t in ipairs({self:CrawlExpression(exp)}) do
                if t.type == "..." then
                    if t.val then
                        for _, t in ipairs(t.val) do
                            table.insert(ret, t)
                        end
                    end
                end
                table.insert(ret, t)
            end
        end

        return ret
    end
end

function META:FireEvent(what, ...)
    if self.suppress_events then return end

    self:OnEvent(what, ...)
end

function META:CrawlStatements(statements, ...)
    for _, val in ipairs(statements) do
        self:CrawlStatement(val, ...)
    end
end

local evaluate_expression

function META:CrawlStatement(statement, ...)
    if statement.kind == "root" then
        self:PushScope(statement)
        self:CrawlStatements(statement.statements, ...)
        self:PopScope()
    elseif statement.kind == "local_assignment" then
        local ret = self:UnpackExpressions(statement.right)

        for i, node in ipairs(statement.left) do
            local key = node.value
            local val = ret[i] or T(nil, node)
            self:DeclareUpvalue(key, val)
        end
    elseif statement.kind == "assignment" then
        local ret = self:UnpackExpressions(statement.right)

        for i, node in ipairs(statement.left) do
            self:Assign(node, ret[i])
        end
    elseif statement.kind == "function" then
        self:Assign(
            statement.expression, 
            self:CrawlExpression(statement:ToExpression("function"))
        )
    elseif statement.kind == "local_function" then
        self:DeclareUpvalue(
            statement.identifier.value, 
            self:CrawlExpression(statement:ToExpression("function"))
        )
    elseif statement.kind == "if" then
        for i, statements in ipairs(statement.statements) do
            if not statement.expressions[i] or self:CrawlExpression(statement.expressions[i]):Truthy() then
                self:PushScope(statement, statement.tokens["if/else/elseif"][i])
                self:CrawlStatements(statements, ...)
                self:PopScope()
            end
        end
    elseif statement.kind == "while" then
        if self:CrawlExpression(statement.expression):Truthy() then
            self:PushScope(statement)
            self:CrawlStatements(statement.statements, ...)
            self:PopScope()
        end
    elseif statement.kind == "do" then
        self:PushScope(statement)
        self:CrawlStatements(statement.statements, ...)
        self:PopScope()
    elseif statement.kind == "repeat" then
        self:PushScope(statement)
        self:CrawlStatements(statement.statements, ...)
        if self:CrawlExpression(statement.expression):Truthy() then
            self:FireEvent("break")
        end
        self:PopScope()
    elseif statement.kind == "return" then
        local return_values = ...

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
        self:PushScope(statement)
        if statement.fori then
            local range = self:CrawlExpression(statement.expressions[1]):Max(self:CrawlExpression(statement.expressions[2]))
            self:DeclareUpvalue(statement.identifiers[1].value, range)
            if statement.expressions[3] then
                self:CrawlExpression(statement.expressions[3])
            end
        else
            for i,v in ipairs(statement.identifiers) do
                self:DeclareUpvalue(v.value, statement.expressions[i] and self:CrawlExpression(statement.expressions[i] or nil))
            end
        end
        self:CrawlStatements(statement.statements, ...)
        self:PopScope()
    elseif statement.kind ~= "end_of_file" and statement.kind ~= "semicolon" then
        error("unhandled statement " .. tostring(statement))
    end
end

do
    local syntax = require("oh.syntax")

    evaluate_expression = function(node, stack, self)
        if node.kind == "value" then
            if node.value.type == "letter" then
                if node.upvalue_or_global then

                    if self.hijack and self.hijack[node.value.value] then
                        stack:Push(self.hijack[node.value.value])
                        return
                    end

                    stack:Push(self:GetValue(T(node.value.value, node)) or T(nil, node, nil, "any"))
                else
                    stack:Push(T(node.value.value, node))
                end
            elseif node.value.type == "number" then
                stack:Push(T(tonumber(node.value.value), node))
            elseif node.value.value == "true" then
                stack:Push(T(true, node))
            elseif node.value.value == "false" then
                stack:Push(T(false, node))
            elseif node.value.type == "string" then
                stack:Push(T(node.value.value, node))
            elseif node.value.value == "..." then
                stack:Push(self:GetValue(T(node.value.value, node)) or T(nil, node, nil, "..."))
            elseif node.value.value == "nil" then
                stack:Push(T(node.value.value, node))
            else
                error("unhandled value type " .. node.value.type .. " " .. node:Render())
            end
        elseif node.kind == "function" then
            stack:Push(T(node, node, nil, "function"))
        elseif node.kind == "table" then
            stack:Push(T(Table(node), node, nil, "table"))
        elseif node.kind == "binary_operator" then
            local r, l = stack:Pop(), stack:Pop()
            local op = node.value.value

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

            if type(r) == "function" then
                local values = {}

                if node.expressions then
                    self.suppress_events = true
                    for _, exp in ipairs(node.expressions) do
                        local val = self:CrawlExpression(exp)
                        table.insert(values, val)
                    end
                    self.suppress_events = false
                end

                r(unpack(values))

                stack:Push(T(nil))
                return
            end

            if r.type == "any" then
                stack:Push(r:Copy("any"))
            else
                local func_expr = r.node

                if func_expr and type(func_expr) == "table" and func_expr.kind == "function" then
                    if self.calling_function == r then
                        stack:Push(r:Copy("any"))
                        return
                    end

                    self.calling_function = r

                    self:PushScope(node)

                    if self_arg then
                        self:DeclareUpvalue("self", self_arg)
                    end

                    for i, v in ipairs(func_expr.identifiers) do
                        if v.value.value == "..." then
                            if node.expressions then
                                local values = {}
                                for i = i, #node.expressions do
                                    table.insert(values, self:CrawlExpression(node.expressions[i]))
                                end
                                self:DeclareUpvalue(v.value, T(values, v, nil, "..."))
                            end
                        else
                            self:DeclareUpvalue(v.value, node.expressions[i] and self:CrawlExpression(node.expressions[i]) or nil)
                        end
                    end

                    local ret = {}
                    self:CrawlStatements(func_expr.statements, ret)
                    self:PopScope()

                    if ret[1] then
                        for _, values in ipairs(ret) do
                            for _, v in ipairs(values) do
                                stack:Push(v)
                            end
                        end
                    end

                    self.calling_function = nil
                else
                    stack:Push(r:Copy("any"))
                end
            end
        else
            error("unhandled expression " .. node.kind)
        end
    end

    function META:CrawlExpression(exp)
        return exp:Evaluate(evaluate_expression, self)
    end
end

return function()
    return setmetatable({env = {}}, META)
end
