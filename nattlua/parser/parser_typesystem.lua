local list = require("nattlua.other.list")

return function(META)
    local math_huge = math.huge
    local syntax = require("nattlua.syntax.syntax")

    do
        function META:IsInlineTypeCode()
            return self:IsCurrentType("type_code")
        end

        function META:ReadInlineTypeCode()
            local node = self:Statement("type_code")

            local code = self:Expression("value")
            code.value = self:ReadType("type_code")
            node.lua_code = code
            
            return node
        end
    end
    function META:HandleTypeListSeparator(out, i, node)
        if not node then
            return true
        end

        out[i] = node

        if not self:IsCurrentValue(",") and not self:IsCurrentValue(";") then
            return true
        end

        if self:IsCurrentValue(";") then
            node.tokens[","] = self:ReadValue(";")
        else
            node.tokens[","] = self:ReadValue(",")
        end
    end


    do -- identifier
        function META:ReadTypeExpressionList(max)
            local out = list.new()

            for i = 1, math_huge do
                if self:HandleTypeListSeparator(out, i, self:ReadTypeExpression()) then
                    break
                end

                if max then
                    max = max - 1
                    if max == 0 then
                        break
                    end
                end
            end

            return out
        end
    end

    do
        function META:IsLocalTypeFunctionStatement()
            return self:IsCurrentValue("local") and self:IsValue("type", 1) and self:IsValue("function", 2)
        end

        function META:ReadLocalTypeFunctionStatement()
            local node = self:Statement("local_type_function")
            :ExpectKeyword("local")
            :ExpectKeyword("type")
            :ExpectKeyword("function")
            :ExpectSimpleIdentifier()
            self:ReadTypeFunctionBody(node, true)
            return node:End() 
        end
    end


    do
        function META:IsTypeFunctionStatement()
            return self:IsCurrentValue("type") and self:IsValue("function", 1)
        end

        function META:ReadTypeFunctionStatement()
            local node = self:Statement("type_function")
            node.tokens["type"] = self:ReadValue("type")
            node.tokens["function"] = self:ReadValue("function")
            local force_upvalue
            if self:IsCurrentValue("^") then
                force_upvalue = true
                self:Advance(1)
            end
            node.expression = self:ReadIndexExpression()

            do -- hacky
                if node.expression.left then
                    node.expression.left.standalone_letter = node
                    node.expression.left.force_upvalue = force_upvalue
                else
                    node.expression.standalone_letter = node
                    node.expression.force_upvalue = force_upvalue
                end

                if node.expression.value.value == ":" then
                    node.self_call = true
                end
            end

            self:ReadTypeFunctionBody(node, true)

            return node
        end
    end


    do
        function META:IsLocalGenericsTypeFunctionStatement()
            return self:IsCurrentValue("local") and self:IsValue("function", 1) and self:IsValue("<|", 3)
        end

        function META:ReadLocalGenericsTypeFunctionStatement()
            local node = self:Statement("local_generics_type_function")
            :ExpectKeyword("local")
            :ExpectKeyword("function")
            :ExpectSimpleIdentifier()
            self:ReadTypeFunctionBody2(node)
            return node:End()
        end
    end

    function META:ReadTypeFunctionArgument()
        if (self:IsCurrentType("letter") or self:IsCurrentValue("...")) and self:IsValue(":", 1) then
            local identifier = self:ReadTokenLoose()
            local token = self:ReadValue(":")
            local exp = self:ReadTypeExpression()
            exp.tokens[":"] = token
            exp.identifier = identifier
            return exp
        end

        return self:ReadTypeExpression()
    end

    function META:HasExplicitFunctionReturn()
        return self:IsCurrentValue(":") 
    end

    function META:ReadExplicitFunctionReturn(node)
        node.tokens[":"] = self:ReadValue(":")

        local out = list.new()
        for i = 1, self:GetLength() do

            local typ = self:ReadTypeExpression()

            if self:HandleListSeparator(out, i, typ) then
                break
            end
        end

        node.return_types = out
    end

    function META:ReadTypeFunctionBody(node, plain_args)
        node.tokens["arguments("] = self:ReadValue("(")

        if plain_args then
            node.identifiers = self:ReadIdentifierList()
        else
            node.identifiers = list.new()

            for i = 1, math_huge do
                if self:HandleListSeparator(node.identifiers, i, self:ReadTypeFunctionArgument()) then
                    break
                end
            end
        end

        if self:IsCurrentValue("...") then
            local vararg = self:Expression("value")
            vararg.value = self:ReadValue("...")
            
            if self:IsCurrentType("letter") then
                vararg.explicit_type = self:ReadValue()
            end
            node.identifiers:insert(vararg)
        end

        node.tokens["arguments)"] = self:ReadValue(")", node.tokens["arguments("])

        if self:IsCurrentValue(":") then
            node.tokens[":"] = self:ReadValue(":")
            node.return_types = self:ReadTypeExpressionList()
        elseif not self:IsCurrentValue(",") then
            local start = self:GetCurrentToken()
            node.statements = self:ReadStatements({["end"] = true})
            node.tokens["end"] = self:ReadValue("end", start, start)
        end

        return node
    end

    function META:ReadTypeFunctionBody2(node)
        node.tokens["arguments("] = self:ReadValue("<|")

        node.identifiers = self:ReadIdentifierList()

        if self:IsCurrentValue("...") then
            local vararg = self:Expression("value")
            vararg.value = self:ReadValue("...")
            node.identifiers:insert(vararg)
        end

        node.tokens["arguments)"] = list.new(self:ReadValue("|>", node.tokens["arguments("]))

        if self:IsCurrentValue(":") then
            node.tokens[":"] = self:ReadValue(":")
            node.return_types = self:ReadTypeExpressionList()
        else
            local start = self:GetCurrentToken()
            node.statements = self:ReadStatements({["end"] = true})
            node.tokens["end"] = self:ReadValue("end", start, start)
        end

        return node
    end

    function META:ReadTypeFunction(plain_args)
        local node = self:Expression("type_function")
        node.tokens["function"] = self:ReadValue("function")
        return self:ReadTypeFunctionBody(node, plain_args)
    end


    function META:ExpectTypeExpression(node)
        if node.expressions then
            node.expressions:insert(self:ReadTypeExpression())
        elseif node.expression then
            node.expressions = list.new(node.expression)
            node.expression = nil
            node.expressions:insert(self:ReadTypeExpression())
        else
            node.expression = self:ReadTypeExpression()
        end

        return node
    end


    function META:ReadTypeTableEntry(i)
        local node
        if self:IsCurrentValue("[") then
            node = self:Expression("table_expression_value")
            :Store("expression_key", true)
            :ExpectKeyword("[")

            self:ExpectTypeExpression(node)

            node:ExpectKeyword("]")
            :ExpectKeyword("=")
        elseif self:IsCurrentType("letter") and self:IsValue("=", 1) then
            node = self:Expression("table_key_value")
            :ExpectSimpleIdentifier()
            :ExpectKeyword("=")
        else
            node = self:Expression("table_index_value")
            :Store("key", i)
        end

        self:ExpectTypeExpression(node)

        return node:End()
    end

    function META:ReadTypeTable()
        local tree = self:Expression("type_table")
        tree:ExpectKeyword("{")

        tree.children = list.new()
        tree.tokens["separators"] = list.new()

        for i = 1, math_huge do
            if self:IsCurrentValue("}") then
                break
            end

            local entry = self:ReadTypeTableEntry(i)

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
        function META:IsTypeCall()
            return self:IsCurrentValue("<|")
        end

        function META:ReadTypeCall()
            local node = self:Expression("postfix_call")
            node.tokens["call("] = self:ReadValue("<|")
            node.expressions = self:ReadTypeExpressionList()
            node.tokens["call)"] = self:ReadValue("|>")
            node.type_call = true
            return node:End()
        end
    end

    function META:ReadTypeExpression(priority)
        priority = priority or 0

        local node

        local force_upvalue
        if self:IsCurrentValue("^") then
            force_upvalue = true
            self:Advance(1)
        end

        if self:IsCurrentValue("(") then
            local pleft = self:ReadValue("(")
            node = self:ReadTypeExpression(0)
            if not node then
                self:Error("empty parentheses group", pleft)
                return
            end

            node.tokens["("] = node.tokens["("] or list.new()
            node.tokens["("]:insert(1, pleft)


            node.tokens[")"] = node.tokens[")"] or list.new()
            node.tokens[")"]:insert(self:ReadValue(")"))

        elseif syntax.typesystem.IsPrefixOperator(self:GetCurrentToken()) then
            node = self:Expression("prefix_operator")
            node.value = self:ReadTokenLoose()
            node.tokens[1] = node.value
            node.right = self:ReadTypeExpression(math_huge)
        elseif self:IsCurrentValue("...") and self:IsType("letter", 1) then
            node = self:Expression("value")
            node.value = self:ReadValue("...")
            node.explicit_type = self:ReadTypeExpression()
        elseif self:IsCurrentType("letter") and self:IsValue("...", 1) then
            node = self:Expression("vararg_tuple")
            node.value = self:ReadTokenLoose()
            node.tokens["..."] = self:ReadValue("...")
        elseif self:IsCurrentValue("function") and self:IsValue("(", 1) then
            node = self:ReadTypeFunction()
        elseif syntax.typesystem.IsValue(self:GetCurrentToken()) then
            node = self:Expression("value")
            node.value = self:ReadTokenLoose()
        elseif self:IsCurrentValue("{") then
            node = self:ReadTypeTable()
        elseif self:IsCurrentType("$") and self:IsType("string", 1) then
            node = self:Expression("type_string")
            node.tokens["$"] = self:ReadTokenLoose("...")
            node.value = self:ReadType("string")
        elseif self:IsCurrentValue("[") then
            node = self:Expression("type_list")
            node.tokens["["] = self:ReadValue("[")
            node.expressions = self:ReadTypeExpressionList()
            node.tokens["]"] = self:ReadValue("]")
        end

        local first = node

        if node then
            for _ = 1, self:GetLength() do
                local left = node
                if not self:GetCurrentToken() then break end

                if (self:IsCurrentValue(".") or self:IsCurrentValue(":")) and self:IsType("letter", 1) then
                    if self:IsCurrentValue(".") or self:IsCallExpression(true, 2) then
                        node = self:Expression("binary_operator")
                        node.value = self:ReadTokenLoose()
                        node.right = self:Expression("value"):Store("value", self:ReadType("letter")):End()
                        node.left = left
                        node:End()
                    elseif self:IsCurrentValue(":") then
                        node.tokens[":"] = self:ReadValue(":")
                        node.explicit_type = self:ReadTypeExpression()
                    end
                elseif syntax.typesystem.IsPostfixOperator(self:GetCurrentToken()) then
                    node = self:Expression("postfix_operator")
                    node.left = left
                    node.value = self:ReadTokenLoose()
                elseif self:IsCurrentValue("[") and self:IsValue("]", 1) then
                    node = self:Expression("type_list")
                    node.tokens["["] = self:ReadValue("[")
                    node.expressions = self:ReadTypeExpressionList()
                    node.tokens["]"] = self:ReadValue("]")
                    node.left = left
                elseif self:IsTypeCall() then
                    node = self:ReadTypeCall()
                    node.left = left
                elseif self:IsCallExpression(true) then
                    node = self:ReadCallExpression(true)
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
                else
                    break
                end

                if node then
                    node.primary = first
                end
            end
        end

        if first and first.kind == "value" and (first.value.type == "letter" or first.value.value == "...") then
            first.standalone_letter = node
            first.force_upvalue = force_upvalue
        end

        while syntax.typesystem.GetBinaryOperatorInfo(self:GetCurrentToken()) and syntax.typesystem.GetBinaryOperatorInfo(self:GetCurrentToken()).left_priority > priority do
            local op = self:GetCurrentToken()
            local right_priority = syntax.typesystem.GetBinaryOperatorInfo(op).right_priority
            if not op or not right_priority then break end
            self:Advance(1)

            local left = node
            local right = self:ReadTypeExpression(right_priority)

            node = self:Expression("binary_operator")
            node.value = op
            node.left = node.left or left
            node.right = node.right or right
        end

        return node
    end

    do
        function META:IsLocalTypeDeclarationStatement()
            return self:IsCurrentValue("local") and self:IsValue("type", 1) and syntax.GetTokenType(self:GetToken(2)) == "letter"
        end

        function META:ReadLocalTypeDeclarationStatement()
            local node = self:Statement("local_assignment")

            node.tokens["local"] = self:ReadValue("local")
            node.tokens["type"] = self:ReadValue("type")

            node.left = self:ReadIdentifierList()
            node.environment = "typesystem"

            if self:IsCurrentValue("=") then
                node.tokens["="] = self:ReadValue("=")
                node.right = self:ReadTypeExpressionList()
            end

            return node
        end
    end

    do
        function META:IsInterfaceStatement()
            return self:IsCurrentValue("interface") and self:IsType("letter", 1)
        end

        function META:ReadInterfaceStatement()
            local node = self:Statement("type_interface")
            node.tokens["interface"] = self:ReadValue("interface")
            node.key = self:ReadIndexExpression()
            node.tokens["{"] = self:ReadValue("{")
            local list = list.new()
            for i = 1, math_huge do
                if not self:IsCurrentType("letter") then break end
                local node = self:Statement("interface_declaration")
                node.left = self:ReadType("letter")
                node.tokens["="] = self:ReadValue("=")
                node.right = self:ReadTypeExpression()

                list[i] = node
            end
            node.expressions = list
            node.tokens["}"] = self:ReadValue("}")

            return node
        end
    end


    do
        function META:IsTypeAssignment()
            return self:IsCurrentValue("type") and (self:IsType("letter", 1) or self:IsValue("^", 1))
        end

        function META:ReadTypeAssignment()
            local node = self:Statement("assignment")

            node.tokens["type"] = self:ReadValue("type")
            node.left = self:ReadTypeExpressionList()
            node.environment = "typesystem"

            if self:IsCurrentValue("=") then
                node.tokens["="] = self:ReadValue("=")
                node.right = self:ReadTypeExpressionList()
            end

            return node
        end
    end

    do
        function META:IsImportStatement()
            return self:IsCurrentValue("import")
        end

        function META:ReadImportStatement()
            local node = self:Statement("import")
            node.tokens["import"] = self:ReadValue("import")
            node.left = self:ReadIdentifierList()
            node.tokens["from"] = self:ReadValue("from")

            local start = self:GetCurrentToken()

            node.expressions = self:ReadExpressionList()

            local root = self.config.path:match("(.+/)")
            node.path = root .. node.expressions[1].value.value:sub(2, -2)

            local nl = require("nattlua")
            local root, err = nl.ParseFile(node.path, self.root).SyntaxTree

            if not root then
                self:Error("error importing file: $1", start, start, err)
            end

            node.root = root

            self.root.imports = self.root.imports or list.new()
            self.root.imports:insert(node)

            return node
        end
    end

    do
        function META:IsImportExpression()
            return self:IsCurrentValue("import") and self:IsValue("(", 1)
        end

        function META:ReadImportExpression()
            local node = self:Expression("import")
            node.tokens["import"] = self:ReadValue("import")
            node.tokens["("] = list.new(self:ReadValue("("))

            local start = self:GetCurrentToken()

            node.expressions = self:ReadExpressionList()

            local root = self.config.path:match("(.+/)")
            node.path = root .. node.expressions[1].value.value:sub(2, -2)

            local nl = require("nattlua")
            local root, err = nl.ParseFile(node.path, self.root)

            if not root then
                self:Error("error importing file: $1", start, start, err)
            end

            node.root = root.SyntaxTree
            node.analyzer = root

            node.tokens[")"] = list.new(self:ReadValue(")"))

            self.root.imports = self.root.imports or list.new()
            self.root.imports:insert(node)

            return node
        end
    end
end