local Expression = require("oh.expression")
local syntax = require("oh.syntax")

local META = {}

function META:ReadTypeExpression()
    local node = Expression("type_expression")
    local types = {}

    for _ = 1, self:GetLength() do
        if self:IsType("letter") or syntax.IsValue(self:GetToken()) then

            local node = Expression("type")

            if self:IsValue("type") then
                node.tokens["type"] = self:ReadValue("type")
            end

            node.value = self:ReadTokenLoose()

            table.insert(types, node)
        elseif self:IsValue("(") then
            local node = Expression("type_function")
            node.tokens["("] = self:ReadValue("(")
            node.identifiers = self:ReadIdentifierList()
            node.tokens[")"] = self:ReadValue(")")
            node.tokens["=>"] = self:ReadValue("=>")

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
            local node = Expression("type_table")
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

return META