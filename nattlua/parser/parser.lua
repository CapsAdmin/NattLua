local META = require("nattlua.parser.base")

local runtime_syntax = require("nattlua.syntax.runtime")
local typesystem_syntax = require("nattlua.syntax.typesystem")

local math = require("math")
local math_huge = math.huge
local table_insert = require("table").insert
local table_remove = require("table").remove
local ipairs = _G.ipairs


--[[#do return end]]

function META:ReadIdentifier(expect_type--[[#: nil | boolean]])
    if not self:IsType("letter") and not self:IsValue("...") then return end
    local node = self:StartNode("expression", "value") --[[#-- as ValueExpression ]]

    if self:IsValue("...") then
        node.value = self:ExpectValue("...")
    else
        node.value = self:ExpectType("letter")
    end

    if self:IsValue(":") or expect_type then
        node.tokens[":"] = self:ExpectValue(":")
        node.type_expression = self:ExpectTypeExpression(0)
    end

    self:EndNode(node)

    return node
end

function META:ReadValueExpressionToken(expect_value--[[#: nil | string]]) 
    local node = self:StartNode("expression", "value")
    node.value = expect_value and self:ExpectValue(expect_value) or self:ReadToken()
    self:EndNode(node)
    return node
end

function META:ReadValueExpressionType(expect_value--[[#: TokenType]]) 
    local node = self:StartNode("expression", "value")
    node.value = self:ExpectType(expect_value)
    self:EndNode(node)
    return node
end

function META:ReadFunctionBody(node--[[#: FunctionAnalyzerExpression | FunctionExpression | FunctionLocalStatement | FunctionStatement ]])
    node.tokens["arguments("] = self:ExpectValue("(")
    node.identifiers = self:ReadMultipleValues(nil, self.ReadIdentifier)
    node.tokens["arguments)"] = self:ExpectValue(")", node.tokens["arguments("])

    if self:IsValue(":") then
        node.tokens[":"] = self:ExpectValue(":")
        self:PushParserEnvironment("typesystem")
        node.return_types = self:ReadMultipleValues(nil, self.ReadTypeExpression, 0)
        self:PopParserEnvironment("typesystem")
    end

    node.statements = self:ReadNodes({["end"] = true})
    node.tokens["end"] = self:ExpectValue("end", node.tokens["function"])
    
    return node
end

function META:ReadTypeFunctionBody(node--[[#: FunctionTypeStatement | FunctionTypeExpression | FunctionLocalTypeStatement]])
    if self:IsValue("!") then
        node.tokens["!"] = self:ExpectValue("!")	
        node.tokens["arguments("] = self:ExpectValue("(")				
        node.identifiers = self:ReadMultipleValues(nil, self.ReadIdentifier, true)

        if self:IsValue("...") then
            table_insert(node.identifiers, self:ReadValueExpressionToken("..."))
        end
        node.tokens["arguments)"] = self:ExpectValue(")")
    else
        node.tokens["arguments("] = self:ExpectValue("<|")
        node.identifiers = self:ReadMultipleValues(nil, self.ReadIdentifier, true)

        if self:IsValue("...") then
            table_insert(node.identifiers, self:ReadValueExpressionToken("..."))
        end

        node.tokens["arguments)"] = self:ExpectValue("|>", node.tokens["arguments("])
    end

    if self:IsValue(":") then
        node.tokens[":"] = self:ExpectValue(":")
        self:PushParserEnvironment("typesystem")
        node.return_types = self:ReadMultipleValues(math.huge, self.ExpectTypeExpression, 0)
        self:PopParserEnvironment("typesystem")
    end

    node.environment = "typesystem"

    self:PushParserEnvironment("typesystem")

    local start = self:GetToken()
    node.statements = self:ReadNodes({["end"] = true})
    node.tokens["end"] = self:ExpectValue("end", start, start)

    self:PopParserEnvironment()

    return node
end

function META:ReadTypeFunctionArgument(expect_type--[[#: nil | boolean]])
    if self:IsValue(")") then return end
    if self:IsValue("...") then return end

    if expect_type or self:IsType("letter") and self:IsValue(":", 1) then
        local identifier = self:ReadToken()
        local token = self:ExpectValue(":")
        local exp = self:ExpectTypeExpression(0)
        exp.tokens[":"] = token
        exp.identifier = identifier
        return exp
    end

    return self:ExpectTypeExpression(0)
end

function META:ReadAnalyzerFunctionBody(node--[[#: FunctionAnalyzerStatement | FunctionAnalyzerExpression |FunctionLocalAnalyzerStatement]], type_args--[[#: boolean]])
    node.tokens["arguments("] = self:ExpectValue("(")

    node.identifiers = self:ReadMultipleValues(math_huge, self.ReadTypeFunctionArgument, type_args)

    if self:IsValue("...") then
        local vararg = self:StartNode("expression", "value")
        vararg.value = self:ExpectValue("...")

        if self:IsValue(":") or type_args then
            vararg.tokens[":"] = self:ExpectValue(":")
            vararg.type_expression = self:ExpectTypeExpression(0)
        else
            if self:IsType("letter") then
                vararg.type_expression = self:ExpectTypeExpression(0)
            end
        end

        self:EndNode(vararg)

        table_insert(node.identifiers, vararg)
    end

    node.tokens["arguments)"] = self:ExpectValue(")", node.tokens["arguments("])

    if self:IsValue(":") then
        node.tokens[":"] = self:ExpectValue(":")
        self:PushParserEnvironment("typesystem")
        node.return_types = self:ReadMultipleValues(math.huge, self.ReadTypeExpression, 0)
        self:PopParserEnvironment("typesystem")

        local start = self:GetToken()
        node.statements = self:ReadNodes({["end"] = true})
        node.tokens["end"] = self:ExpectValue("end", start, start)
    elseif not self:IsValue(",") then
        local start = self:GetToken()
        node.statements = self:ReadNodes({["end"] = true})
        node.tokens["end"] = self:ExpectValue("end", start, start)
    end

    return node
end

assert(loadfile("nattlua/parser/expressions.lua"))(META)
assert(loadfile("nattlua/parser/statements.lua"))(META)

return META.New
