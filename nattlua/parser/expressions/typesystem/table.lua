local math_huge = math.huge

local function ReadTypeTableEntry(self, i)
    local node

    if self:IsCurrentValue("[") then
        node = self:Expression("table_expression_value"):Store("expression_key", true):ExpectKeyword("[")
        self:ExpectTypeExpression(node)
        node:ExpectKeyword("]"):ExpectKeyword("=")
    elseif self:IsCurrentType("letter") and self:IsValue("=", 1) then
        node = self:Expression("table_key_value"):ExpectSimpleIdentifier():ExpectKeyword("=")
    else
        node = self:Expression("table_index_value"):Store("key", i)
    end

    self:ExpectTypeExpression(node)
    return node:End()
end

return function(parser)
    local tree = parser:Expression("type_table")
    tree:ExpectKeyword("{")
    tree.children = {}
    tree.tokens["separators"] = {}

    for i = 1, math_huge do
        if parser:IsCurrentValue("}") then break end
        local entry = ReadTypeTableEntry(parser, i)

        if entry.spread then
            tree.spread = true
        end

        tree.children[i] = entry

        if not parser:IsCurrentValue(",") and not parser:IsCurrentValue(";") and not parser:IsCurrentValue("}") then
            parser:Error(
                "expected $1 got $2",
                nil,
                nil,
                {",", ";", "}"},
                (parser:GetCurrentToken() and parser:GetCurrentToken().value) or
                "no token"
            )

            break
        end

        if not parser:IsCurrentValue("}") then
            tree.tokens["separators"][i] = parser:ReadTokenLoose()
        end
    end

    tree:ExpectKeyword("}")
    return tree:End()
end
