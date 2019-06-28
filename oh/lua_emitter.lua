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
        if self:GetPrevCharType() == "letter" or self:GetPrevCharType() == "number" then
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

function META:GetPrevCharType()
    local prev = self.out[self.i - 1]
    local char = prev:sub(-1)
    return prev and oh.syntax.GetCharacterType(char:byte())
end

function META:EmitToken(v, translate)
    if v.whitespace then
        for _, data in ipairs(v.whitespace) do
            if data.type ~= "space" or self.PreserveWhitespace then
                self:Emit(data.value)
            end
        end
    end

    if translate then
        if type(translate) == "table" then
            self:Emit(translate[v.value] or v.value)
        elseif translate ~= "" then
            self:Emit(translate)
        end
    else
        self:Emit(v.value)
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

function META:EmitExpression(v)
    if v.tokens["("] then
        for _, v in ipairs(v.tokens["("]) do
            self:EmitToken(v)
        end
    end

    if v.kind == "binary_operator" then
        local func_chunks = oh.syntax.GetFunctionForBinaryOperator(v.value)
        if func_chunks then
            self:Emit(func_chunks[1])
            if v.left then self:EmitExpression(v.left) end
            self:Emit(func_chunks[2])
            if v.right then self:EmitExpression(v.right) end
            self:Emit(func_chunks[3])
            self.operator_transformed = true
        else
            if v.left then self:EmitExpression(v.left) end
            self:EmitBinaryOperator(v)
            if v.right then self:EmitExpression(v.right) end
        end
    elseif v.kind == "function" then
        self:EmitFunction(v, true)
    elseif v.kind == "table" then
        self:EmitTable(v)
    elseif v.kind == "prefix_operator" then
        self:EmitPrefixOperator(v)
    elseif v.kind == "postfix_operator" then
        self:EmitPostfixOperator(v)
    elseif v.kind == "postfix_call" then
        self:EmitExpression(v.left)

        if v.tokens["call("] then
            self:EmitToken(v.tokens["call("])
        end

        self:EmitExpressionList(v.expressions)

        if v.tokens["call)"] then
            self:EmitToken(v.tokens["call)"])
        end
    elseif v.kind == "postfix_expression_index" then
        self:EmitExpression(v.left)
        self:EmitToken(v.tokens["["])
        self:EmitExpression(v.expression)
        self:EmitToken(v.tokens["]"])
    elseif v.kind == "value" then
        self:EmitToken(v.value)
    else
        error("unhandled token type " .. v.kind)
    end

    if v.tokens[")"] then
        for _, v in ipairs(v.tokens[")"]) do
            self:EmitToken(v)
        end
    end
end


function META:EmitBinaryOperator(v)
    self:Whitespace(" ")
    self:EmitToken(v.value)
    self:Whitespace(" ")
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
            self:EmitExpression(node.name)
        else
            self:Whitespace("\t")
            self:EmitToken(node.tokens["function"])
            self:Whitespace(" ")
            self:EmitExpressionList(node.expressions)
        end

        self:EmitToken(node.tokens["("])
        self:EmitExpressionList(node.identifiers)
        self:EmitToken(node.tokens[")"])

        self:Whitespace("\n")
        self:Whitespace("\t+")
        self:EmitStatements(node.statements)
        self:Whitespace("\t-")

        self:Whitespace("\t")
        self:EmitToken(node.tokens["end"])
    end
end

function META:EmitTable(v)
    if not v.children[1] then
        self:EmitToken(v.tokens["{"])
        self:EmitToken(v.tokens["}"])
    else
        self:EmitToken(v.tokens["{"])
        self:Whitespace("\n")
            self:Whitespace("\t+")
            for _,v in ipairs(v.children) do
                self:Whitespace("\t")
                if v.kind == "table_index_value" then
                    self:EmitExpression(v.value)
                elseif v.kind == "table_key_value" then
                    self:EmitToken(v.key)
                    self:EmitToken(v.tokens["="])
                    self:EmitExpression(v.value)
                elseif v.kind == "table_expression_value" then

                    self:EmitToken(v.tokens["["])
                    self:Whitespace("(")
                    self:EmitExpression(v.key)
                    self:Whitespace(")")
                    self:EmitToken(v.tokens["]"])

                    self:EmitToken(v.tokens["="])

                    self:EmitExpression(v.value)
                end
                if v.tokens[","] then
                    self:EmitToken(v.tokens[","])
                else
                    self:Whitespace(",")
                end
                self:Whitespace("\n")
            end
            self:Whitespace("\t-")
        self:Whitespace("\t")self:EmitToken(v.tokens["}"])
    end
end

function META:EmitPrefixOperator(v)
    local func_chunks = oh.syntax.GetFunctionForPrefixOperator(v.value)
    if func_chunks then
        self:Emit(func_chunks[1])
        self:EmitExpression(v.right)
        self:Emit(func_chunks[2])
        self.operator_transformed = true
    else
        if oh.syntax.IsKeyword(v) then
            self:Whitespace("?")
            self:EmitToken(v.value)
            self:Whitespace("?")
            self:EmitExpression(v.right)
        else
            self:EmitToken(v.value)
            self:EmitExpression(v.right)
        end
    end
end

function META:EmitPostfixOperator(v)
    local func_chunks = oh.syntax.GetFunctionForPostfixOperator(v.value)
    if func_chunks then
        self:Emit(func_chunks[1])
        self:EmitExpression(v.left)
        self:Emit(func_chunks[2])
        self.operator_transformed = true
    else
        if oh.syntax.IsKeyword(v) then
            self:Whitespace("?")
            self:EmitToken(v.value)
            self:Whitespace("?")
            self:EmitExpression(v.left)
        else
            self:EmitToken(v.value)
            self:EmitExpression(v.left)
        end
    end
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
        self:Whitespace("\t+")
        self:EmitStatements(node.statements[i])
        self:Whitespace("\t-")
    end
    self:Whitespace("\t")
    self:EmitToken(node.tokens["end"])
end

function META:EmitForStatement(node)
    self:Whitespace("\t")
    self:EmitToken(node.tokens["for"])
    self:Whitespace(" ")
    if node.fori then
        self:EmitExpressionList(node.identifiers)
        self:Whitespace(" ")
        self:EmitToken(node.tokens["="])
        self:Whitespace(" ")
        self:EmitExpressionList(node.expressions)
    else
        self:EmitExpressionList(node.identifiers)
        self:Whitespace(" ")
        self:EmitToken(node.tokens["in"])
        self:Whitespace(" ")
        self:EmitExpressionList(node.expressions)
    end

    self:Whitespace(" ")
    self:EmitToken(node.tokens["do"])
    self:Whitespace("\n")
    self:Whitespace("\t+")
    self:EmitStatements(node.statements)
    self:Whitespace("\t-")
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
    self:Whitespace("\t+")
    self:EmitStatements(node.statements)
    self:Whitespace("\t-")
    self:Whitespace("\t")
    self:EmitToken(node.tokens["end"])
end

function META:EmitRepeatStatement(node)
    self:Whitespace("\t")
    self:EmitToken(node.tokens["repeat"])
    self:Whitespace("\n")

    self:Whitespace("\t+")
    self:EmitStatements(node.statements)
    self:Whitespace("\t-")

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

    self:Whitespace("\t+")
    self:EmitStatements(node.statements)
    self:Whitespace("\t-")

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
        self:EmitExpressionList(node.identifiers)
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
end

function META:EmitStatements(tbl)
    for _, node in ipairs(tbl) do
        self:EmitStatement(node)
        self:Whitespace("\n")
    end
end

function META:EmitExpressionList(tbl)
    for i = 1, #tbl do
        self:EmitExpression(tbl[i])
        if i ~= #tbl then
            self:EmitToken(tbl[i].tokens[","])
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