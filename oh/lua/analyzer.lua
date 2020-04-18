
local syntax = require("oh.lua.syntax")
local types = require("oh.typesystem.types")
types.Initialize()

local META = {}
META.__index = META

local table_insert = table.insert

local function binary_operator(op, l, r, env)
    assert(types.IsTypeObject(l))
    assert(types.IsTypeObject(r))

    if l[op] and r[op] then
        local ret = l[op](l, r, env)
        if not ret then
            error("operator " .. op .. " on " .. tostring(l) .. " does not return anything")
        end
        return ret
    end

    if env == "typesystem" then
        if op == "|" then
            return types.Set:new({l, r})
        end

        if op == "extends" then
            return l:Extend(r)
        end

        if op == ".." then
            local new = l:Copy()
            new.max = r
            return new
        end
    end

    if syntax.CompiledBinaryOperatorFunctions[op] and l.data ~= nil and r.data ~= nil then

        if l.type ~= r.type then
            return false, "no operator for " .. tostring(l.type or l) .. " " .. op .. " " .. tostring(r.type or r)
        end

        local lval = l.data
        local rval = r.data
        local type = l.type

        if l.Type == "tuple" then
            lval = l.data[1].data
            type = l.data[1].type
        end

        if r.Type == "tuple" then
            rval = r.data[1].data
        end

        local ok, res = pcall(syntax.CompiledBinaryOperatorFunctions[op], rval, lval)

        if not ok then
            return false, res
        else
            return types.Object:new(type, res)
        end
    end

    if l.type == r.type then
        return types.Object:new(l.type)
    end

    if l.type == "any" or r.type == "any" then
        return types.Object:new("any")
    end

    error(" NYI " .. env .. ": "..tostring(l).." "..op.. " "..tostring(r))
end

local function __new_index(obj, key, val, env)
    if obj.Type ~= "dictionary" then
        return false, "undefined set: " .. tostring(obj) .. "[" .. tostring(key) .. "] = " .. tostring(val)
    end

    return obj:Set(key, val, env)
end


local function __index(obj, key)
    if obj.Type ~= "dictionary" and obj.Type ~= "tuple" and (obj.Type ~= "object" or obj.type ~= "string") then
        return false, "undefined get: " .. tostring(obj) .. "[" .. tostring(key) .. "]"
    end

    return obj:Get(key)
end


do -- types
    function META:TypeFromImplicitNode(node, name, data, const)
        node.scope = self.scope -- move this out of here

        local obj = types.Create(name, data, const)

        if not obj then error("NYI: " .. name) end

        if name == "string" then
            local string_meta = types.Create("table", {})
            string_meta:Set("__index", self.IndexNotFound and self:IndexNotFound("string") or self:GetValue("string", "typesystem"))
            obj.meta = string_meta
        end

        obj.node = node
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
        function META:Call(obj, arguments, node, deferred)
            node = node or obj.node

            -- for deferred calls
            obj.called = true

            -- diregard arguments and use function's arguments in case they have been maniupulated (ie string.gsub)
            if deferred then
                arguments = obj:GetArguments()
            end

            --lua function
            if obj.node and (obj.node.kind == "function" or obj.node.kind == "local_function") then

                do -- recursive guard
                    if self.calling_function == obj then
                        return (obj:GetReturnTypes() and obj:GetReturnTypes().data and obj:GetReturnTypes().data[1]) or {self:TypeFromImplicitNode(node, "any")}
                    end
                    self.calling_function = obj
                end

                local return_tuple = self:Assert(obj.node, obj:Call(arguments))

                self:PushScope(obj.node)

                    if obj.node.self_call then
                        self:SetUpvalue("self", arguments.data[1] or self:TypeFromImplicitNode(obj.node, "nil"), "runtime")
                    end

                    for i, identifier in ipairs(obj.node.identifiers) do
                        local argi = obj.node.self_call and (i+1) or i

                        if identifier.value.value == "..." then
                            local values = {}
                            for i = argi, arguments:GetLength() do
                                table.insert(values, arguments.data[i])
                            end
                            self:SetUpvalue(identifier, self:TypeFromImplicitNode(identifier, "...", values), "runtime")
                        else
                            self:SetUpvalue(identifier, arguments.data[argi] or self:TypeFromImplicitNode(identifier, "nil"), "runtime")
                        end
                    end


                    types.collected_return_tuples = {}
                    local ret = types.collected_return_tuples

                    -- crawl and collect return values from function statements
                    self:AnalyzeStatements(obj.node.statements)

                    types.collected_return_tuples = nil

                self:PopScope()

                local ret_tuple = types.Tuple:new(ret)

                -- if this function has an explicit return type
                if obj.node.return_types then
                    if not ret_tuple:SupersetOf(return_tuple) then
                        self:Error(obj.node, "expected return " .. tostring(return_tuple) .. " to be a superset of " .. tostring(ret_tuple))
                    end
                else
                    obj:GetReturnTypes():Merge(ret_tuple)
                end

                obj:GetArguments():Merge(arguments)

                for i, v in ipairs(obj:GetArguments().data) do
                    if obj.node.identifiers[i] then
                        obj.node.identifiers[i].inferred_type = v
                    end
                end

                obj.node.inferred_type = obj

                self:FireEvent("function_spec", obj)

                self.calling_function = nil

                if not ret[1] then
                    -- if this is called from CallMeLater we cannot create a nil type from node
                    local old = node.inferred_type
                    ret[1] = self:TypeFromImplicitNode(node, "nil")
                    node.inferred_type = old
                end

                return ret
            elseif obj.Call then
                self:FireEvent("external_call", node, obj)

                local return_tuple, err = obj:Call(arguments)

                if return_tuple == false then
                    self:Error(obj.node, err)
                end

                return return_tuple.data
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

        if type(node.value) == "string" then
            return node.value
        end

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

    function META:SetUpvalue(key, val, env)
        assert(val == nil or types.IsTypeObject(val))

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

    function META:GetValue(key, env)
        local upvalue = self:GetUpvalue(key, env)

        if upvalue then
            return upvalue.data
        end

        return self.env[env][self:Hash(key)]
    end

    function META:SetValue(key, val, env)
        assert(val == nil or types.IsTypeObject(val))

        if type(key) == "string" or key.kind == "value" then
            -- local key = val; key = val

            local upvalue = self:GetUpvalue(key, env)
            if upvalue then
                upvalue.data = val
                self:FireEvent("mutate_upvalue", key, val, env)
            else
                -- key = val
                self.env[env][self:Hash(key)] = val
                self:FireEvent("set_global", key, val, env)
            end
        else
            local obj = self:AnalyzeExpression(key.left, env)
            local key = key.kind == "postfix_expression_index" and self:AnalyzeExpression(key.expression, env) or self:AnalyzeExpression(key.right, env)

            self:Assert(key.node, __new_index(obj, key, val, env))
            self:FireEvent("newindex", obj, key, val, env)
        end
    end

    function META:SetObjectKeyValue(obj, key, val, env)
        assert(val == nil or types.IsTypeObject(val))

        self:Assert(key.node, __new_index(obj, key, val, env))
        self:FireEvent("newindex", obj, key, val, env)
    end
end

function META:FireEvent(what, ...)
    if self.suppress_events then return end

    if self.OnEvent then
        self:OnEvent(what, ...)
    end
end

function META:AnalyzeStatements(statements)
    for _, val in ipairs(statements) do
        if self:AnalyzeStatement(val) == true then
            return true
        end
    end
end

function META:CallMeLater(...)
    self.deferred_calls = self.deferred_calls or {}
    table.insert(self.deferred_calls, 1, {...})
end

function META:Assert(node, ok, err)
    if ok == false then
        err = err or "unknown error"
        self:Error(node, err)
        return self:TypeFromImplicitNode(node, "any")
    end
    return ok
end

local utl = require("oh.pri".."nt_util")

function META:Error(node, msg)
    if not node then
        io.write("invalid error, no node supplied\n")
        print(debug.traceback())
        error(msg)
    end

    if require("oh").current_analyzer and require("oh").current_analyzer ~= self then
        return require("oh").current_analyzer:Error(node, msg)
    end

    if self.OnError then
        self:OnError(msg, utl.LazyFindStartStop(node))
    end

    if self.code then
        local start, stop = utl.LazyFindStartStop(node)
        io.write(utl.FormatError(self.code, self.type, msg, start, stop), "\n")
    else
        local s = tostring(self)
        s = s .. ": " .. msg

        io.write(s, "\n")
    end
end

function META:AnalyzeStatement(statement)
    self.current_statement = statement

    if statement.kind == "root" then
        self:PushScope(statement)
        local ret
        if self:AnalyzeStatements(statement.statements) == true then
            ret = true
        end
        self:PopScope()
        if self.deferred_calls then
            for _,v in ipairs(self.deferred_calls) do
                if not v[1].called then
                    self:Call(unpack(v))
                end
            end
        end
        return ret
    elseif statement.kind == "assignment" or statement.kind == "local_assignment" then
        local env = statement.environment or "runtime"
        local assignments = {}

        for i, exp_key in ipairs(statement.left) do
            if statement.kind == "local_assignment" then
                assignments[i] = {
                    key = exp_key,
                    env = env,
                }
            elseif statement.kind == "assignment" then
                if type(exp_key) == "string" or exp_key.kind == "value" then
                    assignments[i] = {
                        key = exp_key,
                        env = env,
                    }
                else
                    local obj = self:AnalyzeExpression(exp_key.left, env)
                    local key = exp_key.kind == "postfix_expression_index" and self:AnalyzeExpression(exp_key.expression, env) or self:AnalyzeExpression(exp_key.right, env)

                    assignments[i] = {
                        obj = obj,
                        key = key,
                    }
                end
            end
        end

        local values = {}

        if statement.right then
            for _, exp in ipairs(statement.right) do
                for _, obj in ipairs({self:AnalyzeExpression(exp, env)}) do

                    -- unpack
                    if obj.Type == "tuple" then -- vararg
                        for _, obj in ipairs(obj.data) do
                            table.insert(values, obj)
                        end
                    end

                    table.insert(values, obj)
                end
            end
        end

        for i, exp_key in ipairs(statement.left) do
            local val = values[i] or self:TypeFromImplicitNode(exp_key, "nil")

            local key = assignments[i].key
            local obj = assignments[i].obj


            -- if there's a type expression override the right value
            if exp_key.type_expression then
                local left = self:AnalyzeExpression(exp_key.type_expression, "typesystem")

                if statement.right and statement.right[i] then
                    if not val:SupersetOf(left) then
                        self:Error(val.node, "expected " .. tostring(left) .. " but the right hand side is " .. tostring(right))
                    end

                    -- local a: 1 = 1
                    -- should turn the right side into a constant number rather than number(1)
                    val.const = left:IsConst()
                end

                -- lock the dictionary if there's an explicit type annotation
                if left.Type == "dictionary" then
                    left.locked = true
                end

                val = left
            else
                val.const = false
            end

            exp_key.inferred_type = val

            if statement.kind == "local_assignment" then
                self:SetUpvalue(key, val, env)
            elseif statement.kind == "assignment" then
                if type(exp_key) == "string" or exp_key.kind == "value" then
                    self:SetValue(key, val, env)
                else
                    self:Assert(exp_key, __new_index(obj, key, val, env))
                    self:FireEvent("newindex", obj, key, val, env)
                end
            end
        end
--[[
        if statement.right then
            for _, exp in ipairs(statement.right) do
                for _, obj in ipairs({self:AnalyzeExpression(exp, env)}) do

                    -- unpack
                    if obj.Type == "tuple" then -- vararg
                        for _, obj in ipairs(obj.data) do
                            table.insert(values, obj)
                        end
                    end

                    table.insert(values, obj)
                end
            end
        end

        for i, node in ipairs(statement.left) do
            local left = values[i]
            local right = values[i]

            if node.type_expression then
                left = self:AnalyzeExpression(node.type_expression, "typesystem")

                if right then
                    if not right:SupersetOf(left) then
                        self:Error(right.node, "expected " .. tostring(left) .. " but the right hand side is " .. tostring(right))
                    end

                    -- local a: 1 = 1
                    -- should turn the right side into a constant number rather than number(1)
                    right.const = left:IsConst()
                end

                -- lock the dictionary if there's an explicit type annotation
                if left.Type == "dictionary" then
                    left.locked = true
                end
            elseif left then
                left.const = false
            end

            if statement.kind == "local_assignment" then
                self:SetUpvalue(node, left or self:TypeFromImplicitNode(node, "nil"), env)
            elseif statement.kind == "assignment" then
                self:SetValue(node, left or self:TypeFromImplicitNode(node, "nil"), env)
            end

            node.inferred_type = left
        end

]]

    elseif statement.kind == "destructure_assignment" or statement.kind == "local_destructure_assignment" then
        local env = statement.environment or "runtime"
        local obj = self:AnalyzeExpression(statement.right, env)

        if obj.Type ~= "dictionary" then
            self:Error(statement.right, "expected a table on the right hand side, got " .. tostring(obj))
        end

        if statement.default then
            if statement.kind == "local_destructure_assignment" then
                self:SetUpvalue(statement.default, obj, env)
            elseif statement.kind == "destructure_assignment" then
                self:SetValue(statement.default, obj, env)
            end
        end

        for _, node in ipairs(statement.left) do
            local obj = node.value and obj:Get(node.value.value, env) or self:TypeFromImplicitNode(node, "nil")

            if statement.kind == "local_destructure_assignment" then
                self:SetUpvalue(node, obj, env)
            elseif statement.kind == "destructure_assignment" then
                self:SetValue(node, obj, env)
            end
        end
    elseif statement.kind == "function" then
        self:SetValue(statement.expression, self:AnalyzeFunction(statement), "runtime")
    elseif statement.kind == "local_function" then
        self:SetUpvalue(statement.tokens["identifier"], self:AnalyzeFunction(statement), "runtime")
    elseif statement.kind == "local_type_function" then
        self:SetUpvalue(statement.identifier, self:AnalyzeFunction(statement), "typesystem")
    elseif statement.kind == "if" then
        for i, statements in ipairs(statement.statements) do
            if not statement.expressions[i] then
                self:PushScope(statement, statement.tokens["if/else/elseif"][i])
                self:AnalyzeStatements(statements)
                self:PopScope()
                break
            else
                local obj = self:AnalyzeExpression(statement.expressions[i], "runtime")

                if obj:IsTruthy() then
                    self:PushScope(statement, statement.tokens["if/else/elseif"][i])
                    obj:PushTruthy()

                    if self:AnalyzeStatements(statements) == true then
                        if obj.data == true then
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
            if self:AnalyzeStatements(statement.statements) == true then
                return true
            end
            self:PopScope()
        end
    elseif statement.kind == "do" then
        self:PushScope(statement)
        if self:AnalyzeStatements(statement.statements) == true then
            return true
        end
        self:PopScope()
    elseif statement.kind == "repeat" then
        self:PushScope(statement)
        if self:AnalyzeStatements(statement.statements) == true then
            return true
        end
        if self:AnalyzeExpression(statement.expression):IsTruthy() then
            self:FireEvent("break")
        end
        self:PopScope()
    elseif statement.kind == "return" then
        local return_values = types.collected_return_tuples

        local evaluated = {}
        for i,v in ipairs(statement.expressions) do
            evaluated[i] = self:AnalyzeExpression(v)

            -- add the return values
            if return_values then
                return_values[i] = return_values[i] and types.Union(return_values[i], evaluated[i]) or evaluated[i]
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
        local obj = args[1]

        if obj then
            table.remove(args, 1)
            local values = self:Call(obj, types.Tuple:new(args), statement.expressions[1])

            for i,v in ipairs(statement.identifiers) do
                self:SetUpvalue(v, values[i], "runtime")
            end
        end

        if self:AnalyzeStatements(statement.statements) == true then
            return true
        end

        self:PopScope()
    elseif statement.kind == "numeric_for" then
        self:PushScope(statement)
        local range = self:AnalyzeExpression(statement.expressions[1]):Max(self:AnalyzeExpression(statement.expressions[2]))
        self:SetUpvalue(statement.identifiers[1], range, "runtime")

        if statement.expressions[3] then
            self:AnalyzeExpression(statement.expressions[3])
        end

        if self:AnalyzeStatements(statement.statements) == true then
            self:PopScope()
            return true
        end
        self:PopScope()
    elseif statement.kind == "type_interface" then
        local tbl = self:GetValue(statement.key, "typesystem") or self:TypeFromImplicitNode(statement, "table", {})

        for _, exp in ipairs(statement.expressions) do
            local left = tbl:Get(exp.left.value)
            local right = self:AnalyzeExpression(exp.right, "typesystem")

            -- function overload shortcut
            if left and left.Type == "object" and left.type == "function" then
                tbl:Set(exp.left.value, types.Set:new({left, right}))
            elseif left and left.Type == "set" then
                left:AddElement(right)
            else
                tbl:Set(exp.left.value, right)
            end
        end

        self:SetUpvalue(statement.key, tbl, "typesystem")
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
    do
        local meta = {}
        meta.__index = meta

        local function Stack()
            return setmetatable({values = {}, i = 1}, meta)
        end

        function meta:Push(val)
            if val[1] then
                for _,v in ipairs(val) do
                    assert(types.IsTypeObject(v))
                end
            else
                assert(types.IsTypeObject(val))
            end

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
                assert(types.IsTypeObject(val[1]))
                return val[1], val
            end

            self.last_val = val

            assert(types.IsTypeObject(val))

            return val
        end

        function meta:Unpack()
            local out = {}

            for _,v in ipairs(self.values) do
                if v[1] then
                    for _,v in ipairs(v) do
                        table.insert(out, v)
                    end
                else
                    table.insert(out, v)
                end
            end

            return unpack(out)
        end

        local function expand(exp, out)
            out = out or {}

            if exp.left then
                expand(exp.left, out)
            end

            if exp.right then
                expand(exp.right, out)
            end

            table.insert(out, exp)

            return out
        end

        function META:AnalyzeExpression(exp, env)
            assert(exp and exp.type == "expression")
            env = env or "runtime"
            local stack = Stack()

            for _, node in ipairs(expand(exp)) do
                self.current_expression = node

                if node.type_expression then
                    local val = self:AnalyzeExpression(node.type_expression, "typesystem")
                    stack:Push(val)
                    if node.tokens["is"] then
                        node.result_is = self:GetValue(node, env):IsType(val)
                    end
                elseif node.kind == "value" then
                    if (node.value.type == "letter" and node.upvalue_or_global) or node.value.value == "..." then
                        local obj

                        -- if it's ^string, number, etc, but not string
                        if env == "typesystem" and types.IsPrimitiveType(self:Hash(node)) and not node.force_upvalue then
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

                        if not obj and self.IndexNotFound then
                            obj = self:IndexNotFound(node)
                        end

                        -- last resort, itemCount > number
                        if not obj then
                            obj = self:GetInferredType(node)
                        end

                        stack:Push(obj)
                    elseif node.value.type == "number" then
                        stack:Push(self:TypeFromImplicitNode(node, "number", tonumber(node.value.value), true))
                    elseif node.value.type == "string" then
                        stack:Push(self:TypeFromImplicitNode(node, "string", node.value.value:sub(2, -2), true))
                    elseif node.value.type == "letter" then
                        stack:Push(self:TypeFromImplicitNode(node, "string", node.value.value, true))
                    elseif node.value.value == "nil" then
                        stack:Push(self:TypeFromImplicitNode(node, "nil", env == "typesystem"))
                    elseif node.value.value == "true" then
                        stack:Push(self:TypeFromImplicitNode(node, "boolean", true, true))
                    elseif node.value.value == "false" then
                        stack:Push(self:TypeFromImplicitNode(node, "boolean", false, true))
                    else
                        error("unhandled value type " .. node.value.type .. " " .. node:Render())
                    end
                elseif node.kind == "function" then
                    stack:Push(self:AnalyzeFunction(node))
                elseif node.kind == "table" then
                    stack:Push(self:TypeFromImplicitNode(node, "table", self:AnalyzeTable(node, env)))
                elseif node.kind == "binary_operator" then
                    local right, left = stack:Pop(), stack:Pop()

                    if node.value.value == ":" then
                        stack:Push(left)
                    end

                    if node.value.value == "." or node.value.value == ":" then
                        stack:Push(self:Assert(left.node, __index(left, right)) or self:TypeFromImplicitNode(left.node, "nil"))
                    else
                        local val, err = binary_operator(node.value.value, left, right, env)
                        if not val and not err then
                            print(node:Render(), right, node.value.value, left, env)
                            print(left.type, right.type)
                            print(val, err)
                            error("wtf")
                        end
                        stack:Push(self:Assert(node, val, err))
                    end
                elseif node.kind == "prefix_operator" then
                    stack:Push(self:Assert(node, stack:Pop():PrefixOperator(node.value.value, self:AnalyzeExpression(node.right))))
                elseif node.kind == "postfix_operator" then
                    stack:Push(stack:Pop():PostfixOperator(node))
                elseif node.kind == "postfix_expression_index" then
                    local obj = stack:Pop()
                    stack:Push(self:Assert(obj.node, __index(obj, self:AnalyzeExpression(node.expression))) or self:TypeFromImplicitNode(obj.node, "nil"))
                elseif node.kind == "type_function" then
                    local args = {}
                    local rets = {}
                    local func

                    -- declaration
                    if node.identifiers then
                        for i, key in ipairs(node.identifiers) do
                            if key.kind == "value" and key.value.value == "..." then
                                args[i] = self:TypeFromImplicitNode(key, "...", {self:TypeFromImplicitNode(key, "any")})
                                args[i].max = math.huge
                            else
                                args[i] = self:GetValue(key.left or key, env) or (types.IsPrimitiveType(key.value.value) and self:TypeFromImplicitNode(node, key.value.value)) or self:GetInferredType(key)
                            end
                        end
                    end

                    if node.return_expressions then
                        for i,v in ipairs(node.return_expressions) do
                            rets[i] = self:AnalyzeExpression(v, env)
                        end
                    end

                    if node.statements then
                        local str = "local oh, analyzer, types, node = ...; return " .. node:Render({})
                        local load_func, err = loadstring(str, "")
                        if not load_func then
                            -- this should never happen unless node:Render() produces bad code or the parser didn't catch any errors
                            io.write(str, "\n")
                            error(err)
                        end
                        func = load_func(require("oh"), self, types, node)
                    end


                    args = types.Tuple:new(args)
                    rets = types.Tuple:new(rets)

                    stack:Push(self:TypeFromImplicitNode(node, "function", {
                        arg = args,
                        ret = rets,
                        lua_function = func
                    }))
                elseif node.kind == "postfix_call" then
                    local obj = stack:Pop()

                    local arguments = self:AnalyzeExpressions(node.expressions, env)

                    if node.self_call then
                        local val = stack:Pop()
                        table.insert(arguments, 1, val)
                    end

                    if obj.type and obj.type ~= "function" and obj.type ~= "table" and obj.type ~= "any" then
                        self:Error(node, tostring(obj) .. " cannot be called")
                    else
                        stack:Push(self:Call(obj, types.Tuple:new(arguments), node))
                    end
                elseif node.kind == "type_list" then
                    local tbl = {}

                    if node.types then
                        for i, exp in ipairs(node.types)do
                            tbl[i] = self:AnalyzeExpression(exp, env)
                        end
                    end

                    -- number[3] << tbl only contains {3}.. hmm
                    stack:Push(self:TypeFromImplicitNode(node, "list", {length = nil, values = tbl}))
                elseif node.kind == "type_table" then
                    local obj = self:TypeFromImplicitNode(node, "table")

                    self.current_table = obj
                    for _, v in ipairs(self:AnalyzeTable(node, env)) do
                        obj:Set(v.key, v.val)
                    end
                    self.current_table = nil

                    stack:Push(obj)
                elseif node.kind == "import" or node.kind == "lsx" then
                    --stack:Push(self:AnalyzeStatement(node.root))
                else
                    error("unhandled expression " .. node.kind)
                end
            end

            return stack:Unpack()
        end

        function META:AnalyzeExpressions(expressions, ...)
            if not expressions then return end
            local out = {}
            for _, expression in ipairs(expressions) do
                local ret = {self:AnalyzeExpression(expression, ...)}
                for _,v in ipairs(ret) do
                    table.insert(out, v)
                end
            end
            return out
        end

        function META:AnalyzeFunction(node)
            local args = {}

            for i, key in ipairs(node.identifiers) do
                -- if this node is already explicitly annotated with foo: mytype or foo as mytype use that
                if key.type_expression then
                    args[i] = self:AnalyzeExpression(key.type_expression, "typesystem") or self:GetInferredType(key)
                else
                    if key.value.value == "..." then
                        args[i] = self:TypeFromImplicitNode(key, "...", {self:TypeFromImplicitNode(key, "any")})
                        args[i].max = math.huge
                    else
                        args[i] = self:GetInferredType(key)
                    end
                    args[i].volatile = true
                end
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
            else
                --ret[1] = self:TypeFromImplicitNode(node, "any")
            end

            args = types.Tuple:new(args)
            ret = types.Tuple:new(ret)

            local obj = self:TypeFromImplicitNode(node, "function", {
                arg = args,
                ret = ret,
            })

            self:CallMeLater(obj, args, node, true)

            return obj
        end

        function META:AnalyzeTable(node, env)
            local out = {}
            for i, node in ipairs(node.children) do
                if node.kind == "table_key_value" then
                    out[i] = {
                        key = node.tokens["identifier"].value, 
                        val = self:AnalyzeExpression(node.expression, env)
                    }
                elseif node.kind == "table_expression_value" then

                    local key = self:AnalyzeExpression(node.expressions[1], env)
                    local obj = self:AnalyzeExpression(node.expressions[2], env)

                    if key:IsType("string") and key.value then
                        out[i] = {key = key.value, val = obj}
                    else
                        out[i] = {key = key, val = obj}
                    end
                elseif node.kind == "table_index_value" then
                    if node.i then
                        out[i] = {
                            key = node.i, 
                            val = self:AnalyzeExpression(node.expression, env)
                        }
                    else
                        table.insert(out, {
                            key = #out + 1, 
                            val = self:AnalyzeExpression(node.expression, env)
                        })
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
            io.write(tostring(obj), "[", (tostring(key)), "] = ", tostring(val))
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
                for _,v in ipairs(values) do
                    io.write(tostring(v), ", ")
                end
            end
            io.write("\n")
        else
            io.write((" "):rep(t))
            io.write(what .. " - ", ...)
            io.write("\n")
        end
    end
end

return function()
    local self = setmetatable({env = {runtime = {}, typesystem = {}}}, META)
    self.IndexNotFound = DefaultIndex
    return self
end
