local oh = ...
local ipairs = ipairs

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

function META:Hash(token)
    return hash(token)
end

function META:PushScope(node, token)
    self.globals = self.globals or {}
    local parent = self.scope

    local scope = {
        children = {},
        parent = self.scope,
        upvalues = {},
        upvalue_map = {},
        events = {},
        node = node,
        token = token,
    }

    if self.scope then
        self:RecordScopeEvent("scope", "create", {scope = scope})
        table_insert(self.scope.children, self.scope)
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

    self:RecordScopeEvent("local", "create", {
        key = key,
        token = token,
        node = node,
        upvalue = upvalue,
    })

    return upvalue
end

function META:RecordScopeEvent(type, kind, data)
    data.type = type
    data.kind = kind
    table_insert(self.scope.events, data)
    return data
end

function META:RecordUpvalueEvent(what, key, data)
    local upvalue = assert(self:GetUpvalue(key), tostring(hash(key)))
    local event = {}
    event.upvalue = upvalue
    event.key = key
    event.data = data
    table_insert(upvalue.events, self:RecordScopeEvent("local", what, event))
    return event
end

function META:RecordGlobalEvent(what, key, data)
    if what == "mutate" then
        self.globals[key.value.value] = data
    end

    return self:RecordScopeEvent("global", what, {
        key = key,
        data = data,
    })
end

function META:RecordEvent(what, key, data)
    if self:GetUpvalue(key) then
        return self:RecordUpvalueEvent(what, key, data)
    end

    return self:RecordGlobalEvent(what, key, data)
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

function META:PopScope()
    local scope = self.scope.parent
    if scope then
        self.scope = scope
    end
end

function META:GetScope()
    return self.scope
end

function META:GetScopeEvents()
    return self.scope.events
end

do
    local function walk(scope, level, cb)
        for _, event in ipairs(scope.events) do
            if event.type == "scope" then
                level = level + 1
                cb(event, level)
                walk(event.scope, level, cb)
                level = level - 1
            else
                cb(event, level)
            end
        end
    end

    function META:WalkAllEvents(cb)
        walk(self:GetScope(), 0, cb)
    end
end

function META:DumpScope(scope, level)
    level = level or 0
    scope = scope or self:GetScope()
    local str = ""

    local friendly = scope.node.kind
    if scope.token then
        friendly = tostring(scope.token.value)
    end
    str = str .. ("\t"):rep(level) .. friendly .. " {\n"

    for _, v in ipairs(scope.events) do
        if v.type == "scope" then
            level = level + 1
            str = str .. self:DumpScope(v.scope, level)
            level = level - 1
        else
            local key = hash(v.key)
            if v.type == "global" then
                if v.kind == "index" then
                    str = str .. ("\t"):rep(level+1) .. "? = _G." .. key .. "\n"
                elseif v.kind == "newindex" then
                    str = str .. ("\t"):rep(level+1) .. "_G." .. key .. " = ?\n"
                else
                    str = str .. ("\t"):rep(level+1) .. v.kind  .. key .. "\n"
                end
            elseif v.type == "local" then
                if v.kind == "create" then
                    str = str .. ("\t"):rep(level+1) .. "local " .. key

                    if v.upvalue.init then
                        str = str .. " = " .. v.upvalue.init:Render()
                    end

                    str = str  .. "\n"
                elseif v.kind == "index" then
                    str = str .. ("\t"):rep(level+1) .. "use" .. "(" .. key .. ")\n"
                elseif v.kind == "newindex" then
                    str = str .. ("\t"):rep(level+1) .. key .. "\n"
                end
            else
                local view = (v.token or v.node):Render()

                str = str .. ("\t"):rep(level+1) .. v.type .. "_" .. v.kind .. ": " .. view .. "\n"
            end
        end
    end

    str = str .. ("\t"):rep(level) .. "}\n"

    return str
end

function META:WalkScopes()
    local events = self:GetScopeEvents()
    local i = 1
    return function()
        local event = events[i]
        i = i + 1
        if event then

        end
    end
end

do
    local function record_expressions(self, node, expressions, callback)
        if expressions then
            for _, expression in ipairs(expressions) do
                if expression.kind == "table" then
                    for _,v in ipairs(expression.children) do
                        if v.kind == "table_expression_value" then
                            record_expressions(self, node, {v.key, v.value}, callback)
                        else
                            record_expressions(self, node, {v.value}, callback)
                        end
                    end
                elseif expression.kind == "postfix_call" then
                    record_expressions(self, node, {expression.left}, callback)
                    record_expressions(self, node, expression.expressions, callback)
                elseif expression.kind == "function" then
                    self:PushScope(expression)
                    for _, statement in ipairs(expression.statements) do
                        statement:Walk(callback, self)
                    end
                    self:PopScope()
                else
                    for _, key in ipairs(expression:GetUpvaluesAndGlobals()) do
                        self:RecordEvent("index", key)
                    end
                end
            end
        end
    end


    local function record_assignments(self, node, assignments, statement, callback)
        if assignments then
            for _, assignment in ipairs(assignments) do
                if node.is_local or (statement and node.kind == "function" ) then
                    self:DeclareUpvalue(assignment[1])
                else
                    local tbl = assignment[1]:Flatten()

                    if tbl[2] then
                        if false and tbl[2].kind == "binary_operator" then
                            local bin_op = tbl[2]
                            self:RecordEvent("index", bin_op.left)
                        end

                        for _, value in ipairs(assignment[1]:GetUpvaluesAndGlobals()) do
                            self:RecordEvent("index", value.left or value)
                        end
                    else
                        self:RecordEvent("newindex", assignment[1])
                    end

                    if assignment[2].type == "expression" then
                        record_expressions(self, node, {assignment[2]}, callback)
                    end
                end
            end
        end
    end

    local function callback(node, self, statements, expressions, start_token)
        record_assignments(self, node, node:GetAssignments())

        if node.kind ~= "repeat" then
            record_expressions(self, node, expressions, callback)
        end

        if statements then
            self:PushScope(node, start_token)

            record_assignments(self, node, node:GetStatementAssignments(), true, callback)

            for _, statement in ipairs(statements) do
                statement:Walk(callback, self)
            end

            if node.kind == "repeat" then
                record_expressions(self, node, expressions)
            end

            self:PopScope()
        end
    end

    function META:Walk(ast)
        ast:Walk(callback, self)
    end
end

function oh.Analyzer()
    local self = setmetatable({}, META)
    self.globals = {}
    return self
end