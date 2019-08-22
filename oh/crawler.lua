local types = require("oh.types")

local META = {}
META.__index = META

local table_insert = table.insert

local function table_to_types(self, node, out, env)
    for _,v in ipairs(node.children) do
        if v.kind == "table_key_value" then
            --out[types.Type("string", v.key.value)] = self:TypeFromNode(v.value) -- HMMM
            out[v.key.value] = self:CrawlExpression(v.value, env)
        elseif v.kind == "table_expression_value" then
            local t = self:CrawlExpression(v.key, env)
            local v = self:CrawlExpression(v.value, env)
            if t:IsType("string") then
                out[t.value] = v
            else
                out[t] = v
            end
        elseif v.kind == "table_index_value" then
            if v.i then
                out[v.i] = self:CrawlExpression(v.value, env)
            else
                table.insert(out, self:CrawlExpression(v.value, env))
            end
        end
    end
end

do
    function META:Hash(t)
        if type(t) == "string" then
            return t
        end

        assert(type(t.value.value) == "string")

        return t.value.value
    end


    local function new_type(self, node, ...)
        if type(node) == "string" then
            return types.Type(type)
        end

        assert(node.type == "expression")

        if node.kind == "value" then
            local t = node.value.type
            local v = node.value.value
            if t == "number" then
                return types.Type("number", tonumber(v))
            elseif t == "string" then
                return types.Type("string", v:sub(2, -2))
            elseif t == "letter" then
                return types.Type("string", v)
            elseif v == "..." then
                local t = types.Type("...")
                t.values = ... -- HACK
                return t
            elseif v == "true" then
                return types.Type("boolean", true)
            elseif v == "false" then
                return types.Type("boolean", false)
            elseif v == "nil" then
                return types.Type("nil")
            elseif v == "function" then
                return types.Type("function", ...)
            elseif v == "list" then
                return types.Type("list", ...)
            else
                error("unhanlded value type " .. t .. " ( " .. v .. " ) ")
            end
            --local t = types.Type()
        elseif node.kind == "table" then
            local t = types.Type("table")

            table_to_types(self, node, t.value, "runtime")

            return t
        elseif node.kind == "function" then
            local t = types.Type("function")
            node.scope = self.scope
            return t
        else
            error("unhanlded expression kind " .. node.kind)
        end
    end

    function META:TypeFromNode(node, ...)
        node.scope = self.scope
        local t = new_type(self, node, ...):AttachNode(node)
        t.code = self.code
        t.crawler = self
        return t
    end

    function META:TypeFromImplicitNode(node, ...)
        node.scope = self.scope
        local t = types.Type(...):AttachNode(node)
        t.code = self.code
        t.crawler = self
        return t
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

    function META:PushScope(node, extra_node)
        self.old_scope = self.scope
        self.scope = node.scope or self.scope

        assert(type(node) == "table" and node.kind, "expected an associated ast node")

        self:FireEvent("enter_scope", node, extra_node)

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

        if parent then
            table_insert(parent.children, scope)
        end

        self.scope = scope

        return scope
    end

    function META:PopScope()
        self:FireEvent("leave_scope", self.scope.node, self.scope.extra_node)

        local scope = self.scope.parent
        if scope then
            self.scope = scope
        end

        if self.old_scope then
            self.scope = self.old_scope
            self.old_scope = nil
        end
    end

    function META:GetScope()
        return self.scope
    end

    function META:DeclareUpvalue(key, data, env)
        assert(data == nil or types.IsTypeObject(data))

        local upvalue = {
            key = key,
            data = data,
            scope = self.scope,
            events = {},
            shadow = self:GetUpvalue(key, env),
        }

        table_insert(self.scope.upvalues[env].list, upvalue)
        self.scope.upvalues[env].map[self:Hash(key)] = upvalue

        self:FireEvent("upvalue", key, data, env)

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
        assert(val == nil or types.IsTypeObject(val))

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
        assert(val == nil or types.IsTypeObject(val))
        self:FireEvent("set_global", key, val, env)

        self.env[env][self:Hash(key)] = val
    end

    function META:NewIndex(obj, key, val, env)
        assert(val == nil or types.IsTypeObject(val))

        local node = obj

        local key = self:CrawlExpression(key, env)
        local obj = self:CrawlExpression(obj, env) or self:TypeFromImplicitNode(node, "nil")

        obj:set(key, val)

        self:FireEvent("newindex", obj, key, val, env)
    end

    function META:Assign(node, val, env)
        assert(val == nil or types.IsTypeObject(val))

        if node.kind == "value" then
            if not self:MutateUpvalue(node, val, env) then
                self:SetGlobal(node, val, env)
            end
        elseif node.kind == "postfix_expression_index" then
            self:NewIndex(node.left, node.expression, val, env)
        else
            self:NewIndex(node.left, node.right, val, env)
        end
    end

    function META:UnpackExpressions(expressions, env)
        local ret = {}

        if not expressions then return ret end

        for _, exp in ipairs(expressions) do
            for _, t in ipairs({self:CrawlExpression(exp, env)}) do
                if type(t) == "table" and t:IsType("...") then
                    if t.values then
                        for _, t in ipairs(t.values) do
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

    if self.OnEvent then
        self:OnEvent(what, ...)
    end
end

local function merge_types(src, dst)
    if src then
        for i,v in ipairs(dst) do
            if src[i] then
                src[i] = v + src[i]
            else
                src[i] = dst[i]
            end
        end

        return src
    end

    return dst
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
            local node, extra_node = ...
            io.write((" "):rep(t))
            t = t + 1
            if extra_node then
                io.write(extra_node.value)
            else
                io.write(node.kind)
            end
            io.write(" { ")
            io.write("\n")
        elseif what == "leave_scope" then
            local node, extra_node = ...
            t = t - 1
            io.write((" "):rep(t))
            io.write("}")
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

function META:CrawlStatements(statements, ...)
    if not statements then print(debug.traceback()) end
    for _, val in ipairs(statements) do
        if self:CrawlStatement(val, ...) == true then
            return true
        end
    end
end

function META:CallMeLater(typ, arguments, node)
    self.deferred_calls = self.deferred_calls or {}
    table.insert(self.deferred_calls, {typ, arguments, node})
end


function META:CallFunctionType(typ, arguments, node)
    node = node or typ.node
    local func_expr = typ.node

    typ.called = true

    if func_expr and func_expr.kind == "function" then
        --lua function

        do -- recursive guard
            if self.calling_function == typ then
                return {self:TypeFromImplicitNode(node, "any")}
            end
            self.calling_function = typ
        end

        local ret

        do
            self:PushScope(typ.node)

            local identifiers = {}

            for i,v in ipairs(typ.node.identifiers) do
                identifiers[i] = v
            end

            if typ.node.self_call then
                table.insert(identifiers, 1, "self")
            end

            for i, identifier in ipairs(identifiers) do
                local node = identifier == "self" and typ.node or identifier
                local arg = arguments[i] or self:TypeFromImplicitNode(node, "nil")

                if identifier == "self" or identifier.value.value ~= "..." then
                    self:DeclareUpvalue(identifier, arg, "runtime")
                else
                    local values = {}
                    for i = i, #arguments do
                        table.insert(values, arguments[i] or self:TypeFromImplicitNode(node, "nil"))
                    end
                    self:DeclareUpvalue(identifier, self:TypeFromNode(node, values), "runtime")
                end
            end

            if typ.node.return_types then
                ret = self:CrawlExpressions(typ.node.return_types, "typesystem")
            else
                ret = {}
            end

            -- collect return values from function statements
            self:CrawlStatements(typ.node.statements, ret)

            self:PopScope()

            typ.ret = merge_types(typ.ret, ret)
            typ.arguments = merge_types(typ.arguments, arguments)

            for i,v in ipairs(typ.ret) do
                -- ERROR HERE
                if ret[i] == nil then
                    ret[i] = v
                end
            end

            for i, v in ipairs(typ.arguments) do
                if typ.node.identifiers[i] then
                    typ.node.identifiers[i].inferred_type = v
                end
            end

            self:FireEvent("function_spec", typ)
        end

        self.calling_function = nil

        return ret
    elseif typ:IsType("function") and typ.ret then
        --external

        self:FireEvent("external_call", node, typ)

        -- HACKS
        typ.crawler = self
        typ.node = node

        return types.CallFunction(typ, arguments)
    end
    -- calling something that has no type and does not exist
    -- expressions assumed to be crawled from caller

    return {self:TypeFromImplicitNode(node, "any")}
end

function META:Error(node, msg)
    if self.code then
        local print_util = require("oh.print_util")
        local start, stop = print_util.LazyFindStartStop(node)
        print(print_util.FormatError(self.code, self.name, msg, start, stop))
    else
        local s = tostring(self)
        s = s .. ": " .. msg

        error(s)
    end
end

do
    local guesses = {
        {pattern = "count", type = "number"},
        {pattern = "tbl", type = "table"},
        {pattern = "str", type = "string"},
    }

    table.sort(guesses, function(a, b) return #a.pattern > #b.pattern end)

    function META:GetInferredType(node)
        if node.type_expression then
            return self:CrawlExpression(node.type_expression, "typesystem")
        end

        local str = node.value and node.value.value

        if str then
            str = str:lower()
            for i, v in ipairs(guesses) do
                if str:find(v.pattern) then
                    return self:TypeFromImplicitNode(node, v.type)
                end
            end
        end

        return self:TypeFromImplicitNode(node, "any")
    end
end

local evaluate_expression

function META:CrawlStatement(statement, ...)
    if statement.kind == "root" then
        self:PushScope(statement)
        if self:CrawlStatements(statement.statements, ...) == true then
            return true
        end
        self:PopScope()
        if self.deferred_calls then
            for i,v in ipairs(self.deferred_calls) do
                if not v[1].called then
                    self:CallFunctionType(unpack(v))
                end
            end
        end
    elseif
        statement.kind == "assignment" or
        statement.kind == "local_assignment" or

        statement.kind == "type_assignment" or
        statement.kind == "local_type_assignment"
    then
        local env = (statement.kind == "type_assignment" or statement.kind == "local_type_assignment") and "typesystem" or "runtime"
        local ret = self:UnpackExpressions(statement.right, env)

        for i, node in ipairs(statement.left) do
            local val

            if node.type_expression then
                val = self:CrawlExpression(node.type_expression, "typesystem")
                if ret[i] and not ret[i]:IsType(val) then
                    self:Error(node, "expected " .. tostring(val) .. " but the right hand side is a " .. tostring(ret[i]))
                end
            else
                val = ret[i]
            end


            if statement.kind == "local_assignment" then
                self:DeclareUpvalue(node, val, "runtime")
            elseif statement.kind == "assignment" then
                self:Assign(node, val, "runtime")

            elseif statement.kind == "type_assignment" then
                self:Assign(node, val, "typesystem")
            elseif statement.kind == "local_type_assignment" then
                self:DeclareUpvalue(node, val, "typesystem")
            end

            node.inferred_type = val
        end
    elseif statement.kind == "function" then
        self:Assign(statement.expression, self:CrawlExpression(statement:ToExpression("function")), "runtime")

        if statement.return_types then
            statement.inferred_return_types = self:CrawlExpressions(statement.return_types, "typesystem")
        end
    elseif statement.kind == "local_function" then
        self:DeclareUpvalue(statement.identifier, self:CrawlExpression(statement:ToExpression("function")), "runtime")
    elseif statement.kind == "local_type_function" then
        self:DeclareUpvalue(statement.identifier, self:CrawlExpression(statement:ToExpression("function")), "typesystem")
    elseif statement.kind == "if" then
        for i, statements in ipairs(statement.statements) do
            local b = not statement.expressions[i] or (self:CrawlExpression(statement.expressions[i], "runtime") or self:TypeFromImplicitNode(statement.expressions[i], "any"))

            if b:IsType("nil") then
                b = types.Fuse(b, self:TypeFromImplicitNode(statement.expressions[i], "any"))
            end

            if b == true or b:IsTruthy() or b == nil then
                self:PushScope(statement, statement.tokens["if/else/elseif"][i])

                if b ~= true then
                    b.truthy = (b.truthy or 0) + 1
                end

                if self:CrawlStatements(statements, ...) == true then
                    self:PopScope()
                    if type(b) == "table" and b.value == true then
                        return true
                    end
                end

                if b ~= true then
                    b.truthy = (b.truthy or 0) - 1
                end

                self:PopScope()
                break
            end
        end
    elseif statement.kind == "while" then
        if self:CrawlExpression(statement.expression):IsTruthy() then
            self:PushScope(statement)
            if self:CrawlStatements(statement.statements, ...) == true then
                return true
            end
            self:PopScope()
        end
    elseif statement.kind == "do" then
        self:PushScope(statement)
        if self:CrawlStatements(statement.statements, ...) == true then
            return true
        end
        self:PopScope()
    elseif statement.kind == "repeat" then
        self:PushScope(statement)
        if self:CrawlStatements(statement.statements, ...) == true then
            return true
        end
        if self:CrawlExpression(statement.expression):IsTruthy() then
            self:FireEvent("break")
        end
        self:PopScope()
    elseif statement.kind == "return" then
        local return_values = ...

        local evaluated = {}
        for i,v in ipairs(statement.expressions) do
            evaluated[i] = self:CrawlExpression(v)

            if return_values then
                table.insert(return_values, evaluated[i])
            end
        end

        self:FireEvent("return", evaluated)

        self.last_return = evaluated

        return true
    elseif statement.kind == "break" then
        self:FireEvent("break")

        --return true
    elseif statement.kind == "call_expression" then
        self:FireEvent("call", statement.value, {self:CrawlExpression(statement.value)})
    elseif statement.kind == "generic_for" then
        self:PushScope(statement)

        if statement.expressions[1].kind ~= "postfix_call" then
            local copy = {
                kind = "postfix_call",
                expressions = {unpack(statement.expressions, 2)},
                left = statement.expressions[1],
                tokens = {},
            }

            setmetatable(copy, getmetatable(statement.expressions[1]))

            args = {self:CrawlExpression(copy)}
        else
            args = {self:CrawlExpression(statement.expressions[1])}
        end

        local ret = self:CallFunctionType(args[1], {unpack(args, 2)}, statement.expressions[1])

        for i,v in ipairs(statement.identifiers) do
            self:DeclareUpvalue(v, ret and ret[i], "runtime")
        end

        if self:CrawlStatements(statement.statements, ...) == true then
            return true
        end

        self:PopScope()
    elseif statement.kind == "numeric_for" then
        self:PushScope(statement)
        local range = self:CrawlExpression(statement.expressions[1]):Max(self:CrawlExpression(statement.expressions[2]))
        self:DeclareUpvalue(statement.identifiers[1], range, "runtime")

        if statement.expressions[3] then
            self:CrawlExpression(statement.expressions[3])
        end

        if self:CrawlStatements(statement.statements, ...) == true then
            self:PopScope()
            return true
        end
        self:PopScope()
    elseif statement.kind == "local_type_assignment" then
        self:DeclareUpvalue(statement.left, self:CrawlExpression(statement.right, "typesystem"), "typesystem")
    elseif statement.kind == "type_assignment" then
        self:Assign(statement.left, self:CrawlExpression(statement.right, "typesystem"), "typesystem")
    elseif statement.kind == "type_interface" then
        local tbl = self:GetValue(statement.key, "typesystem")

        if tbl then
        else
            tbl = self:TypeFromImplicitNode(statement, "table")
        end

        for i,v in ipairs(statement.expressions) do
            local val = self:CrawlExpression(v.right, "typesystem")
            if tbl.value[v.left.value] then
                types.OverloadFunction(tbl:get(v.left.value), val)
            else
                tbl:set(v.left.value, self:CrawlExpression(v.right, "typesystem"))
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
        if node.kind == "value" then
            if node.type_expression then
                local val = self:CrawlExpression(node.type_expression, "typesystem")

                stack:Push(val)
                if node.tokens["is"] then
                    node.result_is = self:GetValue(node, env):IsType(val)
                end
            elseif
                (node.value.type == "letter" and node.upvalue_or_global) or
                node.value.value == "..."
            then
                local val

                if env == "typesystem" and types.IsType(self:Hash(node)) and not node.force_upvalue then
                    val = self:TypeFromImplicitNode(node, node.value.value)
                else
                    val = self:GetValue(node, env)

                    if env == "runtime" and not val then
                        val = self:GetValue(node, "typesystem")
                    end
                end

                if type(val) == "table" and val.truthy and val.truthy > 0 then
                    local copy = val:Copy()
                    copy:RemoveNonTruthy()
                    val = copy
                end

                if not val then
                    val = self:GetInferredType(node)
                end

                stack:Push(val or self:TypeFromImplicitNode(node, "any"))
            elseif
                node.value.type == "number" or
                node.value.type == "string" or
                node.value.type == "letter" or
                node.value.value == "nil" or
                node.value.value == "true" or
                node.value.value == "false" or
                (env == "typesystem" and node.value.value == "function")
            then
                stack:Push(self:TypeFromNode(node))
            else
                error("unhandled value type " .. node.value.type .. " " .. node:Render())
            end
        elseif node.kind == "function" then
            local args = {}
            for i, key in ipairs(node.identifiers) do
                local val = self:GetInferredType(key)

                if val then
                    table.insert(args, val)
                end
            end

            if node.self_call and node.expression then
                local val = self:GetUpvalue(node.expression.left, "runtime")

                if val and val.key.type_expression then
                    table.insert(args, 1, val.data)
                end
            end

            local ret = {}
            if node.type_expressions then
                for i, type_exp in ipairs(node.type_expressions) do
                    ret[i] = self:CrawlExpression(type_exp, "typesystem")
                end
            end
            local t = self:TypeFromImplicitNode(node, "function", ret, args)

            self:CallMeLater(t, args, node)

            stack:Push(t)
        elseif node.kind == "table" then
            stack:Push(self:TypeFromNode(node))
        elseif node.kind == "binary_operator" then
            local r, l = stack:Pop(), stack:Pop()
            local op = node.value.value

            if op == ":" then
                stack:Push(l)
            end

            stack:Push(r:BinaryOperator(op, l, node, env))
        elseif node.kind == "prefix_operator" then
            local r = stack:Pop()
            local op = node.value.value

            stack:Push(r:PrefixOperator(op, node, env))
        elseif node.kind == "postfix_operator" then
            local r = stack:Pop()
            local op = node.value.value

            stack:Push(r:PostfixOperator(op, node, env))
        elseif node.kind == "postfix_expression_index" then
            local r = stack:Pop()
            local index = self:CrawlExpression(node.expression)

            stack:Push(r:get(index))
        elseif node.kind == "type_function" then
            local args = {}
            local rets = {}
            local func

            -- declaration

            if node.identifiers then
                for i,v in ipairs(node.identifiers) do
                    args[i] = self:CrawlExpression(v, "typesystem")
                end
            end

            if node.return_expressions then
                for i,v in ipairs(node.return_expressions) do
                    rets[i] = self:CrawlExpression(v, "typesystem")
                end
            end

            if node.statements then
                local str = "local oh, crawler, types = ...; return " .. node:Render({})
                local f, err = loadstring(str, "")
                if not f then
                    -- this should never happen unless node:Render() produces bad code or the parser didn't catch any errors
                    print(str)
                    error(err)
                end
                func = f(require("oh"), self, types)
            end

            stack:Push(types.Type("function", rets, args, func))
        elseif node.kind == "postfix_call" then
            local typ = stack:Pop()

            local arguments = self:CrawlExpressions(node.expressions, env)

            if node.self_call then
                local val = stack:Pop()
                table.insert(arguments, 1, val)
            end

            for i,v in ipairs(self:CallFunctionType(typ, arguments, node)) do
                stack:Push(v)
            end

        elseif node.kind == "type_list" then
            local tbl = {}
            if node.types then
                for i,v in ipairs(node.types)do
                    tbl[i] = self:CrawlExpression(v, env)
                end
            end
            local val = types.Type("list", tbl, node.length and tonumber(node.length.value))
            val.value = {}
            stack:Push(val)
        elseif node.kind == "type_table" then
            local t = types.Type("table")

            table_to_types(self, node, t.value, env)

            stack:Push(t)
        else
            error("unhandled expression " .. node.kind)
        end
    end

    do
        local meta = {}
        meta.__index = meta

        function meta:Push(val)
            assert(types.IsTypeObject(val))
            self.values[self.i] = val
            self.i = self.i + 1
        end

        function meta:Pop()
            self.i = self.i - 1
            if self.i < 1 then error("stack underflow", 2) end
            local val = self.values[self.i]
            self.values[self.i] = nil
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

        function META:CrawlExpression(exp, env)
            assert(exp and exp.type == "expression")
            env = env or "runtime"
            local stack = setmetatable({values = {}, i = 1}, meta)
            expand(self, exp, evaluate_expression, stack, env)
            return unpack(stack.values)
        end

        function META:CrawlExpressions(expressions, ...)
            if not expressions then return end
            local ret = {}
            for i, expression in ipairs(expressions) do
                ret[i] = self:CrawlExpression(expression, ...)
            end
            return ret
        end
    end
end

return function()
    return setmetatable({env = {runtime = {}, typesystem = {}}}, META)
end
