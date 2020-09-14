local META = ...

local table_insert = table.insert
local types = require("oh.typesystem.types")
local helpers = require("oh.helpers")

function META:StringToNumber(str)
    if str:sub(1,2) == "0b" then
        return tonumber(str:sub(3))
    end

    local num = tonumber(str)
    if not num then
        error("unable to convert " .. str .. " to number", 2)
    end
    return num
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

    function META:CopyUpvalue(upvalue, data)
        return {
            data = data or upvalue.data:Copy(),
            shadow = upvalue.shadow
        }
    end

    function META:SetUpvalue(key, obj, env)
        assert(obj == nil or types.IsTypeObject(obj))

        local upvalue = {
            data = obj,
            shadow = self:GetUpvalue(key, env),
        }

        table_insert(self.scope.upvalues[env].list, upvalue)
        self.scope.upvalues[env].map[self:Hash(key)] = upvalue

        self:FireEvent("upvalue", key, obj, env)

        return upvalue
    end
    
    function META:OnGetUpvalue(found, key, env, original_scope)
        
    end

    function META:OnSetUpvalue(upvalue, key, val, env)
        
    end

    function META:GetUpvalue(key, env)
        if not self.scope then return end

        local key_hash = self:Hash(key)

        local scope = self.scope
        local current_scope = scope
        
        while scope do
            if scope.upvalues[env].map[key_hash] then
                local found = scope.upvalues[env].map[key_hash]
                return self:OnGetUpvalue(found, key, env, current_scope) or found
            end
            current_scope = scope
            scope = scope.parent
        end
    end

    function META:GetValue(key, env)
        env = env or "runtime"

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

                if not self:OnSetUpvalue(upvalue, key, val, env) then
                    upvalue.data = val
                end

                --self:SetUpvalue(key, val, env)

                self:FireEvent("mutate_upvalue", key, val, env)
            else
                -- key = val
                self.env[env][self:Hash(key)] = val
                self:FireEvent("set_global", key, val, env)
            end
        else
            local obj = self:AnalyzeExpression(key.left, env)
            local key = key.kind == "postfix_expression_index" and self:AnalyzeExpression(key.expression, env) or self:AnalyzeExpression(key.right, env)

            self:Assert(key.node, self:SetOperator(obj, key, val, env))
            self:FireEvent("newindex", obj, key, val, env)
        end
    end
end

function META:FireEvent(what, ...)
    if self.suppress_events then return end

    if self.OnEvent then
        self:OnEvent(what, ...)
    end
end

function META:CollectReturnExpressions(val)
    self.return_types = self.return_types or {}
    table.insert(self.return_types, val)
end

function META:ClearReturnExpressions()
    self.return_types = {}
end

function META:GetReturnExpressions()
    local out = {}
    if self.return_types then
        for _, ret in ipairs(self.return_types) do
            for i, obj in ipairs(ret) do
                if out[i] then
                    out[i] = types.Set({out[i], obj})
                else
                    out[i] = obj
                end
            end
        end
    end
    return out
end

function META:ReturnFromThisScope()
    self.ReturnFromFunction = #self.scope_stack
end

function META:AnalyzeStatements(statements)
    for _, val in ipairs(statements) do
        self:AnalyzeStatement(val)
        if self.Returned and self.ReturnFromFunction == #self.scope_stack then
            self.ReturnFromFunction = nil
            self.Returned = nil
            break
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

function META:Error(node, msg)
    if not node then
        io.write("invalid error, no node supplied\n", debug.traceback(), "\n")
        error(msg)
    end

    if self.OnError then
        self:OnError(msg, helpers.LazyFindStartStop(node))
    end

    if self.code then
        local start, stop = helpers.LazyFindStartStop(node)
        io.write(helpers.FormatError(self.code, self.path or node.type, msg, start, stop), "\n")
    else
        local s = tostring(self)
        s = s .. ": " .. msg

        io.write(s, "\n")
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
            local _, extra_node, scope = ...
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

do
    local meta = {}
    meta.__index = meta

    function META:CreateStack()
        return setmetatable({values = {}, i = 1}, meta)
    end

    function meta:Push(val)
        assert(val)
        if val.Type == "tuple" then
            for _,v in ipairs(val) do
                assert(types.IsTypeObject(v))
            end
        else
            if not types.IsTypeObject(val) then
                if not next(val) then
                    error("cannot push empty table", 2)
                end
                for k,v in pairs(val) do print(k,v) end
                error("cannot push non type object", 2)
            end
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

        if val.Type == "tuple" then
            return val:Get(1)
        end

        self.last_val = val

        assert(types.IsTypeObject(val))

        return val
    end

    function meta:Unpack()
        local out = {}

        for _,v in ipairs(self.values) do
            if v.Type == "tuple" then
                for _, v in ipairs(v:GetData()) do
                    table.insert(out, v)
                end
            else
                table.insert(out, v)
            end
        end
        return table.unpack(out)
    end
end

function META:AnalyzeExpression(exp, env, stack)
    assert(exp and exp.type == "expression")
    env = env or "runtime"
    stack = stack or self:CreateStack()

    if self.PreferTypesystem then
        env = "typesystem"
    end

    self:HandleExpression(stack, exp, env)

    return stack:Unpack()
end

function META:AnalyzeExpressions(expressions, env)
    if not expressions then return end
    local out = {}
    for _, expression in ipairs(expressions) do
        local ret = {self:AnalyzeExpression(expression, env)}
        for _,v in ipairs(ret) do
            table.insert(out, v)
        end
    end
    return out
end