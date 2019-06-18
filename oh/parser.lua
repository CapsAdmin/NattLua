local oh = ...
local table_insert = table.insert
local table_remove = table.remove

local META = {}
META.__index = META

function META:Node(t)
    local node = {}

    node.type = t
    node.tokens = {}

    return node
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
        self:Error("expected " .. oh.QuoteToken(value) .. ": reached end of code", start, stop, 3, -1)
    elseif tk.value ~= value then
        self:Error("expected " .. oh.QuoteToken(value) .. ": got " .. oh.QuoteToken(tk.value), start, stop, 3, -1)
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

function META:PushLoopBlock(node)
    table_insert(self.loop_stack, node)
end

function META:PopLoopBlock()
    table_remove(self.loop_stack)
end

do
    function META:PushNode(type)
        local node = self:Node(type)
        self.node_stack = self.node_stack or {}
        node.parent = self.node_stack[#self.node_stack]
        table.insert(self.node_stack, node)

        if node.parent then
            node.parent.children = node.parent.children or {}
            table.insert(node.parent.children, node)
        end

        return node
    end

    function META:PopNode()
        table.remove(self.node_stack)
    end

    function META:StoreToken(what, tk)
        self.node_stack[#self.node_stack].tokens[what] = tk
    end

    function META:Store(key, val)
        self.node_stack[#self.node_stack][key] = val
    end
end

function META:BuildAST(tokens)
    self.chunks = tokens
    self.chunks_length = #tokens
    self.i = 1
    self.loop_stack = {}

    local shebang

    if self:IsType("shebang") then
        shebang = self:Node("shebang")
        shebang.tokens["shebang"] = self:ReadToken()
    end

    local block = self:Block()

    if shebang then
        table.insert(block.statements, 1, shebang)
    end

    if tokens[#tokens] and tokens[#tokens].type == "end_of_file" then
        local node = self:Node("end_of_file")
        node.tokens["end_of_file"] = tokens[#tokens]
        table.insert(block.statements, node)
    end

    return block
end

do -- compiler option
    function META:IsCompilerOption()
        return self:IsType("compiler_option")
    end

    function META:ReadCompilerOption()
        local node = self:Node("compiler_option")
        node.lua = self:ReadToken().value:sub(3)

        if node.lua:sub(1, 2) == "P:" then
            assert(loadstring("local self = ...;" .. node.lua:sub(3)))(self)
        end
        return node
    end
end

do -- do
    function META:IsDoStatement()
        return self:IsValue("do")
    end

    function META:ReadDoStatement()
        local token = self:GetToken()
        local node = self:Node("do")

        node.tokens["do"] = self:ReadToken()
        node.block = self:Block({["end"] = true})
        node.tokens["end"] = self:ReadExpectValue("end", token, token)

        return node
    end

end

do -- while
    function META:IsWhileStatement()
        return self:IsValue("while")
    end

    function META:ReadWhileStatement()
        local node = self:Node("while")

        node.tokens["while"] = self:ReadToken()
        node.expression = self:Expression()
        node.tokens["do"] = self:ReadExpectValue("do")

        self:PushLoopBlock(node)
        node.block = self:Block({["end"] = true})
        node.tokens["end"] = self:ReadExpectValue("end", node.tokens["while"], node.tokens["while"])
        self:PopLoopBlock()

        return node
    end
end

do -- for
    function META:IsForStatement()
        return self:IsValue("for")
    end

    function META:ReadForStatement()
        local node
        local for_token = self:ReadToken()

        local identifier = self:ReadIdentifier()

        if self:IsValue("=") then
            node = self:Node("for_i")
            node.identifier = identifier
            node.tokens["="] = self:ReadToken("=")
            node.expression = self:Expression()
            node.tokens[",1"] = self:ReadExpectValue(",")
            node.max = self:Expression()

            if self:IsValue(",") then
                node.tokens[",2"] = self:ReadToken()
                node.step = self:Expression()
            end

        else
            node = self:Node("for_kv")

            if self:IsValue(",") then
                identifier.tokens[","] = self:ReadToken()
                node.identifiers = self:IdentifierList({identifier})
            else
                node.identifiers = {identifier}
            end

            if self:IsValue("of") then
                node.of = true
                node.tokens["of"] = self:ReadExpectValue("of")
            else
                node.tokens["in"] = self:ReadExpectValue("in")
            end
            node.expressions = self:ExpressionList()
        end


        node.tokens["for"] = for_token

        self:PushLoopBlock(node)
        node.tokens["do"] = self:ReadExpectValue("do")
        node.block = self:Block({["end"] = true})
        node.tokens["end"] = self:ReadExpectValue("end", for_token, for_token)
        self:PopLoopBlock()

        return node
    end
end

do -- function
    function META:IsFunctionStatement()
        return
            self:IsValue("function") or
            (self:IsValue("local") and self:GetTokenOffset(1).value == "function") or
            (self:IsValue("async") and self:GetTokenOffset(1).value == "function") or
            (self:IsValue("local") and self:GetTokenOffset(1).value == "async" and self:GetTokenOffset(2).value == "function")
    end

    local function read_short_call_body(self, node)

        local implicit_return = false

        if self:IsValue("(") then
            node.tokens["func("] = self:ReadToken("(")
        else
            implicit_return = true
        end

        node.arguments = self:IdentifierList()

        if self:IsValue(")") then
            node.tokens["func)"] = self:ReadToken(")")
        end

        if implicit_return then
            --[[

            node.block = {type = "block", statements = {ret}}
            node.no_end = true
            ]]
            node.block = self:Block({["end"] = true, [")"] = true}, true)
            node.no_end = true
        else
            node.block = self:Block({["end"] = true})
            node.tokens["end"] = self:ReadToken("end")
        end

        return node
    end

    local function read_call_body(self, node)
        local start = self:GetToken()

        node.tokens["func("] = self:ReadExpectValue("(")
        node.arguments = self:IdentifierList()
        node.tokens["func)"] = self:ReadExpectValue(")", start, start)
        node.block = self:Block({["end"] = true})
        node.tokens["end"] = self:ReadExpectValue("end")

        return node
    end

    function META:ReadFunctionStatement()
        local node = self:Node("function")

        if self:IsValue("local") then
            node.tokens["local"] = self:ReadToken("local")

            if self:IsValue("async") then
                node.tokens["async"] = self:ReadToken()
                node.async = true
            end

            node.tokens["function"] = self:ReadExpectValue("function")

            node.value = self:Node("value")
            node.value.value = self:ReadExpectType("letter")
            node.is_local = true
        else
            if self:IsValue("async") then
                node.tokens["async"] = self:ReadToken()
                node.async = true
            end
            node.tokens["function"] = self:ReadExpectValue("function")
            node.value = self:Expression(0, true)
        end

        return read_call_body(self, node)
    end

    function META:IsAnonymousFunction()
        return
            self:IsValue("function") or self:IsValue("do") or (self:IsValue("async") and self:GetTokenOffset(1).value == "function")
    end

    function META:AnonymousFunction()
        if self:IsValue("do") then
            local node = self:Node("function")
            node.tokens["function"] = self:ReadExpectValue("do")
            return read_short_call_body(self, node)
        else
            local node = self:Node("function")
            node.tokens["function"] = self:ReadExpectValue("function")

            return read_call_body(self, node)
        end
    end
end

do -- goto
    function META:IsGotoLabelStatement()
        return self:IsValue("::")
    end

    function META:ReadGotoLabelStatement()
        local node = self:Node("goto_label")

        node.tokens["::left"] = self:ReadToken()
        node.label = self:Node("value")
        node.label.value = self:ReadExpectType("letter")
        node.tokens["::right"]  = self:ReadExpectValue("::")

        return node
    end

    function META:IsGotoStatement()
        return self:IsValue("goto")
    end

    function META:ReadGotoStatement()
        local node = self:Node("goto")

        node.tokens["goto"] = self:ReadToken()
        node.label = self:Node("value")
        node.label.value = self:ReadExpectType("letter")

        return node
    end
end

do -- identifier
    function META:Type()
        local out = {}

        for _ = 1, self:GetLength() do
            local token = self:ReadToken()

            if not token then return out end

            local node = self:Node("value")
            node.value = token
            table.insert(out, node)

            if token.type == "letter" and self:IsValue("(") then
                local start = self:GetToken()

                node.tokens["func("] = self:ReadExpectValue("(")
                node.function_arguments = self:IdentifierList()
                node.tokens["func)"] = self:ReadExpectValue(")", start, start)
                node.tokens["return:"] = self:ReadExpectValue(":")
                node.function_return_type = self:Type()
            end

            if not self:IsValue("|") then
                break
            end

            node.tokens["|"] = self:ReadToken()
        end

        return out
    end

    function META:ReadAttributes()
        local out = {}

        for _ = 1, self:GetLength() do
            local node =  self:Node("attributes")
            node.tokens["@"] = self:ReadExpectValue("@")

            if self:IsValue("(") then
                node.tokens["("] = self:ReadExpectValue("(")
                node.name = self:ReadExpectType("letter")

                if not self:IsValue(")") then
                    node.arguments = self:ExpressionList()
                end

                node.tokens[")"] = self:ReadExpectValue(")")
            else
                node.name = self:ReadExpectType("letter")
            end

            out[_] = node

            if not self:IsValue("@") then
                break
            end

        end

        return out
    end

    function META:ReadIdentifier()
        local node = self:Node("value")

        if self:IsValue("@") then
            node.attributes = self:ReadAttributes()
        end

        if self:IsValue("{") then
            node.tokens["{"] = self:ReadExpectValue("{")
            node.destructor = self:IdentifierList(nil, true)
            node.tokens["}"] = self:ReadExpectValue("}")
        else
            node.value = self:ReadExpectType("letter")
        end

        if self:IsValue(":") then
            node.tokens[":"] = self:ReadToken(":")
            node.data_type = self:Type()
        end

        return node
    end

    function META:IdentifierList(out, destructor)
        out = out or {}

        for _ = 1, self:GetLength() do
            if not self:IsType("letter") and not self:IsValue("...") and not self:IsValue(":") and not self:IsValue("{") and not self:IsValue("@") then
                break
            end

            local node

            if self:IsValue("...") then
                node = self:Node("value")
                node.value = self:ReadToken()
                if self:IsValue(":") then
                    node.tokens[":"] = self:ReadToken(":")
                    node.data_type = self:Type()
                end
            else
                node = self:ReadIdentifier()
            end


            if destructor and self:IsValue("=") then
                self:ReadToken()
                node.default = self:Expression()
            end

            table.insert(out, node)

            if self:IsValue(",") then
                node.tokens[","] = self:ReadToken()
            else
                break
            end
        end

        return out
    end
end

do -- if
    function META:IsIfStatement()
        return self:IsValue("if")
    end

    function META:ReadIfStatement(out)
        local node = self:Node("if")

        node.clauses = {}

        local prev_token = self:GetToken()

        for _ = 1, self:GetLength() do

            if self:IsValue "end" then
                node.tokens["end"] = self:ReadToken()
                break
            end

            local clause = self:Node("clause")

            if self:IsValue("else") then
                clause.tokens["if/else/elseif"] = self:ReadToken()
                clause.block = self:Block({["end"] = true})
                clause.tokens["end"] = self:ReadExpectValue("end", prev_token, prev_token)
            else
                clause.tokens["if/else/elseif"] = self:ReadToken()
                clause.condition = self:Expression()
                clause.tokens["then"] = self:ReadExpectValue("then")
                clause.block = self:Block({["else"] = true, ["elseif"] = true, ["end"] = true})
                clause.tokens["end"] = self:ReadExpectValues({"else", "elseif", "end"}, prev_token, prev_token)
            end

            table.insert(node.clauses, clause)

            out.has_continue = node.clauses[#node.clauses].block.has_continue
            node.has_continue = out.has_continue

            prev_token = self:GetToken()

            self:Advance(-1) -- we want to read the else/elseif/end in the next iteration
        end
        return node
    end
end

do -- interface
    function META:IsInterfaceStatemenet()
        return self:IsValue("interface") and self:GetTokenOffset(1).type == "name" and self:GetTokenOffset(2).value == "do"
    end

    function META:ReadInterfaceStatement()
        local node = self:Node("interface")
        node.tokens["interface"] = self:ReadToken()
        node.name = self:ReadExpectType("letter")
        node.values = {}
        for i = 1, self:GetLength() do
            local val = self:ReadIdentifier()

            node.values[i] = val

            if self:IsValue("end") then
                break
            end

            if not self:IsValue(",") and not self:IsValue(";") then
                self:Error("expected ".. oh.QuoteTokens(",", ";", "}") .. " got " .. (self:GetToken() and self:GetToken().value or "no token"))
            end

            val.tokens[","] = self:ReadToken()

            if self:IsValue("end") then
                break
            end
        end
        node.tokens["end"] = self:ReadExpectValue("end")
        return node
    end
end

do -- struct
    function META:IsStructStatemenet()
        return
            (self:IsValue("struct") and self:GetTokenOffset(1).value == "do") or
            (self:IsValue("struct") and self:GetTokenOffset(1).type == "name" and self:GetTokenOffset(2).value == "do")
    end

    function META:ReadStructContent(node)
        node.tokens["do"] = self:ReadExpectValue("do")
        node.values = {}
        for i = 1, self:GetLength() do
            local val = self:ReadIdentifier()

            node.values[i] = val

            if self:IsValue("end") then
                break
            end

            if not self:IsValue(",") and not self:IsValue(";") then
                self:Error("expected ".. oh.QuoteTokens(",", ";", "}") .. " got " .. (self:GetToken() and self:GetToken().value or "no token"))
            end

            val.tokens[","] = self:ReadToken()

            if self:IsValue("end") then
                break
            end
        end
        node.tokens["end"] = self:ReadExpectValue("end")
        return node
    end

    function META:ReadStructStatement()
        local node = self:Node("struct")
        node.tokens["struct"] = self:ReadToken()
        node.name = self:ReadIdentifier()
        return self:ReadStructContent(node)
    end

    function META:ReadAnonymousStruct()
        local node = self:Node("struct")
        node.tokens["struct"] = self:ReadToken()
        return self:ReadStructContent(node)
    end
end

do -- local
    function META:IsLocalAssignmentStatement()
        return self:IsValue("local")
    end

    function META:ReadLocalAssignmentStatement()
        local node = self:Node("assignment")
        node.tokens["local"] = self:ReadToken()
        node.is_local = true

        node.lvalues = self:IdentifierList()

        if self:IsValue("=") then
            node.tokens["="] = self:ReadToken("=")
            node.rvalues = self:ExpressionList()
        end
        return node
    end
end

do -- repeat
    function META:IsRepeatStatement()
        return self:IsValue("repeat")
    end

    function META:ReadRepeatStatement()
        local token = self:GetToken()

        local node = self:Node("repeat")
        node.tokens["repeat"] = self:ReadToken()


        self:PushLoopBlock(node)
        node.block = self:Block({["until"] = true})
        node.tokens["until"] = self:ReadExpectValue("until", token, token)
        node.condition = self:Expression()
        self:PopLoopBlock()

        return node
    end
end

function META:Block(stop, implicit_return)
    local node = self:Node("block")
    node.statements = {}

    for _ = 1, self:GetLength() do
        if not self:GetToken() or stop and stop[self:GetToken().value] then

            if implicit_return then
                local last = node.statements[#node.statements]
                if last and last.type == "expression" then
                    local ret = self:Node("return")
                    ret.implicit = true
                    table_insert(node.statements, #node.statements, ret)
                end
            end

            break
        end

        local statement = self:Statement(node, implicit_return)

        if statement then
            if statement.type == "continue" then
                node.has_continue = true

                if self.loop_stack[1] then
                    self.loop_stack[#self.loop_stack].has_continue = true
                end
            end

            table_insert(node.statements, statement)
        end
    end

    return node
end

function META:Statement(block, implicit_return)

    do
        if self:IsValue("return") then
            local node = self:Node("return")
            node.tokens["return"] = self:ReadToken()
            node.expressions = self:ExpressionList()
            return node
        elseif self:IsValue("break") then
            local node = self:Node("break")
            node.tokens["break"] = self:ReadToken()
            return node
        elseif self:IsValue("continue") then
            local node = self:Node("continue")
            node.tokens["continue"] = self:ReadToken()
            return node
        end
    end

    if self:IsCompilerOption() then
        return self:ReadCompilerOption()
    elseif self:IsGotoLabelStatement() then
        return self:ReadGotoLabelStatement()
    elseif self:IsInterfaceStatemenet() then
        return self:ReadInterfaceStatement()
    elseif self:IsStructStatemenet() then
        return self:ReadStructStatement()
    elseif self:IsGotoStatement() then
        return self:ReadGotoStatement()
    elseif self:IsRepeatStatement() then
        return self:ReadRepeatStatement()
    elseif self:IsFunctionStatement() then
        return self:ReadFunctionStatement()
    elseif self:IsLocalAssignmentStatement() then
        return self:ReadLocalAssignmentStatement()
    elseif self:IsDoStatement() then
        local node = self:ReadDoStatement()
        block.has_continue = node.block.has_continue
        return node
    elseif self:IsIfStatement() then
        return self:ReadIfStatement(block)
    elseif self:IsWhileStatement() then
        return self:ReadWhileStatement()
    elseif self:IsForStatement() then
        return self:ReadForStatement()
    elseif self:IsValue("{") then
        local node = self:Node("assignment")
        node.destructor = true

        node.lvalues = self:IdentifierList()
        node.tokens["="] = self:ReadExpectValue("=")
        node.rvalues = self:ExpressionList()
        return node
    elseif (self:IsType("letter") or self:IsValue("(")) and not oh.syntax.IsKeyword(self:GetToken()) then
        local node
        local start_token = self:GetToken()
        local expr = self:Expression()

        if self:IsValue("=") then
            node = self:Node("assignment")
            node.lvalues = {expr}
            node.tokens["="] = self:ReadToken()
            node.rvalues = self:ExpressionList()
        elseif self:IsValue(",") then
            node = self:Node("assignment")
            expr.tokens[","] = self:ReadToken()
            local list = self:ExpressionList()
            table_insert(list, 1, expr)
            node.lvalues = list
            node.tokens["="] = self:ReadExpectValue("=")
            node.rvalues = self:ExpressionList()
        elseif expr.suffixes and expr.suffixes[#expr.suffixes].type == "call" then
            node = self:Node("expression")
            node.value = expr
        elseif implicit_return then
            local node = self:Node("return")
            node.implicit = true
            node.expressions = self:ExpressionList()
            return node
        else
            self:Error("unexpected " .. start_token.type, start_token)
        end
        return node
    elseif self:IsValue(";") then
        local node = self:Node("end_of_statement")
        node.tokens[";"] = self:ReadToken()
        return node
    end

    local type = self:GetToken().type

    if oh.syntax.IsKeyword(self:GetToken()) then
        type = "keyword"
    end

    self:Error("unexpected " .. type)
end

function META:LiteralString()
    local node = self:Node("value")
    node.value = self:ReadExpectType("literal_string")
    node.value.value = "([=["..node.value.value:sub(2, -2):gsub("${(.-)}", "]=]..tostring(%1)..[=[") .. "]=])"
    return node
end

function META:Expression(priority, stop_on_call)
    priority = priority or 0

    local token = self:GetToken()

    if not token then
        self:Error("attempted to read expression but reached end of code")
        return
    end

    local val

    if oh.syntax.IsUnaryOperator(token) then
        val = self:Node("unary")
        val.tokens["operator"] = self:ReadToken()
        val.operator = val.tokens["operator"].value
        val.expression = self:Expression(math.huge, stop_on_call)
    elseif self:IsValue("(") then
        local pleft = self:ReadToken()
        val = self:Expression(0, stop_on_call)
        if not val then
            self:Error("empty parentheses group", token)
        end

        val.tokens["left("] = val.tokens["left("] or {}
        table_insert(val.tokens["left("], pleft)

        val.tokens["right)"] = val.tokens["right)"] or {}
        table_insert(val.tokens["right)"], self:ReadExpectValue(")"))

    elseif self:IsStructStatemenet() then
        val = self:ReadAnonymousStruct()
    elseif self:IsAnonymousFunction() then
        val = self:AnonymousFunction()
    elseif token.type == "number" and self:GetTokenOffset(1).type == "letter" and self:GetTokenOffset(1).start == token.stop+1 then
        val = self:Node("value")
        val.value = self:ReadToken()
        val.annotation = self:ReadToken()
    elseif oh.syntax.IsValue(token) or (token.type == "letter" and not oh.syntax.IsKeyword(token)) then
        val = self:Node("value")
        val.value = self:ReadToken()

    elseif token.value == "{" then
        val = self:Table()
    elseif token.value == "[" then
        val = self:List()
    elseif token.type == "literal_string" then
        val = self:LiteralString()
    elseif token.value == "@" then
        local attributes = self:ReadAttributes()
        val = self:Expression(priority, stop_on_call)
        val.attributes = attributes
    elseif token.value == "<" then
        val = self:LSX()
    end

    if self:IsValue("as") and val then
        val.tokens["as"] = self:ReadToken()
        val.data_type = self:Type()
    end

    token = self:GetToken()

    if token and (
        token.value == "." or
        token.value == ":" or
        token.value == "[" or
        token.value == "(" or
        token.value == "{" or
        token.type == "string" or
        token.type == "literal_string"
    ) then
        local suffixes = val.suffixes or {}

        for _ = 1, self:GetLength() do
            if not self:GetToken() then break end

            local node

            if self:IsValue(".") then
                node = self:Node("index")

                node.tokens["."] = self:ReadToken()
                node.value = self:Node("value")
                node.value.value = self:ReadExpectType("letter")
            elseif self:IsValue(":") then
                local nxt = self:GetTokenOffset(2)
                if nxt.type == "string" or nxt.type == "literal_string" or nxt.value == "(" or nxt.value == "{" then
                    node = self:Node("self_index")
                    node.tokens[":"] = self:ReadToken()
                    node.value = self:Node("value")
                    node.value.value = self:ReadExpectType("letter")
                else
                    break
                end
            elseif self:IsValue("[") then
                node = self:Node("index_expression")

                node.tokens["["] = self:ReadToken()
                node.value = self:Expression(0, stop_on_call)
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
                node = self:Node("call")

                node.tokens["call("] = pleft
                node.arguments = self:ExpressionList()
                node.tokens["call)"] = self:ReadExpectValue(")", start)
            elseif self:IsValue("{") then
                node = self:Node("call")
                node.arguments = {self:Table()}
            elseif self:IsType("string") then
                node = self:Node("call")
                node.arguments = {self:Node("value")}
                node.arguments[1].value = self:ReadToken()
            elseif self:IsType("literal_string") then
                node = self:Node("call")
                node.arguments = {self:LiteralString()}
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

            local right = self:Expression(right_priority, stop_on_call)
            local left = val

            val = self:Node("operator")
            val.operator = op.value
            val.tokens["operator"] = op
            val.left = left
            val.right = right
        end
    end

    return val
end

function META:LSX2()
    local node = self:Node("lsx2")
    node.class = self:ReadExpectType("letter")
    node.props = {}

    if self:IsValue("letter") then
        for _ = 1, self:GetLength() do
            if self:IsValue("{") then break end

            if self:IsType("letter") then
                if self:GetTokenOffset(1).value == "=" then
                    local prop = self:Node("prop")
                    prop.key = self:ReadIdentifier()
                    prop.tokens["="] = self:ReadExpectValue("=")
                    prop.expression = self:Expression()
                    table.insert(node.props, prop)
                end
            end
        end
    end

    self:ReadExpectValue("{")

    node.children = {}

    for _ = 1, self:GetLength() do
        if self:IsValue("}") then break end

        if self:IsType("letter") then
            if self:GetTokenOffset(1).value == "=" then
                local prop = self:Node("prop")
                prop.key = self:ReadIdentifier()
                prop.tokens["="] = self:ReadExpectValue("=")
                prop.expression = self:Expression()
                table.insert(node.props, prop)
            elseif self:GetTokenOffset(1).value == "{" then
                table.insert(node.children, self:LSX2())
            else
                table.insert(node.children, self:Expression())
            end
        else
            table.insert(node.children, self:Expression())
        end
    end

    self:ReadExpectValue("}")

    return node
end

function META:LSX()
    if self:GetTokenOffset(1).value == "!" then
        self:Advance(2)
        local node = self:LSX2()
        self:ReadExpectValue(">")
        return node
    end

    local node = self:Node("lsx")
    node.tokens["start<"] = self:ReadExpectValue("<")

    node.class = self:ReadExpectType("letter")

    if self:IsType("letter") then
        node.props = {}
        while self:IsType("letter") do
            local prop = self:Node("prop")
            prop.key = self:ReadToken()
            prop.tokens["="] = self:ReadExpectValue("=")

            if oh.syntax.IsValue(self:GetToken()) then
                prop.value = self:ReadToken()
            else
                prop.tokens["{"] = self:ReadExpectValue("{")
                if not self:IsValue("}") then
                    prop.expression = self:Expression()
                end
                prop.tokens["}"] = self:ReadExpectValue("}")
            end

            table.insert(node.props, prop)
        end
    end

    if self:IsValue("/") then
        node.tokens["/"] = self:ReadExpectValue("/")
        node.tokens["start>"] = self:ReadExpectValue(">")
        return node
    else
        node.tokens["start>"] = self:ReadExpectValue(">")

        node.children = {}
        for _ = 1, self:GetLength() do
            if self:IsValue("<") and self:GetTokenOffset(1).value == "/" and self:GetTokenOffset(2).value == node.class.value then
                break
            elseif self:IsValue("<") and self:GetTokenOffset(1).value ~= "/" then
                table.insert(node.children, self:LSX())
            elseif self:IsValue("{") then
                self:ReadToken()
                if not self:IsValue("}") then
                    table.insert(node.children, self:Expression())
                end
                self:ReadExpectValue("}")
            elseif self:IsValue(">") then
                break
            else
                table.insert(node.children, self:ReadToken())
            end
        end
        node.tokens["stop<"] = self:ReadToken()
        node.tokens["/"] = self:ReadExpectValue("/")
        node.tokens["identifier"] = self:ReadExpectValue(node.class.value)
        node.tokens["stop>"] = self:ReadToken()
    end
    return node
end

function META:ExpressionList()
    local out = {}

    for _ = 1, self:GetLength() do
        local exp = self:Expression()

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

function META:List()
    local list = self:Node("list")

    list.tokens["["] = self:ReadExpectValue("[")
    list.values = {}
    for i = 1, self:GetLength() do
        local expr = self:Expression()
        if expr then
            local value = self:Node("list_value")
            value.expr = expr
            list.values[i] = value
            if not self:IsValue("]") then
                value.tokens[","] = self:ReadExpectValue(",")
            end
        end
    end
    list.tokens["]"] = self:ReadExpectValue("]")

    return list
end

function META:Table()
    local tree = self:Node("table")

    tree.children = {}
    tree.tokens["{"] = self:ReadExpectValue("{")

    for i = 1, self:GetLength() do
        local node

        if self:IsValue("}") then
            break
        elseif self:IsValue("[") then
            node = self:Node("table_expression_value")

            node.tokens["["] = self:ReadToken()
            node.key = self:Expression()
            node.tokens["]"] = self:ReadExpectValue("]")
            node.tokens["="] = self:ReadExpectValue("=")
            node.value = self:Expression()
            node.expression_key = true
        elseif self:IsType("letter") and self:GetTokenOffset(1).value == "=" then
            node = self:Node("table_key_value")

            node.key = self:Node("value")
            node.key.value = self:ReadToken()
            node.tokens["="] = self:ReadToken()
            node.value = self:Expression()
        elseif
            self:IsType("letter") and
            self:GetTokenOffset(1).value == ":" and
            self:GetTokenOffset(2).type == "letter" and
            (
                self:GetTokenOffset(3).type == "string" or
                self:GetTokenOffset(3).value == "(" or
                self:GetTokenOffset(3).value == "{"
            )
        then
            node = self:Node("table_index_value")
            node.value = self:Expression()
            node.key = i
            if not node.value then
                self:Error("expected expression got nothing")
            end
        elseif self:IsType("letter") and self:GetTokenOffset(1).value == ":" then
            node = self:Node("table_key_value")
            node.key = self:ReadIdentifier()

            if self:IsValue("=") then
                node.tokens["="] = self:ReadToken()
                node.value = self:Expression()
            end
        else
            node = self:Node("table_index_value")
            node.value = self:Expression()
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
            self:Error("expected ".. oh.QuoteTokens(",", ";", "}") .. " got " .. (self:GetToken().value or "no token"))
        end

        node.tokens[","] = self:ReadToken()
    end

    tree.tokens["}"] = self:ReadExpectValue("}")

    return tree
end

function oh.Parser()
    return setmetatable({}, META)
end