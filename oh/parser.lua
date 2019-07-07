local table_insert = table.insert
local setmetatable = setmetatable
local type = type
local math_huge = math.huge
local pairs = pairs

local syntax = require("oh.syntax")
local Expression = require("oh.expression")
local Statement = require("oh.statement")

local META = {}
META.__index = META

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
            self:Error("expected $1 $2: reached end of code", start, stop, what, str)
        else
            self:Error("expected $1 $2: got $3", start, stop, what, str, self:GetToken()[what])
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
            self:Error("expected $1: reached end of code", start, stop, values)
        end
        local array = {}
        for k in pairs(values) do table_insert(array, k) end
        self:Error("expected $1 got $2", start, stop, array, tk.type)
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

    return self:Root()
end


function META:Root()
    local node = Statement("root")

    local shebang

    if self:IsType("shebang") then
        shebang = Statement("shebang")
        shebang.tokens["shebang"] = self:ReadToken()
    end

    node.statements = self:ReadStatements()

    if shebang then
        table_insert(node.statements, 1, shebang)
    end

    if self:IsType("end_of_file") then
        local eof = Statement("end_of_file")
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
            node = Statement("assignment")
            node.tokens["="] = self:ReadToken()
            node.left = {expr}
            node.right = self:ReadExpressionList(math_huge)
        elseif self:IsValue(",") then
            node = Statement("assignment")
            expr.tokens[","] = self:ReadToken()
            local list = self:ReadExpressionList(math_huge)
            table_insert(list, 1, expr)
            node.left = list
            node.tokens["="] = self:ReadExpectValue("=")
            node.right = self:ReadExpressionList(math_huge)
        elseif expr and expr.kind == "postfix_call" then
            node = Statement("expression")
            node.value = expr
        elseif not self:IsType("end_of_file") then
            self:Error("unexpected " .. start.type .. " (" .. (self:GetToken().value) .. ") while trying to read assignment or call statement", start, start)
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
            self:IsLocalFunctionStatement() then    return self:ReadLocalFunctionStatement() elseif
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
        local node = Statement("semicolon")
        node.tokens[";"] = self:ReadToken()
        return node
    end
end

do
    function META:IsBreakStatement()
        return self:IsValue("break")
    end

    function META:ReadBreakStatement()
        local node = Statement("break")
        node.tokens["break"] = self:ReadToken()
        return node
    end
end

do
    function META:IsReturnStatement()
        return self:IsValue("return")
    end

    function META:ReadReturnStatement()
        local node = Statement("return")
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

        local node = Statement("do")
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
        local node = Statement("while")

        node.tokens["while"] = self:ReadToken()
        node.expression = self:ReadExpectExpression()
        node.tokens["do"] = self:ReadExpectValue("do")
        node.statements = self:ReadStatements({["end"] = true})
        node.tokens["end"] = self:ReadExpectValue("end", node.tokens["while"], node.tokens["while"])

        return node
    end
end

do -- repeat
    function META:IsRepeatStatement()
        return self:IsValue("repeat")
    end

    function META:ReadRepeatStatement()
        local node = Statement("repeat")

        node.tokens["repeat"] = self:ReadToken()
        node.statements = self:ReadStatements({["until"] = true})
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
        local node = Statement("goto_label")

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
        local node = Statement("goto")

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
        local node = Statement("local_assignment")
        node.tokens["local"] = self:ReadToken()
        node.left = self:ReadIdentifierList()

        if self:IsValue("=") then
            node.tokens["="] = self:ReadToken("=")
            node.right = self:ReadExpressionList()
        end

        return node
    end
end

do -- for
    function META:IsForStatement()
        return self:IsValue("for")
    end

    function META:ReadForStatement()
        local node = Statement("for")
        node.tokens["for"] = self:ReadToken()
        node.is_local = true

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
        node.statements = self:ReadStatements({["end"] = true})
        node.tokens["end"] = self:ReadExpectValue("end", node.tokens["do"], node.tokens["do"])

        return node
    end
end

function META:ReadFunctionBody(node)
    node.tokens["("] = self:ReadExpectValue("(")
    node.identifiers = self:ReadIdentifierList()

    if self:IsValue("...") then
        local vararg = Expression("value")
        vararg.value = self:ReadToken()
        table_insert(node.identifiers, vararg)
    end

    node.tokens[")"] = self:ReadExpectValue(")")
    local start = self:GetToken()
    node.statements = self:ReadStatements({["end"] = true})
    node.tokens["end"] = self:ReadExpectValue("end", start, start)
end

do  -- function
    function META:IsFunctionStatement()
        return self:IsValue("function")
    end

    local function read_function_expression(self)
        local val = Expression("value")
        val.value = self:ReadExpectType("letter")

        while self:IsValue(".") or self:IsValue(":") do
            local op = self:GetToken()
            if not op then break end
            self:Advance(1)

            local left = val
            local right = read_function_expression(self)

            val = Expression("binary_operator")
            val.value = op
            val.left = val.left or left
            val.right = val.right or right
        end

        return val
    end

    function META:ReadFunctionStatement()
        local node = Statement("function")
        node.tokens["function"] = self:ReadExpectValue("function")
        node.expression = read_function_expression(self)
        node.expression.upvalue_or_global = node
        self:ReadFunctionBody(node)
        return node
    end
end

do -- local function
    function META:IsLocalFunctionStatement()
        return self:IsValue("local") and self:IsValue("function", 1)
    end

    function META:ReadLocalFunctionStatement()
        local node = Statement("local_function")
        node.tokens["local"] = self:ReadToken()
        node.tokens["function"] = self:ReadExpectValue("function")
        node.identifier = self:ReadIdentifier()
        self:ReadFunctionBody(node)
        return node
    end
end

do -- if
    function META:IsIfStatement()
        return self:IsValue("if")
    end

    function META:ReadIfStatement()
        local node = Statement("if")

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

            node.statements[i] = self:ReadStatements({["end"] = true, ["else"] = true, ["elseif"] = true})

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
        local node = Expression("value")
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
    do -- function
        function META:IsAnonymousFunction()
            return self:IsValue("function")
        end

        function META:ReadAnonymousFunction()
            local node = Expression("function")
            node.tokens["function"] = self:ReadExpectValue("function")
            self:ReadFunctionBody(node)
            return node
        end
    end

    do -- table
        function META:IsTable()
            return self:IsValue("{")
        end

        function META:ReadTable()
            local tree = Expression("table")

            tree.children = {}
            tree.tokens["{"] = self:ReadExpectValue("{")

            for i = 1, self:GetLength() do
                if self:IsValue("}") then
                    break
                end

                local node

                if self:IsValue("[") then
                    node = Expression("table_expression_value")

                    node.tokens["["] = self:ReadToken()
                    node.key = self:ReadExpectExpression()
                    node.tokens["]"] = self:ReadExpectValue("]")
                    node.tokens["="] = self:ReadExpectValue("=")
                    node.expression_key = true
                elseif self:IsType("letter") and self:IsValue("=", 1) then
                    node = Expression("table_key_value")

                    node.key = self:ReadToken()
                    node.tokens["="] = self:ReadToken()
                else
                    node = Expression("table_index_value")

                    node.key = i
                end

                node.value = self:ReadExpectExpression()

                tree.children[i] = node

                if not self:IsValue(",") and not self:IsValue(";") and not self:IsValue("}") then
                    self:Error("expected $1 got $2", nil, nil,  {",", ";", "}"}, (self:GetToken() and self:GetToken().value) or "no token")
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

    function META:ReadExpression(priority)
        priority = priority or 0

        local node

        if self:IsValue("(") then
            local pleft = self:ReadToken()
            node = self:ReadExpression(0)
            if not node then
                self:Error("empty parentheses group", pleft)
                return
            end

            node.tokens["("] = node.tokens["("] or {}
            table_insert(node.tokens["("], 1, pleft)

            node.tokens[")"] = node.tokens[")"] or {}
            table_insert(node.tokens[")"], self:ReadExpectValue(")"))

        elseif syntax.IsPrefixOperator(self:GetToken()) then
            node = Expression("prefix_operator")
            node.value = self:ReadToken()
            node.right = self:ReadExpression(math_huge)
        elseif self:IsAnonymousFunction() then
            node = self:ReadAnonymousFunction()
        elseif syntax.IsValue(self:GetToken()) or self:IsType("letter") then
            node = Expression("value")
            node.value = self:ReadToken()
        elseif self:IsTable() then
            node = self:ReadTable()
        end

        local first = node

        if node then
            for _ = 1, self:GetLength() do
                local left = node
                if not self:GetToken() then break end

                if self:IsValue(".") or self:IsValue(":") then
                    local op = self:GetToken()
                    local right_priority = syntax.GetRightOperatorPriority(op)
                    if not op or not right_priority then break end
                    self:Advance(1)

                    local left = node
                    local right
                    if self:IsAnonymousFunction() then
                        right = self:ReadAnonymousFunction()
                    elseif syntax.IsValue(self:GetToken()) or self:IsType("letter") then
                        right = Expression("value")
                        right.value = self:ReadToken()
                    elseif self:IsTable() then
                        right = self:ReadTable()
                    else
                        break
                    end

                    node = Expression("binary_operator")
                    node.value = op
                    node.left = left
                    node.right = right
                elseif syntax.IsPostfixOperator(self:GetToken()) then
                    node = Expression("postfix_operator")
                    node.left = left
                    node.value = self:ReadToken()
                elseif self:IsValue("(") then
                    node = Expression("postfix_call")
                    node.left = left
                    node.tokens["call("] = self:ReadExpectValue("(")
                    node.expressions = self:ReadExpressionList()
                    node.tokens["call)"] = self:ReadExpectValue(")")
                elseif self:IsTable() or self:IsType("string") then
                    node = Expression("postfix_call")
                    node.left = left
                    if self:IsTable() then
                        node.expressions = {self:ReadTable()}
                    else
                        local val = Expression("value")
                        val.value = self:ReadToken()
                        node.expressions = {val}
                    end
                elseif self:IsValue("[") then
                    node = Expression("postfix_expression_index")
                    node.left = left
                    node.tokens["["] = self:ReadToken()
                    node.expression = self:ReadExpectExpression()
                    node.tokens["]"] = self:ReadExpectValue("]")
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

        while syntax.IsOperator(self:GetToken()) and syntax.GetLeftOperatorPriority(self:GetToken()) > priority do
            local op = self:GetToken()
            local right_priority = syntax.GetRightOperatorPriority(op)
            if not op or not right_priority then break end
            self:Advance(1)

            local left = node
            local right = self:ReadExpression(right_priority)

            node = Expression("binary_operator")
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
end

return function(config)
    return setmetatable({config = config}, META)
end