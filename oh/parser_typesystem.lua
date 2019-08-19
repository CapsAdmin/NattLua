local table_insert = table.insert

local syntax = require("oh.syntax")

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

        for i = 1, max or self:GetLength() do
            if self:HandleTypeListSeparator(out, i, self:ReadTypeExpression()) then
                break
            end
        end

        return out
    end
end

function META:ReadFunctionArgument()
    if self:IsType("letter") and self:IsValue(":", 1) then
        local identifier = self:ReadType("letter")
        local token = self:ReadValue(":")
        local exp = self:ReadTypeExpression()
        exp.tokens[":"] = token
        exp.identifier = identifier
        return exp
    end

    return self:ReadTypeExpression()
end

function META:ReadTypeFunction()
    local node = self:Expression("type_function")
    node.tokens["function"] = self:ReadValue("function")
    node.tokens["("] = self:ReadValue("(")

    node.identifiers = {}

    for i = 1, max or self:GetLength() do
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
        node.return_expressions = self:ReadTypeExpressionList()
    else
        local start = self:GetToken()
        node.statements = self:ReadStatements({["end"] = true})
        node.tokens["end"] = self:ReadValue("end", start, start)
    end

    return node
end

function META:ReadTypeTable()
    local tree = self:Expression("type_table")

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
            node.key = self:ReadTypeExpression()
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

        node.value = self:ReadTypeExpression()

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
    elseif self:IsValue("function") and self:IsValue("(", 1) then
        node = self:ReadTypeFunction()
    elseif syntax.IsTypeValue(self:GetToken()) or self:IsType("letter") then
        node = self:Expression("value")
        node.value = self:ReadTokenLoose()
    elseif self:IsValue("{") then
        node = self:ReadTypeTable()
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
        local right = self:ReadExpression(right_priority)

        node = self:Expression("binary_operator")
        node.value = op
        node.left = node.left or left
        node.right = node.right or right
    end

    return node
end

return META