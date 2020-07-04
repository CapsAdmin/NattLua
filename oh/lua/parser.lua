local table_insert = table.insert
local setmetatable = setmetatable
local type = type
local math_huge = math.huge
local pairs = pairs
local table_insert = table.insert
local table_concat = table.concat

local syntax = require("oh.lua.syntax")

local META = {}

local extended = {
    "oh.lua.parser_typesystem",
    "oh.lua.parser_extra",
}

for _, name in ipairs(extended) do
    for k, v in pairs(require(name)) do
        META[k] = v
    end
end

do -- functional helpers
    function META:ExpectExpression(what)
        if self.nodes[1].expressions then
            table.insert(self.nodes[1].expressions, self:ReadExpectExpression())
        elseif self.nodes[1].expression then
            self.nodes[1].expressions = {self.nodes[1].expression}
            self.nodes[1].expression = nil
            table.insert(self.nodes[1].expressions, self:ReadExpectExpression())
        else
            self.nodes[1].expression = self:ReadExpectExpression()
        end

        return self
    end


    function META:ExpectSimpleIdentifier()
        self.nodes[1].tokens["identifier"] = self:ReadType("letter")
        return self
    end

    function META:ExpectIdentifier()
        self:Store("identifier", self:ReadIdentifier())
        return self
    end

    function META:ExpectIdentifierList(length)
        self:Store("identifiers", self:ReadIdentifierList(length))
        return self
    end

    function META:ExpectExpressionList(length)
        self:Store("expressions", self:ReadExpressionList(length))
        return self
    end

    function META:ExpectDoBlock()
        return self:ExpectKeyword("do")
            :StatementsUntil("end")
        :ExpectKeyword("end", "do")
    end
end

do
    function META:IsBreakStatement()
        return self:IsValue("break")
    end

    function META:ReadBreakStatement()
        return self:BeginStatement("break")
            :ExpectKeyword("break")
        :EndStatement()
    end
end

do
    function META:IsReturnStatement()
        return self:IsValue("return")
    end

    function META:ReadReturnStatement()
        return self:BeginStatement("return")
            :ExpectKeyword("return")
            :ExpectExpressionList()
        :EndStatement()
    end
end

do
    function META:IsDoStatement()
        return self:IsValue("do")
    end

    function META:ReadDoStatement()
        return self:BeginStatement("do")
            :ExpectDoBlock()
        :EndStatement()
    end
end


do
    function META:IsWhileStatement()
        return self:IsValue("while")
    end

    function META:ReadWhileStatement()
        return self:BeginStatement("while")
            :ExpectKeyword("while")
            :ExpectExpression()
            :ExpectDoBlock()
        :EndStatement()
    end
end

do
    function META:IsRepeatStatement()
        return self:IsValue("repeat")
    end

    function META:ReadRepeatStatement()
        return self:BeginStatement("repeat")
            :ExpectKeyword("repeat")
                :StatementsUntil("until")
            :ExpectKeyword("until")
            :ExpectExpression()
        :EndStatement()
    end
end

do
    function META:IsGotoLabelStatement()
        return self:IsValue("::")
    end

    function META:ReadGotoLabelStatement()
        return self:BeginStatement("goto_label")
            :ExpectKeyword("::")
                :ExpectSimpleIdentifier()
            :ExpectKeyword("::")
        :EndStatement()
    end
end

do
    function META:IsGotoStatement()
        return self:IsValue("goto") and self:IsType("letter", 1)
    end

    function META:ReadGotoStatement()
        return self:BeginStatement("goto")
            :ExpectKeyword("goto")
            :ExpectSimpleIdentifier()
        :EndStatement()
    end
end

do
    function META:IsLocalAssignmentStatement()
        return self:IsValue("local")
    end

    function META:ReadLocalAssignmentStatement()
        self:BeginStatement("local_assignment")
        self:ExpectKeyword("local")
        self:Store("left", self:ReadIdentifierList())

        if self:IsValue("=") then
            self:ExpectKeyword("=")
            self:Store("right", self:ReadExpressionList())
        end

        return self:EndStatement()
    end
end


do
    function META:IsNumericForStatement()
        return self:IsValue("for") and self:IsValue("=", 2)
    end

    function META:ReadNumericForStatement()
        return self:BeginStatement("numeric_for")
            :Store("is_local", true)
            :ExpectKeyword("for")
            :ExpectIdentifierList(1)
            :ExpectKeyword("=")
            :ExpectExpressionList(3)
            :ExpectDoBlock()
        :EndStatement()
    end
end

do
    function META:IsGenericForStatement()
        return self:IsValue("for")
    end

    function META:ReadGenericForStatement()
        return self:BeginStatement("generic_for")
            :Store("is_local", true)
            :ExpectKeyword("for")
            :ExpectIdentifierList()
            :ExpectKeyword("in")
            :ExpectExpressionList()
            :ExpectDoBlock()
        :EndStatement()
    end
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
        for i = 1, self:GetLength() do

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

    do
        function META:IsFunctionStatement()
            return self:IsValue("function")
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
end


do
    function META:IsLocalFunctionStatement()
        return self:IsValue("local") and self:IsValue("function", 1)
    end

    function META:ReadLocalFunctionStatement()
        self:BeginStatement("local_function")
        :ExpectKeyword("local")
        :ExpectKeyword("function")
        :ExpectSimpleIdentifier()

        local node = self:GetNode()
        self:ReadFunctionBody(node)

        return self:EndStatement()
    end
end

do
    function META:IsIfStatement()
        return self:IsValue("if")
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

        if self:IsValue("...") then
            node.value = self:ReadValue("...")
        else
            node.value = self:ReadType("letter")
        end

        if self.ReadTypeExpression and self:IsValue(":") then
            node.tokens[":"] = self:ReadValue(":")
            node.type_expression = self:ReadTypeExpression()
        end

        return node
    end

    function META:ReadIdentifierList(max)
        local out = {}

        for i = 1, max or self:GetLength() do
            if (not self:IsType("letter") and not self:IsValue("...")) or self:HandleListSeparator(out, i, self:ReadIdentifier()) then
                break
            end
        end

        return out
    end
end

do -- expression

    do
        function META:IsFunctionValue()
            return self:IsValue("function")
        end

        function META:ReadFunctionValue()
            local node = self:Expression("function")
            node.tokens["function"] = self:ReadValue("function")
            self:ReadFunctionBody(node)
            return node
        end
    end

    do
        function META:IsTableSpread()
            return self:IsValue("...") and (self:IsType("letter", 1) or self:IsValue("{", 1) or self:IsValue("(", 1))
        end

        function META:ReadTableSpread()
            return self:BeginExpression("table_spread")
            :ExpectKeyword("...")
            :ExpectExpression()
            :EndExpression()
        end
    end

    function META:ReadTableEntry(i)
        if self:IsValue("[") then
            self:BeginExpression("table_expression_value")
            :Store("expression_key", true)
            :ExpectKeyword("[")
            :ExpectExpression()
            :ExpectKeyword("]")
            :ExpectKeyword("=")
        elseif self:IsType("letter") and self:IsValue("=", 1) then
            self:BeginExpression("table_key_value")
            :ExpectSimpleIdentifier()
            :ExpectKeyword("=")
        else
            self:BeginExpression("table_index_value")
            :GetNode().key = i
        end

        if self:IsTableSpread() then
            self:Store("spread", self:ReadTableSpread())
        else
            self:ExpectExpression()
        end

        return self:EndExpression()
    end

    function META:ReadTable()
        self:BeginExpression("table")
        self:ExpectKeyword("{")

        local tree = self:GetNode()
        tree.children = {}
        tree.tokens["separators"] = {}

        for i = 1, self:GetLength() do
            if self:IsValue("}") then
                break
            end

            local entry = self:ReadTableEntry(i)

            if entry.spread then
                tree.spread = true
            end

            tree.children[i] = entry

            if not self:IsValue(",") and not self:IsValue(";") and not self:IsValue("}") then
                self:Error("expected $1 got $2", nil, nil,  {",", ";", "}"}, (self:GetToken() and self:GetToken().value) or "no token")
                break
            end

            if not self:IsValue("}") then
                tree.tokens["separators"][i] = self:ReadTokenLoose()
            end
        end

        self:ExpectKeyword("}")

        return self:EndExpression()
    end

    do
        function META:IsExpressionValue()
            return syntax.IsValue(self:GetToken()) or self:IsType("letter")
        end

        function META:ReadExpressionValue()
            local node = self:Expression("value")
            node.value = self:ReadTokenLoose()
            return node
        end
    end

    function META:ReadExpression(priority, no_ambigious_calls)
        priority = priority or 0

        local node

        if self:IsValue("(") then
            local pleft = self:ReadValue("(")
            node = self:ReadExpression(0, no_ambigious_calls)
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
            node.right = self:ReadExpression(math.huge, no_ambigious_calls)
        elseif self:IsFunctionValue() then
            node = self:ReadFunctionValue()
        elseif self:IsImportExpression() then
            node = self:ReadImportExpression()
        elseif self:IsLSXExpression() then
            node = self:ReadLSXExpression()
        elseif self:IsExpressionValue() then
            node = self:ReadExpressionValue()
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
                    if self:IsType("letter", 1) and (self:IsValue("(", 2) or (not no_ambigious_calls and self:IsValue("{", 2) or self:IsType("string", 2))) then
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
                elseif self:IsValue("<") and self:IsValue("(", 1) then
                    node = self:Expression("postfix_call")
                    node.left = left
                    node.tokens["call("] = self:ReadValue("<")
                    node.tokens["call(2"] = self:ReadValue("(")
                    node.expressions = self:ReadTypeExpressionList()
                    node.tokens["call)2"] = self:ReadValue(")")
                    node.tokens["call)"] = self:ReadValue(">")
                    node.type_call = true

                    if left.value and left.value.value == ":" then
                        node.self_call = true
                    end
                elseif not no_ambigious_calls and (self:IsValue("{") or self:IsType("string")) then
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
            local right = self:ReadExpression(right_priority, no_ambigious_calls)

            node = self:Expression("binary_operator")
            node.value = op
            node.left = node.left or left
            node.right = node.right or right
        end

        return node
    end

    function META:ReadExpectExpression(priority, no_ambigious_calls)
        if syntax.IsDefinetlyNotStartOfExpression(self:GetToken()) then
            self:Error("expected beginning of expression, got $1", nil, nil, self:GetToken() and self:GetToken().value ~= "" and self:GetToken().value or self:GetToken().type)
            return
        end

        return self:ReadExpression(priority, no_ambigious_calls)
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


do -- statements
    function META:ReadRemainingStatement()
        if self:IsType("end_of_file") then
            return
        end

        if self:IsDestructureStatement(0) then
            return self:ReadDestructureAssignmentStatement()
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
            self:IsReturnStatement() then                           return self:ReadReturnStatement() elseif
            self:IsBreakStatement() then                            return self:ReadBreakStatement() elseif
            self:IsSemicolonStatement() then                        return self:ReadSemicolonStatement() elseif
            self:IsGotoStatement() then                             return self:ReadGotoStatement() elseif
            self:IsImportStatement() then                           return self:ReadImportStatement() elseif
            self:IsGotoLabelStatement() then                        return self:ReadGotoLabelStatement() elseif
            self:IsLSXStatement() then                              return self:ReadLSXStatement() elseif
            self:IsRepeatStatement() then                           return self:ReadRepeatStatement() elseif
            self:IsFunctionStatement() then                         return self:ReadFunctionStatement() elseif
            self:IsLocalTypeFunctionStatement2() then               return self:ReadLocalTypeFunctionStatement2() elseif
            self:IsLocalFunctionStatement() then                    return self:ReadLocalFunctionStatement() elseif
            self:IsLocalTypeFunctionStatement() then                return self:ReadLocalTypeFunctionStatement() elseif
            self:IsLocalTypeDeclarationStatement() then             return self:ReadLocalTypeDeclarationStatement() elseif
            self:IsLocalDestructureAssignmentStatement() then       return self:ReadLocalDestructureAssignmentStatement() elseif
            self:IsLocalAssignmentStatement() then                  return self:ReadLocalAssignmentStatement() elseif
            self:IsTypeAssignment() then                            return self:ReadTypeAssignment() elseif
            self:IsTypeComment() then                               return self:ReadTypeComment() elseif
            self:IsInterfaceStatement() then                        return self:ReadInterfaceStatement() elseif
            self:IsDoStatement() then                               return self:ReadDoStatement() elseif
            self:IsIfStatement() then                               return self:ReadIfStatement() elseif
            self:IsWhileStatement() then                            return self:ReadWhileStatement() elseif
            self:IsNumericForStatement() then                       return self:ReadNumericForStatement() elseif
            self:IsGenericForStatement() then                       return self:ReadGenericForStatement()
        end

        return self:ReadRemainingStatement()
    end
end


return require("oh.parser")(META, require("oh.lua.syntax"), require("oh.lua.emitter"))