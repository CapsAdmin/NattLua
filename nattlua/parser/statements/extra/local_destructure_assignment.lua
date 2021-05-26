local function IsDestructureStatement(parser, offset)
    offset = offset or 0
    return
        (parser:IsValue("{", offset + 0) and parser:IsType("letter", offset + 1)) or
        (parser:IsType("letter", offset + 0) and parser:IsValue(",", offset + 1) and parser:IsValue("{", offset + 2))
end

local function read_remaining(parser, node)
    if parser:IsCurrentType("letter") then
        local val = parser:Expression("value")
        val.value = parser:ReadTokenLoose()
        node.default = val
        node.default_comma = parser:ReadValue(",")
    end

    node.tokens["{"] = parser:ReadValue("{")
    node.left = parser:ReadIdentifierList()
    node.tokens["}"] = parser:ReadValue("}")
    node.tokens["="] = parser:ReadValue("=")
    node.right = parser:ReadExpression()
end

local function IsLocalDestructureAssignmentStatement(parser)
    if parser:IsCurrentValue("local") then
        if parser:IsValue("type", 1) then return IsDestructureStatement(parser, 2) end
        return IsDestructureStatement(parser, 1)
    end
end

return function(parser)
    if not IsLocalDestructureAssignmentStatement(parser) then return end
    local node = parser:Statement("local_destructure_assignment")
    node.tokens["local"] = parser:ReadValue("local")

    if parser:IsCurrentValue("type") then
        node.tokens["type"] = parser:ReadValue("type")
        node.environment = "typesystem"
    end

    read_remaining(parser, node)
    return node
end