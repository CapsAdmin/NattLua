local list = require("nattlua.other.list")
local syntax = require("nattlua.syntax.syntax")
local ipairs = ipairs
local assert = assert
local type = type

local META = {}
META.__index = META

require("nattlua.transpiler.base_emitter")(META)

function META:OptionalWhitespace()
    if self.config.preserve_whitespace == nil and not force then return end

    if syntax.IsLetter(self:GetPrevChar()) or syntax.IsNumber(self:GetPrevChar()) then
        self:Emit(" ")
    end
end

function META:EmitStringToken(token)
    if self.config.string_quote then
        local current = token.value:sub(1, 1)
        local target = self.config.string_quote

        if current == "\"" or current == "\'" then
            local contents = token.value:sub(2, -2)
            contents = contents:gsub("([\\])" .. current, current)
            contents = contents:gsub(target, "\\" .. target)
            self:EmitToken(token, target .. contents .. target)
        else
            self:EmitToken(token)
        end
    else
        self:EmitToken(token)
    end
end

function META:EmitNumberToken(token)
    self:EmitToken(token)
end

function META:EmitExpression(node, from_assignment)
    local pushed = false

    if node.tokens["("] then
        for _, node in node.tokens["("]:pairs() do
            self:EmitToken(node)
        end

        if node.tokens["("] then
            if node:GetLength() < 100 then
                self:PushForceNewlines(false)
                pushed = true
            else
                self:Indent()
                self:Whitespace("\n")
                self:Whitespace("\t")
            end
        end

    end

    if node.kind == "binary_operator" then
        self:EmitBinaryOperator(node)
    elseif node.kind == "function" then
        self:EmitAnonymousFunction(node)
    elseif node.kind == "type_function" then
        self:EmitInvalidLuaCode("EmitTypeFunction", node)
    elseif node.kind == "table" then
        self:EmitTable(node)
    elseif node.kind == "prefix_operator" then
        self:EmitPrefixOperator(node)
    elseif node.kind == "postfix_operator" then
        self:EmitPostfixOperator(node)
    elseif node.kind == "postfix_call" then
        if node.type_call then
            self:EmitInvalidLuaCode("EmitCall", node)
        else
            self:EmitCall(node)
        end
    elseif node.kind == "postfix_expression_index" then
        self:EmitExpressionIndex(node)
    elseif node.kind == "value" then
        if node.tokens["is"] then
            self:EmitToken(node.value, tostring(node.result_is))
        else
            if node.value.type == "string" then
                self:EmitStringToken(node.value)
            elseif node.value.type == "number" then
                self:EmitNumberToken(node.value)
            else
                self:EmitToken(node.value)
            end
        end
    elseif node.kind == "import" then
        self:EmitImportExpression(node)
    elseif node.kind == "lsx" then
        self:EmitLSXExpression(node)
    elseif node.kind == "type_table" then
        self:EmitTableType(node)
    elseif node.kind == "type_list" then
       self:EmitTypeList(node)
    elseif node.kind == "table_expression_value" then
        self:EmitTableExpressionValue(node)
    elseif node.kind == "table_key_value" then
        self:EmitTableKeyValue(node)
    else
        error("unhandled token type " .. node.kind)
    end

    if node.tokens[")"] then
        if pushed then
            self:PopForceNewlines()
        else
            self:Outdent()
            self:Whitespace("\n")
            self:Whitespace("\t")
        end
        for _, node in node.tokens[")"]:pairs() do
            self:EmitToken(node)
        end

    end

    if from_assignment and self.config.annotate and node.inferred_type then
        self:Emit(": ")
        self:Emit(tostring((node.inferred_type:GetContract() or node.inferred_type)))
    end
end

function META:EmitVarargTuple(node)
    self:Emit(tostring(node.inferred_type))
end

function META:EmitExpressionIndex(node)
    self:EmitExpression(node.left)
    self:EmitToken(node.tokens["["])
    self:EmitExpression(node.expression)
    self:EmitToken(node.tokens["]"])
end

function META:PushForceNewlines(b)
    self.force_newlines = self.force_newlines or {}
    table.insert(self.force_newlines, b)
end

function META:PopForceNewlines()
    table.remove(self.force_newlines)
end

function META:IsForcingNewlines()
    return self.force_newlines and self.force_newlines[#self.force_newlines]
end

function META:EmitBreakableExpressionList(list, first_newline)
    local newlines = self:ShouldBreakExpressionList(list)

    if newlines then
        self:Indent()
        self:PushForceNewlines(true)
        if first_newline then
            self:Whitespace("\n")
            self:Whitespace("\t")
        end
    end

    self:EmitExpressionList(list)

    if newlines then
        self:Outdent()
        self:Whitespace("\n")
        self:Whitespace("\t")
        self:PopForceNewlines()
    end

    return newlines
end

function META:EmitCall(node)
    if node:GetLength() > 100 then
        
    end

    self:EmitExpression(node.left)

    if node.tokens["call("] then
        self:EmitToken(node.tokens["call("])
    end

    if #node.expressions <= 2 then
        self:PushForceNewlines(false)
    end

    self:EmitBreakableExpressionList(node.expressions, true)
    
    if #node.expressions <= 2 then
        self:PopForceNewlines()
    end

    if node.tokens["call)"] then
        self:EmitToken(node.tokens["call)"])
    end
end

function META:EmitBinaryOperator(node)
    local func_chunks = syntax.GetFunctionForBinaryOperator(node.value)
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
        elseif node.value.value == "and" or node.value.value == "or" then
            self:Whitespace(" ")
            self:EmitToken(node.value)
            
            if self:IsForcingNewlines() or node:GetLength() > 100 then
                self:Whitespace("\n")
                self:Whitespace("\t")
            else
                self:Whitespace(" ")
            end

        else
            self:Whitespace(" ")
            self:EmitToken(node.value)
            self:Whitespace(" ")
        end
        if node.right then self:EmitExpression(node.right) end
    end
end

do
    local function emit_function_body(self, node, type_function)
        self:EmitToken(node.tokens["arguments("])
        self:EmitIdentifierList(node.identifiers)
        self:EmitToken(node.tokens["arguments)"])

        

        if self.config.annotate and node.inferred_type and not type_function then
            --self:Emit(" --[[ : ")
            local str = list.new()
            -- this iterates the first return tuple
            local obj = node.inferred_type:GetContract() or node.inferred_type

            if obj.Type == "function" then
                for i,v in ipairs(obj:GetReturnTypes():GetData()) do
                    str[i] = tostring(v)
                end
            else
                str[1] = tostring(obj)
            end
            if str[1] then
                self:Emit(": ")
                self:Emit(str:concat(", "))
            end
            --self:Emit(" ]] ")
        end

        
        if node.statements then
            self:PushForceNewlines(false)

            if #node.statements > 0 then
                self:Whitespace("\n")
            end

            if #node.statements == 0 then
                self:Whitespace(" ")
            end

            self:EmitBlock(node.statements)
            
            if #node.statements > 0 then
                self:Whitespace("\t")
            end

            self:PopForceNewlines()

            self:EmitToken(node.tokens["end"])
        end
    end

    function META:EmitAnonymousFunction(node)
        self:EmitToken(node.tokens["function"])
        emit_function_body(self, node)
    end

    function META:EmitLocalFunction(node)
        self:Whitespace("\t")
        self:EmitToken(node.tokens["local"])
        self:Whitespace(" ")
        self:EmitToken(node.tokens["function"])
        self:Whitespace(" ")
        self:EmitToken(node.tokens["identifier"])
        emit_function_body(self, node)
    end

    function META:EmitLocalTypeFunction(node)
        self:Whitespace("\t")
        self:EmitToken(node.tokens["local"])
        self:Whitespace(" ")
        self:EmitToken(node.tokens["type"])
        self:Whitespace(" ")
        self:EmitToken(node.tokens["function"])
        self:Whitespace(" ")
        self:EmitToken(node.tokens["identifier"])
        emit_function_body(self, node)
    end

    function META:EmitLocalGenericsTypeFunction(node)
        self:Whitespace("\t")
        self:EmitToken(node.tokens["local"])
        self:Whitespace(" ")
        self:EmitToken(node.tokens["function"])
        self:Whitespace(" ")
        self:EmitToken(node.tokens["identifier"])
        emit_function_body(self, node, true)
    end

    function META:EmitGenericsTypeFunction(node)
        self:Whitespace("\t")
        self:EmitToken(node.tokens["function"])
        self:Whitespace(" ")
        self:EmitExpression(node.expression or node.identifier)
        emit_function_body(self, node, true)
    end

    function META:EmitFunction(node)
        self:Whitespace("\t")
        if node.tokens["local"] then
            self:EmitToken(node.tokens["local"])
            self:Whitespace(" ")
        end
        self:EmitToken(node.tokens["function"])
        self:Whitespace(" ")
        self:EmitExpression(node.expression or node.identifier)
        emit_function_body(self, node)
    end

    function META:EmitTypeFunctionStatement(node)
        self:Whitespace("\t")
        if node.tokens["local"] then
            self:EmitToken(node.tokens["local"])
            self:Whitespace(" ")
        end
        self:EmitToken(node.tokens["function"])
        self:Whitespace(" ")
        if node.expression or node.identifier then
            self:EmitExpression(node.expression or node.identifier)
        end
        emit_function_body(self, node)
    end
end

function META:EmitTableExpressionValue(node)
    self:EmitToken(node.tokens["["])
    self:EmitExpression(node.expressions[1])
    self:EmitToken(node.tokens["]"])

    self:Whitespace(" ")
    self:EmitToken(node.tokens["="])
    self:Whitespace(" ")

    self:EmitExpression(node.expressions[2])
end

function META:EmitTableKeyValue(node)
    self:EmitToken(node.tokens["identifier"])
    self:Whitespace(" ")
    self:EmitToken(node.tokens["="])
    self:Whitespace(" ")
    self:EmitExpression(node.expression)
end

local function has_function_value(tree)
    for _, exp in ipairs(tree.children) do
        if exp.expression and exp.expression.kind == "function" then
            return true
        end
    end
    return false
end

function META:EmitTable(tree)
    if tree.spread then
        self:Emit("table.mergetables")
    end

    local during_spread = false

    self:EmitToken(tree.tokens["{"])
    local newline = tree:GetLength() > 100 or has_function_value(tree)

    if tree.children[1] then
        if newline then
            self:Whitespace("\n")
            self:Whitespace("\t+")
        end
        
        for i,node in tree.children:pairs() do

            if newline then
                self:Whitespace("\t")
            end

            if node.kind == "table_index_value" then
                if node.spread then
                    if during_spread then
                        self:Emit("},")
                        during_spread = false
                    end
                    self:EmitExpression(node.spread.expression)
                else
                    self:EmitExpression(node.expression)
                end
            elseif node.kind == "table_key_value" then
                if tree.spread and not during_spread then
                    during_spread = true
                    self:Emit("{")
                end
                self:EmitTableKeyValue(node)
            elseif node.kind == "table_expression_value" then
                self:EmitTableExpressionValue(node)
            end

            if tree.tokens["separators"][i] then
                self:EmitToken(tree.tokens["separators"][i])
                self:Whitespace(" ")
            else
                if newline then
                    self:Whitespace(",")
                end
            end

            if newline then
                self:Whitespace("\n")
            end
        end

        if newline then
            self:Whitespace("\t-")
            self:Whitespace("\t")
        end
    end
    if during_spread then
        self:Emit("}")
    end
    self:EmitToken(tree.tokens["}"])
end

function META:EmitPrefixOperator(node)
    local func_chunks = syntax.GetFunctionForPrefixOperator(node.value)

    if self.TranslatePrefixOperator then
        func_chunks = self:TranslatePrefixOperator(node) or func_chunks
    end

    if func_chunks then
        self:Emit(func_chunks[1])
        self:EmitExpression(node.right)
        self:Emit(func_chunks[2])
        self.operator_transformed = true
    else
        if syntax.IsKeyword(node.value) then
            self:OptionalWhitespace()
            self:EmitToken(node.value)
            self:OptionalWhitespace()
            self:EmitExpression(node.right)
        else
            self:EmitToken(node.value)
            self:EmitExpression(node.right)
        end
    end
end

function META:EmitPostfixOperator(node)
    local func_chunks = syntax.GetFunctionForPostfixOperator(node.value)

    -- no such thing as postfix operator in lua,
    -- so we have to assume that there's a translation
    assert(func_chunks)

    self:Emit(func_chunks[1])
    self:EmitExpression(node.left)
    self:Emit(func_chunks[2])
    self.operator_transformed = true
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
            self:EmitBreakableExpressionList({node.expressions[i]}, true)
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


function META:EmitGenericForStatement(node)
    self:Whitespace("\t")
    self:EmitToken(node.tokens["for"])
    self:Whitespace(" ")

    self:EmitIdentifierList(node.identifiers)
    self:Whitespace(" ")
    self:EmitToken(node.tokens["in"])
    self:Whitespace(" ")
    self:EmitExpressionList(node.expressions)

    self:Whitespace(" ")
    self:EmitToken(node.tokens["do"])
    self:Whitespace("\n")
    self:EmitBlock(node.statements)
    self:Whitespace("\t")
    self:EmitToken(node.tokens["end"])
end

function META:EmitNumericForStatement(node)
    self:Whitespace("\t")
    self:EmitToken(node.tokens["for"])
    self:Whitespace(" ")

    self:EmitIdentifierList(node.identifiers)
    self:Whitespace(" ")
    self:EmitToken(node.tokens["="])
    self:Whitespace(" ")
    self:EmitExpressionList(node.expressions)

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

function META:EmitLabelStatement(node)
    self:Whitespace("\t")

    self:EmitToken(node.tokens["::"][1])
    self:EmitToken(node.tokens["identifier"])
    self:EmitToken(node.tokens["::"][2])
end

function META:EmitGotoStatement(node)
    self:Whitespace("\t")
    self:EmitToken(node.tokens["goto"])
    self:Whitespace(" ")
    self:EmitToken(node.tokens["identifier"])
end

function META:EmitBreakStatement(node)
    self:Whitespace("\t")
    self:EmitToken(node.tokens["break"])
end

function META:EmitContinueStatement(node)
    self:Whitespace("\t")
    self:EmitToken(node.tokens["continue"])
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
    if node.expressions[1] then
        self:Whitespace(" ")
        self:EmitBreakableExpressionList(node.expressions)
    end
end

function META:EmitSemicolonStatement(node)
    if self.config.no_semicolon then 
        self:EmitToken(node.tokens[";"], "")
    else
    self:EmitToken(node.tokens[";"])
end
end

function META:EmitLocalAssignment(node)
    if node.environment == "typesystem" then return end

    self:Whitespace("\t")

    self:EmitToken(node.tokens["local"])

    if node.environment == "typesystem" then
        self:EmitToken(node.tokens["type"])
    end

    self:Whitespace(" ")
    self:EmitIdentifierList(node.left)

    if node.tokens["="] then
        self:Whitespace(" ")
        self:EmitToken(node.tokens["="])
        self:Whitespace(" ")
        self:EmitBreakableExpressionList(node.right)
    end
end

function META:EmitAssignment(node)
    if node.environment == "typesystem" then return end

    self:Whitespace("\t")

    if node.environment == "typesystem" then
        self:EmitToken(node.tokens["type"])
    end

    self:EmitExpressionList(node.left, nil, true)

    if node.tokens["="] then
        self:Whitespace(" ")
        self:EmitToken(node.tokens["="])
        self:Whitespace(" ")
        self:EmitBreakableExpressionList(node.right)
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
    elseif node.kind == "numeric_for" then
        self:EmitNumericForStatement(node)
    elseif node.kind == "generic_for" then
        self:EmitGenericForStatement(node)
    elseif node.kind == "do" then
        self:EmitDoStatement(node)
    elseif node.kind == "type_function" then
        self:EmitInvalidLuaCode("EmitTypeFunctionStatement", node)
    elseif node.kind == "function" then
        self:EmitFunction(node)
    elseif node.kind == "local_function" then
        self:EmitLocalFunction(node)
    elseif node.kind == "local_type_function" then
        self:EmitLocalTypeFunction(node)
    elseif node.kind == "local_generics_type_function" then
        self:EmitInvalidLuaCode("EmitLocalGenericsTypeFunction", node)
    elseif node.kind == "generics_type_function" then
        self:EmitInvalidLuaCode("EmitGenericsTypeFunction", node)
    elseif node.kind == "destructure_assignment" then
        self:EmitDestructureAssignment(node)
    elseif node.kind == "assignment" then
        self:EmitAssignment(node)
        self:Emit_ENVFromAssignment(node)
    elseif node.kind == "local_assignment" then
        self:EmitLocalAssignment(node)
    elseif node.kind == "local_destructure_assignment" then
        self:EmitLocalDestructureAssignment(node)
    elseif node.kind == "import" then
        self:Emit("local ")
        self:EmitIdentifierList(node.left)
        self:Emit(" = ")
        self:EmitImportExpression(node)
    elseif node.kind == "call_expression" then
        self:Whitespace("\t")
        self:EmitExpression(node.value)
    elseif node.kind == "shebang" then
        self:EmitToken(node.tokens["shebang"])
    elseif node.kind == "type_interface" then
        self:EmitInterfaceType(node)
    elseif node.kind == "lsx" then
        self:EmitLSXStatement(node)
    elseif node.kind == "continue" then
        self:EmitContinueStatement(node)
    elseif node.kind == "semicolon" then
        self:EmitSemicolonStatement(node)

        if self.config.preserve_whitespace == false then
            if self.out[self.i - 2] and self.out[self.i - 2] == "\n" then
                self.out[self.i - 2] = ""
            end
        end
    elseif node.kind == "end_of_file" then
        self:EmitToken(node.tokens["end_of_file"])
    elseif node.kind == "root" then
        self:EmitStatements(node.statements)
    elseif node.kind == "type_code" then
        self:Emit("--" .. node.lua_code.value.value)
    elseif node.kind then
        error("unhandled statement: " .. node.kind)
    else
        for k,v in pairs(node) do print(k,v) end
        error("invalid statement: " .. tostring(node))
    end

    if self.OnEmitStatement then
        if node.kind ~= "end_of_file" then
            self:OnEmitStatement()
        end
    end
end

local function general_kind(node)
    if  
        node.kind == "call_expression" or 
        node.kind == "local_assignment" or 
        node.kind == "assignment" or
        node.kind == "return"
    then
        return "expression_statement"
    end
    return "other"
end

function META:EmitStatements(tbl)
    for i, node in tbl:pairs() do
        local last_statement = self.level == 0 and i >= #tbl - 1
        
        if not last_statement then
            local kind = general_kind(node)
            if (kind == "other" and i > 1) or (tbl[i - 1] and general_kind(tbl[i - 1]) ~= kind) then
                self:Whitespace("\n")
            end
        end

        self:EmitStatement(node)

        if not last_statement then
            self:Whitespace("\n")
        end
    end
end

function META:ShouldBreakExpressionList(tbl)
    if self.config.preserve_whitespace == false then
        -- more than 5 arguments, always break everything into newline call
        if #tbl > 5 then
            return true
        else
            local total_length = 0
            for _, exp in ipairs(tbl) do
                local length = exp:GetLength()

                total_length = total_length + length
                
                if total_length > 50 then
                    return true
                end
            end
        end
    end

    return false
end

function META:EmitExpressionList(tbl, delimiter, from_assignment)
    for i = 1, #tbl do
        if i > 1 and self:IsForcingNewlines() then
            self:Whitespace("\n")
            self:Whitespace("\t")
        end

        local pushed = false
        if self:IsForcingNewlines() then
            if tbl[i]:GetLength() < 50 then
                self:PushForceNewlines(false)
                pushed = true
            end
        end

        self:EmitExpression(tbl[i], from_assignment)

        if pushed then
            self:PopForceNewlines()
        end

        if i ~= #tbl then
            self:EmitToken(tbl[i].tokens[","], delimiter)
            if not self:IsForcingNewlines() then
                self:Whitespace(" ")
            end
        end
    end
end

function META:EmitIdentifier(node)
    self:EmitToken(node.value)

    if self.config.annotate then
        if node.explicit_type and node.tokens[":"] then
            self:EmitToken(node.tokens[":"])
            self:EmitTypeExpression(node.explicit_type)
        elseif node.inferred_type then
            self:Emit(": ")
            self:Emit(tostring((node.inferred_type:GetContract() or node.inferred_type)))
        end
    end
end

function META:EmitIdentifierList(tbl)
    for i = 1, #tbl do
        self:EmitIdentifier(tbl[i])
        if i ~= #tbl then
            self:EmitToken(tbl[i].tokens[","])
            self:Whitespace(" ")
        end
    end
end

do -- types
    function META:EmitTypeBinaryOperator(node)
        if node.left then self:EmitTypeExpression(node.left) end
        if node.value.value == "." or node.value.value == ":" then
            self:EmitToken(node.value)
        else
            self:Whitespace(" ")
            self:EmitToken(node.value)
            self:Whitespace(" ")
        end
        if node.right then self:EmitTypeExpression(node.right) end
    end

    function META:EmitType(node)
        self:EmitToken(node.value)

        if node.explicit_type then
            self:EmitToken(node.tokens[":"])
            self:EmitTypeExpression(node.explicit_type)
        end
    end

    function META:EmitTypeList(node)
        self:EmitToken(node.tokens["["])
        for i = 1, #node.types do
            self:EmitTypeExpression(node.types[i])
            if i ~= #node.types then
                self:EmitToken(node.types[i].tokens[","])
                self:Whitespace(" ")
            end
        end
        self:EmitToken(node.tokens["]"])
    end

    function META:EmitListType(node)
--        self:EmitTypeList(node)
    end


    function META:EmitInterfaceType(node)
        self:EmitToken(node.tokens["interface"])
        self:EmitExpression(node.key)
        self:EmitToken(node.tokens["{"])
        for _,node in node.expressions:pairs() do
            self:EmitToken(node.left)
            self:EmitToken(node.tokens["="])
            self:EmitTypeExpression(node.right)
        end
        self:EmitToken(node.tokens["}"])
    end


    function META:EmitTableType(node)
        local tree = node
        self:EmitToken(node.tokens["{"])
        if node.children[1] then
            self:Whitespace("\n")
                self:Whitespace("\t+")
                for i, node in node.children:pairs() do
                    self:Whitespace("\t")
                    if node.kind == "table_index_value" then
                        self:EmitTypeExpression(node.expression)
                    elseif node.kind == "table_key_value" then
                        self:EmitToken(node.tokens["identifier"])
                        self:Whitespace(" ")
                        self:EmitToken(node.tokens["="])
                        self:Whitespace(" ")
                        self:EmitTypeExpression(node.expression)
                    elseif node.kind == "table_expression_value" then
                        self:EmitToken(node.tokens["["])
                        self:Whitespace("(")
                        self:EmitTypeExpression(node.expressions[1])
                        self:Whitespace(")")
                        self:EmitToken(node.tokens["]"])
                        self:EmitToken(node.tokens["="])
                        self:EmitTypeExpression(node.expressions[2])
                    end

                    if tree.tokens["separators"][i] then
                        self:EmitToken(tree.tokens["separators"][i])
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

    function META:EmitTypeFunction(node)
        self:EmitToken(node.tokens["function"])
        self:EmitToken(node.tokens["arguments("])
        for i, exp in node.identifiers:pairs() do

            if not self.config.annotate and node.statements then
                if exp.identifier then
                    self:EmitToken(exp.identifier)
                else
                    self:EmitTypeExpression(exp)
                end
            else
                if exp.identifier then
                    self:EmitToken(exp.identifier)
                    self:EmitToken(exp.tokens[":"])
                end

                self:EmitTypeExpression(exp)
            end

            if i ~= #node.identifiers then
                if exp.tokens[","]then
                    self:EmitToken(exp.tokens[","])
                end
            end
        end
        self:EmitToken(node.tokens["arguments)"])
        if node.tokens[":"] then
            self:EmitToken(node.tokens[":"])
            for i, exp in node.return_types:pairs() do
                self:EmitTypeExpression(exp)
                if i ~= #node.return_types then
                    self:EmitToken(exp.tokens[","])
                end
            end
        else
            self:Whitespace("\n")
            self:EmitBlock(node.statements)
            self:Whitespace("\t")
            self:EmitToken(node.tokens["end"])
        end
    end

    function META:EmitTypeExpression(node)
        if node.tokens["("] then
            for _, node in node.tokens["("]:pairs() do
                self:EmitToken(node)
            end
        end

        if node.kind == "binary_operator" then
            self:EmitTypeBinaryOperator(node)
        elseif node.kind == "type_function" then
            self:EmitInvalidLuaCode("EmitTypeFunction", node)
        elseif node.kind == "table" then
            self:EmitTable(node)
        elseif node.kind == "prefix_operator" then
            self:EmitPrefixOperator(node)
        elseif node.kind == "postfix_operator" then
            self:EmitPostfixOperator(node)
        elseif node.kind == "postfix_call" then
            if node.type_call then
                self:EmitInvalidLuaCode("EmitCall", node)
            else
                self:EmitCall(node)
            end
        elseif node.kind == "postfix_expression_index" then
            self:EmitExpressionIndex(node)
        elseif node.kind == "value" then
            self:EmitToken(node.value)
        elseif node.kind == "type_table" then
            self:EmitTableType(node)
        elseif node.kind == "type_list" then
            self:EmitListType(node)
        elseif node.kind == "table_expression_value" then
            self:EmitTableExpressionValue(node)
        elseif node.kind == "table_key_value" then
            self:EmitTableKeyValue(node)
        else
            error("unhandled token type " .. node.kind)
        end

        if node.tokens[")"] then
            for _, node in node.tokens[")"]:pairs() do
                self:EmitToken(node)
            end
        end
    end

    function META:EmitInvalidLuaCode(func, ...)
        if not self.config.uncomment_types then
            if not self.during_comment_type or self.during_comment_type == 0 then
                self:Emit("\n--[==[")
            end
            self.during_comment_type = self.during_comment_type or 0
            self.during_comment_type = self.during_comment_type + 1
        end
        
        self[func](self, ...)

        if not self.config.uncomment_types then
            self.during_comment_type = self.during_comment_type - 1
            if not self.during_comment_type or self.during_comment_type == 0 then
                self:Emit("]==]")
            end
        end
    end
end

do -- extra
    function META:EmitDestructureAssignment(node)
        self:Whitespace("\t")
        self:EmitToken(node.tokens["{"], "")

        if node.default then
            self:EmitToken(node.default.value)
            self:EmitToken(node.default_comma)
        end
        self:EmitToken(node.tokens["{"], "")
        self:Whitespace(" ")
        self:EmitIdentifierList(node.left)
        self:EmitToken(node.tokens["}"], "")

            self:Whitespace(" ")
        self:EmitToken(node.tokens["="])
        self:Whitespace(" ")

        self:Emit("table.destructure(")
        self:EmitExpression(node.right)
        self:Emit(", ")
        self:Emit("{")
        for i, v in node.left:pairs() do
            self:Emit("\"")
            self:Emit(v.value.value)
            self:Emit("\"")
            if i ~= #node.left then
                self:Emit(", ")
            end
        end
        self:Emit("}")

        if node.default then
            self:Emit(", true")
        end

        self:Emit(")")
    end

    function META:EmitLocalDestructureAssignment(node)
        self:Whitespace("\t")
        self:EmitToken(node.tokens["local"])
        self:EmitDestructureAssignment(node)
        end

    function META:Emit_ENVFromAssignment(node)
        for i,v in node.left:pairs() do
            if v.kind == "value" and v.value.value == "_ENV" then
                if node.right[i] then
                    local key = node.left[i]
                    local val = node.right[i]

                    self:Emit(";setfenv(1, _ENV);")
                end
            end
        end
    end

    function META:EmitImportExpression(node)
        self:Emit(" IMPORTS['" .. node.path .. "'](")
        self:EmitExpressionList(node.expressions)
        self:Emit(")")
    end

    function META:EmitLSXStatement(node, root)
        if not root then
            self:Whitespace("\n", true)
            self:Whitespace("\t", true)
            self:Emit("local ")
        else
            self:Whitespace("\t", true)
        end
        self:EmitToken(node.tag) self:Emit(" = {type=\""..node.tag.value.."\",")

        for _, prop in node.props:pairs() do
            self:EmitToken(prop.key)
            self:Emit("=")
            self:EmitExpression(prop.val)
            self:Emit(",")
        end

        self:Emit("}\n")
        if not root then
            self:Whitespace("\t", true)
            self:Emit("table.insert(parent.children, ") self:EmitToken(node.tag) self:Emit(")\n")
        end
        if node.statements then
            self:Whitespace("\t", true)
            self:EmitToken(node.tag)
            self:Emit(".children={}")
            self:Whitespace("\n", true)
            self:Whitespace("\t", true)
            self:Emit("do")
            self:Indent()
            self:Whitespace("\n", true)
            self:Whitespace("\t", true)
            self:Emit("local parent = "..node.tag.value.."\n")
            self:EmitStatements(node.statements)
            self:Outdent()
            self:Whitespace("\t", true)
            self:Emit("end")
            self:Whitespace("\n", true)
        end
    end

    function META:EmitLSXExpression(node)
        self:Emit("(function()\n\tlocal ") self:EmitToken(node.tag) self:Emit(" do\n")
            self:Indent()
            self:EmitLSXStatement(node, true)
            self:Outdent()
        self:Emit(" end\n\treturn ") self:EmitToken(node.tag) self:Emit("\nend)()")
    end
end

return function(config)
    local self = setmetatable({}, META)
    self.config = config or {}
    self:Initialize()
    return self
end