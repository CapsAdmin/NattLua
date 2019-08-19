local table_insert = table.insert
local setmetatable = setmetatable
local type = type
local math_huge = math.huge
local pairs = pairs
local table_insert = table.insert
local table_concat = table.concat

local syntax = require("oh.syntax")
local LuaEmitter = require("oh.lua_emitter")

local META = {}
META.__index = META

for k, v in pairs(require("oh.parser_extended")) do
    META[k] = v
end

for k, v in pairs(require("oh.parser_typesystem")) do
    META[k] = v
end

do
    local PARSER = META

    local META = {}
    META.__index = META
    META.type = "expression"

    function META:__tostring()
        return "[" .. self.type .. " - " .. self.kind .. "] " .. ("%p"):format(self)
    end

    function META:Render(op)
        local em = LuaEmitter(op or {preserve_whitespace = false, no_newlines = true})

        em:EmitExpression(self)

        return em:Concat()
    end

    PARSER.ExpressionMeta = META

    function PARSER:Expression(kind)
        local node = {}
        node.tokens = {}
        node.kind = kind

        setmetatable(node, META)

        return node
    end
end

do
    local PARSER = META

    local META = {}
    META.__index = META
    META.type = "statement"

    function META:__tostring()
        return "[" .. self.type .. " - " .. self.kind .. "] " .. ("%p"):format(self)
    end

    function META:Render(op)
        local em = LuaEmitter(op or {preserve_whitespace = false, no_newlines = true})

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

    function PARSER:Statement(kind)
        local node = {}
        node.tokens = {}
        node.kind = kind

        setmetatable(node, META)

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
    local node = self:Statement("root")
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
        if self:IsType("end_of_file") then
            return
        end

        local start = self:GetToken()
        local left = self:ReadExpressionList(math_huge)

        if self:IsValue("=") then
            local node = self:Statement("assignment")
            node.tokens["="] = self:ReadValue("=")
            node.left = left
            node.right = self:ReadExpressionList(math_huge)
            return node
        end

        if left[1] and left[1].kind == "postfix_call" and not left[2] then
            local node = self:Statement("call_expression")
            node.value = left[1]
            return node
        end

        self:Error("expected assignment or call expression got $1 ($2)", start, self:GetToken(), self:GetToken().type, self:GetToken().value)
    end

    function META:ReadStatement()
        if
            self:IsValue("return") then                                                         return self:ReadReturnStatement() elseif
            self:IsValue("break") then                                                          return self:ReadBreakStatement() elseif
            self:IsValue(";") then                                                              return self:ReadSemicolonStatement() elseif
            self:IsValue("goto") and self:IsType("letter", 1) then                              return self:ReadGotoStatement() elseif
            self:IsValue("import") then                                                         return self:ReadImportStatement() elseif
            self:IsValue("::") then                                                             return self:ReadGotoLabelStatement() elseif
            self:IsValue("repeat") then                                                         return self:ReadRepeatStatement() elseif
            self:IsValue("function") then                                                       return self:ReadFunctionStatement() elseif
            self:IsValue("local") and self:IsValue("function", 1) then                          return self:ReadLocalFunctionStatement() elseif
            self:IsValue("local") and self:IsValue("type", 1) and self:IsType("letter", 2) then return self:ReadLocalTypeDeclarationStatement() elseif
            self:IsValue("local") then                                                          return self:ReadLocalAssignmentStatement() elseif
            self:IsValue("type") and (self:IsType("letter", 1) or self:IsValue("^", 1)) then    return self:ReadTypeAssignment() elseif
            self:IsValue("interface") then                                                      return self:ReadInterfaceStatement() elseif
            self:IsValue("do") then                                                             return self:ReadDoStatement() elseif
            self:IsValue("if") then                                                             return self:ReadIfStatement() elseif
            self:IsValue("while") then                                                          return self:ReadWhileStatement() elseif
            self:IsValue("for") and self:IsValue("=", 2) then                                   return self:ReadNumericForStatement() elseif
            self:IsValue("for") then                                                            return self:ReadGenericForStatement()
        end

        return self:ReadRemainingStatement()
    end

end

function META:ReadSemicolonStatement()
    local node = self:Statement("semicolon")

    node.tokens[";"] = self:ReadValue(";")

    return node
end

function META:ReadBreakStatement()
    local node = self:Statement("break")

    node.tokens["break"] = self:ReadValue("break")

    return node
end

function META:ReadReturnStatement()
    local node = self:Statement("return")

    node.tokens["return"] = self:ReadValue("return")
    node.expressions = self:ReadExpressionList()

    return node
end

function META:ReadDoStatement()
    local node = self:Statement("do")

    node.tokens["do"] = self:ReadValue("do")
    node.statements = self:ReadStatements({["end"] = true})
    node.tokens["end"] = self:ReadValue("end", node.tokens["do"], node.tokens["do"])

    return node
end

function META:ReadWhileStatement()
    local node = self:Statement("while")

    node.tokens["while"] = self:ReadValue("while")
    node.expression = self:ReadExpectExpression()
    node.tokens["do"] = self:ReadValue("do")
    node.statements = self:ReadStatements({["end"] = true})
    node.tokens["end"] = self:ReadValue("end", node.tokens["while"], node.tokens["while"])

    return node
end

function META:ReadRepeatStatement()
    local node = self:Statement("repeat")

    node.tokens["repeat"] = self:ReadValue("repeat")
    node.statements = self:ReadStatements({["until"] = true})
    node.tokens["until"] = self:ReadValue("until", node.tokens["repeat"], node.tokens["repeat"])
    node.expression = self:ReadExpectExpression()

    return node
end

function META:ReadGotoLabelStatement()
    local node = self:Statement("goto_label")

    node.tokens["::left"] = self:ReadValue("::")
    node.identifier = self:ReadType("letter")
    node.tokens["::right"]  = self:ReadValue("::")

    return node
end

function META:ReadGotoStatement()
    local node = self:Statement("goto")

    node.tokens["goto"] = self:ReadValue("goto")
    node.identifier = self:ReadType("letter")

    return node
end

function META:ReadLocalAssignmentStatement()
    local node = self:Statement("local_assignment")

    node.tokens["local"] = self:ReadValue("local")
    node.left = self:ReadIdentifierList()

    if self:IsValue("=") then
        node.tokens["="] = self:ReadValue("=")
        node.right = self:ReadExpressionList()
    end

    return node
end

function META:ReadNumericForStatement()
    local node = self:Statement("numeric_for")

    node.tokens["for"] = self:ReadValue("for")
    node.is_local = true

    node.identifiers = self:ReadIdentifierList(1)
    node.tokens["="] = self:ReadValue("=")
    node.expressions = self:ReadExpressionList(3)

    node.tokens["do"] = self:ReadValue("do")
    node.statements = self:ReadStatements({["end"] = true})
    node.tokens["end"] = self:ReadValue("end", node.tokens["do"], node.tokens["do"])

    return node
end

function META:ReadGenericForStatement()
    local node = self:Statement("generic_for")

    node.tokens["for"] = self:ReadValue("for")
    node.is_local = true

    node.identifiers = self:ReadIdentifierList()
    node.tokens["in"] = self:ReadValue("in")
    node.expressions = self:ReadExpressionList()

    node.tokens["do"] = self:ReadValue("do")
    node.statements = self:ReadStatements({["end"] = true})
    node.tokens["end"] = self:ReadValue("end", node.tokens["do"], node.tokens["do"])

    return node
end

function META:ReadFunctionBody(node)
    node.tokens["("] = self:ReadValue("(")
    node.identifiers = self:ReadIdentifierList()

    if self:IsValue("...") then
        local vararg = self:Expression("value")
        vararg.value = self:ReadValue("...")
        table_insert(node.identifiers, vararg)
    end

    node.tokens[")"] = self:ReadValue(")")

    if self:IsValue(":") then
        node.tokens[":"] = self:ReadValue(":")

        local out = {}
        for i = 1, max or self:GetLength() do

            local typ = self:ReadTypeExpression()

            if self:HandleListSeparator(out, i, typ) then
                break
            end
        end

        node.return_types = out
    end

    local start = self:GetToken()
    node.statements = self:ReadStatements({["end"] = true})
    node.tokens["end"] = self:ReadValue("end", start, start)
end

do  -- function
    local function read_function_expression(self)
        local val = self:Expression("value")
        val.value = self:ReadType("letter")

        while self:IsValue(".") or self:IsValue(":") do
            local op = self:GetToken()
            if not op then break end
            self:Advance(1)

            local left = val
            local right = read_function_expression(self)

            val = self:Expression("binary_operator")
            val.value = op
            val.left = val.left or left
            val.right = val.right or right
        end

        return val
    end

    function META:ReadIndexExpression()
        return read_function_expression(self)
    end

    function META:ReadFunctionStatement()
        local node = self:Statement("function")
        node.tokens["function"] = self:ReadValue("function")
        node.expression = read_function_expression(self)

        do -- hacky
            if node.expression.left then
                node.expression.left.upvalue_or_global = node
            else
                node.expression.upvalue_or_global = node
            end

            if node.expression.value.value == ":" then
                node.self_call = true
            end
        end

        self:ReadFunctionBody(node)

        return node
    end
end

function META:ReadLocalFunctionStatement()
    local node = self:Statement("local_function")
    node.tokens["local"] = self:ReadValue("local")
    node.tokens["function"] = self:ReadValue("function")
    node.identifier = self:ReadIdentifier()
    self:ReadFunctionBody(node)
    return node
end

function META:ReadIfStatement()
    local node = self:Statement("if")

    node.expressions = {}
    node.statements = {}
    node.tokens["if/else/elseif"] = {}
    node.tokens["then"] = {}

    for i = 1, self:GetLength() do
        local token

        if i == 1 then
            token = self:ReadValue("if")
        else
            token = self:ReadValues({["else"] = true, ["elseif"] = true, ["end"] = true})
        end

        if not token then return end

        node.tokens["if/else/elseif"][i] = token

        if token.value ~= "else" then
            node.expressions[i] = self:ReadExpectExpression()
            node.tokens["then"][i] = self:ReadValue("then")
        end

        node.statements[i] = self:ReadStatements({["end"] = true, ["else"] = true, ["elseif"] = true})

        if self:IsValue("end") then
            break
        end
    end

    node.tokens["end"] = self:ReadValue("end")

    return node
end


function META:HandleListSeparator(out, i, node)
    if not node then
        return true
    end

    out[i] = node

    if not self:IsValue(",") then
        return true
    end

    node.tokens[","] = self:ReadValue(",")
end

do -- identifier
   function META:ReadIdentifier()
        local node = self:Expression("value")
        node.value = self:ReadType("letter")

        if self.ReadTypeExpression and self:IsValue(":") then
            node.tokens[":"] = self:ReadValue(":")
            node.type_expression = self:ReadTypeExpression()
        end

        return node
    end

    function META:ReadIdentifierList(max)
        local out = {}

        for i = 1, max or self:GetLength() do
            if not self:IsType("letter") or self:HandleListSeparator(out, i, self:ReadIdentifier()) then
                break
            end
        end

        return out
    end
end

do -- expression

    function META:ReadAnonymousFunction()
        local node = self:Expression("function")
        node.tokens["function"] = self:ReadValue("function")
        self:ReadFunctionBody(node)
        return node
    end

    function META:ReadTable()
        local tree = self:Expression("table")

        tree.children = {}
        tree.tokens["{"] = self:ReadValue("{")

        for i = 1, self:GetLength() do
            if self:IsValue("}") then
                break
            end

            local node

            if self:IsValue("[") then
                node = self:Expression("table_expression_value")

                node.tokens["["] = self:ReadValue("[")
                node.key = self:ReadExpectExpression()
                node.tokens["]"] = self:ReadValue("]")
                node.tokens["="] = self:ReadValue("=")
                node.expression_key = true
            elseif self:IsType("letter") and self:IsValue("=", 1) then
                node = self:Expression("table_key_value")

                node.key = self:ReadType("letter")
                node.tokens["="] = self:ReadValue("=")
            else
                node = self:Expression("table_index_value")

                node.key = i
            end

            node.value = self:ReadExpectExpression()

            tree.children[i] = node

            if not self:IsValue(",") and not self:IsValue(";") and not self:IsValue("}") then
                self:Error("expected $1 got $2", nil, nil,  {",", ";", "}"}, (self:GetToken() and self:GetToken().value) or "no token")
                break
            end

            if not self:IsValue("}") then
                node.tokens[","] = self:ReadValues({[","] = true, [";"] = true})
            end
        end

        tree.tokens["}"] = self:ReadValue("}")

        return tree
    end

    function META:ReadExpression(priority)
        priority = priority or 0

        local node

        if self:IsValue("(") then
            local pleft = self:ReadValue("(")
            node = self:ReadExpression(0)
            if not node then
                self:Error("empty parentheses group", pleft)
                return
            end

            node.tokens["("] = node.tokens["("] or {}
            table_insert(node.tokens["("], 1, pleft)

            node.tokens[")"] = node.tokens[")"] or {}
            table_insert(node.tokens[")"], self:ReadValue(")"))

        elseif syntax.IsPrefixOperator(self:GetToken()) then
            node = self:Expression("prefix_operator")
            node.value = self:ReadTokenLoose()
            node.right = self:ReadExpression(math_huge)
        elseif self:IsValue("function") then
            node = self:ReadAnonymousFunction()
        elseif syntax.IsValue(self:GetToken()) or self:IsType("letter") then
            node = self:Expression("value")
            node.value = self:ReadTokenLoose()
        elseif self.ReadImportExpression and self:IsValue("import") then
            node = self:ReadImportExpression()
        elseif self:IsValue("{") then
            node = self:ReadTable()
        end

        local first = node

        if node then
            for _ = 1, self:GetLength() do
                local left = node
                if not self:GetToken() then break end

                if self:IsValue(".") and self:IsType("letter", 1) then
                    local op = self:ReadTokenLoose()
    
                    local right = self:Expression("value")
                    right.value = self:ReadType("letter")
    
                    node = self:Expression("binary_operator")
                    node.value = op
                    node.left = left
                    node.right = right
                elseif self:IsValue(":") then
                    if self:IsType("letter", 1) and (self:IsValue("(", 2) or self:IsValue("{", 2) or self:IsValue("\"", 2) or self:IsValue("'", 2)) then
                        local op = self:ReadTokenLoose()
        
                        local right = self:Expression("value")
                        right.value = self:ReadType("letter")
        
                        node = self:Expression("binary_operator")
                        node.value = op
                        node.left = left
                        node.right = right
                    else
                        node.tokens[":"] = self:ReadValue(":")
                        node.type_expression = self:ReadTypeExpression()
                    end
                elseif syntax.IsPostfixOperator(self:GetToken()) then
                    node = self:Expression("postfix_operator")
                    node.left = left
                    node.value = self:ReadTokenLoose()
                elseif self:IsValue("(") then
                    node = self:Expression("postfix_call")
                    node.left = left
                    node.tokens["call("] = self:ReadValue("(")
                    node.expressions = self:ReadExpressionList()
                    node.tokens["call)"] = self:ReadValue(")")

                    if left.value and left.value.value == ":" then
                        node.self_call = true
                    end
                elseif self:IsValue("{") or self:IsType("string") then
                    node = self:Expression("postfix_call")
                    node.left = left
                    if self:IsValue("{") then
                        node.expressions = {self:ReadTable()}
                    else
                        local val = self:Expression("value")
                        val.value = self:ReadTokenLoose()
                        node.expressions = {val}
                    end
                elseif self:IsValue("[") then
                    node = self:Expression("postfix_expression_index")
                    node.left = left
                    node.tokens["["] = self:ReadValue("[")
                    node.expression = self:ReadExpectExpression()
                    node.tokens["]"] = self:ReadValue("]")
                elseif self:IsValue("as") then
                    node.tokens["as"] = self:ReadValue("as")
                    node.type_expression = self:ReadTypeExpression()
                elseif self:IsValue("is") then
                    node.tokens["is"] = self:ReadValue("is")
                    node.type_expression = self:ReadTypeExpression()
                else
                    break
                end

                if node then
                    node.primary = first
                end
            end
        end

        if first and first.kind == "value" and (first.value.type == "letter" or first.value.value == "...") then
            first.upvalue_or_global = node
        end

        while syntax.IsBinaryOperator(self:GetToken()) and syntax.GetLeftOperatorPriority(self:GetToken()) > priority do
            local op = self:GetToken()
            local right_priority = syntax.GetRightOperatorPriority(op)
            if not op or not right_priority then break end
            self:Advance(1)

            local left = node
            local right = self:ReadExpression(right_priority)

            node = self:Expression("binary_operator")
            node.value = op
            node.left = node.left or left
            node.right = node.right or right
        end

        return node
    end

    function META:ReadExpectExpression(priority)
        if syntax.IsDefinetlyNotStartOfExpression(self:GetToken()) then
            self:Error("expected beginning of expression, got $1", nil, nil, self:GetToken() and self:GetToken().value ~= "" and self:GetToken().value or self:GetToken().type)
            return
        end

        return self:ReadExpression(priority)
    end

    function META:ReadExpressionList(max)
        local out = {}

        for i = 1, max or self:GetLength() do
            local exp = max and self:ReadExpectExpression() or self:ReadExpression()

            if self:HandleListSeparator(out, i, exp) then
                break
            end
        end

        return out
    end
end

return function(config)
    return setmetatable({config = config}, META)
end