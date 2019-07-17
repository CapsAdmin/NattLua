local Expression = require("oh.expression")

local META = {}

function META:ReadTypeExpression()
    local node = Expression("type_expression")

    local out = {}

    for _ = 1, self:GetLength() do
        local token = self:ReadTokenLoose()

        if not token then return node end

        do
            local node = Expression("type")
            node.value = token
            table.insert(out, node)

            if token.type == "letter" and self:IsValue("(") then
                local start = self:GetToken()

                node.tokens["func("] = self:ReadValue("(")
                node.function_arguments = self:IdentifierList()
                node.tokens["func)"] = self:ReadValue(")", start, start)
                node.tokens["return:"] = self:ReadValue(":")
                node.function_return_type = self:ReadTypeExpression()
            end

            if not self:IsValue("|") then
                break
            end
        end

        node.tokens["|"] = node.tokens["|"] or {}
        table.insert(node.tokens["|"], self:ReadValue("|"))
    end

    node.types = out

    return node
end

return META