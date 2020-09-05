local META = ...

local table_insert = table.insert
local setmetatable = setmetatable
local type = type
local math_huge = math.huge
local pairs = pairs
local table_insert = table.insert
local table_concat = table.concat

local table_insert = table.insert

local syntax = require("oh.lua.syntax")

do
    function META:IsDestructureStatement(offset)
        return
            (self:IsValue("{", offset + 0) and self:IsType("letter", offset + 1)) or
            (self:IsType("letter", offset + 0) and self:IsValue(",", offset + 1) and self:IsValue("{", offset + 2))
    end

    local function read_remaining(self, node)
        if self:IsType("letter") then

            local val = self:Expression("value")
            val.value = self:ReadTokenLoose()
            node.default = val

            node.default_comma = self:ReadValue(",")
        end

        node.tokens["{"] = self:ReadValue("{")
        node.left = self:ReadIdentifierList()
        node.tokens["}"] = self:ReadValue("}")
        node.tokens["="] = self:ReadValue("=")
        node.right = self:ReadExpression()
    end

    function META:ReadDestructureAssignmentStatement()
        local node = self:Statement("destructure_assignment")

        read_remaining(self, node)

        return node
    end

    do
        function META:IsLocalDestructureAssignmentStatement() 
            return self:IsValue("local") and self:IsDestructureStatement(1) 
        end

        function META:ReadLocalDestructureAssignmentStatement()
            local node = self:Statement("local_destructure_assignment")
            node.tokens["local"] = self:ReadValue("local")

            read_remaining(self, node)

            return node
        end
    end
end

do
    function META:IsLSXExpression()
        return self:IsValue("[") and self:IsType("letter", 1)
    end

    do
        function META:IsLSXStatement() 
            return self:IsLSXExpression() 
        end

        function META:ReadLSXStatement()
            return self:ReadLSXExpression(true)
        end
    end

    function META:ReadLSXExpression(statement)
        local node = statement and self:Statement("lsx") or self:Expression("lsx")

        node.tokens["["] = self:ReadValue("[")
        node.tag = self:ReadType("letter")

        local props = {}

        while true do
            if self:IsType("letter") and self:IsValue("=", 1) then
                local key = self:ReadType("letter")
                self:ReadValue("=")
                local val = self:ReadExpectExpression(nil, true)
                table.insert(props, {
                    key = key,
                    val = val,
                })
            elseif self:IsValue("...") then
                self:ReadTokenLoose() -- !
                table.insert(props, {
                    val = self:ReadExpression(nil, true),
                    spread = true,
                })
            else
                break
            end
        end

        node.tokens["]"] = self:ReadValue("]")

        node.props = props

        if self:IsValue("{") then
            node.tokens["{"] = self:ReadValue("{")
            node.statements = self:ReadStatements({["}"] = true})
            node.tokens["}"] = self:ReadValue("}")
        end

        return node
    end
end