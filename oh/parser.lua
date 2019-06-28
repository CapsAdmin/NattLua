local oh = ...
local table_insert = table.insert

local META = {}
META.__index = META

do
    local NODE = {}
    NODE.__index = NODE

    function NODE:__tostring()
        return "node[" .. self.type .. "]"
    end

    function NODE:Render(what)
        local em = oh.LuaEmitter({preserve_whitespace = false})

        if what and self.tokens[what] then
            em:EmitToken(self.tokens[what])
            return em:Concat()
        end

        if self.type == "operator" or self.type == "prefix" then
            em:ReadExpression(self)
        elseif self.type == "block" then
            em:Block(self)
        else
            em:EmitStatement(self)
        end

        return em:Concat()
    end

    function NODE:GetArguments()
        return self.arguments
    end

    function NODE:FindByType(what, out)
        out = out or {}
        for _, child in ipairs(self:GetChildren()) do
            if child.type == what then
                table.insert(out, child)
            elseif child:GetChildren() then
                child:FindByType(what, out)
            end
        end
        return out
    end

    function NODE:GetStatements()
        if self.block then
            return self.block:GetStatements()
        end
        return self.statements
    end

    function NODE:GetChildren()
        if self.clauses then
            local out = {}
            for _, v in ipairs(self.clauses) do
                table.insert(out, v.block)
            end
            return out
        end

        if self.block then
            return self.block.statements
        end

        return self.statements or self.children or self.values or self.expressions
    end

    function NODE:Assignments()
        assert(self.type == "assignment")

        local i = 1

        return function()
            local l, r = self.lvalues[i], self.rvalues and self.rvalues[i]
            i = i + 1
            return l, r
        end
    end

    function NODE:IsType(what)
        return self.type == what
    end

    function NODE:IsValue(val)
        return self.value and self.value.value == val
    end

    function NODE:SetValue(val)
        assert(self.value or self.operator)

        if self.operator then
            self.operator = val
            self.tokens["operator"].value = val
        else
            self.value.value = val
        end
    end

    do
        local STATEMENT = {}
        STATEMENT.__index = STATEMENT
        STATEMENT.type = "statement"

        function STATEMENT:__tostring()
            return "[" .. self.type .. " - " .. self.kind .. "] " .. ("%p"):format(self)
        end

        function STATEMENT:Render()
            local em = oh.LuaEmitter({preserve_whitespace = false})

            em:EmitStatement(self)

            return em:Concat()
        end

        function STATEMENT:GetStatements()
            if self.kind == "if" then
                local flat = {}
                for _, statements in ipairs(self.statements) do
                    for _, v in ipairs(statements) do
                        table.insert(flat, v)
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
                    table.insert(out, child)
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
        local EXPRESSSION = {}
        EXPRESSSION.__index = EXPRESSSION
        EXPRESSSION.type = "expression"

        function EXPRESSSION:__tostring()
            return "[" .. self.type .. " - " .. self.kind .. "] " .. ("%p"):format(self)
        end

        function EXPRESSSION:Render()
            local em = oh.LuaEmitter({preserve_whitespace = false})

            em:EmitExpression(self)

            return em:Concat()
        end

        do
            local function expand(node, tbl)
                if node.left then
                    expand(node.left, tbl)
                end

                table.insert(tbl, node)

                if node.right then
                    expand(node.right, tbl)
                end
            end

            function EXPRESSSION:Walk()
                local flat = {}

                expand(self, flat)

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

            setmetatable(node, EXPRESSSION)

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
        return self.chunks[self.i + offset]
    end
    return self.chunks[self.i]
end

function META:ReadToken()
    self:Advance(1)
    return self:GetToken(-1)
end

function META:IsValue(str, offset)
    if offset then
        return self.chunks[self.i + offset] and self.chunks[self.i + offset].value == str
    end
    return self.chunks[self.i] and self.chunks[self.i].value == str
end

function META:IsType(str, offset)
    if offset then
        return self:GetToken(offset) and self:GetToken(offset).type == str
    end
    return self:GetToken() and self:GetToken().type == str
end

function META:ReadExpectType(type, start, stop)
    if not self:GetToken() then
        self:Error("expected " .. oh.QuoteToken(type) .. " reached end of code", start, stop, 3, -1)
    elseif not self:IsType(type) then
        self:Error("expected " .. oh.QuoteToken(type) .. " got " .. oh.QuoteToken(self:GetToken().type) .. "(" .. self:GetToken().value .. ")", start, stop, 3, -1)
    end
    
    return self:ReadToken()
end

function META:ReadExpectValue(value, start, stop)

    if not self:GetToken() then
        self:Error("expected " .. oh.QuoteToken(value) .. ": reached end of code", start, stop)
    elseif not self:IsValue(value) then
        self:Error("expected " .. oh.QuoteToken(value) .. ": got " .. oh.QuoteToken(self:GetToken().value), start, stop)
    end

    return self:ReadToken()
end

do
    local function table_hasvalue(tbl, val)
        for k,v in ipairs(tbl) do
            if v == val then
                return k
            end
        end

        return false
    end

    function META:ReadExpectValues(values, start, stop)
        if not self:GetToken() then
            self:Error("expected " .. oh.QuoteTokens(values) .. ": reached end of code", start, stop)
        elseif not table_hasvalue(values, self:GetToken().value) then
            local tk = self:GetToken()
            self:Error("expected " .. oh.QuoteTokens(values) .. " got " .. (tk.value == "" and tk.type or tk.value), start, stop)
        end

        return self:ReadToken()
    end
end

function META:GetLength()
    return self.chunks_length
end

function META:Advance(offset)
    self.i = self.i + offset
end

function META:BuildAST(tokens)
    self.chunks = tokens
    self.chunks_length = #tokens
    self.i = 1

    if self.config then
        if self.config.record_nodes then
            self.NodeRecord = {}
            self.NodeRecordI = 1
        end
    end

    return self:Root()
end

function META:Root()
    local node = self:NewStatement("root")

    local shebang

    if self:IsType("shebang") then
        shebang = self:NewStatement("shebang")
        shebang.tokens["shebang"] = self:ReadToken()
    end

    node.statements = self:ReadStatements()

    if shebang then
        table.insert(node.statements, 1, shebang)
    end

    if self:IsType("end_of_file") then
        local eof = self:NewStatement("end_of_file")
        eof.tokens["end_of_file"] = self.chunks[#self.chunks]
        table.insert(node.statements, eof)
    end

    return node
end

do -- statements
    function META:ReadStatements(stop_token)
        local out = {}

        for _ = 1, self:GetLength() do
            if not self:GetToken() or stop_token and stop_token[self:GetToken().value] then
                break
            end

            local statement = self:ReadStatement()

            if statement then
                table_insert(out, statement)
            end
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
            node.expressions_right = self:ReadExpressionList()
        elseif self:IsValue(",") then
            node = self:NewStatement("assignment")
            expr.tokens[","] = self:ReadToken()
            local list = self:ReadExpressionList()
            table_insert(list, 1, expr)
            node.expressions_left = list
            node.tokens["="] = self:ReadExpectValue("=")
            node.expressions_right = self:ReadExpressionList()
        elseif expr then
            node = self:NewStatement("expression")
            node.value = expr
        elseif not self:IsType("end_of_file") then
            local type = start.type

            if oh.syntax.IsKeyword(self:GetToken()) then
                type = "keyword"
            end
    
            self:Error("unexpected " .. type .. " while trying to read assignment or call statement", start, start)
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

do -- do
    function META:IsDoStatement()
        return self:IsValue("do")
    end

    function META:ReadDoStatement()

        local node = self:NewStatement("do")
        node.tokens["do"] = self:ReadToken()
        node.statements = self:ReadStatements({["end"] = true})
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
        node.statements = self:ReadStatements({["end"] = true})
        node.tokens["end"] = self:ReadExpectValue("end", node.tokens["while"], node.tokens["while"])

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

            node.identifiers = self:IdentifierList(1)
            node.tokens["="] = self:ReadToken()
            node.expressions = self:ReadExpressionList(3)
        else
            node.fori = false

            node.identifiers = self:IdentifierList()
            node.tokens["in"] = self:ReadExpectValue("in")
            node.expressions = self:ReadExpressionList()
        end

        node.tokens["do"] = self:ReadExpectValue("do")

        node.statements = self:ReadStatements({["end"] = true})

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
        node.identifiers = self:IdentifierList()
        if self:IsValue("...") then
            local vararg = self:NewExpression("value")
            vararg.value = self:ReadToken()
            table.insert(node.identifiers, vararg)
        end
        node.tokens[")"] = self:ReadExpectValue(")")

        local start = self:GetToken()

        node.statements = self:ReadStatements({["end"] = true})

        node.tokens["end"] = self:ReadExpectValue("end", start, start)
    end

    function META:ReadFunctionStatement()
        local node = self:NewStatement("function")
        if self:IsValue("local") then
            node.is_local = true
            node.tokens["local"] = self:ReadToken()
            node.tokens["function"] = self:ReadExpectValue("function")
            node.name = self:ReadIdentifier() -- YUCK
        else
            node.is_local = false
            node.tokens["function"] = self:ReadExpectValue("function")
            node.expressions = {self:ReadExpression(nil, true)}
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

do -- goto
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

    function META:IsGotoStatement()
        -- letter check is needed for cases like 'goto:foo()'
        return self:IsValue("goto") and self:IsType("letter", 1)
    end

    function META:ReadGotoStatement()
        local node = self:NewStatement("goto")

        node.tokens["goto"] = self:ReadToken()
        node.identifier = self:ReadExpectType("letter")

        return node
    end
end

do -- identifier
    function META:ReadIdentifier()
        local node = self:NewExpression("value")
        node.value = self:ReadExpectType("letter")
        return node
    end

    function META:IdentifierList(max)
        local out = {}

        for _ = 1, max or self:GetLength() do
            if not self:IsType("letter") then
                break
            end

            local node = self:ReadIdentifier()

            table.insert(out, node)

            if not self:IsValue(",") then
                break
            end

            node.tokens[","] = self:ReadToken()
        end

        return out
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
                token = self:ReadExpectValues({"else", "elseif", "end"})
            end

            if not token then return end

            node.tokens["if/else/elseif"][i] = token

            if token.value ~= "else" then
                node.expressions[i] = self:ReadExpectExpression()
                node.tokens["then"][i] = self:ReadExpectValue("then")
            end

            node.statements[i] = self:ReadStatements({["end"] = true, ["else"] = true, ["elseif"] = true})

            if self:IsValue("end") then
                break
            end
        end

        node.tokens["end"] = self:ReadExpectValue("end")

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

        node.identifiers = self:IdentifierList()

        if self:IsValue("=") then
            node.tokens["="] = self:ReadToken("=")
            node.expressions = self:ReadExpressionList()
        end

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
        node.statements = self:ReadStatements({["until"] = true})
        node.tokens["until"] = self:ReadExpectValue("until", node.tokens["repeat"], node.tokens["repeat"])
        node.expression = self:ReadExpectExpression()

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
    function META:IsSemicolonStatement()
        return self:IsValue(";")
    end

    function META:ReadSemicolonStatement()
        local node = self:NewStatement("semicolon")
        node.tokens[";"] = self:ReadToken()
        return node
    end
end

do -- expression
    function META:ReadExpectExpression(priority, stop_on_call)
        if oh.syntax.IsDefinetlyNotStartOfExpression(self:GetToken()) then
            self:Error("expected beginning of expression, got ".. oh.QuoteToken(self:GetToken() and self:GetToken().value or "no token"))
            return
        end

        return self:ReadExpression(priority, stop_on_call)
    end

    function META:ReadExpression(priority, stop_on_call)
        priority = priority or 0

        local val

        if self:IsValue("(") then
            local pleft = self:ReadToken()
            val = self:ReadExpression(0, stop_on_call)
            if not val then
                self:Error("empty parentheses group", pleft)
                return
            end

            val.tokens["("] = val.tokens["("] or {}
            table_insert(val.tokens["("], 1, pleft)

            val.tokens[")"] = val.tokens[")"] or {}
            table_insert(val.tokens[")"], 1, self:ReadExpectValue(")"))

        elseif oh.syntax.IsPrefixOperator(self:GetToken()) then
            val = self:NewExpression("prefix_operator")
            val.value = self:ReadToken()
            val.right = self:ReadExpression(math.huge, stop_on_call)
        elseif self:IsAnonymousFunction() then
            val = self:ReadAnonymousFunction()
        elseif oh.syntax.IsValue(self:GetToken()) or (self:IsType("letter") and not oh.syntax.IsKeyword(self:GetToken())) then
            val = self:NewExpression("value")
            val.value = self:ReadToken()
        elseif self:IsValue("{") then
            val = self:ReadTable()
        end

        if val then
            for _ = 1, self:GetLength() do
                if not self:GetToken() then break end

                if oh.syntax.IsPostfixOperator(self:GetToken()) then
                    local left = val
                    val = self:NewExpression("postfix_operator")
                    val.value = self:ReadToken()
                    val.left = left
                elseif self:IsValue("(") then
                    if stop_on_call then
                        return val
                    end

                    local left = val
                    val = self:NewExpression("postfix_call")
                    val.tokens["call("] = self:ReadExpectValue("(")
                    val.expressions = self:ReadExpressionList()
                    val.tokens["call)"] = self:ReadExpectValue(")")

                    val.left = left
                elseif self:IsValue("{") or self:IsType("string") then
                    if stop_on_call then
                        return val
                    end

                    local left = val
                    val = self:NewExpression("postfix_call")
                    val.expressions = {self:ReadExpression()}
                    val.left = left
                elseif self:IsValue("[") then
                    local left = val
                    val = self:NewExpression("postfix_expression_index")
                    val.tokens["["] = self:ReadToken()
                    val.expression = self:ReadExpectExpression()
                    val.tokens["]"] = self:ReadExpectValue("]")
                    val.left = left
                else
                    break
                end
            end
        end

        while self:GetToken() and oh.syntax.IsOperator(self:GetToken()) and oh.syntax.GetLeftOperatorPriority(self:GetToken()) > priority do
            local op = self:GetToken()
            local right_priority = oh.syntax.GetRightOperatorPriority(op)
            if not op or not right_priority then break end
            self:Advance(1)

            local right = self:ReadExpression(right_priority, stop_on_call)
            local left = val

            val = self:NewExpression("binary_operator")
            val.left = left
            val.value = op
            val.right = right
        end

        return val
    end

    function META:ReadExpressionList(max)
        local out = {}

        for _ = 1, max or self:GetLength() do
            local exp = max and self:ReadExpectExpression() or self:ReadExpression()

            if not exp then
                break
            end

            table_insert(out, exp)

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
            local node

            if self:IsValue("}") then
                break
            elseif self:IsValue("[") then
                node = self:NewExpression("table_expression_value")

                node.tokens["["] = self:ReadToken()
                node.key = self:ReadExpectExpression()
                node.tokens["]"] = self:ReadExpectValue("]")
                node.tokens["="] = self:ReadExpectValue("=")
                node.value = self:ReadExpectExpression()
                node.expression_key = true
            elseif self:IsType("letter") and self:IsValue("=", 1) then
                node = self:NewExpression("table_key_value")
                node.key = self:ReadToken()
                node.tokens["="] = self:ReadToken()
                node.value = self:ReadExpectExpression()
            else
                node = self:NewExpression("table_index_value")
                node.value = self:ReadExpectExpression()
                node.key = i
                if not node.value then
                    self:Error("expected expression got nothing")
                end
            end

            table_insert(tree.children, node)

            if self:IsValue("}") then
                break
            end

            if not self:IsValue(",") and not self:IsValue(";") then
                self:Error("expected ".. oh.QuoteTokens({",", ";", "}"}) .. " got " .. ((self:GetToken() and self:GetToken().value) or "no token"))
            end

            node.tokens[","] = self:ReadToken()
        end

        tree.tokens["}"] = self:ReadExpectValue("}")

        return tree
    end
end

function oh.Parser(config)
    return setmetatable({config = config}, META)
end