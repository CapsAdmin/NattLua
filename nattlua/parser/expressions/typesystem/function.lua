local function_body = require("nattlua.parser.statements.typesystem.function_body")

return function(parser, plain_args)
    local node = parser:Expression("type_function")
    node.stmnt = false
    node.tokens["function"] = parser:ReadValue("function")
    return function_body(parser, node, plain_args)
end
