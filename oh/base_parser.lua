local list = require("oh.library.list")

return function(META)
    local tprint = require("libraries.tprint")

    local setmetatable = setmetatable
    local type = type

    local function expect(node, parser, func, what, start, stop)
        local tokens = node.tokens

        if start then
            start = tokens[start]
        end

        if stop then
            stop = tokens[stop]
        end

        if start and not stop then
            stop = tokens[start]
        end

        local token = func(parser, what, start, stop)

        if tokens[what] then
            if not tokens[what][1] then
                tokens[what] = list.new(tokens[what])
            end

            tokens[what]:insert(token)
        else
            tokens[what] = token
        end

        token.parent = node
    end

    do
        local PARSER = META

        local META = {}
        META.__index = META
        META.type = "expression"

        function META:__tostring()
            local str = "[" .. self.type .. " - " .. self.kind .. " - " .. ("%s"):format(self.id) .. "]"

            if self.value and type(self.value.value) == "string" then
                str = str ..  ": " .. require("oh.helpers").QuoteToken(self.value.value)
            end

            return str
        end

        function META:Dump()
            tprint(self)
        end

        function META:Render(op)
            local em = PARSER.Emitter(op or {preserve_whitespace = false, no_newlines = true})

            em:EmitExpression(self)

            return em:Concat()
        end

        function META:IsWrappedInParenthesis()
            return self.tokens["("] and self.tokens[")"]
        end

        function META:ExpectKeyword(what, start, stop)
            expect(self, self.parser, self.parser.ReadValue, what, start, stop)
            return self
        end
        
        function META:ExpectExpression(what)
            if self.expressions then
                self.expressions:insert(self.parser:ReadExpectExpression())
            elseif self.expression then
                self.expressions = list.new(self.expression)
                self.expression = nil
                self.expressions:insert(self.parser:ReadExpectExpression())
            else
                self.expression = self.parser:ReadExpectExpression()
            end
    
            return self
        end    
    
        function META:ExpectSimpleIdentifier()
            self.tokens["identifier"] = self.parser:ReadType("letter")
            return self
        end

        function META:Store(key, val)
            self[key] = val
            return self
        end
    
        function META:ExpectIdentifier()
            self.identifier = self:ReadIdentifier()
            return self
        end
    
        function META:ExpectIdentifierList(length)
            self.identifiers = self.parser:ReadIdentifierList(length)
            return self
        end

        function META:End()
            self.parser.nodes:remove(1)
            return self
        end


        PARSER.ExpressionMeta = META

        local id = 0

        function PARSER:Expression(kind)
            local node = {}
            node.tokens = list.new()
            node.kind = kind
            node.id = id
            node.code = self.code
            node.name = self.name
            node.parser = self
            id = id + 1

            setmetatable(node, META)
            self.current_expression = node

            if self.OnNode then
                self:OnNode(node)
            end

            return node
        end
    end

    do
        local PARSER = META

        local META = {}
        META.__index = META
        META.type = "statement"

        function META:__tostring()
            return "[" .. self.type .. " - " .. self.kind .. "] " .. ("%s"):format(self.id)
        end

        function META:Dump()
            tprint(self)
        end

        function META:Render(op)
            local em = PARSER.Emitter(op or {preserve_whitespace = false, no_newlines = true})

            em:EmitStatement(self)

            return em:Concat()
        end

        function META:GetStatements()
            if self.kind == "if" then
                local flat = list.new()
                for _, statements in self.statements:pairs() do
                    for _, v in statements:pairs() do
                        flat:insert(v)
                    end
                end
                return flat
            end
            return self.statements
        end

        function META:HasStatements()
            return self.statements ~= nil
        end

        function META:FindStatementsByType(what, out)
            out = out or list.new()
            for _, child in self:GetStatements():pairs() do
                if child.kind == what then
                    out:insert(child)
                elseif child:GetStatements() then
                    child:FindStatementsByType(what, out)
                end
            end
            return out
        end

        function META:StatementsUntil(what)
            self.statements = self.parser:ReadStatements(type(what) == "table" and what or {[what] = true})

            return self
        end

        function META:ToExpression(kind)
            setmetatable(self, PARSER.ExpressionMeta)
            self.kind = kind
            return self
        end

        function META:ExpectSimpleIdentifier()
            self.tokens["identifier"] = self.parser:ReadType("letter")
            return self
        end

        function META:Store(key, val)
            self[key] = val
            return self
        end
            
        function META:ExpectExpressionList(length)
            self.expressions = self.parser:ReadExpressionList(length)
            return self
        end  
            
        function META:ExpectIdentifierList(length)
            self.identifiers = self.parser:ReadIdentifierList(length)
            return self
        end

        function META:ExpectExpression()
            if self.expressions then
                self.expressions:insert(self.parser:ReadExpectExpression())
            elseif self.expression then
                self.expressions = list.new(self.expression)
                self.expression = nil
                self.expressions:insert(self.parser:ReadExpectExpression())
            else
                self.expression = self.parser:ReadExpectExpression()
            end
            return self
        end

        function META:ExpectStatementsUntil(what)
            self.statements = self.parser:ReadStatements(type(what) == "table" and what or {[what] = true})
            return self
        end

        function META:ExpectKeyword(what, start, stop)
            expect(self, self.parser, self.parser.ReadValue, what, start, stop)
            return self
        end

        function META:End()
            self.parser.nodes:remove(1)
            return self
        end

        local id = 0

        function PARSER:Statement(kind)
            local node = {}

            node.tokens = list.new()
            node.kind = kind
            node.id = id
            node.code = self.code
            node.name = self.name
            node.parser = self
            id = id + 1

            setmetatable(node, META)
            self.current_statement = node

            if self.OnNode then
                self:OnNode(node)
            end

            node.parent = self.nodes[1]

            self.nodes:insert(1, node)

            return node
        end

    end

    function META:Error(msg, start, stop, ...)
        if type(start) == "table" then
            start = start.start
        end
        if type(stop) == "table" then
            stop = stop.stop
        end

        local tk = self:GetToken()
        start = start or tk and tk.start or 0
        stop = stop or tk and tk.stop or 0

        self:OnError(self.code, self.name, msg, start, stop, ...)
    end

    function META:OnError()

    end

    function META:GetToken(offset)
        if offset then
            return self.tokens[self.i + offset]
        end
        return self.tokens[self.i]
    end

    function META:ReadTokenLoose()
        self:Advance(1)
        local tk = self:GetToken(-1)
        tk.parent = self.nodes[1]
        return tk
    end

    function META:RemoveToken(i)
        local t = self.tokens[i]
        self.tokens:remove(i)
        return t
    end

    function META:AddTokens(tokens)
        local eof = self.tokens:remove()
        for i, token in tokens:pairs() do
            if token.type == "end_of_file" then
                break
            end
            self.tokens:insert(self.i + i - 1, token)
        end
        self.tokens:insert(eof)
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
                self:Error("expected $1 $2: reached end of code", start, stop, what, str)
            else
                self:Error("expected $1 $2: got $3", start, stop, what, str, self:GetToken()[what])
            end
        end

        function META:ReadValue(str, start, stop)
            if not self:IsValue(str) then
                error_expect(self, str, "value", start, stop)
            end

            return self:ReadTokenLoose()
        end

        function META:ReadType(str, start, stop)
            if not self:IsType(str) then
                error_expect(self, str, "type", start, stop)
            end

            return self:ReadTokenLoose()
        end
    end

    function META:ReadValues(values, start, stop)
        if not self:GetToken() or not values[self:GetToken().value] then
            local tk = self:GetToken()
            if not tk then
                self:Error("expected $1: reached end of code", start, stop, values)
            end
            local array = list.new()
            for k in pairs(values) do array:insert(k) end
            self:Error("expected $1 got $2", start, stop, array, tk.type)
        end

        return self:ReadTokenLoose()
    end

    function META:GetLength()
        return #self.tokens
    end

    function META:Advance(offset)
        self.i = self.i + offset
    end

    function META:BuildAST(tokens)
        self.tokens = list.fromtable(tokens)
        self.i = 1

        return self:Root(self.config and self.config.root)
    end


    function META:Root(root)
        local node = self:Statement("root")
        self.root = root or node

        local shebang

        if self:IsType("shebang") then
            shebang = self:Statement("shebang")
            shebang.tokens["shebang"] = self:ReadType("shebang")
        end

        node.statements = self:ReadStatements()

        if shebang then
            node.statements:insert(1, shebang)
        end

        if self:IsType("end_of_file") then
            local eof = self:Statement("end_of_file")
            eof.tokens["end_of_file"] = self.tokens[#self.tokens]
            node.statements:insert(eof)
        end

        return node:End()
    end

    function META:ReadStatements(stop_token)
        local out = list.new()

        for i = 1, self:GetLength() do
            if not self:GetToken() or stop_token and stop_token[self:GetToken().value] then
                break
            end

            out[i] = self:ReadStatement()

            if not out[i] then
                break
            end

            if self.config and self.config.on_statement then
                out[i] = self.config.on_statement(self, out[i]) or out[i]
            end
        end

        return out
    end

    do
        function META:IsSemicolonStatement()
            return self:IsValue(";")
        end

        function META:ReadSemicolonStatement()
            local node = self:Statement("semicolon")

            node.tokens[";"] = self:ReadValue(";")

            return node
        end
    end
end