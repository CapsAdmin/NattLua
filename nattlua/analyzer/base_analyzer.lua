local types = require("nattlua.types.types")
local helpers = require("nattlua.util.helpers")
local list = require("nattlua.util.list")

local LexicalScope

do
    local table_insert = table.insert
    local META = {}
    META.__index = META

    function META:Initialize(node, extra_node, event_data)
       
    end

    function META:SetParent(parent)
        self.parent = parent
        parent:AddChild(self)
    end

    function META:AddChild(scope)
        table_insert(self.children, scope)
    end

    function META:Hash(node)
        if type(node) == "string" then
            return node
        end

        if type(node.value) == "string" then
            return node.value
        end

        return node.value.value
    end

    function META:FindValue(key, env)
        local key_hash = self:Hash(key)

        local scope = self
        local current_scope = scope
        
        while scope do
            if scope.upvalues[env].map[key_hash] then
                return scope.upvalues[env].map[key_hash], current_scope
            end
            current_scope = scope
            scope = scope.parent
        end
    end

    function META:CreateValue(key, obj, env)
        assert(obj == nil or types.IsTypeObject(obj))

        local upvalue = {
            data = obj,
            key = key,
            shadow = self:FindValue(key, env),
        }

        table_insert(self.upvalues[env].list, upvalue)
        self.upvalues[env].map[self:Hash(key)] = upvalue

        return upvalue
    end

    function META:Copy(node)
        local copy = LexicalScope(node or self.node, self.extra_node, self.event_data)

        for env, data in pairs(self.upvalues) do
            for key, obj in pairs(data.map) do
                copy:CreateValue(key, obj.data, env)
            end
        end
        
        copy.returns = self.returns

        return copy
    end

    function META:GetTestCondition()
        local scope = self
        while true do
            if scope.test_condition then
                break
            end
            scope = scope.parent
            if not scope then
                return
            end
        end
        return scope.test_condition, scope.test_condition_inverted
    end

    function META:FindTestCondition(obj)
        local scope = self
        while true do
            if scope.test_condition then
                local condition = scope.test_condition
                if 
                    condition == obj or 
                    condition.source == obj or 
                    condition.source_left == obj or 
                    condition.source_right == obj or
                    condition.type_checked == obj 
                then
                    break
                end
            end
            
            scope = scope.parent            
            
            if not scope then
                return
            end


            -- find in siblings too, if they have returned
            local found = nil

            for _, child in ipairs(scope.children) do
                if child ~= scope then
                    if child.test_condition then
                        local condition = child.test_condition
                        if 
                            condition == obj or 
                            condition.source == obj or 
                            condition.source_left == obj or 
                            condition.source_right == obj or
                            condition.type_checked == obj 
                        then
                            found = child
                            break
                        end
                    end                    
                end
            end

            if found then
                scope = found
                break
            end


        end
        return scope.test_condition, scope.test_condition_inverted
    end


    local ref = 0

    function META:__tostring()
        return "scope[" .. self.ref .. "]" .. "[".. (self.uncertain and "uncertain" or "certain") .."]" .. "[" .. tostring(self:GetTestCondition() or nil) .. "]"
    end

    function LexicalScope(node, extra_node, event_data)
        assert(type(node) == "table" and node.kind, "expected an associated ast node")
        ref = ref + 1

        local scope = {
            ref = ref,
            children = {},

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
            event_data = event_data,
        }

        setmetatable(scope, META)

        return scope
    end
end

return function(META)
    local table_insert = table.insert

    function META:FatalError(msg)
        error(msg, 2)
    end

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

        function META:PushScope(scope)
            local parent = self:GetScope()

            if parent then
                scope:SetParent(parent)
            end

            if scope.node and scope.node.scope then
                scope:SetParent(scope.node.scope)
            end

            self.scope_stack = self.scope_stack or {}
            table.insert(self.scope_stack, self.scope)

            self.scope = scope

            self:FireEvent("enter_scope", scope)

            if scope.event_data and self.OnEnterScope then
                self:OnEnterScope(scope.node.kind, scope.event_data)
            end

            return scope
        end

        function META:CreateAndPushScope(node, extra_node, event_data)
            return self:PushScope(self:CreateScope(node, extra_node, event_data))
        end

        function META:CreateScope(node, extra_node, event_data)
            assert(type(node) == "table" and node.kind, "expected an associated ast node")

            return LexicalScope(node, extra_node, event_data)
        end


        function META:PopScope(event_data)
            local old = table.remove(self.scope_stack)

            self:FireEvent("leave_scope", self.scope.node, self.scope.extra_node, old)

            if old then
                self.last_scope = self.scope
                self.scope = old
            end

            if event_data and self.OnExitScope then
                self:OnExitScope(self.last_scope.node.kind, event_data)
            end
        end

        function META:GetLastScope()
            return self.last_scope or self.scope
        end

        function META:GetScope()
            return self.scope
        end

        function META:CloneCurrentScope(node)
            local current_scope = self:GetScope()
            self:PopScope()
            self:PushScope(current_scope:Copy(node))
        end

        function META:DumpScope()
            print("scope:")
            for i,v in ipairs(self.scope.upvalues.runtime.list) do
                print("\t",i,v.data)
            end

            for i,v in ipairs(self.scope.upvalues.typesystem.list) do
                print("\t",i,v.data)
            end
        end

        function META:CopyUpvalue(upvalue, data)
            return {
                data = data or upvalue.data:Copy(),
                key = upvalue.key,
                shadow = upvalue.shadow,
            }
        end

        function META:CreateLocalValue(key, obj, env)
            local upvalue = self.scope:CreateValue(key, obj, env)
            obj.upvalue = upvalue
            self:FireEvent("upvalue", key, obj, env)
            return upvalue
        end
        
        function META:OnFindLocalValue(found, key, env, original_scope)
            
        end

        function META:OnCreateLocalValue(upvalue, key, val, env)
            
        end

        function META:FindLocalValue(key, env)
            if not self.scope then return end
            
            local found, scope = self.scope:FindValue(key, env)
            
            if found then
                return self:OnFindLocalValue(found, key, env, scope) or found
            end
        end

        function META:SetEnvironmentOverride(node, obj, env)
            if not obj then
                if not env then
                    node.environments_override = nil
                else
                    node.environments_override[env] = nil
                end
            else
                node.environments_override = node.environments_override or {}
                node.environments_override[env] = obj
            end
        end

        function META:GetEnvironmentOverride(node, env)
            if node.environments_override then
                return node.environments_override[env]
            end
        end

        function META:SetDefaultEnvironment(obj, env)
            self.default_environment[env] = obj
        end

        function META:PushEnvironment(node, obj, env)
            obj = obj or self.default_environment[env]

            if #self.environments[env] == 0 then
                -- this is needed for when calling GetEnvironmentValue when analysis is done
                -- it's mostly useful for tests, but maybe a better solution can be done here
                self.first_environment = self.first_environment or {}
                self.first_environment[env] = obj
            end

            table.insert(self.environments[env], 1, obj)

            node.environments = node.environments or {}
            node.environments[env] = obj

            self.environment_nodes = self.environment_nodes or {}
            table.insert(self.environment_nodes, 1, node)
        end

        function META:PopEnvironment(env)
            table.remove(self.environment_nodes)            
            table.remove(self.environments[env])            
        end
        
        function META:GetEnvironmentValue(key, env)
            env = env or "runtime"

            local upvalue = self:FindLocalValue(key, env)

            if upvalue then
                return upvalue.data
            end

            local string_key = types.String(self:Hash(key)):MakeLiteral(true)

            if self.environment_nodes[1] and self.environment_nodes[1].environments_override and self.environment_nodes[1].environments_override[env] then
                return self.environment_nodes[1].environments_override[env]:Get(string_key)
            end

            if not self.environments[env][1] then
                return self.first_environment[env]:Get(string_key)
            end
        
            local val, err = self.environments[env][1]:Get(string_key)

            if val then
                return val
            end

            -- log error maybe?

            return  nil
        end

        function META:SetEnvironmentValue(key, val, env)
            assert(val == nil or types.IsTypeObject(val))

            if type(key) == "string" or key.kind == "value" then
                -- local key = val; key = val

                local upvalue = self:FindLocalValue(key, env)
                if upvalue then

                    if not self:OnMutateUpvalue(upvalue, key, val, env) then
                        upvalue.data = val
                    end

                    --self:CreateLocalValue(key, val, env)

                    self:FireEvent("mutate_upvalue", key, val, env)
                else
                    -- key = val

                    if not self.environments[env][1] then
                        error("tried to set environment value outside of Push/Pop/Environment", 2)
                    end

                    local ok, err = self.environments[env][1]:Set(types.String(self:Hash(key)):MakeLiteral(true), val, env == "runtime")

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
        else
            --self:DumpEvent(what, ...)
        end
    end

    do
        -- return statement
        function META:CollectReturnExpressions(types)
            table.insert(self.returns[1], types)

            self.returned_from_certain_scope = not self:GetScope().uncertain
            self.returned_from_block = (self.returned_from_block or 0) + 1
        end

        function META:ResetReturnState()
            self.returned_from_certain_scope = nil
        end

        -- used in exit scope
        function META:DidJustReturnFromBlock()
            local a = self.returned_from_block and self.returned_from_block > 0
            self.returned_from_block = (self.returned_from_block or 0) - 1
            return a
        end

        function META:AnalyzeStatementsAndCollectReturnTypes(statement)
            self:ResetReturnState()
            self.return_to_this_level = #self.scope_stack
            self.returns = self.returns or {}
            table.insert(self.returns, 1, {})
            self:AnalyzeStatements(statement.statements)
            local out = {}
            if self.returns then
                local return_types = table.remove(self.returns, 1)
                if return_types then
                    for _, ret in ipairs(return_types) do
                        for i, obj in ipairs(ret) do
                            if out[i] then
                                out[i] = types.Union({out[i], obj})
                            else
                                out[i] = obj
                            end
                        end
                    end
                end
            end
            return types.Tuple(out)
        end

        function META:AnalyzeStatements(statements)
            for i, statement in ipairs(statements) do
                self:AnalyzeStatement(statement)

                -- if we're analyzing statements and encounter a return statement
                -- certain: do return x end
                -- certain: if true then return x end
                -- uncertain: if math.random() > 0.5 then return x end
                if self.returned_from_certain_scope and self.return_to_this_level == #self.scope_stack then
                    if 
                        statement.kind ~= "return" and 
                        statement.kind ~= "if" and 
                        statement.kind ~= "numeric_for" and
                        statement.kind ~= "do"
                    then
                        self:FatalError("returning from invalid statement: " .. tostring(statement))
                    end
                    
                    self.return_to_this_level = nil
                    self.returned_from_certain_scope = nil
                    
                    break
                end
            end
        end
    end

    function META:Assert(node, ok, err)
        if ok == false then
            err = err or "unknown error"
            self:Error(node, err)
            return self:NewType(node, "any")
        end
        return ok
    end

    function META:Error(node, msg)
        if not node then
            io.write("invalid error, no node supplied\n", debug.traceback(), "\n")
            error(msg)
        end

        if self.OnError then
            self:OnError(node.code, node.name, msg, helpers.LazyFindStartStop(node))
        end

        if node.code then
            local start, stop = helpers.LazyFindStartStop(node)
            io.write(helpers.FormatError(node.code, node.name or node.type, msg, start, stop), "\n")
        else
            local s = tostring(self)
            s = s .. ": " .. msg

            io.write(s, "\n")
        end
    end

    function META:Report(node, msg)
        local start, stop = helpers.LazyFindStartStop(node)

        if self.OnReport then
            self:OnReport(node.code, node.name, msg, start, stop)
        else
            if not _G.TEST then 
                io.write(helpers.FormatError(node.code, node.name or node.type, msg, start, stop), "\n")
            end
        end

        table.insert(self.diagnostics, {node = node, msg = msg})
    end

    function META:GetDiagnostics()
        return self.diagnostics
    end

    do
        local t = 0
        local function tab()
            io.write(("    "):rep(t))
        end
        function META:DumpEvent(what, ...)

            if what == "create_global" then
                tab()
                io.write(what, " - ")
                local key, val = ...
                io.write(key:Render())
                if val then
                    io.write(" = ")
                    io.write(tostring(val))
                end
                io.write("\n")
            elseif what == "newindex" then
                tab()
                local obj, key, val = ...
                io.write(tostring(obj), "[", (tostring(key)), "] = ", tostring(val))
                io.write("\n")
            elseif what == "mutate_upvalue" then
                tab()
                local key, val = ...
                io.write(self:Hash(key), " = ", tostring(val))
                io.write("\n")
            elseif what == "upvalue" then
                tab()

                io.write("local ")
                local key, val = ...
                io.write(self:Hash(key))
                if val then
                    io.write(" = ")
                    io.write(tostring(val))
                end
                io.write("\n")
            elseif what == "set_global" then
                tab()
                local key, val = ...
                io.write("_ENV.", self:Hash(key), " = ", tostring(val))
                io.write("\n")
            elseif what == "enter_scope" then
                local scope = ...
                tab()
                t = t + 1

                io.write(scope.event_data.type, " ")
                
                local data = scope.event_data
                if data and data.condition then
                    io.write(tostring(data.condition), " then")
                end

                io.write("\n")
            elseif what == "leave_scope" then
                local _, extra_node, scope = ...
                t = t - 1
                tab()
                io.write("end")
                io.write("\n")
            elseif what == "external_call" then
                tab()
                local node, type = ...
                io.write(node:Render(), " - (", tostring(type), ")")
                io.write("\n")
            elseif what == "call" then
                tab()
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
                tab()
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
                tab()
                io.write(what, " - ")
                io.write(tostring(func))
                io.write("\n")
            elseif what == "return" then
                tab()
                io.write(what)
                local values = ...
                if values then
                    io.write(" ")
                    for i, v in ipairs(values) do
                        io.write(tostring(v))
                        if i ~= #values then
                            io.write(", ")
                        end
                    end
                end
                io.write("\n")
            else
                tab()
                io.write(what .. " - ", ...)
                io.write("\n")
            end
        end
    end

    function META:AnalyzeExpressions(expressions, env)
        if not expressions then return end
        local out = list.new()
        for _, expression in ipairs(expressions) do
            local ret = {self:AnalyzeExpression(expression, env)}
            for _,v in ipairs(ret) do
                table.insert(out, v)
            end
        end
        return out
    end

    do
        local function call(self, obj, arguments, node)
            -- diregard arguments and use function's arguments in case they have been maniupulated (ie string.gsub)
            arguments = obj:GetArguments()
            self:Assert(node, self:Call(obj, arguments, node))
        end

        function META:CallMeLater(...)
            self.deferred_calls = self.deferred_calls or {}
            table.insert(self.deferred_calls, 1, {...})
        end

        function META:AnalyzeUnreachableCode()
            if not self.deferred_calls then
                return
            end

            self.processing_deferred_calls = true 

            self:ResetReturnState()

            for _,v in ipairs(self.deferred_calls) do
                if not v[1].called and v[1].explicit_arguments then
                    call(self, table.unpack(v))
                end
            end

            for _,v in ipairs(self.deferred_calls) do
                if not v[1].called and not v[1].explicit_arguments then
                    call(self, table.unpack(v))
                end
            end

            self.processing_deferred_calls = false
            self.deferred_calls = nil
        end
    end

    do
        local helpers = require("nattlua.util.helpers")

        function META:CompileLuaTypeCode(code, node)
            
            -- append newlines so that potential line errors are correct
            if node.code then
                local start, stop = helpers.LazyFindStartStop(node)
                local line = helpers.SubPositionToLinePosition(node.code, start, stop).line_start
                code = ("\n"):rep(line - 1) .. code
            end

            local func, err = load(code, node.name)

            if not func then
                self:FatalError(err)
            end

            return func
        end

        function META:CallLuaTypeFunction(node, func, ...)
            setfenv(func, setmetatable({
                nl = require("nattlua"),
                types = types,
                analyzer = self,
            }, {
                __index = _G
            }))

            local res = {pcall(func, ...)}

            local ok = table.remove(res, 1)

            if not ok then 
                local msg = tostring(res[1])

                local name = debug.getinfo(func).source
                if name:sub(1, 1) == "@" then -- is this a name that is a location?
                    local line, rest = msg:sub(#name):match("^:(%d+):(.+)") -- remove the file name and grab the line number
                    if line then
                        local f, err = io.open(name:sub(2), "r")
                        if f then
                            local code = f:read("*all")
                            f:close()
                            
                            local start = helpers.LinePositionToSubPosition(code, tonumber(line), 0)
                            local stop = start + #(code:sub(start):match("(.-)\n") or "") - 1

                            msg = helpers.FormatError(code, name, rest, start, stop)
                        end
                    end
                end
                
                local trace = self:TypeTraceBack()
                if trace then
                    msg = msg .. "\ntraceback:\n" .. trace
                end

                self:Error(node, msg)
            end

            return table.unpack(res)
        end

        function META:TypeTraceBack()
            if not self.call_stack then return "" end

            local str = ""

            for i,v in ipairs(self.call_stack) do 
                local callexp = v.call_expression
                local func_str

                if not v.func then
                    func_str = tostring(v.obj)
                else
                    local lol =  v.func.statements
                    v.func.statements = {}
                    func_str = v.func:Render()
                    v.func.statements = lol
                end
        
                local start, stop = helpers.LazyFindStartStop(callexp)
                local part = helpers.FormatError(self.code_data.code, self.code_data.name, "", start, stop, 1)
                if str:find(part, nil, true) then
                    str = str .. "*"
                else
                    str = str .. part .. "#" .. tostring(i) .. ": " .. self.code_data.name
                end
            end

            return str
        end
    end

end