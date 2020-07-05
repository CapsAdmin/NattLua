local table_insert = table.insert
local math_huge = math.huge
local syntax = require("oh.lua.syntax")

local META = {}

function META:HandleTypeListSeparator(out, i, node)
    if not node then
        return true
    end

    out[i] = node

    if not self:IsValue(",") and not self:IsValue(";") then
        return true
    end

    if self:IsValue(";") then
        node.tokens[","] = self:ReadValue(";")
    else
        node.tokens[","] = self:ReadValue(",")
    end
end


do -- identifier
    function META:ReadTypeExpressionList(max)
        local out = {}

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
        return self:IsValue("local") and self:IsValue("type", 1) and self:IsValue("function", 2)
    end

    function META:ReadLocalTypeFunctionStatement()
        local node = self:Statement("local_type_function")
        node.tokens["local"] = self:ReadValue("local")
        node.tokens["type"] = self:ReadValue("type")
        node.tokens["function"] = self:ReadValue("function")
        node.identifier = self:ReadIdentifier()
        return self:ReadTypeFunctionBody(node)
    end
end


do
    function META:IsLocalTypeFunctionStatement2()
        return self:IsValue("local") and self:IsValue("function", 1) and self:IsValue("<", 3)
    end

    function META:ReadLocalTypeFunctionStatement2()
        local node = self:Statement("local_type_function2")
        node.tokens["local"] = self:ReadValue("local")
        node.tokens["function"] = self:ReadValue("function")
        node.identifier = self:ReadIdentifier()
        return self:ReadTypeFunctionBody2(node)
    end
end

function META:ReadFunctionArgument()
    if (self:IsType("letter") or self:IsValue("...")) and self:IsValue(":", 1) then
        local identifier = self:ReadTokenLoose()
        local token = self:ReadValue(":")
        local exp = self:ReadTypeExpression()
        exp.tokens[":"] = token
        exp.identifier = identifier
        return exp
    end

    return self:ReadTypeExpression()
end


function META:ReadTypeFunctionBody(node)
    node.tokens["("] = self:ReadValue("(")

    node.identifiers = {}

    for i = 1, math_huge do
        if self:HandleListSeparator(node.identifiers, i, self:ReadFunctionArgument()) then
            break
        end
    end

    if self:IsValue("...") then
        local vararg = self:Expression("value")
        vararg.value = self:ReadValue("...")
        table.insert(node.identifiers, vararg)
    end

    node.tokens[")"] = self:ReadValue(")", node.tokens["("])

    if self:IsValue(":") then
        node.tokens[":"] = self:ReadValue(":")
        node.return_types = self:ReadTypeExpressionList()
    else
        local start = self:GetToken()
        node.statements = self:ReadStatements({["end"] = true})
        node.tokens["end"] = self:ReadValue("end", start, start)
    end

    return node
end

function META:ReadTypeFunctionBody2(node)
    node.tokens["<"] = self:ReadValue("<")

    node.identifiers = self:ReadIdentifierList()

    if self:IsValue("...") then
        local vararg = self:Expression("value")
        vararg.value = self:ReadValue("...")
        table.insert(node.identifiers, vararg)
    end

    node.tokens[">"] = self:ReadValue(">", node.tokens["<"])

    if self:IsValue(":") then
        node.tokens[":"] = self:ReadValue(":")
        node.return_types = self:ReadTypeExpressionList()
    else
        local start = self:GetToken()
        node.statements = self:ReadStatements({["end"] = true})
        node.tokens["end"] = self:ReadValue("end", start, start)
    end

    return node
end

function META:ReadTypeFunction()
    local node = self:Expression("type_function")
    node.tokens["function"] = self:ReadValue("function")
    return self:ReadTypeFunctionBody(node)
end


function META:ExpectTypeExpression(what)
    if self.nodes[1].expressions then
        table.insert(self.nodes[1].expressions, self:ReadTypeExpression())
    elseif self.nodes[1].expression then
        self.nodes[1].expressions = {self.nodes[1].expression}
        self.nodes[1].expression = nil
        table.insert(self.nodes[1].expressions, self:ReadTypeExpression())
    else
        self.nodes[1].expression = self:ReadTypeExpression()
    end

    return self
end


function META:ReadTypeTableEntry(i)
    if self:IsValue("[") then
        self:BeginExpression("table_expression_value")
        :Store("expression_key", true)
        :ExpectKeyword("[")
        :ExpectTypeExpression()
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

    self:ExpectTypeExpression()

    return self:EndExpression()
end

function META:ReadTypeTable()
    self:BeginExpression("type_table")
    self:ExpectKeyword("{")

    local tree = self:GetNode()
    tree.children = {}
    tree.tokens["separators"] = {}

    for i = 1, math_huge do
        if self:IsValue("}") then
            break
        end

        local entry = self:ReadTypeTableEntry(i)

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

function META:ReadTypeExpression(priority)
    priority = priority or 0

    local node

    local force_upvalue
    if self:IsValue("^") then
        force_upvalue = true
        self:Advance(1)
    end

    if self:IsValue("(") then
        local pleft = self:ReadValue("(")
        node = self:ReadTypeExpression(0)
        if not node then
            self:Error("empty parentheses group", pleft)
            return
        end

        node.tokens["("] = node.tokens["("] or {}
        table_insert(node.tokens["("], 1, pleft)


        node.tokens[")"] = node.tokens[")"] or {}
        table_insert(node.tokens[")"], self:ReadValue(")"))

    elseif syntax.IsTypePrefixOperator(self:GetToken()) then
        node = self:Expression("prefix_operator")
        node.value = self:ReadTokenLoose()
        node.right = self:ReadTypeExpression(math_huge)
    elseif self:IsType("letter") and self:IsValue("...", 1) then
        node = self:Expression("vararg_tuple")
        node.value = self:ReadTokenLoose()
        node.tokens["..."] = self:ReadValue("...")
    elseif self:IsValue("function") and self:IsValue("(", 1) then
        node = self:ReadTypeFunction()
    elseif syntax.IsTypeValue(self:GetToken()) or self:IsType("letter") then
        node = self:Expression("value")
        node.value = self:ReadTokenLoose()
    elseif self:IsValue("{") then
        node = self:ReadTypeTable()
    elseif self:IsType("$") and self:IsType("string", 1) then
        node = self:Expression("type_string")
        node.tokens["$"] = self:ReadTokenLoose("...")
        node.value = self:ReadType("string")
    elseif self:IsValue("[") then
        node = self:Expression("type_list")
        node.tokens["["] = self:ReadValue("[")
        node.types = self:ReadTypeExpressionList()
        node.tokens["]"] = self:ReadValue("]")
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
                end
            elseif syntax.IsPostfixTypeOperator(self:GetToken()) then
                node = self:Expression("postfix_operator")
                node.left = left
                node.value = self:ReadTokenLoose()
            elseif self:IsValue("<") then
                node = self:Expression("postfix_call")
                node.left = left
                node.tokens["call("] = self:ReadValue("<")
                node.expressions = self:ReadTypeExpressionList()
                node.tokens["call)"] = self:ReadValue(">")
                node.type_call = true
            elseif self:IsValue("(") then
                node = self:Expression("postfix_call")
                node.left = left
                node.tokens["call("] = self:ReadValue("(")
                node.expressions = self:ReadTypeExpressionList()
                node.tokens["call)"] = self:ReadValue(")")
            elseif self:IsValue("[") then
                node = self:Expression("type_list")
                node.left = left
                node.tokens["["] = self:ReadValue("[")
                node.types = self:ReadTypeExpressionList()
                node.tokens["]"] = self:ReadValue("]")
            elseif self:IsValue("as") then
                node.tokens["as"] = self:ReadValue("as")
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
        first.force_upvalue = force_upvalue
    end

    while syntax.IsBinaryTypeOperator(self:GetToken()) and syntax.GetLeftTypeOperatorPriority(self:GetToken()) > priority do
        local op = self:GetToken()
        local right_priority = syntax.GetRightTypeOperatorPriority(op)
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
        return self:IsValue("local") and self:IsValue("type", 1) and self:IsType("letter", 2)
    end

    function META:ReadLocalTypeDeclarationStatement()
        local node = self:Statement("local_assignment")

        node.tokens["local"] = self:ReadValue("local")
        node.tokens["type"] = self:ReadValue("type")

        node.left = self:ReadIdentifierList()
        node.environment = "typesystem"

        if self:IsValue("=") then
            node.tokens["="] = self:ReadValue("=")
            node.right = self:ReadTypeExpressionList()
        end

        return node
    end
end

do
    function META:IsInterfaceStatement()
        return self:IsValue("interface") and self:IsType("letter", 1)
    end

    function META:ReadInterfaceStatement()
        local node = self:Statement("type_interface")
        node.tokens["interface"] = self:ReadValue("interface")
        node.key = self:ReadIndexExpression()
        node.tokens["{"] = self:ReadValue("{")
        local list = {}
        for i = 1, math_huge do
            if not self:IsType("letter") then break end
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
        return self:IsValue("type") and (self:IsType("letter", 1) or self:IsValue("^", 1))
    end

    function META:ReadTypeAssignment()
        local node = self:Statement("assignment")

        node.tokens["type"] = self:ReadValue("type")
        node.left = self:ReadTypeExpressionList()
        node.environment = "typesystem"

        if self:IsValue("=") then
            node.tokens["="] = self:ReadValue("=")
            node.right = self:ReadTypeExpressionList()
        end

        return node
    end
end

do
    function META:IsImportStatement()
        return self:IsValue("import")
    end

    function META:ReadImportStatement()
        local node = self:Statement("import")
        node.tokens["import"] = self:ReadValue("import")
        node.left = self:ReadIdentifierList()
        node.tokens["from"] = self:ReadValue("from")

        local start = self:GetToken()

        node.expressions = self:ReadExpressionList()

        local root = self.config.path:match("(.+/)")
        node.path = root .. node.expressions[1].value.value:sub(2, -2)

        local oh = require("oh")
        local root, err = oh.ParseFile(node.path, self.root).SyntaxTree

        if not root then
            self:Error("error importing file: $1", start, start, err)
        end

        node.root = root

        self.root.imports = self.root.imports or {}
        table.insert(self.root.imports, node)

        return node
    end
end

do
    function META:IsImportExpression()
        return self:IsValue("import") and self:IsValue("(", 1)
    end

    function META:ReadImportExpression()
        local node = self:Expression("import")
        node.tokens["import"] = self:ReadValue("import")
        node.tokens["("] = self:ReadValue("(")

        local start = self:GetToken()

        node.expressions = self:ReadExpressionList()

        local root = self.config.path:match("(.+/)")
        node.path = root .. node.expressions[1].value.value:sub(2, -2)

        local oh = require("oh")
        local root, err = oh.ParseFile(node.path, self.root)

        if not root then
            self:Error("error importing file: $1", start, start, err)
        end

        node.root = root.SyntaxTree
        node.analyzer = root

        node.tokens[")"] = self:ReadValue(")")

        self.root.imports = self.root.imports or {}
        table.insert(self.root.imports, node)

        return node
    end
end

do
    -- todo: GetLength > while
    function META:IsTypeComment()
        return self:IsType("type_comment")
    end

    function META:ReadTypeComment()
        local code = self:ReadType("type_comment").value:sub(4)
        local lexer = require("oh.lua.lexer")(code)
        self:AddTokens(lexer:GetTokens())
        return self:ReadStatement()
    end
end

return META