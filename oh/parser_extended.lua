local syntax = require("oh.syntax")

local META = {}

function META:ReadTypeExpression()
    local node = self:Expression("type_expression")
    local types = {}

    for _ = 1, self:GetLength() do
        if self:IsType("letter") or syntax.IsValue(self:GetToken()) then

            local node = self:Expression("type")

            if self:IsValue("type") then
                node.tokens["type"] = self:ReadValue("type")
            end

            node.value = self:ReadTokenLoose()

            table.insert(types, node)
        elseif self:IsValue("(") then
            local node = self:Expression("type_function")
            node.tokens["("] = self:ReadValue("(")
            node.identifiers = self:ReadIdentifierList()
            node.tokens[")"] = self:ReadValue(")")
            node.tokens[":"] = self:ReadValue(":")

            local out = {}
            for i = 1, max or self:GetLength() do

                local typ = self:ReadTypeExpression()

                if self:HandleListSeparator(out, i, typ) then
                    break
                end
            end
            node.return_types = out

            table.insert(types, node)
        elseif self:IsValue("{") then
            local node = self:Expression("type_table")
            node.tokens["{"] = self:ReadValue("{")
            node.key_values = self:ReadIdentifierList()
            node.tokens["}"] = self:ReadValue("}")

            table.insert(types, node)
        end

        if not self:IsValue("|") then
            break
        end

        node.tokens["|"] = node.tokens["|"] or {}
        table.insert(node.tokens["|"], self:ReadValue("|"))
    end

    node.types = types
    return node
end


function META:ReadLocalTypeDeclarationStatement()
    local node = self:Statement("local_type_declaration")

    node.tokens["local"] = self:ReadValue("local")
    node.tokens["type"] = self:ReadValue("type")
    node.left = self:ReadExpression()
    node.tokens["="] = self:ReadValue("=")
    node.right = self:ReadTypeExpression()

    return node
end

function META:ReadInterfaceStatement()
    local node = self:Statement("type_interface")
    node.tokens["interface"] = self:ReadValue("interface")
    node.key = self:ReadIndexExpression()
    node.tokens["{"] = self:ReadValue("{")
    local list = {}
    for i = 1, max or self:GetLength() do
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

function META:ReadTypeAssignment()
    local node = self:Statement("type_assignment")

    node.tokens["type"] = self:ReadValue("type")
    node.left = self:ReadExpression()
    node.tokens["="] = self:ReadValue("=")
    node.right = self:ReadTypeExpression()

    return node
end

function META:ReadImportExpression()
    local node = self:Expression("import")
    node.tokens["import"] = self:ReadValue("import")
    node.tokens["("] = self:ReadValue("(")

    local start = self:GetToken()

    node.expressions = self:ReadExpressionList()

    local root = self.config.path:match("(.+/)")

    local oh = require("oh")
    local code, err = oh.TranspileFile(root .. node.expressions[1].value.value:sub(2, -2))

    if not code then
        self:Error("error importing file: $1", start, start, err)
    end

    node.code = code

    node.tokens[")"] = self:ReadValue(")")
    return node
end

return META