local table_insert = table.insert
local setmetatable = setmetatable
local type = type
local pairs = pairs

return function(parser_meta, syntax, Emitter)
    local META = {}
    META.__index = META
    do
        local PARSER = META

        local META = {}
        META.__index = META
        META.type = "expression"

        function META:__tostring()
            return "[" .. self.type .. " - " .. self.kind .. "] " .. ("%s"):format(self.id)
        end

        function META:Dump()
            local tprint = require("libraries.tprint")
            tprint(self)
        end

        function META:Render(op)
            local em = Emitter(op or {preserve_whitespace = false, no_newlines = true})

            em:EmitExpression(self)

            return em:Concat()
        end

        PARSER.ExpressionMeta = META

        local id = 0

        function PARSER:Expression(kind)
            local node = {}
            node.tokens = {}
            node.kind = kind
            node.id = id
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
            local tprint = require("libraries.tprint")
            tprint(self)
        end

        function META:Render(op)
            local em = Emitter(op or {preserve_whitespace = false, no_newlines = true})

            em:EmitStatement(self)

            return em:Concat()
        end

        function META:GetStatements()
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

        function META:HasStatements()
            return self.statements ~= nil
        end

        function META:FindStatementsByType(what, out)
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

        function META:ToExpression(kind)
            setmetatable(self, PARSER.ExpressionMeta)
            self.kind = kind
            return self
        end

        local id = 0

        function PARSER:Statement(kind)
            local node = {}

            node.tokens = {}
            node.kind = kind
            node.id = id
            id = id + 1

            setmetatable(node, META)
            self.current_statement = node

            if self.OnNode then
                self:OnNode(node)
            end

            return node
        end
    end

    function META:Error(msg, start, stop, ...)
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

        --msg = debug.traceback(msg)

        self:OnError(msg, start, stop, ...)
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
        table.remove(self.tokens, i)
        self.tokens_length = #self.tokens
        return t
    end

    function META:AddTokens(tokens)
        for i, token in ipairs(tokens) do
            if token.type == "end_of_file" then
                break
            end
            table.insert(self.tokens, self.i + i - 1, token)
        end
        self.tokens_length = #self.tokens
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
            local array = {}
            for k in pairs(values) do table_insert(array, k) end
            self:Error("expected $1 got $2", start, stop, array, tk.type)
        end

        return self:ReadTokenLoose()
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

        return self:Root(self.config and self.config.root)
    end


    function META:Root(root)
        local node = self:BeginStatement("root", true)
        self.root = root or node

        local shebang

        if self:IsType("shebang") then
            shebang = self:Statement("shebang")
            shebang.tokens["shebang"] = self:ReadType("shebang")
        end

        node.statements = self:ReadStatements()

        if shebang then
            table_insert(node.statements, 1, shebang)
        end

        if self:IsType("end_of_file") then
            local eof = self:Statement("end_of_file")
            eof.tokens["end_of_file"] = self.tokens[#self.tokens]
            table_insert(node.statements, eof)
        end

        return self:EndStatement()
    end

    function META:ReadStatements(stop_token)
        local out = {}
        for i = 1, self:GetLength() do
            if not self:GetToken() or stop_token and stop_token[self:GetToken().value] then
                break
            end

            out[i] = self:ReadStatement()

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

    do -- functional-like helpers. makes the code easier to read and maintain but does not always work
        function META:BeginStatement(kind, return_node)
            self.nodes = self.nodes or {}

            local node = self:Statement(kind)
            node.parent = self.nodes[1]

            table.insert(self.nodes, 1, node)

            if return_node then
                return node
            end

            return self
        end

        function META:BeginExpression(kind, return_node)
            self.nodes = self.nodes or {}

            local node = self:Expression(kind)
            node.parent = self.nodes[1]
            table.insert(self.nodes, 1, node)

            if return_node then
                return node
            end

            return self
        end

        local function expect(self, func, what, start, stop)
            local tokens = self.nodes[1].tokens

            if start then
                start = tokens[start]
            end

            if stop then
                stop = tokens[stop]
            end

            if start and not stop then
                stop = tokens[start]
            end

            local token = func(self, what, start, stop)

            if tokens[what] then
                if not tokens[what][1] then
                    tokens[what] = {tokens[what]}
                end

                table.insert(tokens[what], token)
            else
                tokens[what] = token
            end

            token.parent = self.nodes[1]

            return self
        end

        function META:ExpectKeyword(what, start, stop)
            return expect(self, self.ReadValue, what, start, stop)
        end

        function META:StatementsUntil(what)
            self.nodes[1].statements = self:ReadStatements(type(what) == "table" and what or {[what] = true})

            return self
        end

        function META:EndStatement()
            local node = table.remove(self.nodes, 1)
            return node
        end

        function META:EndExpression()
            local node = table.remove(self.nodes, 1)
            return node
        end

        function META:GetNode()
            return self.nodes[1]
        end

        function META:Store(key, val)
            self.nodes[1][key] = val
            return self
        end
    end

    for k, v in pairs(parser_meta) do
        META[k] = v
    end

    return function(config)
        return setmetatable({config = config}, META)
    end

end