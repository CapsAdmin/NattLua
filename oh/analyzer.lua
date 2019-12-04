local types = require("oh.types")
local types3 = require("oh.types3")

local META = {}
META.__index = META

local table_insert = table.insert

do -- types
    function META:TypeFromImplicitNode(node, name, ...)
        node.scope = self.scope -- move this out of here

        local obj = types3.Create(name, ...)
        if not obj then error("NYI: " .. name) end

        obj.node = node
        obj.analyzer = self
        node.inferred_type = obj

        return obj
    end

    do
        local guesses = {
            {pattern = "count", type = "number"},
            {pattern = "tbl", type = "table"},
            {pattern = "str", type = "string"},
        }

        table.sort(guesses, function(a, b) return #a.pattern > #b.pattern end)

        function META:GetInferredType(node)
            local str = node.value.value:lower()

            for _, v in ipairs(guesses) do
                if str:find(v.pattern, nil, true) then
                    return self:TypeFromImplicitNode(node, v.type)
                end
            end

            return self:TypeFromImplicitNode(node, "any")
        end
    end

    do
        local function merge_types(src, dst)
            for i,v in ipairs(dst) do
                if src[i] and src[i].type ~= "any" then
                    src[i] = types3.Set:new(src[i], v)
                else
                    src[i] = dst[i]
                end
            end

            return src
        end

        function META:CallFunctionType(obj, arguments, node, deferred)
            node = node or obj.node
            local func_expr = obj.node

            obj.called = true

            if func_expr and func_expr.kind == "function" then
                --lua function

                do -- recursive guard
                    if self.calling_function == obj then
                        return {self:TypeFromImplicitNode(node, "any")}
                    end
                    self.calling_function = obj
                end

                local ret

                do
                    self:PushScope(obj.node)



                    local argument_tuple = types3.Tuple:new(unpack(arguments))
                    local return_tuple = obj:Call(argument_tuple)

                    if not return_tuple then
                        self:Error(func_expr, "cannot call " .. tostring(obj) .. " with arguments " ..  tostring(argument_tuple))
                    end




                    local identifiers = {}

                    for i,v in ipairs(obj.node.identifiers) do
                        identifiers[i] = v
                    end

                    if obj.node.self_call then
                        table.insert(identifiers, 1, "self")
                    end

                    for i, identifier in ipairs(identifiers) do
                        local node = identifier == "self" and obj.node or identifier
                        local arg = arguments[i] or self:TypeFromImplicitNode(node, "nil")


                        if identifier == "self" or identifier.value.value ~= "..." then
                            self:DeclareUpvalue(identifier, arg, "runtime")
                        else
                            local values = {}
                            for i = i, #arguments do
                                table.insert(values, arguments[i] or self:TypeFromImplicitNode(node, "nil"))
                            end
                            local obj = self:TypeFromImplicitNode(node, "...", values)
                            self:DeclareUpvalue(identifier, obj, "runtime")
                        end
                    end

                    ret = {}

                    -- crawl and collect return values from function statements
                    self:AnalyzeStatements(obj.node.statements, ret)

                    self:PopScope()

                    if obj.node.return_types then
                        for i,v in ipairs(return_tuple.data) do
                            if not ret[i] or not types3.SupersetOf(v, ret[i]) then
                                self:Error(func_expr, "expected return #" .. i .. " to be a superset of " .. tostring(v) .. " got " .. tostring(ret[i]))
                            end
                        end
                    else
                        for i,v in ipairs(return_tuple.data) do
                            if ret[i] == nil then
                                ret[i] = self:TypeFromImplicitNode(func_expr, "nil")
                            end
                        end

                        -- return tuples
                        obj.data:GetKeyVal(argument_tuple).val.data = merge_types(obj.data:GetKeyVal(argument_tuple).val.data, ret)
                    end

                    -- argument tuples
                    obj.data:GetKeyVal(argument_tuple).key.data = merge_types(obj.data:GetKeyVal(argument_tuple).key.data, arguments)

                    for i, v in ipairs(obj.data:GetKeyVal(argument_tuple).key.data) do
                        if obj.node.identifiers[i] then
                            obj.node.identifiers[i].inferred_type = v
                        end
                    end

                    func_expr.inferred_type = obj

                    self:FireEvent("function_spec", obj)
                end

                self.calling_function = nil

                if not ret[1] then
                    -- if this is called from CallMeLater we cannot create a nil type from node
                    local old = node.inferred_type
                    ret[1] = self:TypeFromImplicitNode(node, "nil")
                    node.inferred_type = old
                end

                return ret
            elseif obj:IsType("function") then
                --external

                self:FireEvent("external_call", node, obj)

                -- HACKS
                obj.analyzer = self
                obj.node = node


                local argument_tuple = types3.Tuple:new(unpack(arguments))
                local return_tuple = obj:Call(argument_tuple)
                if not return_tuple then
                    self:Error(func_expr, "cannot call " .. tostring(obj) .. " with arguments " ..  tostring(argument_tuple))
                end

                return return_tuple
            end
            -- calling something that has no type and does not exist
            -- expressions assumed to be crawled from caller

            return {self:TypeFromImplicitNode(node, "any")}
        end
    end
end

do
    function META:Hash(node)
        if type(node) == "string" then
            return node
        end

        assert(type(node.value.value) == "string")

        return node.value.value
    end

    function META:PushScope(node, extra_node)
        assert(type(node) == "table" and node.kind, "expected an associated ast node")

        local parent = self.scope

        local scope = {
            children = {},
            parent = parent,

            upvalues = {
                runtime = {
                    list = {},
                    map = {},
                },
                typesystem = {
                    list = {},
                    map = {},
                }
            },

            node = node,
            extra_node = extra_node,
        }

        self:FireEvent("enter_scope", node, extra_node, scope)

        if parent then
            table_insert(parent.children, scope)
        end

        self.scope_stack = self.scope_stack or {}
        table.insert(self.scope_stack, self.scope)

        self.scope = node.scope or scope

        return scope
    end

    function META:PopScope()
        local old = table.remove(self.scope_stack)

        self:FireEvent("leave_scope", self.scope.node, self.scope.extra_node, old)

        if old then
            self.scope = old
        end
    end

    function META:GetScope()
        return self.scope
    end

    function META:DeclareUpvalue(key, val, env)
        local upvalue = {
            key = key,
            data = val,
            scope = self.scope,
            events = {},
            shadow = self:GetUpvalue(key, env),
        }

        table_insert(self.scope.upvalues[env].list, upvalue)
        self.scope.upvalues[env].map[self:Hash(key)] = upvalue

        self:FireEvent("upvalue", key, val, env)

        return upvalue
    end

    function META:GetUpvalue(key, env)
        if not self.scope then return end

        local key_hash = self:Hash(key)

        if self.scope.upvalues[env].map[key_hash] then
            return self.scope.upvalues[env].map[key_hash]
        end

        local scope = self.scope.parent
        while scope do
            if scope.upvalues[env].map[key_hash] then
                return scope.upvalues[env].map[key_hash]
            end
            scope = scope.parent
        end
    end

    function META:MutateUpvalue(key, val, env)
        local upvalue = self:GetUpvalue(key, env)
        if upvalue then
            upvalue.data = val
            self:FireEvent("mutate_upvalue", key, val, env)
            return true
        end
        return false
    end

    function META:GetValue(key, env)
        local upvalue = self:GetUpvalue(key, env)

        if upvalue then
            return upvalue.data
        end

        return self.env[env][self:Hash(key)]
    end

    function META:SetGlobal(key, val, env)
        self:FireEvent("set_global", key, val, env)

        self.env[env][self:Hash(key)] = val
    end

    -- obj[key] = val
    function META:NewIndex(obj, key, val, env)
        local key = self:AnalyzeExpression(key, env)
        local obj = self:AnalyzeExpression(obj, env)

        obj:Set(key, val)

        self:FireEvent("newindex", obj, key, val, env)
    end

    function META:Assign(key, val, env)
        if key.kind == "value" then
            -- local key = val; key = val
            if not self:MutateUpvalue(key, val, env) then
                -- key = val
                self:SetGlobal(key, val, env)
            end
        elseif key.kind == "postfix_expression_index" then
            -- key[foo] = val
            self:NewIndex(key.left, key.expression, val, env)
        else
            -- key.foo = val
            self:NewIndex(key.left, key.right, val, env)
        end
    end
end

function META:FireEvent(what, ...)
    if self.suppress_events then return end

    if self.OnEvent then
        self:OnEvent(what, ...)
    end
end

do
    local t = 0
    function META:DumpEvent(what, ...)

        if what == "create_global" then
            io.write((" "):rep(t))
            io.write(what, " - ")
            local key, val = ...
            io.write(key:Render())
            if val then
                io.write(" = ")
                io.write(tostring(val))
            end
            io.write("\n")
        elseif what == "newindex" then
            io.write((" "):rep(t))
            io.write(what, " - ")
            local obj, key, val = ...
            io.write(tostring(obj.name), "[", (tostring(key)), "] = ", tostring(val))
            io.write("\n")
        elseif what == "mutate_upvalue" then
            io.write((" "):rep(t))
            io.write(what, " - ")
            local key, val = ...
            io.write(self:Hash(key), " = ", tostring(val))
            io.write("\n")
        elseif what == "upvalue" then
            io.write((" "):rep(t))



            io.write(what, "  - ")
            local key, val = ...
            io.write(self:Hash(key))
            if val then
                io.write(" = ")
                io.write(tostring(val))
            end
            io.write("\n")
        elseif what == "set_global" then
            io.write((" "):rep(t))
            io.write(what, " - ")
            local key, val = ...
            io.write(self:Hash(key))
            if val then
                io.write(" = ")
                io.write(tostring(val))
            end
            io.write("\n")
        elseif what == "enter_scope" then
            local node, extra_node, scope = ...
            io.write((" "):rep(t))
            t = t + 1
            if extra_node then
                io.write(extra_node.value)
            else
                io.write(node.kind)
            end
            io.write(" {")
            io.write("[", tostring(tonumber(("%p"):format(scope))), "]")
            io.write("\n")
        elseif what == "leave_scope" then
            local node, extra_node, scope = ...
            t = t - 1
            io.write((" "):rep(t))
            io.write("}")
            io.write("[", tostring(tonumber(("%p"):format(scope))), "]")
            --io.write(node.kind)
            if extra_node then
            --  io.write(tostring(extra_node))
            end
            io.write("\n")
        elseif what == "external_call" then
            io.write((" "):rep(t))
            local node, type = ...
            io.write(node:Render(), " - (", tostring(type), ")")
            io.write("\n")
        elseif what == "call" then
            io.write((" "):rep(t))
            --io.write(what, " - ")
            local exp, return_values = ...
            if return_values then
                local str = {}
                for i,v in ipairs(return_values) do
                    str[i] = tostring(v)
                end
                io.write(table.concat(str, ", "))
            end
            io.write(" = ", exp:Render())
            io.write("\n")
        elseif what == "deferred_call" then
            io.write((" "):rep(t))
            --io.write(what, " - ")
            local exp, return_values = ...
            if return_values then
                local str = {}
                for i,v in ipairs(return_values) do
                    str[i] = tostring(v)
                end
                io.write(table.concat(str, ", "))
            end
            io.write(" = ", exp:Render())
            io.write("\n")
        elseif what == "function_spec" then
            local func = ...
            io.write((" "):rep(t))
            io.write(what, " - ")
            io.write(tostring(func))
            io.write("\n")
        elseif what == "return" then
            io.write((" "):rep(t))
            io.write(what, "   - ")
            local values = ...
            if values then
                for i,v in ipairs(values) do
                    io.write(tostring(v), ", ")
                end
            end
            io.write("\n")
        else
            io.write((" "):rep(t))
            print(what .. " - ", ...)
        end
    end
end

function META:AnalyzeStatements(statements, ...)
    for _, val in ipairs(statements) do
        if self:AnalyzeStatement(val, ...) == true then
            return true
        end
    end
end

function META:CallMeLater(...)
    self.deferred_calls = self.deferred_calls or {}
    table.insert(self.deferred_calls, 1, {...})
end

function META:Error(node, msg)
    if require("oh").current_analyzer and require("oh").current_analyzer ~= self then
        return require("oh").current_analyzer:Error(node, msg)
    end

    if self.OnError then
        local print_util = require("oh.print_util")
        local start, stop = print_util.LazyFindStartStop(node)
        self:OnError(msg, start, stop)
    end


    if self.code then
        local print_util = require("oh.print_util")
        local start, stop = print_util.LazyFindStartStop(node)
        print(print_util.FormatError(self.code, self.name, msg, start, stop))
    else
        local s = tostring(self)
        s = s .. ": " .. msg

        print(s)
    end
end


local evaluate_expression

function META:AnalyzeStatement(statement, ...)
    if statement.kind == "root" then
        self:PushScope(statement)
        local ret
        if self:AnalyzeStatements(statement.statements, ...) == true then
            ret = true
        end
        self:PopScope()
        if self.deferred_calls then
            for i,v in ipairs(self.deferred_calls) do
                if not v[1].called then
                    self:CallFunctionType(unpack(v))
                end
            end
        end
        return ret
    elseif statement.kind == "assignment" or statement.kind == "local_assignment" then
        local env = statement.environment or "runtime"

        local values = {}

        if statement.right then
            for _, exp in ipairs(statement.right) do
                for _, obj in ipairs({self:AnalyzeExpression(exp, env)}) do
                    --if obj:IsType("...") and obj.values then
                    if types3.GetType(obj) == "tuple" then -- vararg
                        for _, obj in ipairs(obj.data) do
                            table.insert(values, obj)
                        end
                    end
                    table.insert(values, obj)
                end
            end
        end

        for i, node in ipairs(statement.left) do
            local obj

            if node.type_expression then
                obj = self:AnalyzeExpression(node.type_expression, "typesystem")

                local superset = obj
                local subset = values[i]

                if subset and not types3.SupersetOf(subset, superset) then
                    self:Error(node, "expected " .. tostring(obj) .. " but the right hand side is a " .. tostring(values[i]))
                end

                node.type_explicit = true
            else
                node.type_explicit = false
                obj = values[i]
            end

            if statement.kind == "local_assignment" then
                self:DeclareUpvalue(node, obj, env)
            elseif statement.kind == "assignment" then
                self:Assign(node, obj, env)
            end

            node.inferred_type = obj
        end
    elseif statement.kind == "destructure_assignment" or statement.kind == "local_destructure_assignment" then
        local env = statement.environment or "runtime"
        local obj = self:AnalyzeExpression(statement.right, env)

        if not obj:IsType("table") then
            self:Error(statement.right, "expected a table on the right hand side, got " .. tostring(obj))
        end

        if statement.default then
            if statement.kind == "local_destructure_assignment" then
                self:DeclareUpvalue(statement.default, obj, env)
            elseif statement.kind == "destructure_assignment" then
                self:Assign(statement.default, obj, env)
            end
        end

        for _, node in ipairs(statement.left) do
            local obj = obj:Get(node.value) or self:TypeFromImplicitNode(node, "nil")

            if statement.kind == "local_destructure_assignment" then
                self:DeclareUpvalue(node, obj, env)
            elseif statement.kind == "destructure_assignment" then
                self:Assign(node, obj, env)
            end
        end
    elseif statement.kind == "function" then
        self:Assign(statement.expression, self:AnalyzeExpression(statement:ToExpression("function")), "runtime")

        if statement.return_types then
            statement.inferred_return_types = self:AnalyzeExpressions(statement.return_types, "typesystem")
        end
    elseif statement.kind == "local_function" then
        self:DeclareUpvalue(statement.identifier, self:AnalyzeExpression(statement:ToExpression("function")), "runtime")
    elseif statement.kind == "local_type_function" then
        self:DeclareUpvalue(statement.identifier, self:AnalyzeExpression(statement:ToExpression("function")), "typesystem")
    elseif statement.kind == "if" then
        for i, statements in ipairs(statement.statements) do
            if not statement.expressions[i] then
                self:PushScope(statement, statement.tokens["if/else/elseif"][i])
                self:AnalyzeStatements(statements, ...)
                self:PopScope()
                break
            else
                local obj = self:AnalyzeExpression(statement.expressions[i], "runtime")

                if obj:IsTruthy() then
                    self:PushScope(statement, statement.tokens["if/else/elseif"][i])
                    obj:PushTruthy()

                    if self:AnalyzeStatements(statements, ...) == true then
                        if obj.value == true then
                            obj:PopTruthy()
                            self:PopScope()
                            return true
                        end
                    end

                    obj:PopTruthy()
                    self:PopScope()
                    break
                end
            end
        end
    elseif statement.kind == "while" then
        if self:AnalyzeExpression(statement.expression):IsTruthy() then
            self:PushScope(statement)
            if self:AnalyzeStatements(statement.statements, ...) == true then
                return true
            end
            self:PopScope()
        end
    elseif statement.kind == "do" then
        self:PushScope(statement)
        if self:AnalyzeStatements(statement.statements, ...) == true then
            return true
        end
        self:PopScope()
    elseif statement.kind == "repeat" then
        self:PushScope(statement)
        if self:AnalyzeStatements(statement.statements, ...) == true then
            return true
        end
        if self:AnalyzeExpression(statement.expression):IsTruthy() then
            self:FireEvent("break")
        end
        self:PopScope()
    elseif statement.kind == "return" then
        local return_values = ...

        local evaluated = {}
        for i,v in ipairs(statement.expressions) do
            evaluated[i] = self:AnalyzeExpression(v)

            -- add the return values
            if return_values then
                return_values[i] = return_values[i] and types.Fuse(return_values[i], evaluated[i]) or evaluated[i]
            end
        end

        self:FireEvent("return", evaluated)

        self.last_return = evaluated

        return true
    elseif statement.kind == "break" then
        self:FireEvent("break")
        --return true
    elseif statement.kind == "call_expression" then
        self:FireEvent("call", statement.value, {self:AnalyzeExpression(statement.value)})
    elseif statement.kind == "generic_for" then
        self:PushScope(statement)

        local args = self:AnalyzeExpressions(statement.expressions)

        if args[1] then
            local values = self:CallFunctionType(args[1], {unpack(args, 2)}, statement.expressions[1])

            for i,v in ipairs(statement.identifiers) do
                self:DeclareUpvalue(v, values[i], "runtime")
            end
        end

        if self:AnalyzeStatements(statement.statements, ...) == true then
            return true
        end

        self:PopScope()
    elseif statement.kind == "numeric_for" then
        self:PushScope(statement)
        local range = self:AnalyzeExpression(statement.expressions[1]):Max(self:AnalyzeExpression(statement.expressions[2]))
        self:DeclareUpvalue(statement.identifiers[1], range, "runtime")

        if statement.expressions[3] then
            self:AnalyzeExpression(statement.expressions[3])
        end

        if self:AnalyzeStatements(statement.statements, ...) == true then
            self:PopScope()
            return true
        end
        self:PopScope()
    elseif statement.kind == "type_interface" then
        local tbl = self:GetValue(statement.key, "typesystem")

        if not tbl then
            tbl = self:TypeFromImplicitNode(statement, "table", {})
        end

        for i,v in ipairs(statement.expressions) do
            local val = self:AnalyzeExpression(v.right, "typesystem")
            if tbl.value and tbl.value[v.left.value] then
                types.OverloadFunction(tbl:Get(v.left.value), val)
            else
                tbl:Set(v.left.value, self:AnalyzeExpression(v.right, "typesystem"))
            end
        end

        self:DeclareUpvalue(statement.key, tbl, "typesystem")
    elseif
        statement.kind ~= "end_of_file" and
        statement.kind ~= "semicolon" and
        statement.kind ~= "shebang" and
        statement.kind ~= "goto_label" and
        statement.kind ~= "goto"
    then
        error("unhandled statement " .. tostring(statement))
    end
end

do
    evaluate_expression = function(self, node, stack, env)
        if node.type_expression then
            local val = self:AnalyzeExpression(node.type_expression, "typesystem")
            stack:Push(val)
            if node.tokens["is"] then
                node.result_is = self:GetValue(node, env):IsType(val)
            end
        elseif node.kind == "value" then
            if
                (node.value.type == "letter" and node.upvalue_or_global) or
                node.value.value == "..."
            then
                local obj

                -- if it's ^string, number, etc, but not string
                if env == "typesystem" and types.IsType(self:Hash(node)) and not node.force_upvalue then
                    obj = self:TypeFromImplicitNode(node, node.value.value)
                else
                    obj = self:GetValue(node, env)

                    if not obj and env == "runtime" then
                        obj = self:GetValue(node, "typesystem")
                    end
                end

                -- self in a table type declaration refers to the type table itself
                if env == "typesystem" and not obj and node.value.value == "self" then
                    obj = self.current_table
                end

                if not obj and self.Index then
                    obj = self:Index(node)
                end

                -- last resort, itemCount > number
                if not obj then
                    obj = self:GetInferredType(node)
                end

                -- ...
                if obj.GetTruthy and obj:GetTruthy() then
                    obj = obj:RemoveNonTruthy()
                end

                stack:Push(obj)
            elseif node.value.type == "number" then
                stack:Push(self:TypeFromImplicitNode(node, "number", tonumber(node.value.value)))
            elseif node.value.type == "string" then
                stack:Push(self:TypeFromImplicitNode(node, "string", node.value.value:sub(2, -2)))
            elseif node.value.type == "letter" then
                stack:Push(self:TypeFromImplicitNode(node, "string", node.value.value))
            elseif node.value.value == "nil" then
                stack:Push(self:TypeFromImplicitNode(node, "nil"))
            elseif node.value.value == "true" then
                stack:Push(self:TypeFromImplicitNode(node, "boolean", true))
            elseif node.value.value == "false" then
                stack:Push(self:TypeFromImplicitNode(node, "boolean", false))
            else
                error("unhandled value type " .. node.value.type .. " " .. node:Render())
            end
        elseif node.kind == "function" then
            local args = {}

            for i, key in ipairs(node.identifiers) do
                -- if this node is already explicitly annotated with foo: mytype or foo as mytype use that
                args[i] = key.type_expression and self:AnalyzeExpression(key.type_expression, "typesystem") or self:GetInferredType(key)
            end

            if node.self_call and node.expression then
                local upvalue = self:GetUpvalue(node.expression.left, "runtime")
                if upvalue then
                    table.insert(args, 1, upvalue.data)
                end
            end

            local ret = {}

            if node.return_types then
                for i, type_exp in ipairs(node.return_types) do
                    ret[i] = self:AnalyzeExpression(type_exp, "typesystem")
                end
            end

            local obj = self:TypeFromImplicitNode(node, "function", ret, args)
            self:CallMeLater(obj, args, node, true)
            stack:Push(obj)

        elseif node.kind == "table" then
            stack:Push(self:TypeFromImplicitNode(node, "table", self:AnalyzeTable(node, env)))
        elseif node.kind == "binary_operator" then
            local right, left = stack:Pop(), stack:Pop()

            if node.value.value == ":" then
                stack:Push(left)
            end

            stack:Push(types3.BinaryOperator(node.value.value, right, left, env))
        elseif node.kind == "prefix_operator" then
            stack:Push(stack:Pop():PrefixOperator(node))
        elseif node.kind == "postfix_operator" then
            stack:Push(stack:Pop():PostfixOperator(node))
        elseif node.kind == "postfix_expression_index" then
            stack:Push(stack:Pop():Get(self:AnalyzeExpression(node.expression)))
        elseif node.kind == "type_function" then
            local args = {}
            local rets = {}
            local func

            -- declaration
            if node.identifiers then
                for i, key in ipairs(node.identifiers) do
                    args[i] = self:GetValue(key.left or key, env) or self:GetInferredType(key)
                end
            end

            if node.return_expressions then
                for i,v in ipairs(node.return_expressions) do
                    rets[i] = self:AnalyzeExpression(v, "typesystem")
                end
            end

            if node.statements then
                local str = "local oh, analyzer, types, node = ...; return " .. node:Render({})
                local load_func, err = loadstring(str, "")
                if not load_func then
                    -- this should never happen unless node:Render() produces bad code or the parser didn't catch any errors
                    print(str)
                    error(err)
                end
                func = load_func(require("oh"), self, types3, node)
            end

            stack:Push(self:TypeFromImplicitNode(node, "function", rets, args, func))
        elseif node.kind == "postfix_call" then
            local obj = stack:Pop()

            local arguments = self:AnalyzeExpressions(node.expressions, env)

            if node.self_call then
                local val = stack:Pop()
                table.insert(arguments, 1, val)
            end

            if obj.name and obj.name ~= "function" and obj.name ~= "table" and obj.name ~= "any" then
                self:Error(node, tostring(obj) .. " cannot be called")
            else
                stack:Push(self:CallFunctionType(obj, arguments, node))
            end
        elseif node.kind == "type_list" then
            local tbl = {}

            if node.types then
                for i, exp in ipairs(node.types)do
                    tbl[i] = self:AnalyzeExpression(exp, env)
                end
            end

            local obj = self:TypeFromImplicitNode(node, "list", tbl, node.length and tonumber(node.length.value))

            obj.value = {}
            stack:Push(obj)
        elseif node.kind == "type_table" then
            local obj = self:TypeFromImplicitNode(node, "table")

            self.current_table = obj
            obj.value = self:AnalyzeTable(node, env)
            self.current_table = nil

            stack:Push(obj)
        elseif node.kind == "import" or node.kind == "lsx" then
            --stack:Push(self:AnalyzeStatement(node.root))
--            print(node.analyzer:Analyze())
        else
            error("unhandled expression " .. node.kind)
        end
    end

    do
        local meta = {}
        meta.__index = meta

        function meta:Push(val)
            assert(val)
            self.values[self.i] = val
            self.i = self.i + 1
        end

        function meta:Pop()
            self.i = self.i - 1

            if self.i < 1 then
                if self.last_val then
                    self.last_val:Error("stack underflow")
                end
                error("stack underflow", 2)
            end

            local val = self.values[self.i]
            self.values[self.i] = nil

            if val[1] then
                return val[1], val
            end

            self.last_val = val

            return val
        end

        local function expand(self, node, cb, ...)
            if node.left then
                expand(self, node.left, cb, ...)
            end

            if node.right then
                expand(self, node.right, cb, ...)
            end

            cb(self, node, ...)
        end

        function META:AnalyzeExpression(exp, env)
            assert(exp and exp.type == "expression")
            env = env or "runtime"
            local stack = setmetatable({values = {}, i = 1}, meta)

            expand(self, exp, evaluate_expression, stack, env)

            local out = {}

            for i,v in ipairs(stack.values) do
                if v[1] then
                    for i,v in ipairs(v) do
                        table.insert(out, v)
                    end
                else
                    table.insert(out, v)
                end
            end

            return unpack(out)
        end

        function META:AnalyzeExpressions(expressions, ...)
            if not expressions then return end
            local out = {}
            for i, expression in ipairs(expressions) do
                local ret = {self:AnalyzeExpression(expression, ...)}
                for i,v in ipairs(ret) do
                    table.insert(out, v)
                end
            end
            return out
        end

        function META:AnalyzeTable(node, env)
            local out = {}
            for _, node in ipairs(node.children) do
                if node.kind == "table_key_value" then
                    out[node.key.value] = self:AnalyzeExpression(node.value, env)
                elseif node.kind == "table_expression_value" then

                    local key = self:AnalyzeExpression(node.key, env)
                    local obj = self:AnalyzeExpression(node.value, env)

                    if key:IsType("string") and key.value then
                        out[key.value] = obj
                    else
                        out[key] = obj
                    end
                elseif node.kind == "table_index_value" then
                    if node.i then
                        out[node.i] = self:AnalyzeExpression(node.value, env)
                    else
                        table.insert(out, self:AnalyzeExpression(node.value, env))
                    end
                end
            end
            return out
        end
    end
end

local function DefaultIndex(self, node)
    local oh = require("oh")
    return oh.GetBaseAnalyzer():GetValue(node, "typesystem")
end

return function()
    local self = setmetatable({env = {runtime = {}, typesystem = {}}}, META)
    self.Index = DefaultIndex
    return self
end
