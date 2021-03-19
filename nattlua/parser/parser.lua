local list = require("nattlua.other.list")
local syntax = require("nattlua.syntax.syntax")

local META = {}
META.__index = META

META.Emitter = require("nattlua.transpiler.emitter")
META.syntax = syntax

require("nattlua.parser.base_parser")(META)
require("nattlua.parser.parser_typesystem")(META)
require("nattlua.parser.parser_extra")(META)

function META:ResolvePath(path)
    return path
end

function META:ReadBreakStatement()
    return 
        self:IsCurrentValue("break") and 
        self:Statement("break")
        :ExpectKeyword("break")
    :End()
end

function META:ReadContinueStatement()
    return 
        self:IsCurrentValue("continue") and 
        self:Statement("continue")
        :ExpectKeyword("continue")
    :End()
end

function META:ReadReturnStatement()
    return 
        self:IsCurrentValue("return") and 
        self:Statement("return")
        :ExpectKeyword("return")
        :ExpectExpressionList()
    :End()
end

function META:ReadDoStatement()
    return
        self:IsCurrentValue("do") and 
        self:Statement("do")
        :ExpectKeyword("do")
            :ExpectStatementsUntil("end")
        :ExpectKeyword("end", "do")
    :End()
end

function META:ReadWhileStatement()
    return 
        self:IsCurrentValue("while") and 
        self:Statement("while")
        :ExpectKeyword("while")
        :ExpectExpression()
        :ExpectKeyword("do")
            :ExpectStatementsUntil("end")
        :ExpectKeyword("end", "do")
    :End()
end

function META:ReadRepeatStatement()
    return 
        self:IsCurrentValue("repeat") and 
        self:Statement("repeat")
        :ExpectKeyword("repeat")
            :ExpectStatementsUntil("until")
        :ExpectKeyword("until")
        :ExpectExpression()
    :End()
end

function META:ReadGotoLabelStatement()
    return 
        self:IsCurrentValue("::") and 
        self:Statement("goto_label")
        :ExpectKeyword("::")
            :ExpectSimpleIdentifier()
        :ExpectKeyword("::")
    :End()
end

function META:ReadGotoStatement()
    return 
        self:IsCurrentValue("goto") and self:IsType("letter", 1) and
        self:Statement("goto")
        :ExpectKeyword("goto")
        :ExpectSimpleIdentifier()
    :End()
end

function META:ReadLocalAssignmentStatement()
    if not self:IsCurrentValue("local") then return end

    local node = self:Statement("local_assignment")
    node:ExpectKeyword("local")
    node.left = self:ReadIdentifierList()

    if self:IsCurrentValue("=") then
        node:ExpectKeyword("=")
        node.right = self:ReadExpressionList()
    end

    return node:End()
end

function META:ReadNumericForStatement()
    return 
        self:IsCurrentValue("for") and self:IsValue("=", 2) and 
        self:Statement("numeric_for")
        :ExpectKeyword("for")
        :ExpectIdentifierList(1)
        :ExpectKeyword("=")
        :ExpectExpressionList(3)
        
        :ExpectKeyword("do")
            :ExpectStatementsUntil("end")
        :ExpectKeyword("end", "do")
    :End()
end

function META:ReadGenericForStatement()
    return 
        self:IsCurrentValue("for") and 
        self:Statement("generic_for")
        :ExpectKeyword("for")
        :ExpectIdentifierList()
        :ExpectKeyword("in")
        :ExpectExpressionList()
        :ExpectKeyword("do")
            :ExpectStatementsUntil("end")
        :ExpectKeyword("end", "do")
    :End()
end

function META:ReadFunctionBody(node)
    node:ExpectAliasedKeyword("(", "arguments(")
    node:ExpectIdentifierList()
    node:ExpectAliasedKeyword(")", "arguments)", "arguments)")

    self:ReadExplicitFunctionReturnType(node)

    node:ExpectStatementsUntil("end")
    node:ExpectKeyword("end", "function")

    return node
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

    function META:ReadFunctionStatement()
        if not self:IsCurrentValue("function") then return end

        local node = self:Statement("function")
        node.tokens["function"] = self:ReadValue("function")
        node.expression = self:ReadIndexExpression()
        
        if node.expression.kind == "binary_operator" then
            node.self_call = node.expression.right.self_call
        end

        if self:IsCurrentValue("<|") then
            node.kind = "generics_type_function"
            
            self:ReadGenericsTypeFunctionBody(node)
        else
            self:ReadFunctionBody(node)
        end

        return node:End()
    end
end

function META:ReadLocalFunctionStatement()
    if not (self:IsCurrentValue("local") and self:IsValue("function", 1)) then return end

    local node = self:Statement("local_function")
    :ExpectKeyword("local")
    :ExpectKeyword("function")
    :ExpectSimpleIdentifier()

    self:ReadFunctionBody(node)

    return node:End()
end

function META:ReadIfStatement()
    if not self:IsCurrentValue("if") then return end

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

    function META:ReadFunctionValue()
        if not self:IsCurrentValue("function") then return end

        local node = self:Expression("function"):ExpectKeyword("function")
        self:ReadFunctionBody(node)
        return node:End()
    end

    function META:ReadTableSpread()
        if not (self:IsCurrentValue("...") and (self:IsType("letter", 1) or self:IsValue("{", 1) or self:IsValue("(", 1))) then return end

        return self:Expression("table_spread")
        :ExpectKeyword("...")
        :ExpectExpression()
        :End()
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

        node.spread = self:ReadTableSpread()
        
        if not node.spread then
            node:ExpectExpression()
        end

        return node:End()
    end

    function META:ReadTable()
        if not self:IsCurrentValue("{") then return end

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

    function META:ReadExpressionValue()
        if not syntax.IsValue(self:GetCurrentToken()) then return end
        return self:Expression("value"):Store("value", self:ReadTokenLoose()):End()
    end


    do
        function META:IsCallExpression(no_ambiguous_calls, offset)
            offset = offset or 0

            if no_ambiguous_calls then
                return self:IsValue("(", offset) or self:IsCurrentValue("<|", offset)
            end

            return self:IsValue("(", offset) or self:IsCurrentValue("<|", offset) or self:IsValue("{", offset) or self:IsType("string", offset)
        end

        function META:ReadCallExpression()
            local node = self:Expression("postfix_call")

            if self:IsCurrentValue("{") then
                node.expressions = list.new(self:ReadTable())
            elseif self:IsCurrentType("string") then
                node.expressions = list.new(self:Expression("value"):Store("value", self:ReadTokenLoose()):End())
            elseif self:IsCurrentValue("<|") then
                node.tokens["call("] = self:ReadValue("<|")
                node.expressions = self:ReadTypeExpressionList()
                node.tokens["call)"] = self:ReadValue("|>")
                node.type_call = true
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

    function META:ReadPrefixOperatorExpression()
        if not syntax.IsPrefixOperator(self:GetCurrentToken()) then return end
        local node = self:Expression("prefix_operator")
        node.value = self:ReadTokenLoose()
        node.tokens[1] = node.value
        node.right = self:ReadExpectExpression(math.huge, no_ambiguous_calls)
        return node:End()
    end

    function META:ReadParenthesisExpression(no_ambiguous_calls)
        if not self:IsCurrentValue("(") then return end

        local pleft = self:ReadValue("(")
        local node = self:ReadExpression(0, no_ambiguous_calls)

        if not node then
            self:Error("empty parentheses group", pleft)
            return
        end

        node.tokens["("] = node.tokens["("] or list.new()
        node.tokens["("]:insert(1, pleft)

        node.tokens[")"] = node.tokens[")"] or list.new()
        node.tokens[")"]:insert(self:ReadValue(")"))

        return node
    end

    do
        function META:ReadAndAddExplicitType(node, no_ambiguous_calls)
            if self:IsCurrentValue(":") and self:IsType("letter", 1) and not self:IsCallExpression(no_ambiguous_calls, 2) then
                node.tokens[":"] = self:ReadValue(":")
                node.explicit_type = self:ReadTypeExpression()
            elseif self:IsCurrentValue("as") then
                node.tokens["as"] = self:ReadValue("as")
                node.explicit_type = self:ReadTypeExpression()
            elseif self:IsCurrentValue("is") then
                node.tokens["is"] = self:ReadValue("is")
                node.explicit_type = self:ReadTypeExpression()
            end
        end

        function META:ReadIndexSubExpression()
            if not (self:IsCurrentValue(".") and self:IsType("letter", 1)) then return end
            local node = self:Expression("binary_operator")
            node.value = self:ReadTokenLoose()
            node.right = self:Expression("value"):Store("value", self:ReadType("letter")):End()
            return node:End()
        end

        function META:ReadSelfCallSubExpression(no_ambiguous_calls)
            if not (self:IsCurrentValue(":") and self:IsType("letter", 1) and self:IsCallExpression(no_ambiguous_calls, 2)) then return end
            local node = self:Expression("binary_operator")
            node.value = self:ReadTokenLoose()
            node.right = self:Expression("value"):Store("value", self:ReadType("letter")):End()
            return node:End()
        end

        function META:ReadPostfixOperatorSubExpression()
            if not syntax.IsPostfixOperator(self:GetCurrentToken()) then return end

            return self:Expression("postfix_operator")
                :Store("value", self:ReadTokenLoose())
            :End()
        end

        function META:ReadCallSubExpression(no_ambiguous_calls)
            if not self:IsCallExpression(no_ambiguous_calls) then return end
            return self:ReadCallExpression()
        end

        function META:ReadPostfixExpressionIndexSubExpression()
            if not self:IsPostfixExpressionIndex() then return end
            return self:ReadPostfixExpressionIndex()            
        end

        function META:ReadSubExpression(node)
            
            for _ = 1, self:GetLength() do
                local left_node = node

                self:ReadAndAddExplicitType(node, no_ambiguous_calls)

                local found = 
                    self:ReadIndexSubExpression() or 
                    self:ReadSelfCallSubExpression(no_ambiguous_calls) or
                    self:ReadPostfixOperatorSubExpression() or 
                    self:ReadCallSubExpression(no_ambiguous_calls) or 
                    self:ReadPostfixExpressionIndexSubExpression()

                if not found then
                    break
                end

                found.left = left_node

                if left_node.value and left_node.value.value == ":" then
                    found.self_call = true
                end

                node = found
            end
            
            return node
        end
    end

    function META:ReadExpression(priority, no_ambiguous_calls)
        priority = priority or 0

        local node =  
            self:ReadParenthesisExpression(no_ambiguous_calls) or
            self:ReadPrefixOperatorExpression() or
                self:ReadFunctionValue() or 
                self:ReadImportExpression() or 
                self:ReadLSXExpression() or
                self:ReadExpressionValue() or
                self:ReadTable()

        local first = node

        if node then
            node = self:ReadSubExpression(node)

            if first.kind == "value" and (first.value.type == "letter" or first.value.value == "...") then
                first.standalone_letter = node
            end
        end

        self:CheckForIntegerDivisionOperator(self:GetCurrentToken())

        while syntax.GetBinaryOperatorInfo(self:GetCurrentToken()) and syntax.GetBinaryOperatorInfo(self:GetCurrentToken()).left_priority > priority do
            local left_node = node
            node = self:Expression("binary_operator")
            node.value = self:ReadTokenLoose()
            node.left = left_node
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

        if left[1] and (left[1].kind == "postfix_call" or left[1].kind == "import") and not left[2] then
            local node = self:Statement("call_expression")
            node.value = left[1]
            node.tokens = left[1].tokens
            return node:End()
        end

        self:Error("expected assignment or call expression got $1 ($2)", start, self:GetCurrentToken(), self:GetCurrentToken().type, self:GetCurrentToken().value)
    end

    function META:ReadStatement()
        return 
            self:ReadInlineTypeCode() or
            self:ReadReturnStatement() or
            self:ReadBreakStatement() or
            self:ReadContinueStatement() or
            self:ReadSemicolonStatement() or
            self:ReadGotoStatement() or
            self:ReadImportStatement() or
            self:ReadGotoLabelStatement() or
            self:ReadLSXStatement() or
            self:ReadRepeatStatement() or
            self:ReadTypeFunctionStatement() or
            self:ReadFunctionStatement() or
            self:ReadLocalGenericsTypeFunctionStatement() or
            self:ReadLocalFunctionStatement() or
            self:ReadLocalTypeFunctionStatement() or
            self:ReadLocalTypeDeclarationStatement() or
            self:ReadLocalDestructureAssignmentStatement() or
            self:ReadLocalAssignmentStatement() or
            self:ReadTypeAssignment() or
            self:ReadInterfaceStatement() or
            self:ReadDoStatement() or
            self:ReadIfStatement() or
            self:ReadWhileStatement() or
            self:ReadNumericForStatement() or
            self:ReadGenericForStatement() or
            self:ReadDestructureAssignmentStatement() or 
            self:ReadRemainingStatement()
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