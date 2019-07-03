local oh = ...
local table_insert = table.insert
local math_huge = math.huge
local pairs = pairs
local ipairs = ipairs

local META = {}
META.__index = META

do
    local SHARED = {}

    function SHARED:GetStartStop()
        if self.type == "statement" then
            if self.kind == "function" then
                return self.expression:GetStartStop()
            end
        end
        local tbl = self:Flatten()
        local start, stop = tbl[1], tbl[#tbl]
        start = start.value.start

        if stop.kind ~= "value" then
            if stop.kind == "postfix_call" then
                stop = stop.tokens["call)"].stop
            elseif stop.kind == "postfix_expression_index" then
                stop = stop.tokens["]"].stop
            else
                error("not sure how to handle stop for " .. stop.kind)
            end
        else
            stop = stop.value.stop
        end

        return start, stop
    end

    do
        local STATEMENT = {}
        for k,v in pairs(SHARED) do STATEMENT[k] = v end
        STATEMENT.__index = STATEMENT
        STATEMENT.type = "statement"

        function STATEMENT:__tostring()
            return "[" .. self.type .. " - " .. self.kind .. "] " .. ("%p"):format(self)
        end

        function STATEMENT:Render()
            local em = oh.LuaEmitter({preserve_whitespace = false, no_newlines = true})

            em:EmitStatement(self)

            return em:Concat()
        end

        function STATEMENT:GetStatements()
            if self.kind == "if" then
                local flat = {}
                for _, statements in ipairs(self.statements) do
                    for _, v in ipairs(statements) do
                        table_insert(flat, v)
                    end
                end
                return flat
            end
            return self.statements
        end

        function STATEMENT:GetExpressions()
            return self.expressions
        end

        function STATEMENT:FindStatementsByType(what, out)
            out = out or {}
            for _, child in ipairs(self:GetStatements()) do
                if child.kind == what then
                    table_insert(out, child)
                elseif child:GetStatements() then
                    child:FindStatementsByType(what, out)
                end
            end
            return out
        end

        function META:NewStatement(kind)
            local node = {}
            node.tokens = {}
            node.kind = kind
            setmetatable(node, STATEMENT)

            if self.NodeRecord then
                self.NodeRecord[self.NodeRecordI] = node
                self.NodeRecordI = self.NodeRecordI + 1
            end

            return node
        end
    end

    do
        local EXPRESSION = {}
        for k,v in pairs(SHARED) do EXPRESSION[k] = v end
        EXPRESSION.__index = EXPRESSION
        EXPRESSION.type = "expression"

        function EXPRESSION:__tostring()
            return "[" .. self.type .. " - " .. self.kind .. "] " .. ("%p"):format(self)
        end

        function EXPRESSION:GetExpressions()
            if self.expression then
                return {self.expression}
            end

            return self.expressions or self.left or self.right
        end

        function EXPRESSION:GetExpression()
            return self.expression or self.expressions[1]
        end

        function EXPRESSION:Render()
            local em = oh.LuaEmitter({preserve_whitespace = false, no_newlines = true})

            em:EmitExpression(self)

            return em:Concat()
        end

        do
            local function expand(node, tbl)

                if node.kind == "prefix_operator" or node.kind == "postfix_operator" then
                    table_insert(tbl, node.value.value)
                    table_insert(tbl, "(")
                    expand(node.right or node.left, tbl)
                    table_insert(tbl, ")")
                    return tbl
                elseif node.kind:sub(1, #"postfix") == "postfix" then
                    table_insert(tbl, node.kind:sub(#"postfix"+2))
                elseif node.kind ~= "binary_operator" then
                    table_insert(tbl, node:Render())
                else
                    table_insert(tbl, node.value.value)
                end

                if node.left then
                    table_insert(tbl, "(")
                    expand(node.left, tbl)
                end


                if node.right then
                    table_insert(tbl, ", ")
                    expand(node.right, tbl)
                    table_insert(tbl, ")")
                end

                if node.kind:sub(1, #"postfix") == "postfix" then
                    local str = {""}
                    for _, exp in ipairs(node:GetExpressions()) do
                        table.insert(str, exp:Render())
                    end
                    table_insert(tbl, table.concat(str, ", "))
                    table_insert(tbl, ")")
                end

                return tbl
            end

            function EXPRESSION:DumpPresedence()
                local list = expand(self, {})
                local a = table.concat(list)
                return a
            end
        end

        do
            local function expand(node, tbl)
                if node.left then
                    expand(node.left, tbl)
                end

                table_insert(tbl, node)

                if node.right then
                    expand(node.right, tbl)
                end
            end

            function EXPRESSION:Flatten()
                local flat = {}

                expand(self, flat)

                return flat
            end

            function EXPRESSION:Walk()
                local flat = self:Flatten()

                local i = 1

                return function()
                    local l,o,r = flat[i + 0], flat[i + 1], flat[i + 2]
                    if r then
                        i = i + 2
                        return l,o,r
                    end
                end
            end
        end

        function META:NewExpression(kind)
            local node = {}
            node.tokens = {}
            node.kind = kind

            setmetatable(node, EXPRESSION)

            if self.NodeRecord then
                self.NodeRecord[self.NodeRecordI] = node
                self.NodeRecordI = self.NodeRecordI + 1
            end

            return node
        end
    end
end

function META:Error(msg, start, stop)
    if not self.OnError then return end

    if type(start) == "table" then
        start = start.start
    end
    if type(stop) == "table" then
        stop = stop.stop
    end

    local tk = self:GetToken()
    start = start or tk and tk.start or 0
    stop = stop or tk and tk.stop or 0

    do
        local hash = msg .. start .. stop

        if hash == self.last_error then
            return
        end

        self.last_error = hash
    end

    self:OnError(msg, start, stop)
end

function META:GetToken(offset)
    if offset then
        return self.tokens[self.i + offset]
    end
    return self.tokens[self.i]
end

function META:ReadToken()
    self:Advance(1)
    return self:GetToken(-1)
end

function META:IsValue(str, offset)
    return self:GetToken(offset) and self:GetToken(offset).value == str
end

function META:IsType(str, offset)
    return self:GetToken(offset) and self:GetToken(offset).type == str
end

do
    local function error_expect(self, str, what, start, stop)
        if not self:GetToken() then
            self:Error("expected " .. what .. " " .. oh.QuoteToken(str) .. ": reached end of code", start, stop)
        else
            self:Error("expected " .. what .. " " .. oh.QuoteToken(str) .. ": got " .. oh.QuoteToken(self:GetToken()[what]), start, stop)
        end
    end

    function META:ReadExpectValue(str, start, stop)
        if not self:IsValue(str) then
            error_expect(self, str, "value", start, stop)
        end

        return self:ReadToken()
    end

    function META:ReadExpectType(str, start, stop)
        if not self:IsType(str) then
            error_expect(self, str, "type", start, stop)
        end

        return self:ReadToken()
    end
end

function META:ReadExpectValues(values, start, stop)
    if not self:GetToken() or not values[self:GetToken().value] then
        local tk = self:GetToken()
        if not tk then
            self:Error("expected " .. oh.QuoteTokens(values) .. ": reached end of code", start, stop)
        end
        local array = {}
        for k in pairs(values) do table_insert(array, k) end
        self:Error("expected " .. oh.QuoteTokens(array) .. " got " .. tk.type, start, stop)
    end

    return self:ReadToken()
end

function META:GetLength()
    return self.tokens_length
end

function META:Advance(offset)
    self.i = self.i + offset
end

function META:BuildAST(tokens)
    self.tokens = tokens
    self.tokens_length = #tokens
    self.i = 1

    if self.config then
        if self.config.record_nodes then
            self.NodeRecord = {}
            self.NodeRecordI = 1
        end
    end

    return self:Root()
end

do
    function META:PushScope(node)
        self.globals = self.globals or {}
        parent = parent or self.scope

        local scope = {
            children = {},
            parent = self.scope,
            upvalues = {},
            upvalue_map = {},
            events = {},
            node = node,
        }

        if self.scope then
            self:RecordScopeEvent("scope", "create", {scope = scope})
            table_insert(self.scope.children, self.scope)
        end

        self.scope = scope
    end

    function META:DeclareUpvalue(token, node, init)
        node = node or token
        local key = type(token) == "table" and token.value.value or token
        local upvalue = {
            token = token,
            key = key,
            node = node,
            scope = self.scope,
            events = {},
            shadow = self:GetUpvalue(key),
            init = init,
        }

        table_insert(self.scope.upvalues, upvalue)
        self.scope.upvalue_map[key] = upvalue

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

    function META:RecordUpvalueEvent(what, key, node)
        local upvalue = assert(self:GetUpvalue(key))
        local data = {}
        data.upvalue = upvalue
        data.key = key
        data.node = node
        table_insert(upvalue.events, self:RecordScopeEvent("local", what, data))
    end

    function META:RecordGlobalEvent(what, key, node)
        if what == "mutate" then
            self.globals[key.value.value] = node
        end

        self:RecordScopeEvent("global", what, {
            key = key.value.value,
            node = node,
        })
    end

    function META:RecordEvent(what, key, node)
        if self:GetUpvalue(key) then
            self:RecordUpvalueEvent(what, key, node)
        else
            self:RecordGlobalEvent(what, key, node)
        end
    end

    function META:GetUpvalue(token)
        local key = type(token) == "table" and token.value.value or token

        if self.scope.upvalue_map[key] then
            return self.scope.upvalue_map[key]
        end

        local scope = self.scope.parent
        while scope do
            if scope.upvalue_map[key] then
                return scope.upvalue_map[key]
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

        str = str .. ("\t"):rep(level) .. scope.node.kind .. " {\n"

        for _, v in ipairs(scope.events) do
            if v.type == "scope" then
                level = level + 1
                str = str .. self:DumpScope(v.scope, level)
                level = level - 1
            else
                str = str .. ("\t"):rep(level+1) .. v.type .. "_" .. v.kind .. ": " .. v.node:Render() .. "\n"
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
end

function META:Root()
    local node = self:NewStatement("root")

    local shebang

    if self:IsType("shebang") then
        shebang = self:NewStatement("shebang")
        shebang.tokens["shebang"] = self:ReadToken()
    end

    self:PushScope(node)
    node.statements = self:ReadStatements()
    self:PopScope()

    if shebang then
        table_insert(node.statements, 1, shebang)
    end

    if self:IsType("end_of_file") then
        local eof = self:NewStatement("end_of_file")
        eof.tokens["end_of_file"] = self.tokens[#self.tokens]
        table_insert(node.statements, eof)
    end

    return node
end

do -- statements
    function META:ReadStatements(stop_token)
        local out = {}
        for i = 1, self:GetLength() do
            if not self:GetToken() or stop_token and stop_token[self:GetToken().value] then
                break
            end

            local statement = self:ReadStatement()

            if not statement then
                break
            end

            out[i] = statement
        end

        return out
    end

    function META:ReadRemainingStatement()
        local node
        local start = self:GetToken()

        local expr = self:ReadExpression()

        if self:IsValue("=") then
            node = self:NewStatement("assignment")
            node.tokens["="] = self:ReadToken()
            node.expressions_left = {expr}
            node.expressions_right = self:ReadExpressionList(math_huge)
        elseif self:IsValue(",") then
            node = self:NewStatement("assignment")
            expr.tokens[","] = self:ReadToken()
            local list = self:ReadExpressionList(math_huge)
            table_insert(list, 1, expr)
            node.expressions_left = list
            node.tokens["="] = self:ReadExpectValue("=")
            node.expressions_right = self:ReadExpressionList(math_huge)
        elseif expr then -- TODO: make sure it's a call
            node = self:NewStatement("expression")
            node.value = expr
        elseif not self:IsType("end_of_file") then
            self:Error("unexpected " .. start.type .. " (" .. (self:GetToken().value) .. ") while trying to read assignment or call statement", start, start)
        end

        if node and node.kind == "assignment" then
            for i, v in ipairs(node.expressions_left) do
                if v.kind == "value" then
                    self:RecordEvent("mutate", v, node.expressions_right[i])
                end
            end
        end

        return node
    end

    function META:ReadStatement()
        if
            self:IsReturnStatement() then           return self:ReadReturnStatement() elseif
            self:IsBreakStatement() then            return self:ReadBreakStatement() elseif
            self:IsSemicolonStatement() then        return self:ReadSemicolonStatement() elseif
            self:IsGotoLabelStatement() then        return self:ReadGotoLabelStatement() elseif
            self:IsGotoStatement() then             return self:ReadGotoStatement() elseif
            self:IsRepeatStatement() then           return self:ReadRepeatStatement() elseif
            self:IsFunctionStatement() then         return self:ReadFunctionStatement() elseif
            self:IsLocalAssignmentStatement() then  return self:ReadLocalAssignmentStatement() elseif
            self:IsDoStatement() then               return self:ReadDoStatement() elseif
            self:IsIfStatement() then               return self:ReadIfStatement() elseif
            self:IsWhileStatement() then            return self:ReadWhileStatement() elseif
            self:IsForStatement() then              return self:ReadForStatement()
        end

        return self:ReadRemainingStatement()
    end

end

do
    function META:IsSemicolonStatement()
        return self:IsValue(";")
    end

    function META:ReadSemicolonStatement()
        local node = self:NewStatement("semicolon")
        node.tokens[";"] = self:ReadToken()
        return node
    end
end

do
    function META:IsBreakStatement()
        return self:IsValue("break")
    end

    function META:ReadBreakStatement()
        local node = self:NewStatement("break")
        node.tokens["break"] = self:ReadToken()
        return node
    end
end

do
    function META:IsReturnStatement()
        return self:IsValue("return")
    end

    function META:ReadReturnStatement()
        local node = self:NewStatement("return")
        node.tokens["return"] = self:ReadToken()
        node.expressions = self:ReadExpressionList()
        return node
    end
end

do -- do
    function META:IsDoStatement()
        return self:IsValue("do")
    end

    function META:ReadDoStatement()

        local node = self:NewStatement("do")
        node.tokens["do"] = self:ReadToken()
        self:PushScope(node)
        node.statements = self:ReadStatements({["end"] = true})
        self:PopScope()
        node.tokens["end"] = self:ReadExpectValue("end", node.tokens["do"], node.tokens["do"])

        return node
    end
end

do -- while
    function META:IsWhileStatement()
        return self:IsValue("while")
    end

    function META:ReadWhileStatement()
        local node = self:NewStatement("while")

        node.tokens["while"] = self:ReadToken()
        node.expression = self:ReadExpectExpression()
        node.tokens["do"] = self:ReadExpectValue("do")
        self:PushScope(node)
        node.statements = self:ReadStatements({["end"] = true})
        self:PopScope()
        node.tokens["end"] = self:ReadExpectValue("end", node.tokens["while"], node.tokens["while"])

        return node
    end
end

do -- repeat
    function META:IsRepeatStatement()
        return self:IsValue("repeat")
    end

    function META:ReadRepeatStatement()
        local node = self:NewStatement("repeat")

        node.tokens["repeat"] = self:ReadToken()
        self:PushScope(node)
        node.statements = self:ReadStatements({["until"] = true})
        self:PopScope()
        node.tokens["until"] = self:ReadExpectValue("until", node.tokens["repeat"], node.tokens["repeat"])
        node.expression = self:ReadExpectExpression()

        return node
    end
end

do -- goto label
    function META:IsGotoLabelStatement()
        return self:IsValue("::")
    end

    function META:ReadGotoLabelStatement()
        local node = self:NewStatement("goto_label")

        node.tokens["::left"] = self:ReadToken()
        node.identifier = self:ReadExpectType("letter")
        node.tokens["::right"]  = self:ReadExpectValue("::")

        return node
    end
end

do -- goto statement
    function META:IsGotoStatement()
        return self:IsValue("goto") and self:IsType("letter", 1)
    end

    function META:ReadGotoStatement()
        local node = self:NewStatement("goto")

        node.tokens["goto"] = self:ReadToken()
        node.identifier = self:ReadExpectType("letter")

        return node
    end
end

do -- local
    function META:IsLocalAssignmentStatement()
        return self:IsValue("local")
    end

    function META:ReadLocalAssignmentStatement()
        local node = self:NewStatement("assignment")
        node.tokens["local"] = self:ReadToken()
        node.is_local = true

        node.identifiers = self:ReadIdentifierList()

        if self:IsValue("=") then
            node.tokens["="] = self:ReadToken("=")
            node.expressions = self:ReadExpressionList()
        end

        for i, v in ipairs(node.identifiers) do
            self:DeclareUpvalue(v, v, node.expressions and node.expressions[i] or nil)
        end

        return node
    end
end

do -- for
    function META:IsForStatement()
        return self:IsValue("for")
    end

    function META:ReadForStatement()
        local node = self:NewStatement("for")
        node.tokens["for"] = self:ReadToken()

        if self:IsType("letter") and self:IsValue("=", 1) then
            node.fori = true

            node.identifiers = self:ReadIdentifierList(1)
            node.tokens["="] = self:ReadToken()
            node.expressions = self:ReadExpressionList(3)
        else
            node.fori = false

            node.identifiers = self:ReadIdentifierList()
            node.tokens["in"] = self:ReadExpectValue("in")
            node.expressions = self:ReadExpressionList()
        end

        node.tokens["do"] = self:ReadExpectValue("do")


        self:PushScope(node)
        for i, v in ipairs(node.identifiers) do
            self:DeclareUpvalue(v, node.expressions[i] or node.expressions[1])
        end
        node.statements = self:ReadStatements({["end"] = true})
        self:PopScope()
        node.tokens["end"] = self:ReadExpectValue("end", node.tokens["do"], node.tokens["do"])

        return node
    end
end

do -- function
    function META:IsFunctionStatement()
        return
            self:IsValue("function") or
            (self:IsValue("local") and self:IsValue("function", 1))
    end

    function META:IsAnonymousFunction()
        return self:IsValue("function")
    end

    function META:ReadFunctionBody(node)
        node.tokens["("] = self:ReadExpectValue("(")
        node.identifiers = self:ReadIdentifierList()

        if self:IsValue("...") then
            local vararg = self:NewExpression("value")
            vararg.value = self:ReadToken()
            table_insert(node.identifiers, vararg)
        end

        node.tokens[")"] = self:ReadExpectValue(")")

        local start = self:GetToken()

        self:PushScope(node)
        if not node.is_local and node.expression and node.expression.value and node.expression.value.value == ":" then
            self:DeclareUpvalue("self", node.expression)
        end
        for _, v in ipairs(node.identifiers) do
            self:DeclareUpvalue(v)
        end
        node.statements = self:ReadStatements({["end"] = true})
        self:PopScope()

        node.tokens["end"] = self:ReadExpectValue("end", start, start)
    end

    function META:ReadFunctionExpression()
        local val = self:NewExpression("value")
        val.value = self:ReadExpectType("letter")

        while self:IsValue(".") or self:IsValue(":") do
            local op = self:GetToken()
            if not op then break end
            self:Advance(1)

            local left = val
            local right = self:ReadFunctionExpression()

            val = self:NewExpression("binary_operator")
            val.value = op
            val.left = val.left or left
            val.right = val.right or right
        end

        return val
    end

    function META:ReadFunctionStatement()
        local node = self:NewStatement("function")
        if self:IsValue("local") then
            node.is_local = true
            node.tokens["local"] = self:ReadToken()
            node.tokens["function"] = self:ReadExpectValue("function")
            node.name = self:ReadIdentifier() -- YUCK
            self:DeclareUpvalue(node.name, node)
            self:RecordUpvalueEvent("mutate", node.name, node)
        else
            node.is_local = false
            node.tokens["function"] = self:ReadExpectValue("function")
            node.expression = self:ReadFunctionExpression()

            self:RecordEvent("mutate", node.expression.left or node.expression, node)
        end
        self:ReadFunctionBody(node)
        return node
    end

    function META:ReadAnonymousFunction()
        local node = self:NewExpression("function")
        node.tokens["function"] = self:ReadExpectValue("function")
        self:ReadFunctionBody(node)
        return node
    end
end

do -- if
    function META:IsIfStatement()
        return self:IsValue("if")
    end

    function META:ReadIfStatement()
        local node = self:NewStatement("if")

        node.expressions = {}
        node.statements = {}
        node.tokens["if/else/elseif"] = {}
        node.tokens["then"] = {}

        for i = 1, self:GetLength() do
            local token

            if i == 1 then
                token = self:ReadExpectValue("if")
            else
                token = self:ReadExpectValues({["else"] = true, ["elseif"] = true, ["end"] = true})
            end

            if not token then return end

            node.tokens["if/else/elseif"][i] = token

            if token.value ~= "else" then
                node.expressions[i] = self:ReadExpectExpression()
                node.tokens["then"][i] = self:ReadExpectValue("then")
            end

            self:PushScope(node)
            node.statements[i] = self:ReadStatements({["end"] = true, ["else"] = true, ["elseif"] = true})
            self:PopScope()

            if self:IsValue("end") then
                break
            end
        end

        node.tokens["end"] = self:ReadExpectValue("end")

        return node
    end
end

do -- identifier
    function META:ReadIdentifier()
        local node = self:NewExpression("value")
        node.value = self:ReadExpectType("letter")
        return node
    end

    function META:ReadIdentifierList(max)
        local out = {}

        for i = 1, max or self:GetLength() do
            if not self:IsType("letter") then
                break
            end

            out[i] = self:ReadIdentifier()

            if not self:IsValue(",") then
                break
            end

            out[i].tokens[","] = self:ReadToken()
        end

        return out
    end
end

do -- expression
    function META:ReadExpectExpression(priority)
        if oh.syntax.IsDefinetlyNotStartOfExpression(self:GetToken()) then
            self:Error("expected beginning of expression, got ".. oh.QuoteToken(self:GetToken() and self:GetToken().value ~= "" and self:GetToken().value or self:GetToken().type))
            return
        end

        return self:ReadExpression(priority)
    end

    local function read_expression(self, priority)
        priority = priority or 0

        local node

        if self:IsValue("(") then
            local pleft = self:ReadToken()
            node = read_expression(self, 0)
            if not node then
                self:Error("empty parentheses group", pleft)
                return
            end

            node.tokens["("] = node.tokens["("] or {}
            table_insert(node.tokens["("], 1, pleft)

            node.tokens[")"] = node.tokens[")"] or {}
            table_insert(node.tokens[")"], self:ReadExpectValue(")"))

        elseif oh.syntax.IsPrefixOperator(self:GetToken()) then
            node = self:NewExpression("prefix_operator")
            node.value = self:ReadToken()
            node.right = read_expression(self, math_huge)
        elseif self:IsAnonymousFunction() then
            node = self:ReadAnonymousFunction()
        elseif oh.syntax.IsValue(self:GetToken()) or self:IsType("letter") then
            node = self:NewExpression("value")
            node.value = self:ReadToken()
        elseif self:IsValue("{") then
            node = self:ReadTable()
        end

        local first = node

        if node then
            for _ = 1, self:GetLength() do
                local left = node
                if not self:GetToken() then break end

                if self:IsValue(".") or self:IsValue(":") then
                    local op = self:GetToken()
                    local right_priority = oh.syntax.GetRightOperatorPriority(op)
                    if not op or not right_priority then break end
                    self:Advance(1)

                    local left = node
                    local right
                    if self:IsAnonymousFunction() then
                        right = self:ReadAnonymousFunction()
                    elseif oh.syntax.IsValue(self:GetToken()) or self:IsType("letter") then
                        right = self:NewExpression("value")
                        right.value = self:ReadToken()
                    elseif self:IsValue("{") then
                        right = self:ReadTable()
                    else
                        break
                    end

                    node = self:NewExpression("binary_operator")
                    node.value = op
                    node.left = left
                    node.right = right
                elseif oh.syntax.IsPostfixOperator(self:GetToken()) then
                    node = self:NewExpression("postfix_operator")
                    node.left = left
                    node.value = self:ReadToken()
                elseif self:IsValue("(") then
                    node = self:NewExpression("postfix_call")
                    node.left = left
                    node.tokens["call("] = self:ReadExpectValue("(")
                    node.expressions = self:ReadExpressionList()
                    node.tokens["call)"] = self:ReadExpectValue(")")
                elseif self:IsValue("{") or self:IsType("string") then
                    node = self:NewExpression("postfix_call")
                    node.left = left
                    if self:IsValue("{") then
                        node.expressions = {self:ReadTable()}
                    else
                        local val = self:NewExpression("value")
                        val.value = self:ReadToken()
                        node.expressions = {val}
                    end
                elseif self:IsValue("[") then
                    node = self:NewExpression("postfix_expression_index")
                    node.left = left
                    node.tokens["["] = self:ReadToken()
                    node.expression = self:ReadExpectExpression()
                    node.tokens["]"] = self:ReadExpectValue("]")
                else
                    break
                end
            end
        end

        if first and first.kind == "value" and (first.value.type == "letter" or first.value.value == "...") then
            self:RecordEvent("handle", first, node)
        end

        while oh.syntax.IsOperator(self:GetToken()) and oh.syntax.GetLeftOperatorPriority(self:GetToken()) > priority do
            local op = self:GetToken()
            local right_priority = oh.syntax.GetRightOperatorPriority(op)
            if not op or not right_priority then break end
            self:Advance(1)

            local left = node
            local right = read_expression(self, right_priority)

            node = self:NewExpression("binary_operator")
            node.value = op
            node.left = node.left or left
            node.right = node.right or right
        end

        return node
    end

    function META:ReadExpression(priority)
        return read_expression(self, priority)
    end

    function META:ReadExpressionList(max)
        local out = {}

        for i = 1, max or self:GetLength() do
            local exp = max and self:ReadExpectExpression() or self:ReadExpression()

            if not exp then
                break
            end

            out[i] = exp

            if not self:IsValue(",") then
                break
            end

            exp.tokens[","] = self:ReadToken()
        end

        return out
    end

    function META:ReadTable()
        local tree = self:NewExpression("table")

        tree.children = {}
        tree.tokens["{"] = self:ReadExpectValue("{")

        for i = 1, self:GetLength() do
            if self:IsValue("}") then
                break
            end

            local node

            if self:IsValue("[") then
                node = self:NewExpression("table_expression_value")

                node.tokens["["] = self:ReadToken()
                node.key = self:ReadExpectExpression()
                node.tokens["]"] = self:ReadExpectValue("]")
                node.tokens["="] = self:ReadExpectValue("=")
                node.expression_key = true
            elseif self:IsType("letter") and self:IsValue("=", 1) then
                node = self:NewExpression("table_key_value")

                node.key = self:ReadToken()
                node.tokens["="] = self:ReadToken()
            else
                node = self:NewExpression("table_index_value")

                node.key = i
            end

            node.value = self:ReadExpectExpression()

            tree.children[i] = node

            if not self:IsValue(",") and not self:IsValue(";") and not self:IsValue("}") then
                self:Error("expected ".. oh.QuoteTokens({",", ";", "}"}) .. " got " .. ((self:GetToken() and self:GetToken().value) or "no token"))
                break
            end

            if not self:IsValue("}") then
                node.tokens[","] = self:ReadToken()
            end
        end

        tree.tokens["}"] = self:ReadExpectValue("}")

        return tree
    end
end

function oh.Parser(config)
    return setmetatable({config = config}, META)
end