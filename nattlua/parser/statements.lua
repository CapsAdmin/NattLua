local META = ...

local runtime_syntax = require("nattlua.syntax.runtime")
local typesystem_syntax = require("nattlua.syntax.typesystem")

do -- destructure statement
    function META:IsDestructureStatement(offset)
        offset = offset or 0
        return
            (self:IsValue("{", offset + 0) and self:IsType("letter", offset + 1)) or
            (self:IsType("letter", offset + 0) and self:IsValue(",", offset + 1) and self:IsValue("{", offset + 2))
    end

    function META:IsLocalDestructureAssignmentStatement()
        if self:IsValue("local") then
            if self:IsValue("type", 1) then return self:IsDestructureStatement(2) end
            return self:IsDestructureStatement(1)
        end
    end

    function META:ReadDestructureAssignmentStatement()
        if not self:IsDestructureStatement() then return end
        local node = self:StartNode("statement", "destructure_assignment")
        do
            if self:IsType("letter") then
                node.default = self:ReadValueExpressionToken()
                node.default_comma = self:ExpectValue(",")
            end
        
            node.tokens["{"] = self:ExpectValue("{")
            node.left = self:ReadMultipleValues(nil, self.ReadIdentifier)
            node.tokens["}"] = self:ExpectValue("}")
            node.tokens["="] = self:ExpectValue("=")
            node.right = self:ReadRuntimeExpression(0)
        end
        self:EndNode(node)
        return node
    end

    function META:ReadLocalDestructureAssignmentStatement()
        if not self:IsLocalDestructureAssignmentStatement() then return end
        local node = self:StartNode("statement", "local_destructure_assignment")
        node.tokens["local"] = self:ExpectValue("local")
    
        if self:IsValue("type") then
            node.tokens["type"] = self:ExpectValue("type")
            node.environment = "typesystem"
        end
    
        do -- remaining
            if self:IsType("letter") then
                node.default = self:ReadValueExpressionToken()
                node.default_comma = self:ExpectValue(",")
            end
        
            node.tokens["{"] = self:ExpectValue("{")
            node.left = self:ReadMultipleValues(nil, self.ReadIdentifier)
            node.tokens["}"] = self:ExpectValue("}")
            node.tokens["="] = self:ExpectValue("=")
            node.right = self:ReadRuntimeExpression(0)
        end

        self:EndNode(node)

        return node
    end
end

do
    function META:ReadFunctionNameIndex()
        if not runtime_syntax:IsValue(self:GetToken()) then return end
        local node = self:ReadValueExpressionToken()
        local first = node

        while self:IsValue(".") or self:IsValue(":") do
            local left = node
            local self_call = self:IsValue(":")
            node = self:StartNode("expression", "binary_operator")
            node.value = self:ReadToken()
            node.right = self:ReadValueExpressionType("letter")
            node.left = left
            node.right.self_call = self_call
            self:EndNode(node)
        end

        first.standalone_letter = node
        return node
    end

    function META:ReadFunctionStatement()
        if not self:IsValue("function") then return end
        local node = self:StartNode("statement", "function")
        node.tokens["function"] = self:ExpectValue("function")
        node.expression = self:ReadFunctionNameIndex()

        if node.expression and node.expression.kind == "binary_operator" then
            node.self_call = node.expression.right.self_call
        end

        if self:IsValue("<|") then
            node.kind = "type_function"
            self:ReadTypeFunctionBody(node)
        else
            self:ReadFunctionBody(node)
        end

        self:EndNode(node)

        return node
    end

    function META:ReadAnalyzerFunctionStatement()
        if not (self:IsValue("analyzer") and self:IsValue("function", 1)) then return end
        local node = self:StartNode("statement", "analyzer_function")
        node.tokens["analyzer"] = self:ExpectValue("analyzer")
        node.tokens["function"] = self:ExpectValue("function")
        local force_upvalue

        if self:IsValue("^") then
            force_upvalue = true
            node.tokens["^"] = self:ReadToken()
        end

        node.expression = self:ReadFunctionNameIndex()

        do -- hacky
            if node.expression.left then
                node.expression.left.standalone_letter = node
                node.expression.left.force_upvalue = force_upvalue
            else
                node.expression.standalone_letter = node
                node.expression.force_upvalue = force_upvalue
            end

            if node.expression.value.value == ":" then
                node.self_call = true
            end
        end

        self:ReadAnalyzerFunctionBody(node, true)

        self:EndNode(node)

        return node
    end
end

function META:ReadLocalFunctionStatement()
    if not (self:IsValue("local") and self:IsValue("function", 1)) then return end
    local node = self:StartNode("statement", "local_function")
    
    node.tokens["local"] = self:ExpectValue("local")
    node.tokens["function"] = self:ExpectValue("function")
    node.tokens["identifier"] = self:ExpectType("letter")
    self:ReadFunctionBody(node)
    self:EndNode(node)

    return node
end
function META:ReadLocalAnalyzerFunctionStatement()
    if not (self:IsValue("local") and self:IsValue("analyzer", 1) and self:IsValue("function", 2)) then return end

    local node = self:StartNode("statement", "local_analyzer_function")
    node.tokens["local"] = self:ExpectValue("local")
    node.tokens["analyzer"] = self:ExpectValue("analyzer")
    node.tokens["function"] = self:ExpectValue("function")
    node.tokens["identifier"] = self:ExpectType("letter")
    self:ReadAnalyzerFunctionBody(node, true)
    self:EndNode(node)

    return node
end
function META:ReadLocalTypeFunctionStatement()
    if not (self:IsValue("local") and self:IsValue("function", 1) and (self:IsValue("<|", 3) or self:IsValue("!", 3))) then return end

    local node = self:StartNode("statement", "local_type_function")
    node.tokens["local"] = self:ExpectValue("local")
    node.tokens["function"] = self:ExpectValue("function")
    node.tokens["identifier"] = self:ExpectType("letter")
    self:ReadTypeFunctionBody(node)
    self:EndNode(node)

    return node
end
function META:ReadBreakStatement()
    if not self:IsValue("break") then return nil end

    local node = self:StartNode("statement", "break")
    node.tokens["break"] = self:ExpectValue("break")
    self:EndNode(node)

    return node
end
function META:ReadDoStatement()
    if not self:IsValue("do") then return nil end

    local node = self:StartNode("statement", "do")
    node.tokens["do"] = self:ExpectValue("do")
    node.statements = self:ReadNodes({["end"] = true})
    node.tokens["end"] = self:ExpectValue("end", node.tokens["do"])

    self:EndNode(node)

    return node
end
function META:ReadGenericForStatement()
    if not self:IsValue("for") then return nil end
    local node = self:StartNode("statement", "generic_for")
    node.tokens["for"] = self:ExpectValue("for")
    node.identifiers = self:ReadMultipleValues(nil, self.ReadIdentifier)
    node.tokens["in"] = self:ExpectValue("in")
    node.expressions = self:ReadMultipleValues(math.huge, self.ExpectRuntimeExpression, 0)

    node.tokens["do"] = self:ExpectValue("do")
    node.statements = self:ReadNodes({["end"] = true})
    node.tokens["end"] = self:ExpectValue("end", node.tokens["do"])

    self:EndNode(node)

    return node
end
function META:ReadGotoLabelStatement()
    if not self:IsValue("::") then return nil end
    local node = self:StartNode("statement", "goto_label")
    node.tokens["::"] = self:ExpectValue("::")
    node.tokens["identifier"] = self:ExpectType("letter")
    node.tokens["::"] = self:ExpectValue("::")
    self:EndNode(node)

    return node
end
function META:ReadGotoStatement()
    if not self:IsValue("goto") or not self:IsType("letter", 1) then return nil end

    local node = self:StartNode("statement", "goto")
    node.tokens["goto"] = self:ExpectValue("goto")
    node.tokens["identifier"] = self:ExpectType("letter")
    self:EndNode(node)

    return node
end
function META:ReadIfStatement()
    if not self:IsValue("if") then return nil end
    local node = self:StartNode("statement", "if")
    node.expressions = {}
    node.statements = {}
    node.tokens["if/else/elseif"] = {}
    node.tokens["then"] = {}

    for i = 1, self:GetLength() do
        local token

        if i == 1 then
            token = self:ExpectValue("if")
        else
            token = self:ReadValues(
                {
                    ["else"] = true,
                    ["elseif"] = true,
                    ["end"] = true,
                }
            )
        end

        if not token then return end -- TODO: what happens here? :End is never called
        node.tokens["if/else/elseif"][i] = token

        if token.value ~= "else" then
            node.expressions[i] = self:ExpectRuntimeExpression(0)
            node.tokens["then"][i] = self:ExpectValue("then")
        end

        node.statements[i] = self:ReadNodes({
            ["end"] = true,
            ["else"] = true,
            ["elseif"] = true,
        })
        if self:IsValue("end") then break end
    end

    node.tokens["end"] = self:ExpectValue("end")
    self:EndNode(node)

    return node
end
function META:ReadLocalAssignmentStatement()
    if not self:IsValue("local") then return end
    local node = self:StartNode("statement", "local_assignment")
    node.tokens["local"] = self:ExpectValue("local")
    node.left = self:ReadMultipleValues(nil, self.ReadIdentifier)

    if self:IsValue("=") then
        node.tokens["="] = self:ExpectValue("=")
        node.right = self:ReadMultipleValues(nil, self.ReadRuntimeExpression, 0)
    end

    self:EndNode(node)

    return node
end
function META:ReadNumericForStatement()
    if not (self:IsValue("for") and self:IsValue("=", 2)) then return nil end
    local node = self:StartNode("statement", "numeric_for")
    node.tokens["for"] = self:ExpectValue("for")
    node.identifiers = self:ReadMultipleValues(1, self.ReadIdentifier)
    node.tokens["="] = self:ExpectValue("=")
    node.expressions = self:ReadMultipleValues(3, self.ExpectRuntimeExpression, 0)

    node.tokens["do"] = self:ExpectValue("do")
    node.statements = self:ReadNodes({["end"] = true})
    node.tokens["end"] = self:ExpectValue("end", node.tokens["do"])

    self:EndNode(node)

    return node
end
function META:ReadRepeatStatement()
    if not self:IsValue("repeat") then return nil end
    local node = self:StartNode("statement", "repeat")
    node.tokens["repeat"] = self:ExpectValue("repeat")
    node.statements = self:ReadNodes({["until"] = true})
    node.tokens["until"] = self:ExpectValue("until")
    node.expression = self:ExpectRuntimeExpression()
    self:EndNode(node)
    return node
end
function META:ReadSemicolonStatement()
    if not self:IsValue(";") then return nil end
    local node = self:StartNode("statement", "semicolon")
    node.tokens[";"] = self:ExpectValue(";")
    self:EndNode(node)
    return node
end
function META:ReadReturnStatement()
    if not self:IsValue("return") then return nil end
    local node = self:StartNode("statement", "return")
    node.tokens["return"] = self:ExpectValue("return")
    node.expressions = self:ReadMultipleValues(nil, self.ReadRuntimeExpression, 0)
    self:EndNode(node)

    return node
end
function META:ReadWhileStatement()
    if not self:IsValue("while") then return nil end
    local node = self:StartNode("statement", "while")
    node.tokens["while"] = self:ExpectValue("while")
    node.expression = self:ExpectRuntimeExpression()
    node.tokens["do"] = self:ExpectValue("do")
    node.statements = self:ReadNodes({["end"] = true})
    node.tokens["end"] = self:ExpectValue("end", node.tokens["do"])

    self:EndNode(node)

    return node
end
function META:ReadContinueStatement()
    if not self:IsValue("continue") then return nil end

    local node = self:StartNode("statement", "continue")
    node.tokens["continue"] = self:ExpectValue("continue")
    self:EndNode(node)

    return node
end
function META:ReadDebugCodeStatement()
    if self:IsType("analyzer_debug_code") then
        local node = self:StartNode("statement", "analyzer_debug_code")
        node.lua_code = self:ReadValueExpressionType("analyzer_debug_code")
        self:EndNode(node)

        return node
    elseif self:IsType("parser_debug_code") then
        local token = self:ExpectType("parser_debug_code")
        assert(loadstring("local parser = ...;" .. token.value:sub(3)))(self)
        local node = self:StartNode("statement", "parser_debug_code")
        
        local code = self:StartNode("expression", "value")
        code.value = token
        self:EndNode(code)

        node.lua_code = code
        
        self:EndNode(node)
        return node
    end
end
function META:ReadLocalTypeAssignmentStatement()
    if not (
        self:IsValue("local") and self:IsValue("type", 1) and
        runtime_syntax:GetTokenType(self:GetToken(2)) == "letter"
    ) then return end
    local node = self:StartNode("statement", "local_assignment")
    node.tokens["local"] = self:ExpectValue("local")
    node.tokens["type"] = self:ExpectValue("type")
    node.left = self:ReadMultipleValues(nil, self.ReadIdentifier)
    node.environment = "typesystem"

    if self:IsValue("=") then
        node.tokens["="] = self:ExpectValue("=")
        self:PushParserEnvironment("typesystem")
        node.right = self:ReadMultipleValues(nil, self.ReadTypeExpression, 0)
        self:PopParserEnvironment()
    end

    self:EndNode(node)

    return node
end
function META:ReadTypeAssignmentStatement()
    if not (self:IsValue("type") and (self:IsType("letter", 1) or self:IsValue("^", 1))) then return end
    local node = self:StartNode("statement", "assignment")
    node.tokens["type"] = self:ExpectValue("type")
    node.left = self:ReadMultipleValues(nil, self.ReadTypeExpression, 0)
    node.environment = "typesystem"

    if self:IsValue("=") then
        node.tokens["="] = self:ExpectValue("=")
        self:PushParserEnvironment("typesystem")
        node.right = self:ReadMultipleValues(nil, self.ReadTypeExpression, 0)
        self:PopParserEnvironment()
    end

    self:EndNode(node)

    return node
end

function META:ReadCallOrAssignmentStatement()
    local start = self:GetToken()
    local left = self:ReadMultipleValues(math.huge, self.ExpectRuntimeExpression, 0)

    if self:IsValue("=") then
        local node = self:StartNode("statement", "assignment")
        node.tokens["="] = self:ExpectValue("=")

        node.left = left
        node.right = self:ReadMultipleValues(math.huge, self.ExpectRuntimeExpression, 0)
        self:EndNode(node)

        return node
    end

    if left[1] and (left[1].kind == "postfix_call" or left[1].kind == "import") and not left[2] then
        local node = self:StartNode("statement", "call_expression")
        node.value = left[1]
        node.tokens = left[1].tokens
        self:EndNode(node)

        return node
    end

    self:Error(
        "expected assignment or call expression got $1 ($2)",
        start,
        self:GetToken(),
        self:GetToken().type,
        self:GetToken().value
    )
end
