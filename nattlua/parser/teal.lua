local META = ...

local runtime_syntax = require("nattlua.syntax.runtime")
local typesystem_syntax = require("nattlua.syntax.typesystem")

local function Value(self, symbol, value)
    local node = self:StartNode("expression", "value")
    node.value = self:NewToken(symbol, value)
    return self:EndNode(node)
end

local function Parse(code)
	local compiler = require("nattlua").Compiler(code, "temp")
    assert(compiler:Lex())
    assert(compiler:Parse())
    return compiler.SyntaxTree
end

local function fix(tk, new_value)
    tk.value = new_value
    return tk
end

function META:NewToken(type, value)
    local tk = {}
    tk.type = type
    tk.is_whitespace = false
    tk.start = start
    tk.stop = stop
    tk.value = value
    return tk
end

function META:ReadTealTypeFunctionArgument(expect_type--[[#: nil | boolean]])
    if expect_type or (self:IsType("letter") or self:IsValue("...")) and self:IsValue(":", 1) then
        local identifier = self:ReadToken()
        local token = self:ExpectValue(":")
        local exp = self:ReadTealTypeExpression(0)
        exp.tokens[":"] = token
        exp.identifier = identifier
        return exp
    end

    return self:ReadTealTypeExpression(0)
end

function META:ReadTealFunctionSignature()
    if not self:IsValue("function") then return nil end
    local node = self:StartNode("expression", "function_signature")
    node.tokens["function"] = self:ExpectValue("function")
    node.tokens["="] = self:NewToken("symbol", "=")

    node.tokens["arguments("] = self:ExpectValue("(")
    node.identifiers = ReadMultipleValues(self, nil, self.ReadTealTypeFunctionArgument)
    node.tokens["arguments)"] = self:ExpectValue(")")

    node.tokens[">"] = self:NewToken("symbol", ">")
    self:Advance(1)

    node.tokens["return("] = self:NewToken("symbol", "(")
    node.return_types = ReadMultipleValues(self, nil, self.ReadTealTypeFunctionArgument)
    node.tokens["return)"] = self:NewToken("symbol", ")")

    self:EndNode(node)
    
    return node
end

function META:ReadTealKeywordValueTypeExpression()
    if not typesystem_syntax:IsValue(self:GetToken()) then return end
    local node = self:StartNode("expression", "value")
    node.value = self:ReadToken()
    self:EndNode(node)
    return node
end	

function META:ReadTealValueTypeExpression()
    if not self:IsType("letter") or not self:IsValue("...", 1) then return end
    local node = self:StartNode("expression", "value")
    node.type_expression = self:ReadTypeExpression(0)
    node.value = self:ExpectValue("...")
    self:EndNode(node)
    return node
end

function META:ReadTealTable()
    if not self:IsValue("{") then return nil end
    local node = self:StartNode("expression", "type_table")
    node.tokens["{"] = self:ExpectValue("{")
    node.tokens["separators"] = {}
    node.children = {}

    if self:IsValue(":", 1) then
        local kv = self:StartNode("expression", "table_expression_value")
        kv.expression_key = true
        kv.tokens["["] = self:NewToken("symbol", "[")
        kv.key_expression = self:ReadTealTypeExpression(0)
        kv.tokens["]"] = self:NewToken("symbol", "]")
        kv.tokens["="] = fix(self:ExpectValue(":"), "=")
        kv.value_expression = self:ReadTealTypeExpression(0)
        self:EndNode(kv)

        node.children = {kv}
    else
        local i = 1
        while true do
            local kv = self:StartNode("expression", "table_expression_value")
            kv.expression_key = true

            kv.tokens["["] = self:NewToken("symbol", "[")
            local key = self:StartNode("expression", "value")
            key.value = self:NewToken("letter", "number")
            self:EndNode(key)

            kv.key_expression = key
            kv.tokens["]"] = self:NewToken("symbol", "]")
            kv.tokens["="] = self:NewToken("symbol", "=")
            kv.value_expression = self:ReadTealTypeExpression(0)
            self:EndNode(kv)

            table.insert(node.children, kv)
            if not self:IsValue(",") then
                if i > 1 then
                    key.value = self:NewToken("number", tostring(i))		
                end
            break end

            key.value = self:NewToken("number", tostring(i))
            i = i + 1
            table.insert(node.tokens["separators"], self:ExpectValue(","))
        end
    end

    node.tokens["}"] = self:ExpectValue("}")
    self:EndNode(node)
    return node
end

function META:ReadTealTuple()
    if not self:IsValue("(") then return nil end
    local node = self:StartNode("expression", "tuple")
    node.tokens["("] = self:ExpectValue("(")
    node.expressions = self:ReadMultipleValues(nil, self.ReadTealTypeExpression, 0)
    node.tokens[")"] = self:ExpectValue(")")
    self:EndNode(node)
    return node
end

function META:ReadTealTypeExpression(priority)
    local node = self:ReadTealFunctionSignature() or 
        self:ReadTealValueTypeExpression() or 
        self:ReadTealKeywordValueTypeExpression() or 
        self:ReadTealTable() or 
        self:ReadTealTuple()

    local first = node

    if node then
        --node = ReadSubExpression(self, node)

        if
            first.kind == "value" and
            (first.value.type == "letter" or first.value.value == "...")
        then
            first.standalone_letter = node
            first.force_upvalue = force_upvalue
        end
    end

    while typesystem_syntax:GetBinaryOperatorInfo(self:GetToken()) and
    typesystem_syntax:GetBinaryOperatorInfo(self:GetToken()).left_priority > priority do
        local left_node = node
        node = self:StartNode("expression", "binary_operator")
        node.value = self:ReadToken()
        node.left = left_node
        node.right = self:ReadTealTypeExpression(typesystem_syntax:GetBinaryOperatorInfo(node.value).right_priority)
        self:EndNode(node)
    end

    return node
end

function META:ReadTealEnum()
    if not self:IsValue("enum") or not self:IsType("letter", 1) then return nil end

    local assignment = self:StartNode("statement", "assignment")
    assignment.tokens["type"] = fix(self:ExpectValue("enum"), "type")

    assignment.left = {self:ReadIdentifier()}
    assignment.tokens["="] = self:NewToken("symbol", "=")

    local node = self:ReadValueExpressionType("string")

    while not self:IsValue("end") do
        local left = node
        node = self:StartNode("expression", "binary_operator")
        node.value = self:NewToken("symbol", "|")
        node.right = self:ReadValueExpressionType("string")
        node.left = left
        self:EndNode(node)
    end

    assignment.right = {node}

    -- end
    self:Advance(1)

    return assignment
end

function META:ReadTealTypeAssignment()
    if not self:IsValue("type") or not self:IsType("letter", 1) then return nil end
    
    local kv = self:StartNode("statement", "assignment")
    kv.tokens["type"] = self:ExpectValue("type")
    kv.left = {self:ExpectType("letter")}
    kv.tokens["="] = self:ExpectValue("=")
    kv.right = {self:ReadTealTypeExpression()}

    return kv
end

function META:ReadTealKeyVal()
    if not self:IsType("letter") or not self:IsValue(":", 1) then return nil end
    
    local kv = self:StartNode("statement", "assignment")
    kv.tokens["type"] = self:NewToken("letter", "type")
    kv.left = {self:ReadValueExpressionToken()}
    kv.tokens["="] = fix(self:ExpectValue(":"), "=")
    kv.right = {self:ReadTealTypeExpression()}
    
    return kv
end

function META:ReadTealRecord()
    if not self:IsValue("record") or not self:IsType("letter", 1) then return nil end
    
    local kv = self:StartNode("statement", "assignment")
    kv.tokens["type"] = fix(self:ExpectValue("record"), "type")
    kv.left = {self:ExpectType("letter")}
    kv.tokens["="] = self:ExpectValue("=")

    do
        local tbl = self:StartNode("expression", "type_table")
        tbl.tokens["{"] = self:NewToken("symbol", "{")
        tbl.children = {}

        tbl.tokens["separators"] = {}
        while true do
            local node = self:ReadTealKeyVal()
            if not node then break end
            table.insert(tbl.children, node)
            table.insert(tbl.tokens["separators"], self:NewToken("symbol", ","))
        end

        tbl.tokens["}"] = self:NewToken("symbol", "}")
        self:EndNode(tbl)

        kv.value_expression = tbl			
    end

    self:ExpectValue("end")

    return kv

end

function META:ReadLocalTealRecord()
    if not self:IsValue("local") or not self:IsValue("record", 1) or not self:IsType("letter", 2) then return nil end

    self:PushParserEnvironment("typesystem")

    local assignment = self:StartNode("statement", "local_assignment")
    assignment.tokens["local"] = self:ExpectValue("local")
    assignment.tokens["type"] = fix(self:ExpectValue("record"), "type")
    assignment.tokens["="] = self:NewToken("symbol", "=")
    assignment.left = {self:ReadValueExpressionToken()}

    local tbl = self:StartNode("expression", "type_table")
    tbl.tokens["{"] = self:NewToken("symbol", "{")
    tbl.tokens["}"] = self:NewToken("symbol", "}")
    tbl.children = {}
    self:EndNode(tbl)

    assignment.right = {tbl}

    self:EndNode(assignment)

    local block = self:StartNode("statement", "do")
    block.tokens["do"] = self:NewToken("letter", "do")
    block.statements = {}

    table.insert(block.statements, Parse("PushTypeEnvironment<|"..assignment.left[1].value.value.."|>").statements[1])

    while true do
        local node = self:ReadTealEnum() or 
            self:ReadTealTypeAssignment() or 
            self:ReadTealRecord() or 
            self:ReadTealKeyVal()

        if not node then break end
        
        table.insert(block.statements, node)
    end
    
    table.insert(block.statements, Parse("PopTypeEnvironment<||>").statements[1])

    block.tokens["end"] = self:ExpectValue("end")
    self:EndNode(block)

    self:PopParserEnvironment("typesystem")

    return {assignment, block}
end

function META:ReadLocalTealEnumStatement()
    if not self:IsValue("local") or not self:IsValue("enum", 1) or not self:IsType("letter", 2) then return nil end
    self:PushParserEnvironment("typesystem")

    local node = self:StartNode("statement", "local_assignment")
    node.tokens["local"] = self:ExpectValue("local")
    node.tokens["type"] = fix(self:ExpectValue("enum"), "type")
    node.left = {self:ReadValueExpressionToken()}
    node.tokens["="] = self:NewToken("symbol", "=")
    
    local bnode = self:ReadValueExpressionType("string")

    while not self:IsValue("end") do
        local left = bnode
        bnode = self:StartNode("expression", "binary_operator")
        bnode.value = self:NewToken("symbol", "|")
        bnode.right = self:ReadValueExpressionType("string")
        bnode.left = left
        self:EndNode(bnode)
    end

    node.right = {bnode}

    self:ExpectValue("end")

    self:EndNode(node)

    self:PopParserEnvironment("typesystem")


    return node
end