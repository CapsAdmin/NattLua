local function_generics_body = require("nattlua.parser.statements.typesystem.function_generics_body")

return function(parser)
    if not (parser:IsValue("function") and parser:IsValue("<|", 2)) then return end
    local node = parser:Statement("generics_type_function"):ExpectKeyword("function")
    node.expression = parser:ReadIndexExpression()
    node:ExpectSimpleIdentifier()
    function_generics_body(parser, node)
    return node:End()
end
