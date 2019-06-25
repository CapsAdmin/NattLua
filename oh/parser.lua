local oh = ...
local table_insert = table.insert
local table_remove = table.remove

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

        if self.type == "operator" or self.type == "unary" then
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

    function NODE:FindStatementsByType(what, out)
        out = out or {}
        for _, child in ipairs(self:GetChildren()) do
            if child.type == what then
                table.insert(out, child)
            elseif child.type ~= "function" and child:GetChildren() then
                child:FindStatementsByType(what, out)
            end
        end
        return out
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

    function NODE:ExpandExpression()
        assert(self.type == "expression" or self.type == "operator")

        local flat = {}

        local function expand(node)
            if node.type == "operator" then
                if node.left then
                    expand(node.left)
                end

                table.insert(flat, node)

                if node.right then
                    expand(node.right)
                end
            else
                table.insert(flat, node)
            end
        end

        expand(self)

        local i = 1

        return function()
            local l,o,r = flat[i + 0], flat[i + 1], flat[i + 2]
            if r then
                i = i + 2
                return l,o,r
            end
        end
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
            for i,v in ipairs(self.clauses) do
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

function META:GetToken()
    return self.chunks[self.i] and self.chunks[self.i].type ~= "end_of_file" and self.chunks[self.i] or nil
end

function META:GetTokenOffset(offset)
    return self.chunks[self.i + offset]
end

function META:ReadToken()
    local tk = self:GetToken()
    self:Advance(1)
    return tk
end

function META:IsValue(str)
    return self.chunks[self.i] and self.chunks[self.i].value == str and self.chunks[self.i]
end

function META:IsType(str)
    local tk = self:GetToken()
    return tk and tk.type == str
end

function META:ReadExpectType(type, start, stop)
    local tk = self:GetToken()
    if not tk then
        self:Error("expected " .. oh.QuoteToken(type) .. " reached end of code", start, stop, 3, -1)
    elseif tk.type ~= type then
        self:Error("expected " .. oh.QuoteToken(type) .. " got " .. oh.QuoteToken(tk.type) .. "(" .. tk.value .. ")", start, stop, 3, -1)
    end
    self:Advance(1)
    return tk
end

function META:ReadExpectValue(value, start, stop)
    local tk = self:ReadToken()
    if not tk then
        self:Advance(-1)
        self:Error("expected " .. oh.QuoteToken(value) .. ": reached end of code", start, stop)
        self:Advance(1)
    elseif tk.value ~= value then
        self:Advance(-1)
        self:Error("expected " .. oh.QuoteToken(value) .. ": got " .. oh.QuoteToken(tk.value), start, stop)
        self:Advance(1)
    end
    return tk
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
        local tk = self:GetToken()
        if not tk then
            self:Error("expected " .. oh.QuoteTokens(values) .. ": reached end of code", start, stop)
        elseif not table_hasvalue(values, tk.value) then
            self:Error("expected " .. oh.QuoteTokens(values) .. " got " .. tk.value, start, stop)
        end
        self:Advance(1)
        return tk
    end
end

function META:GetLength()
    return self.chunks_length
end

function META:Advance(offset)
    self.i = self.i + offset
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

    if self.chunks[#self.chunks] and self.chunks[#self.chunks].type == "end_of_file" then
        local eof = self:NewStatement("end_of_file")
        eof.tokens["end_of_file"] = self.chunks[#self.chunks]
        table.insert(node.statements, eof)
    end

    return node
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

do -- do
    function META:IsDoStatement()
        return self:IsValue("do")
    end

    function META:ReadDoStatement()
        local start = self:GetToken()

        local node = self:NewStatement("do")
        node.tokens["do"] = self:ReadToken()
        node.statements = self:ReadStatements({["end"] = true})
        node.tokens["end"] = self:ReadExpectValue("end", start, start)

        return node
    end
end

do -- while
    function META:IsWhileStatement()
        return self:IsValue("while")
    end

    function META:ReadWhileStatement()
        local node = self:NewStatement("while")

        local start = self:GetToken()

        node.tokens["while"] = self:ReadToken()
        node.expressions = {self:ReadExpression()}
        node.tokens["do"] = self:ReadExpectValue("do")

        node.statements = self:ReadStatements({["end"] = true})

        node.tokens["end"] = self:ReadExpectValue("end", start, start)

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

        if self:IsType("letter") and self:GetTokenOffset(1).value == "=" then
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
            (self:IsValue("local") and self:GetTokenOffset(1).value == "function")
    end

    function META:IsAnonymousFunction()
        return self:IsValue("function")
    end

    local function read_function(self, node, anon)
        if anon then
            node.tokens["function"] = self:ReadExpectValue("function")
        elseif self:IsValue("local") then
            node.is_local = true
            node.tokens["local"] = self:ReadToken()
            node.tokens["function"] = self:ReadExpectValue("function")
            node.name = self:ReadIdentifier() -- YUCK
        else
            node.is_local = false
            node.tokens["function"] = self:ReadExpectValue("function")
            node.expressions = {self:ReadExpression(nil, true)}
        end

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

        return node
    end

    function META:ReadFunctionStatement()
        local node = self:NewStatement("function")
        return read_function(self, node, false)
    end

    function META:ReadAnonymousFunction()
        local node = self:NewExpression("function")
        return read_function(self, node, true)
    end
end

do -- goto
    function META:IsGotoLabelStatement()
        return self:IsValue("::")
    end

    function META:ReadGotoLabelStatement()
        local node = self:NewStatement("goto_label")

        node.tokens["::left"] = self:ReadToken()
        node.identifiers = {self:ReadExpectType("letter")}
        node.tokens["::right"]  = self:ReadExpectValue("::")

        return node
    end

    function META:IsGotoStatement()
        -- letter check is needed for cases like 'goto:foo()'
        return self:IsValue("goto") and self:GetTokenOffset(1).type == "letter"
    end

    function META:ReadGotoStatement()

        local node = self:NewStatement("goto")

        node.tokens["goto"] = self:ReadToken()
        node.identifiers = {self:ReadExpectType("letter")}

        return node
    end
end

do -- identifier
    function META:ReadIdentifier()
        local node = self:NewExpression("value")
        node.value = self:ReadExpectType("letter")
        return node
    end

    function META:IdentifierList(max, with_vararg)
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
                token = self:ReadExpectValues({"else", "elseif"})
            end

            if not token then return end

            node.tokens["if/else/elseif"][i] = token

            if token.value ~= "else" then
                node.expressions[i] = self:ReadExpression()
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
        local start = self:GetToken()

        local node = self:NewStatement("repeat")

        node.tokens["repeat"] = self:ReadToken()
        node.statements = self:ReadStatements({["until"] = true})
        node.tokens["until"] = self:ReadExpectValue("until", start, start)
        node.expressions = {self:ReadExpression()}

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
    local start_token = self:GetToken()
    local expr = self:ReadExpression(nil, nil, true)

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
    elseif expr and expr.suffixes and expr.suffixes[#expr.suffixes].kind == "call" then
        node = self:NewExpression("expression")
        node.value = expr
    else
        self:Error("unexpected " .. start_token.type, start_token)
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
        self:IsForStatement() then              return self:ReadForStatement() else
                                                return self:ReadRemainingStatement()
    end

    local type = self:GetToken().type

    if oh.syntax.IsKeyword(self:GetToken()) then
        type = "keyword"
    end

    self:Error("unexpected " .. type)
end

function META:ReadExpression(priority, stop_on_call, non_explicit)
    priority = priority or 0

    local token = self:GetToken()

    if not token then
        self:Error("attempted to read expression but reached end of code")
        return
    end

    if not non_explicit and oh.syntax.IsDefinetlyNotStartOfExpression(token) then
        self:Error("expected beginning of expression, got ".. oh.QuoteToken(token.value))
        return
    end

    local val

    if oh.syntax.IsUnaryOperator(token) then
        val = self:NewExpression("unary_operator")
        val.value = self:ReadToken()
        val.right = self:ReadExpression(math.huge, stop_on_call)
    elseif self:IsValue("(") then
        local pleft = self:ReadToken()
        val = self:ReadExpression(0, stop_on_call)
        if not val then
            self:Error("empty parentheses group", token)
            return
        end

        val.tokens["("] = val.tokens["("] or {}
        table_insert(val.tokens["("], 1, pleft)

        if val.suffixes then
            local val = val.suffixes[#val.suffixes]
            val.tokens[")"] = val.tokens[")"] or {}
            table_insert(val.tokens[")"], 1, self:ReadExpectValue(")"))
        else
            val.tokens[")"] = val.tokens[")"] or {}
            table_insert(val.tokens[")"], 1, self:ReadExpectValue(")"))
        end

    elseif self:IsAnonymousFunction() then
        val = self:ReadAnonymousFunction()
    elseif oh.syntax.IsValue(token) or (token.type == "letter" and not oh.syntax.IsKeyword(token)) then
        val = self:NewExpression("value")
        val.value = self:ReadToken()
    elseif token.value == "{" then
        val = self:ReadTable()
    end

    token = self:GetToken()

    if token and val and (
        token.value == "." or
        token.value == ":" or
        token.value == "[" or
        token.value == "(" or
        token.value == "{" or
        token.type == "string"
    ) then
        local suffixes = val.suffixes or {}

        for _ = 1, self:GetLength() do
            if not self:GetToken() then break end

            local node

            if self:IsValue(".") then
                node = self:NewExpression("index")
                node.tokens["."] = self:ReadToken()
                node.value = self:ReadExpectType("letter")
            elseif self:IsValue(":") then
                local nxt = self:GetTokenOffset(2)
                if nxt.type == "string" or nxt.value == "(" or nxt.value == "{" then
                    node = self:NewExpression("self_index")
                    node.tokens[":"] = self:ReadToken()
                    node.value = self:ReadExpectType("letter")
                else
                    break
                end
            elseif self:IsValue("[") then
                node = self:NewExpression("index_expression")

                node.tokens["["] = self:ReadToken()
                node.value = self:ReadExpression(0, stop_on_call)
                node.tokens["]"] = self:ReadExpectValue("]")
            elseif self:IsValue("(") then

                if stop_on_call then
                    if suffixes[1] then
                        val.suffixes = suffixes
                    end
                    return val
                end

                local start = self:GetToken()

                local pleft = self:ReadToken()
                node = self:NewExpression("call")

                node.tokens["call("] = pleft
                node.value = self:ReadExpressionList()
                node.tokens["call)"] = self:ReadExpectValue(")", start)
            elseif self:IsValue("{") then
                node = self:NewExpression("call")
                node.value = {self:ReadTable()}
            elseif self:IsType("string") then
                node = self:NewExpression("call")
                node.value = {self:NewExpression("value")}
                node.value[1].value = self:ReadToken()
            elseif self:IsType("literal_string") then
                node = self:NewExpression("call")
                node.value = {self:LiteralString()}
            else
                break
            end

            table_insert(suffixes, node)
        end

        if suffixes[1] then
            val.suffixes = suffixes
        end
    end

    if self:GetToken() then
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
    end

    return val
end

function META:ReadExpressionList(max)
    local out = {}

    for _ = 1, max or self:GetLength() do
        local exp = self:ReadExpression(nil, nil, true)

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
            node.key = self:ReadExpression()
            node.tokens["]"] = self:ReadExpectValue("]")
            node.tokens["="] = self:ReadExpectValue("=")
            node.value = self:ReadExpression()
            node.expression_key = true
        elseif self:IsType("letter") and self:GetTokenOffset(1).value == "=" then
            node = self:NewExpression("table_key_value")
            node.key = self:ReadToken()
            node.tokens["="] = self:ReadToken()
            node.value = self:ReadExpression()
        else
            node = self:NewExpression("table_index_value")
            node.value = self:ReadExpression()
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
            self:Error("expected ".. oh.QuoteTokens(",;}") .. " got " .. (self:GetToken().value or "no token"))
        end

        node.tokens[","] = self:ReadToken()
    end

    tree.tokens["}"] = self:ReadExpectValue("}")

    return tree
end

function oh.Parser(config)
    return setmetatable({config = config}, META)
end