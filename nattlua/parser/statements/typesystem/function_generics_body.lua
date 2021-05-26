local table_insert = table.insert

return function(parser, node)
    node.tokens["arguments("] = parser:ReadValue("<|")
    node.identifiers = parser:ReadIdentifierList()

    if parser:IsCurrentValue("...") then
        local vararg = parser:Expression("value")
        vararg.value = parser:ReadValue("...")
        table_insert(node.identifiers, vararg)
    end

    node.tokens["arguments)"] = parser:ReadValue("|>", node.tokens["arguments("])

    if parser:IsCurrentValue(":") then
        node.tokens[":"] = parser:ReadValue(":")
        node.return_types = parser:ReadTypeExpressionList()
    else
        local start = parser:GetCurrentToken()
        node.statements = parser:ReadStatements({["end"] = true})
        node.tokens["end"] = parser:ReadValue("end", start, start)
    end

    return node
end