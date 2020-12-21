local list = require("nattlua.other.list")
local syntax = require("nattlua.syntax.syntax")

local META = {}
META.__index = META

META.Emitter = require("nattlua.transpiler.emitter")
META.syntax = syntax

require("nattlua.parser.base_parser")(META)
require("nattlua.parser.parser_typesystem")(META)
require("nattlua.parser.parser_extra")(META)

do
    function META:IsBreakStatement()
        return self:IsCurrentValue("break")
    end

    function META:ReadBreakStatement()
        return self:Statement("break")
            :ExpectKeyword("break")
        :End()
    end
end

do
    function META:IsContinueStatement()
        return self:IsCurrentValue("continue")
    end

    function META:ReadContinueStatement()
        return self:Statement("continue")
            :ExpectKeyword("continue")
        :End()
    end
end

do
    function META:IsReturnStatement()
        return self:IsCurrentValue("return")
    end

    function META:ReadReturnStatement()
        return self:Statement("return")
            :ExpectKeyword("return")
            :ExpectExpressionList()
        :End()
    end
end

do
    function META:IsDoStatement()
        return self:IsCurrentValue("do")
    end

    function META:ReadDoStatement()
        return self:Statement("do")
            :ExpectKeyword("do")
                :StatementsUntil("end")
            :ExpectKeyword("end", "do")
        :End()
    end
end


do
    function META:IsWhileStatement()
        return self:IsCurrentValue("while")
    end

    function META:ReadWhileStatement()
        return self:Statement("while")
            :ExpectKeyword("while")
            :ExpectExpression()
            :ExpectKeyword("do")
            :ExpectStatementsUntil("end")
            :ExpectKeyword("end", "do")
        :End()
    end
end

do
    function META:IsRepeatStatement()
        return self:IsCurrentValue("repeat")
    end

    function META:ReadRepeatStatement()
        return self:Statement("repeat")
            :ExpectKeyword("repeat")
                :StatementsUntil("until")
            :ExpectKeyword("until")
            :ExpectExpression()
        :End()
    end
end

do
    function META:IsGotoLabelStatement()
        return self:IsCurrentValue("::")
    end

    function META:ReadGotoLabelStatement()
        return self:Statement("goto_label")
            :ExpectKeyword("::")
                :ExpectSimpleIdentifier()
            :ExpectKeyword("::")
        :End()
    end
end

do
    function META:IsGotoStatement()
        return self:IsCurrentValue("goto") and self:IsType("letter", 1)
    end

    function META:ReadGotoStatement()
        return self:Statement("goto")
            :ExpectKeyword("goto")
            :ExpectSimpleIdentifier()
        :End()
    end
end

do
    function META:IsLocalAssignmentStatement()
        return self:IsCurrentValue("local")
    end

    function META:ReadLocalAssignmentStatement()
        local node = self:Statement("local_assignment")
        node:ExpectKeyword("local")
        node.left = self:ReadIdentifierList()

        if self:IsCurrentValue("=") then
            node:ExpectKeyword("=")
            node.right = self:ReadExpressionList()
        end

        return node:End()
    end
end


do
    function META:IsNumericForStatement()
        return self:IsCurrentValue("for") and self:IsValue("=", 2)
    end

    function META:ReadNumericForStatement()
        return self:Statement("numeric_for")
            :Store("is_local", true)
            :ExpectKeyword("for")
            :ExpectIdentifierList(1)
            :ExpectKeyword("=")
            :ExpectExpressionList(3)
            
            :ExpectKeyword("do")
                :StatementsUntil("end")
            :ExpectKeyword("end", "do")
        :End()
    end
end

do
    function META:IsGenericForStatement()
        return self:IsCurrentValue("for")
    end

    function META:ReadGenericForStatement()
        return self:Statement("generic_for")
            :Store("is_local", true)
            :ExpectKeyword("for")
            :ExpectIdentifierList()
            :ExpectKeyword("in")
            :ExpectExpressionList()
            :ExpectKeyword("do")
                :StatementsUntil("end")
            :ExpectKeyword("end", "do")
        :End()
    end
end

function META:ReadFunctionBody(node)
    node.tokens["arguments("] = self:ReadValue("(")
    node.identifiers = self:ReadIdentifierList()
    node.tokens["arguments)"] = self:ReadValue(")")

    if self:HasExplicitFunctionReturn() then
        self:ReadExplicitFunctionReturn(node)
    end

    local start = self:GetCurrentToken()
    node.statements = self:ReadStatements({["end"] = true})
    node.tokens["end"] = self:ReadValue("end", start, start)
end

do  -- function

    function META:ReadIndexExpression()
        local node = self:ReadExpressionValue()
        local first = node

        for _ = 1, self:GetLength() do
            local left = node
            if not self:GetCurrentToken() then break end

            if self:IsCurrentValue(".") or self:IsCurrentValue(":") then
                local self_call = self:IsCurrentValue(":")
                
                node = self:Expression("binary_operator")
                node.value = self:ReadTokenLoose()
                node.right = self:Expression("value"):Store("value", self:ReadType("letter")):End()
                node.left = left
                node:End()
                node.right.self_call = self_call
            else
                break
            end

            if node then
                node.primary = first
            end
        end

        first.standalone_letter = node

        while self:IsCurrentValue(".") or self:IsCurrentValue(":") do
            local left = node
            node = self:Expression("binary_operator")
            node.value = self:ReadTokenLoose()
            node.left = left
            node.right = self:ReadIndexExpression()
            node:End()
        end

        return node
    end

    do
        function META:IsFunctionStatement()
            return self:IsCurrentValue("function")
        end

        function META:ReadFunctionStatement()
            local node = self:Statement("function")
            node.tokens["function"] = self:ReadValue("function")
            node.expression = self:ReadIndexExpression()
            
            if node.expression.kind == "binary_operator" then
                node.self_call = node.expression.right.self_call
            end

            self:ReadFunctionBody(node)

            return node:End()
        end
    end
end


do
    function META:IsLocalFunctionStatement()
        return self:IsCurrentValue("local") and self:IsValue("function", 1)
    end

    function META:ReadLocalFunctionStatement()
        local node = self:Statement("local_function")
        :ExpectKeyword("local")
        :ExpectKeyword("function")
        :ExpectSimpleIdentifier()

        self:ReadFunctionBody(node)

        return node:End()
    end
end

do
    function META:IsIfStatement()
        return self:IsCurrentValue("if")
    end

    function META:ReadIfStatement()
        local node = self:Statement("if")

        node.expressions = list.new()
        node.statements = list.new()
        node.tokens["if/else/elseif"] = list.new()
        node.tokens["then"] = list.new()

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

            if self:IsCurrentValue("end") then
                break
            end
        end

        node:ExpectKeyword("end")

        return node:End()
    end
end

function META:HandleListSeparator(out, i, node)
    if not node then
        return true
    end

    out[i] = node

    if not self:IsCurrentValue(",") then
        return true
    end

    node.tokens[","] = self:ReadValue(",")
end

do -- identifier
    function META:ReadIdentifier()
        local node = self:Expression("value")

        if self:IsCurrentValue("...") then
            node.value = self:ReadValue("...")
        else
            node.value = self:ReadType("letter")
        end

        if self.ReadTypeExpression and self:IsCurrentValue(":") then
            node:ExpectKeyword(":")
            node.explicit_type = self:ReadTypeExpression()
        end

        return node:End()
    end

    function META:ReadIdentifierList(max)
        local out = list.new()

        for i = 1, max or self:GetLength() do
            if (not self:IsCurrentType("letter") and not self:IsCurrentValue("...")) or self:HandleListSeparator(out, i, self:ReadIdentifier()) then
                break
            end
        end

        return out
    end
end

do -- expression

    do
        function META:IsFunctionValue()
            return self:IsCurrentValue("function")
        end

        function META:ReadFunctionValue()
            local node = self:Expression("function"):ExpectKeyword("function")
            self:ReadFunctionBody(node)
            return node:End()
        end
    end

    do
        function META:IsTableSpread()
            return self:IsCurrentValue("...") and (self:IsType("letter", 1) or self:IsValue("{", 1) or self:IsValue("(", 1))
        end

        function META:ReadTableSpread()
            return self:Expression("table_spread")
            :ExpectKeyword("...")
            :ExpectExpression()
            :End()
        end
    end

    function META:ReadTableEntry(i)
        local node
        if self:IsCurrentValue("[") then
            node = self:Expression("table_expression_value")
            :Store("expression_key", true)
            :ExpectKeyword("[")
            :ExpectExpression()
            :ExpectKeyword("]")
            :ExpectKeyword("=")
        elseif self:IsCurrentType("letter") and self:IsValue("=", 1) then
            node = self:Expression("table_key_value")
            :ExpectSimpleIdentifier()
            :ExpectKeyword("=")
        else
            node = self:Expression("table_index_value")
            node.key = i
        end

        if self:IsTableSpread() then
            node.spread = self:ReadTableSpread()
        else
            node:ExpectExpression()
        end

        return node:End()
    end

    function META:ReadTable()
        local tree = self:Expression("table")
        tree:ExpectKeyword("{")

        tree.children = list.new()
        tree.tokens["separators"] = list.new()

        for i = 1, self:GetLength() do
            if self:IsCurrentValue("}") then
                break
            end

            local entry = self:ReadTableEntry(i)

            if entry.kind == "table_index_value" then
                tree.is_array = true
            else
                tree.is_dictionary = true
            end

            if entry.spread then
                tree.spread = true
            end

            tree.children[i] = entry

            if not self:IsCurrentValue(",") and not self:IsCurrentValue(";") and not self:IsCurrentValue("}") then
                self:Error("expected $1 got $2", nil, nil,  {",", ";", "}"}, (self:GetCurrentToken() and self:GetCurrentToken().value) or "no token")
                break
            end

            if not self:IsCurrentValue("}") then
                tree.tokens["separators"][i] = self:ReadTokenLoose()
            end
        end

        tree:ExpectKeyword("}")

        return tree:End()
    end

    do
        function META:IsExpressionValue()
            return syntax.IsValue(self:GetCurrentToken())
        end

        function META:ReadExpressionValue()
            return self:Expression("value"):Store("value", self:ReadTokenLoose()):End()
        end
    end


    do
        function META:IsCallExpression(no_ambiguous_calls, offset)
            offset = offset or 0
            if no_ambiguous_calls then
                return self:IsValue("(", offset)
            end

            return self:IsValue("(", offset) or self:IsValue("{", offset) or self:IsType("string", offset)
        end

        function META:ReadCallExpression(no_ambiguous_calls)
            local node = self:Expression("postfix_call")

            if self:IsCurrentValue("{") then
                node.expressions = list.new(self:ReadTable())
            elseif self:IsCurrentType("string") then
                node.expressions = list.new(self:Expression("value"):Store("value", self:ReadTokenLoose()):End())
            else
                node.tokens["call("] = self:ReadValue("(")
                node.expressions = self:ReadExpressionList()
                node.tokens["call)"] = self:ReadValue(")")
            end

            return node:End()
        end
    end

    do
        function META:IsPostfixExpressionIndex()
            return self:IsCurrentValue("[")
        end

        function META:ReadPostfixExpressionIndex()
            return self:Expression("postfix_expression_index")
                :ExpectKeyword("[")
                :ExpectExpression()
                :ExpectKeyword("]")
            :End()
        end
    end

    function META:CheckForIntegerDivisionOperator(node)
        if node and not node.idiv_resolved then
            for i, token in node.whitespace:pairs() do
                if token.type == "line_comment" and token.value:sub(1, 2) == "//" then
                    node.whitespace:remove(i)

                    local tokens = require("nattlua.lexer.lexer")("/idiv" .. token.value:sub(2)):GetTokens()
                    
                    for _, token in tokens:pairs() do
                        self:CheckForIntegerDivisionOperator(token)
                    end
                    
                    self:AddTokens(tokens)
                    node.idiv_resolved = true
                    
                    break
                end
            end
        end
    end

    function META:ReadExpression(priority, no_ambiguous_calls)
        priority = priority or 0

        local node

        if self:IsCurrentValue("(") then
            local pleft = self:ReadValue("(")
            node = self:ReadExpression(0, no_ambiguous_calls)
            if not node then
                self:Error("empty parentheses group", pleft)
                return
            end

            node.tokens["("] = node.tokens["("] or list.new()
            node.tokens["("]:insert(1, pleft)

            node.tokens[")"] = node.tokens[")"] or list.new()
            node.tokens[")"]:insert(self:ReadValue(")"))

        elseif syntax.IsPrefixOperator(self:GetCurrentToken()) then
            node = self:Expression("prefix_operator")
            node.value = self:ReadTokenLoose()
            node.tokens[1] = node.value
            node.right = self:ReadExpectExpression(math.huge, no_ambiguous_calls)
            node:End()
        elseif self:IsFunctionValue() then
            node = self:ReadFunctionValue()
        elseif self:IsImportExpression() then
            node = self:ReadImportExpression()
        elseif self:IsLSXExpression() then
            node = self:ReadLSXExpression()
        elseif self:IsExpressionValue() then
            node = self:ReadExpressionValue()
        elseif self:IsCurrentValue("{") then
            node = self:ReadTable()
        end

        local first = node

        if node then
            for _ = 1, self:GetLength() do
                local left = node
                if not self:GetCurrentToken() then break end

                if self:IsCurrentValue(":") and (not self:IsType("letter", 1) and not self:IsCallExpression(nil, 2)) then
                    node.tokens[":"] = self:ReadValue(":")
                    node.explicit_type = self:ReadTypeExpression()
                elseif (self:IsCurrentValue(".") or self:IsCurrentValue(":")) and self:IsType("letter", 1) then
                    if self:IsCurrentValue(".") or self:IsCallExpression(no_ambiguous_calls, 2) then
                        node = self:Expression("binary_operator")
                        node.value = self:ReadTokenLoose()
                        node.right = self:Expression("value"):Store("value", self:ReadType("letter")):End()
                        node.left = left
                        node:End()
                    elseif self:IsCurrentValue(":") then
                        node.tokens[":"] = self:ReadValue(":")
                        node.explicit_type = self:ReadTypeExpression()
                    end
                elseif syntax.IsPostfixOperator(self:GetCurrentToken()) then
                    node = self
                        :Expression("postfix_operator")
                            :Store("left", left)
                            :Store("value", self:ReadTokenLoose())
                        :End()
                elseif self:IsCallExpression(no_ambiguous_calls) then
                    node = self:ReadCallExpression(no_ambiguous_calls)
                    node.left = left
                    if left.value and left.value.value == ":" then
                        node.self_call = true
                    end
                elseif self:IsPostfixExpressionIndex() then
                    node = self:ReadPostfixExpressionIndex()
                    node.left = left
                elseif self:IsCurrentValue("as") then
                    node.tokens["as"] = self:ReadValue("as")
                    node.explicit_type = self:ReadTypeExpression()
                elseif self:IsCurrentValue("is") then
                    node.tokens["is"] = self:ReadValue("is")
                    node.explicit_type = self:ReadTypeExpression()
                elseif self:IsTypeCall() then
                    node = self:ReadTypeCall()

                    node.left = left
                    if left.value and left.value.value == ":" then
                        node.self_call = true
                    end
                else
                    break
                end

                if node then
                    node.primary = first
                end
            end

            if first.kind == "value" and (first.value.type == "letter" or first.value.value == "...") then
                first.standalone_letter = node
            end
        end

        self:CheckForIntegerDivisionOperator(self:GetCurrentToken())

        while syntax.GetBinaryOperatorInfo(self:GetCurrentToken()) and syntax.GetBinaryOperatorInfo(self:GetCurrentToken()).left_priority > priority do
            local left = node
            node = self:Expression("binary_operator")
            node.value = self:ReadTokenLoose()
            node.left = left
            node.right = self:ReadExpression(syntax.GetBinaryOperatorInfo(node.value).right_priority, no_ambiguous_calls)
            node:End()
        end

        return node
    end


    local function IsDefinetlyNotStartOfExpression(token)
        return
        not token or token.type == "end_of_file" or
        token.value == "}" or token.value == "," or
        --[[token.value == "[" or]] token.value == "]" or
        (
            syntax.IsKeyword(token) and
            not syntax.IsPrefixOperator(token) and
            not syntax.IsValue(token) and
            token.value ~= "function"
        )
    end

    function META:ReadExpectExpression(priority, no_ambiguous_calls)
        if IsDefinetlyNotStartOfExpression(self:GetCurrentToken()) then
            self:Error("expected beginning of expression, got $1", nil, nil, self:GetCurrentToken() and self:GetCurrentToken().value ~= "" and self:GetCurrentToken().value or self:GetCurrentToken().type)
            return
        end

        return self:ReadExpression(priority, no_ambiguous_calls)
    end

    function META:ReadExpressionList(max)
        local out = list.new()

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
        if self:IsCurrentType("end_of_file") then
            return
        end

        local start = self:GetCurrentToken()
        local left = self:ReadExpressionList(math.huge)

        if self:IsCurrentValue("=") then
            local node = self:Statement("assignment")
            node:ExpectKeyword("=")
            node.left = left
            node.right = self:ReadExpressionList(math.huge)

            return node:End()
        end

        if left[1] and left[1].kind == "postfix_call" and not left[2] then
            local node = self:Statement("call_expression")
            node.value = left[1]
            node.tokens = left[1].tokens
            return node:End()
        end

        self:Error("expected assignment or call expression got $1 ($2)", start, self:GetCurrentToken(), self:GetCurrentToken().type, self:GetCurrentToken().value)
    end

    function META:ReadStatement()
        if
            self:IsInlineTypeCode() then                            return self:ReadInlineTypeCode() elseif
            self:IsReturnStatement() then                           return self:ReadReturnStatement() elseif
            self:IsBreakStatement() then                            return self:ReadBreakStatement() elseif
            self:IsContinueStatement() then                         return self:ReadContinueStatement() elseif
            self:IsSemicolonStatement() then                        return self:ReadSemicolonStatement() elseif
            self:IsGotoStatement() then                             return self:ReadGotoStatement() elseif
            self:IsImportStatement() then                           return self:ReadImportStatement() elseif
            self:IsGotoLabelStatement() then                        return self:ReadGotoLabelStatement() elseif
            self:IsLSXStatement() then                              return self:ReadLSXStatement() elseif
            self:IsRepeatStatement() then                           return self:ReadRepeatStatement() elseif
            self:IsTypeFunctionStatement() then                     return self:ReadTypeFunctionStatement() elseif
            self:IsFunctionStatement() then                         return self:ReadFunctionStatement() elseif
            self:IsLocalGenericsTypeFunctionStatement() then        return self:ReadLocalGenericsTypeFunctionStatement() elseif
            self:IsLocalFunctionStatement() then                    return self:ReadLocalFunctionStatement() elseif
            self:IsLocalTypeFunctionStatement() then                return self:ReadLocalTypeFunctionStatement() elseif
            self:IsLocalTypeDeclarationStatement() then             return self:ReadLocalTypeDeclarationStatement() elseif
            self:IsLocalDestructureAssignmentStatement() then       return self:ReadLocalDestructureAssignmentStatement() elseif
            self:IsLocalAssignmentStatement() then                  return self:ReadLocalAssignmentStatement() elseif
            self:IsTypeAssignment() then                            return self:ReadTypeAssignment() elseif
            self:IsInterfaceStatement() then                        return self:ReadInterfaceStatement() elseif
            self:IsDoStatement() then                               return self:ReadDoStatement() elseif
            self:IsIfStatement() then                               return self:ReadIfStatement() elseif
            self:IsWhileStatement() then                            return self:ReadWhileStatement() elseif
            self:IsNumericForStatement() then                       return self:ReadNumericForStatement() elseif
            self:IsGenericForStatement() then                       return self:ReadGenericForStatement() elseif
            self:IsDestructureStatement() then                      return self:ReadDestructureAssignmentStatement() elseif

            false then end

        return self:ReadRemainingStatement()
    end
end

return function(config)
    return setmetatable({
        config = config,
        nodes = list.new(),
        name = "",
        code = "",
        current_statement = false,
        current_expression = false,
        root = false,
        i = 1,
        tokens = list.new(),
        OnError = function() end,
    }, META)
end