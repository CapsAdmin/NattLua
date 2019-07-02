local oh = ...
local ipairs = ipairs
local assert = assert
local type = type

local META = {}
META.__index = META

META.PreserveWhitespace = true

function META:Whitespace(str, force)

    if self.PreserveWhitespace and not force then return end

    if str == "?" then
        if oh.syntax.IsLetter(self:GetPrevChar()) or oh.syntax.IsNumber(self:GetPrevChar()) then
            self:Emit(" ")
        end
    elseif str == "\t" then
        self:EmitIndent()
    elseif str == "\t+" then
        self:Indent()
    elseif str == "\t-" then
        self:Outdent()
    else
        self:Emit(str)
    end
end

function META:Emit(str) assert(type(str) == "string")
    self.out[self.i] = str or ""
    self.i = self.i + 1
end

function META:Indent()
    self.level = self.level + 1
end

function META:Outdent()
    self.level = self.level - 1
end

function META:EmitIndent()
    self:Emit(("\t"):rep(self.level))
end

function META:GetPrevChar()
    local prev = self.out[self.i - 1]
    local char = prev:sub(-1)
    return prev and char:byte()
end

function META:EmitWhitespace(token)
    if token.type ~= "space" or self.PreserveWhitespace then
        self:EmitToken(token)
        if token.type ~= "space" then
            self:Whitespace("\n")
            self:Whitespace("\t")
        end
    end
end

function META:EmitToken(node, translate)
    if node.whitespace then
        for _, data in ipairs(node.whitespace) do
            self:EmitWhitespace(data)
        end
    end

    if self.TranslateToken then
        translate = self:TranslateToken(node) or translate
    end

    if translate then
        if type(translate) == "table" then
            self:Emit(translate[node.value] or node.value)
        elseif translate ~= "" then
            self:Emit(translate)
        end
    else
        self:Emit(node.value)
    end
end

function META:Initialize()
    self.level = 0
    self.out = {}
    self.i = 1
end

function META:Concat()
    return table.concat(self.out)
end

function META:BuildCode(block)
    self:EmitStatements(block.statements)
    return self:Concat()
end

function META:EmitExpression(node)
    if node.tokens["("] then
        for _, node in ipairs(node.tokens["("]) do
            self:EmitToken(node)
        end
    end

    if node.kind == "binary_operator" then
        self:EmitBinaryOperator(node)
    elseif node.kind == "function" then
        self:EmitFunction(node, true)
    elseif node.kind == "table" then
        self:EmitTable(node)
    elseif node.kind == "prefix_operator" then
        self:EmitPrefixOperator(node)
    elseif node.kind == "postfix_operator" then
        self:EmitPostfixOperator(node)
    elseif node.kind == "postfix_call" then
        self:EmitCall(node)
    elseif node.kind == "postfix_expression_index" then
        self:EmitExpressionIndex(node)
    elseif node.kind == "value" then
        self:EmitToken(node.value)
    else
        error("unhandled token type " .. node.kind)
    end

    if node.tokens[")"] then
        for _, node in ipairs(node.tokens[")"]) do
            self:EmitToken(node)
        end
    end
end

function META:EmitExpressionIndex(node)
    self:EmitExpression(node.left)
    self:EmitToken(node.tokens["["])
    self:EmitExpression(node.expression)
    self:EmitToken(node.tokens["]"])
end

function META:EmitCall(node)
    self:EmitExpression(node.left)

    if node.tokens["call("] then
        self:EmitToken(node.tokens["call("])
    end

    self:EmitExpressionList(node.expressions)

    if node.tokens["call)"] then
        self:EmitToken(node.tokens["call)"])
    end
end

function META:EmitBinaryOperator(node)
    local func_chunks = oh.syntax.GetFunctionForBinaryOperator(node.value)
    if func_chunks then
        self:Emit(func_chunks[1])
        if node.left then self:EmitExpression(node.left) end
        self:Emit(func_chunks[2])
        if node.right then self:EmitExpression(node.right) end
        self:Emit(func_chunks[3])
        self.operator_transformed = true
    else
        if node.left then self:EmitExpression(node.left) end
        if node.value.value == "." or node.value.value == ":" then
            self:EmitToken(node.value)
        else
            self:Whitespace(" ")
            self:EmitToken(node.value)
            self:Whitespace(" ")
        end
        if node.right then self:EmitExpression(node.right) end
    end
end

do
    function META:EmitFunction(node, anon)
        if anon then
            self:EmitToken(node.tokens["function"])
        elseif node.is_local then
            self:Whitespace("\t")
            self:EmitToken(node.tokens["local"])
            self:Whitespace(" ")
            self:EmitToken(node.tokens["function"])
            self:Whitespace(" ")
            self:EmitIdentifier(node.name)
        else
            self:Whitespace("\t")
            self:EmitToken(node.tokens["function"])
            self:Whitespace(" ")
            self:EmitExpression(node.expression)
        end

        self:EmitToken(node.tokens["("])
        self:EmitIdentifierList(node.identifiers)
        self:EmitToken(node.tokens[")"])

        self:Whitespace("\n")
        self:EmitBlock(node.statements)

        self:Whitespace("\t")
        self:EmitToken(node.tokens["end"])
    end
end

function META:EmitTable(node)
    self:EmitToken(node.tokens["{"])
    if node.children[1] then
        self:Whitespace("\n")
            self:Whitespace("\t+")
            for _,node in ipairs(node.children) do
                self:Whitespace("\t")
                if node.kind == "table_index_value" then
                    self:EmitExpression(node.value)
                elseif node.kind == "table_key_value" then
                    self:EmitToken(node.key)
                    self:EmitToken(node.tokens["="])
                    self:EmitExpression(node.value)
                elseif node.kind == "table_expression_value" then

                    self:EmitToken(node.tokens["["])
                    self:Whitespace("(")
                    self:EmitExpression(node.key)
                    self:Whitespace(")")
                    self:EmitToken(node.tokens["]"])

                    self:EmitToken(node.tokens["="])

                    self:EmitExpression(node.value)
                end
                if node.tokens[","] then
                    self:EmitToken(node.tokens[","])
                else
                    self:Whitespace(",")
                end
                self:Whitespace("\n")
            end
            self:Whitespace("\t-")
        self:Whitespace("\t")
    end
    self:EmitToken(node.tokens["}"])
end

function META:EmitPrefixOperator(node)
    local func_chunks = oh.syntax.GetFunctionForPrefixOperator(node.value)

    if self.TranslatePrefixOperator then
        func_chunks = self:TranslatePrefixOperator(node) or func_chunks
    end

    if func_chunks then
        self:Emit(func_chunks[1])
        self:EmitExpression(node.right)
        self:Emit(func_chunks[2])
        self.operator_transformed = true
    else
        if oh.syntax.IsKeyword(node.value) then
            self:Whitespace("?")
            self:EmitToken(node.value)
            self:Whitespace("?")
            self:EmitExpression(node.right)
        else
            self:EmitToken(node.value)
            self:EmitExpression(node.right)
        end
    end
end

function META:EmitPostfixOperator(node)
    local func_chunks = oh.syntax.GetFunctionForPostfixOperator(node.value)
    if func_chunks then
        self:Emit(func_chunks[1])
        self:EmitExpression(node.left)
        self:Emit(func_chunks[2])
        self.operator_transformed = true
    else
        if oh.syntax.IsKeyword(node.value) then
            self:EmitExpression(node.left)
            self:Whitespace("?")
            self:EmitToken(node.value)
            self:Whitespace("?")
        else
            self:EmitExpression(node.left)
            self:EmitToken(node.value)
        end
    end
end

function META:EmitBlock(statements)
    self:Whitespace("\t+")
    self:EmitStatements(statements)
    self:Whitespace("\t-")
end

function META:EmitIfStatement(node)
    for i = 1, #node.statements do
        self:Whitespace("\t")
        if node.expressions[i] then
            self:EmitToken(node.tokens["if/else/elseif"][i])
            self:Whitespace(" ")
            self:EmitExpression(node.expressions[i])
            self:Whitespace(" ")
            self:EmitToken(node.tokens["then"][i])
        elseif node.tokens["if/else/elseif"][i] then
            self:EmitToken(node.tokens["if/else/elseif"][i])
        end
        self:Whitespace("\n")
        self:EmitBlock(node.statements[i])
    end
    self:Whitespace("\t")
    self:EmitToken(node.tokens["end"])
end

function META:EmitForStatement(node)
    self:Whitespace("\t")
    self:EmitToken(node.tokens["for"])
    self:Whitespace(" ")

    if node.fori then
        self:EmitIdentifierList(node.identifiers)
        self:Whitespace(" ")
        self:EmitToken(node.tokens["="])
        self:Whitespace(" ")
        self:EmitExpressionList(node.expressions)
    else
        self:EmitIdentifierList(node.identifiers)
        self:Whitespace(" ")
        self:EmitToken(node.tokens["in"])
        self:Whitespace(" ")
        self:EmitExpressionList(node.expressions)
    end

    self:Whitespace(" ")
    self:EmitToken(node.tokens["do"])
    self:Whitespace("\n")
    self:EmitBlock(node.statements)
    self:Whitespace("\t")
    self:EmitToken(node.tokens["end"])
end

function META:EmitWhileStatement(node)
    self:Whitespace("\t")
    self:EmitToken(node.tokens["while"])
    self:Whitespace(" ")
    self:EmitExpression(node.expression)
    self:Whitespace(" ")
    self:EmitToken(node.tokens["do"])
    self:Whitespace("\n")
    self:EmitBlock(node.statements)
    self:Whitespace("\t")
    self:EmitToken(node.tokens["end"])
end

function META:EmitRepeatStatement(node)
    self:Whitespace("\t")
    self:EmitToken(node.tokens["repeat"])
    self:Whitespace("\n")

    self:EmitBlock(node.statements)

    self:Whitespace("\t")
    self:EmitToken(node.tokens["until"])
    self:Whitespace(" ")
    self:EmitExpression(node.expression)
end

do
    function META:EmitLabelStatement(node)
        self:Whitespace("\t")
        self:EmitToken(node.tokens["::left"])
        self:EmitToken(node.identifier)
        self:EmitToken(node.tokens["::right"])
    end

    function META:EmitGotoStatement(node)
        self:Whitespace("\t")
        self:EmitToken(node.tokens["goto"])
        self:Whitespace(" ")
        self:EmitToken(node.identifier)
    end
end

function META:EmitBreakStatement(node)
    self:Whitespace("\t")
    self:EmitToken(node.tokens["break"])
end

function META:EmitDoStatement(node)
    self:Whitespace("\t")
    self:EmitToken(node.tokens["do"])
    self:Whitespace("\n")

    self:EmitBlock(node.statements)

    self:Whitespace("\t")
    self:EmitToken(node.tokens["end"])
end

function META:EmitReturnStatement(node)
    self:Whitespace("\t")
    self:EmitToken(node.tokens["return"])
    self:Whitespace(" ")
    self:EmitExpressionList(node.expressions)
end

function META:EmitSemicolonStatement(node)
    self:EmitToken(node.tokens[";"])
end

function META:EmitAssignment(node)
    self:Whitespace("\t")

    if node.is_local then
        self:EmitToken(node.tokens["local"])
        self:Whitespace(" ")
        self:EmitIdentifierList(node.identifiers)
    else
        self:EmitExpressionList(node.expressions_left)
    end
    if node.tokens["="] then
        self:Whitespace(" ")
        self:EmitToken(node.tokens["="])
        self:Whitespace(" ")
        self:EmitExpressionList(node.expressions_right or node.expressions)
    end
end

function META:EmitStatement(node)
    if node.kind == "if" then
        self:EmitIfStatement(node)
    elseif node.kind == "goto" then
        self:EmitGotoStatement(node)
    elseif node.kind == "goto_label" then
        self:EmitLabelStatement(node)
    elseif node.kind == "while" then
        self:EmitWhileStatement(node)
    elseif node.kind == "repeat" then
        self:EmitRepeatStatement(node)
    elseif node.kind == "break" then
        self:EmitBreakStatement(node)
    elseif node.kind == "return" then
        self:EmitReturnStatement(node)
    elseif node.kind == "for" then
        self:EmitForStatement(node)
    elseif node.kind == "do" then
        self:EmitDoStatement(node)
    elseif node.kind == "function" then
        self:EmitFunction(node)
    elseif node.kind == "assignment" then
        self:EmitAssignment(node)
    elseif node.kind == "function" then
        self:Function(node)
    elseif node.kind == "expression" then
        self:Whitespace("\t")
        self:EmitExpression(node.value)
    elseif node.kind == "shebang" then
        self:EmitToken(node.tokens["shebang"])
    elseif node.kind == "value" then
        self:EmitExpression(node)
    elseif node.kind == "semicolon" then
        self:EmitSemicolonStatement(node)

        if not self.PreserveWhitespace then
            if self.out[self.i - 2] and self.out[self.i - 2] == "\n" then
                self.out[self.i - 2] = ""
            end
        end
    elseif node.kind == "end_of_file" then
        self:EmitToken(node.tokens["end_of_file"])
    else
        error("unhandled value: " .. node.kind)
    end

    if self.OnEmitStatement then
        if node.kind ~= "end_of_file" then
            self:OnEmitStatement()
        end
    end
end

function META:EmitStatements(tbl)
    for _, node in ipairs(tbl) do
        self:EmitStatement(node)
        self:Whitespace("\n")
    end
end

function META:EmitExpressionList(tbl, delimiter)
    for i = 1, #tbl do
        self:EmitExpression(tbl[i])
        if i ~= #tbl then
            self:EmitToken(tbl[i].tokens[","], delimiter)
            self:Whitespace(" ")
        end
    end
end

function META:EmitIdentifier(token)
    self:EmitToken(token.value)
end

function META:EmitIdentifierList(tbl, delimiter)
    for i = 1, #tbl do
        self:EmitIdentifier(tbl[i])
        if i ~= #tbl then
            self:EmitToken(tbl[i].tokens[","], delimiter)
            self:Whitespace(" ")
        end
    end
end

function oh.LuaEmitter(config)
    local self = setmetatable({}, META)
    if config and config.preserve_whitespace ~= nil then
        self.PreserveWhitespace = config.preserve_whitespace
    end
    self:Initialize()
    return self
end