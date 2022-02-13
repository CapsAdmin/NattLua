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
        if self:IsValue("<") then
            node.tokens["<"] = self:ExpectValue("<")
            node.attribute = self:ExpectType("letter")
            node.tokens[">"] = self:ExpectValue(">")
        end
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

        if self:IsValue("(") then
            local lparen = self:ExpectValue("(")
            local identifiers = self:ReadMultipleValues(nil, self.ReadIdentifier, true)
            local rparen = self:ExpectValue(")")

            node.identifiers_typesystem = node.identifiers
            node.identifiers = identifiers

            node.tokens["arguments_typesystem("] = node.tokens["arguments("]
            node.tokens["arguments_typesystem)"] = node.tokens["arguments)"]

            node.tokens["arguments("] = lparen
            node.tokens["arguments)"] = rparen
        end
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

assert(loadfile("nattlua/parser/teal.lua"))(META)

function META:ReadRootNode()
    local node = self:StartNode("statement", "root")
    self.root = self.config and self.config.root or node
    local shebang

    if self:IsType("shebang") then

        shebang = self:StartNode("statement", "shebang")
        shebang.tokens["shebang"] = self:ExpectType("shebang")
        self:EndNode(shebang)

        node.tokens["shebang"] = shebang.tokens["shebang"]
    end

    node.statements = self:ReadNodes()

    if shebang then
        table.insert(node.statements, 1, shebang)
    end

    if self:IsType("end_of_file") then
        
        local eof = self:StartNode("statement", "end_of_file")
        eof.tokens["end_of_file"] = self.tokens[#self.tokens]
        self:EndNode(node)

        table.insert(node.statements, eof)
        node.tokens["eof"] = eof.tokens["end_of_file"]
    end

    self:EndNode(node)

    return node
end

function META:ReadNode()
    if self:IsType("end_of_file") then return end
    return
        self:ReadDebugCodeStatement() or
        self:ReadReturnStatement() or
        self:ReadBreakStatement() or
        self:ReadContinueStatement() or
        self:ReadSemicolonStatement() or
        self:ReadGotoStatement() or
        self:ReadGotoLabelStatement() or
        self:ReadRepeatStatement() or
        self:ReadAnalyzerFunctionStatement() or
        self:ReadFunctionStatement() or
        self:ReadLocalTypeFunctionStatement() or
        self:ReadLocalFunctionStatement() or
        self:ReadLocalAnalyzerFunctionStatement() or
        self:ReadLocalTypeAssignmentStatement() or
        self:ReadLocalDestructureAssignmentStatement() or

        self.TealCompat and self:ReadLocalTealRecord() or
        self.TealCompat and self:ReadLocalTealEnumStatement() or

        self:ReadLocalAssignmentStatement() or
        self:ReadTypeAssignmentStatement() or
        self:ReadDoStatement() or
        self:ReadIfStatement() or
        self:ReadWhileStatement() or
        self:ReadNumericForStatement() or
        self:ReadGenericForStatement() or
        self:ReadDestructureAssignmentStatement() or
        self:ReadCallOrAssignmentStatement()
end

return META.New
