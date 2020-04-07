local table_insert = table.insert
local setmetatable = setmetatable
local type = type
local math_huge = math.huge
local pairs = pairs
local table_insert = table.insert
local table_concat = table.concat

local syntax = require("oh.lua.syntax")

local META = {}

local extended = {
    "oh.lua.parser_typesystem",
}

for _, name in ipairs(extended) do
    for k, v in pairs(require(name)) do
        META[k] = v
    end
end

do -- statements
    function META:ReadStatements(stop_token)
        local out = {}
        for i = 1, self:GetLength() do
            if not self:GetToken() or stop_token and stop_token[self:GetToken().value] then
                break
            end

            local statement = self:ReadStatement()

            if not statement then
                break
            end

            out[i] = statement
        end

        return out
    end

    function META:ReadRemainingStatement()
        if self:IsType("end_of_file") then
            return
        end

        if self:IsDestructureStatement(0) then
            return self:ReadDestructureAssignmentStatement()
        end

        local start = self:GetToken()
        local left = self:ReadExpressionList(math_huge)

        if self:IsValue("=") then
            local node = self:Statement("assignment")
            node.tokens["="] = self:ReadValue("=")
            node.left = left
            node.right = self:ReadExpressionList(math_huge)
            return node
        end

        if left[1] and left[1].kind == "postfix_call" and not left[2] then
            local node = self:Statement("call_expression")
            node.value = left[1]
            return node
        end

        self:Error("expected assignment or call expression got $1 ($2)", start, self:GetToken(), self:GetToken().type, self:GetToken().value)
    end

    function META:ReadStatement()
        if
            self:IsValue("return") then                                                             return self:ReadReturnStatement() elseif
            self:IsValue("break") then                                                              return self:ReadBreakStatement() elseif
            self:IsValue(";") then                                                                  return self:ReadSemicolonStatement() elseif
            self:IsValue("goto") and self:IsType("letter", 1) then                                  return self:ReadGotoStatement() elseif
            self:IsValue("import") then                                                             return self:ReadImportStatement() elseif
            self:IsValue("::") then                                                                 return self:ReadGotoLabelStatement() elseif
            self:IsLSXExpression() then                                                             return self:ReadLSXStatement() elseif
            self:IsValue("repeat") then                                                             return self:ReadRepeatStatement() elseif
            self:IsValue("function") then                                                           return self:ReadFunctionStatement() elseif
            self:IsValue("local") and self:IsValue("function", 1) then                              return self:ReadLocalFunctionStatement() elseif
            self:IsValue("local") and self:IsValue("type", 1) and self:IsValue("function", 2) then  return self:ReadLocalTypeFunctionStatement() elseif
            self:IsValue("local") and self:IsValue("type", 1) and self:IsType("letter", 2) then     return self:ReadLocalTypeDeclarationStatement() elseif
            self:IsValue("local") and self:IsDestructureStatement(1) then                           return self:ReadLocalDestructureAssignmentStatement() elseif
            self:IsValue("local") then                                                              return self:ReadLocalAssignmentStatement() elseif
            self:IsValue("type") and (self:IsType("letter", 1) or self:IsValue("^", 1)) then        return self:ReadTypeAssignment() elseif
            self:IsValue("interface") and self:IsType("letter", 1) then                             return self:ReadInterfaceStatement() elseif
            self:IsValue("do") then                                                                 return self:ReadDoStatement() elseif
            self:IsValue("if") then                                                                 return self:ReadIfStatement() elseif
            self:IsValue("while") then                                                              return self:ReadWhileStatement() elseif
            self:IsValue("for") and self:IsValue("=", 2) then                                       return self:ReadNumericForStatement() elseif
            self:IsValue("for") then                                                                return self:ReadGenericForStatement()
        end

        return self:ReadRemainingStatement()
    end
end

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

    function META:ReadLocalDestructureAssignmentStatement()
        local node = self:Statement("local_destructure_assignment")
        node.tokens["local"] = self:ReadValue("local")

        read_remaining(self, node)

        return node
    end
end

function META:ReadBreakStatement()
    local node = self:Statement("break")

    node.tokens["break"] = self:ReadValue("break")

    return node
end

function META:ReadReturnStatement()
    local node = self:Statement("return")

    node.tokens["return"] = self:ReadValue("return")
    node.expressions = self:ReadExpressionList()

    return node
end

function META:ReadDoStatement()
    local node = self:Statement("do")

    node.tokens["do"] = self:ReadValue("do")
    node.statements = self:ReadStatements({["end"] = true})
    node.tokens["end"] = self:ReadValue("end", node.tokens["do"], node.tokens["do"])

    return node
end

function META:ReadWhileStatement()
    local node = self:Statement("while")

    node.tokens["while"] = self:ReadValue("while")
    node.expression = self:ReadExpectExpression()
    node.tokens["do"] = self:ReadValue("do")
    node.statements = self:ReadStatements({["end"] = true})
    node.tokens["end"] = self:ReadValue("end", node.tokens["while"], node.tokens["while"])

    return node
end

function META:ReadRepeatStatement()
    local node = self:Statement("repeat")

    node.tokens["repeat"] = self:ReadValue("repeat")
    node.statements = self:ReadStatements({["until"] = true})
    node.tokens["until"] = self:ReadValue("until", node.tokens["repeat"], node.tokens["repeat"])
    node.expression = self:ReadExpectExpression()

    return node
end

function META:ReadGotoLabelStatement()
    local node = self:Statement("goto_label")

    node.tokens["::left"] = self:ReadValue("::")
    node.identifier = self:ReadType("letter")
    node.tokens["::right"]  = self:ReadValue("::")

    return node
end

function META:ReadGotoStatement()
    local node = self:Statement("goto")

    node.tokens["goto"] = self:ReadValue("goto")
    node.identifier = self:ReadType("letter")

    return node
end

function META:ReadLocalAssignmentStatement()
    local node = self:Statement("local_assignment")

    node.tokens["local"] = self:ReadValue("local")
    node.left = self:ReadIdentifierList()

    if self:IsValue("=") then
        node.tokens["="] = self:ReadValue("=")
        node.right = self:ReadExpressionList()
    end

    return node
end

function META:ReadNumericForStatement()
    local node = self:Statement("numeric_for")

    node.tokens["for"] = self:ReadValue("for")
    node.is_local = true

    node.identifiers = self:ReadIdentifierList(1)
    node.tokens["="] = self:ReadValue("=")
    node.expressions = self:ReadExpressionList(3)

    node.tokens["do"] = self:ReadValue("do")
    node.statements = self:ReadStatements({["end"] = true})
    node.tokens["end"] = self:ReadValue("end", node.tokens["do"], node.tokens["do"])

    return node
end

function META:ReadGenericForStatement()
    local node = self:Statement("generic_for")

    node.tokens["for"] = self:ReadValue("for")
    node.is_local = true

    node.identifiers = self:ReadIdentifierList()
    node.tokens["in"] = self:ReadValue("in")
    node.expressions = self:ReadExpressionList()

    node.tokens["do"] = self:ReadValue("do")
    node.statements = self:ReadStatements({["end"] = true})
    node.tokens["end"] = self:ReadValue("end", node.tokens["do"], node.tokens["do"])

    return node
end

function META:ReadFunctionBody(node)
    node.tokens["("] = self:ReadValue("(")
    node.identifiers = self:ReadIdentifierList()

    if self:IsValue("...") then
        local vararg = self:Expression("value")
        vararg.value = self:ReadValue("...")
        table_insert(node.identifiers, vararg)
    end

    node.tokens[")"] = self:ReadValue(")")

    if self:IsValue(":") then
        node.tokens[":"] = self:ReadValue(":")

        local out = {}
        for i = 1, max or self:GetLength() do

            local typ = self:ReadTypeExpression()

            if self:HandleListSeparator(out, i, typ) then
                break
            end
        end

        node.return_types = out
    end

    local start = self:GetToken()
    node.statements = self:ReadStatements({["end"] = true})
    node.tokens["end"] = self:ReadValue("end", start, start)
end

do  -- function
    local function read_function_expression(self)
        local val = self:Expression("value")
        val.value = self:ReadType("letter")

        while self:IsValue(".") or self:IsValue(":") do
            local op = self:GetToken()
            if not op then break end
            self:Advance(1)

            local left = val
            local right = read_function_expression(self)

            val = self:Expression("binary_operator")
            val.value = op
            val.left = val.left or left
            val.right = val.right or right
        end

        return val
    end

    function META:ReadIndexExpression()
        return read_function_expression(self)
    end

    function META:ReadFunctionStatement()
        local node = self:Statement("function")
        node.tokens["function"] = self:ReadValue("function")
        node.expression = read_function_expression(self)

        do -- hacky
            if node.expression.left then
                node.expression.left.upvalue_or_global = node
            else
                node.expression.upvalue_or_global = node
            end

            if node.expression.value.value == ":" then
                node.self_call = true
            end
        end

        self:ReadFunctionBody(node)

        return node
    end
end

function META:ReadLocalFunctionStatement()
    local node = self:Statement("local_function")
    node.tokens["local"] = self:ReadValue("local")
    node.tokens["function"] = self:ReadValue("function")
    node.identifier = self:ReadIdentifier()
    self:ReadFunctionBody(node)
    return node
end

function META:ReadIfStatement()
    local node = self:Statement("if")

    node.expressions = {}
    node.statements = {}
    node.tokens["if/else/elseif"] = {}
    node.tokens["then"] = {}

    for i = 1, self:GetLength() do
        local token

        if i == 1 then
            token = self:ReadValue("if")
        else
            token = self:ReadValues({["else"] = true, ["elseif"] = true, ["end"] = true})
        end

        if not token then return end

        node.tokens["if/else/elseif"][i] = token

        if token.value ~= "else" then
            node.expressions[i] = self:ReadExpectExpression()
            node.tokens["then"][i] = self:ReadValue("then")
        end

        node.statements[i] = self:ReadStatements({["end"] = true, ["else"] = true, ["elseif"] = true})

        if self:IsValue("end") then
            break
        end
    end

    node.tokens["end"] = self:ReadValue("end")

    return node
end


function META:HandleListSeparator(out, i, node)
    if not node then
        return true
    end

    out[i] = node

    if not self:IsValue(",") then
        return true
    end

    node.tokens[","] = self:ReadValue(",")
end

do -- identifier
function META:ReadIdentifier()
        local node = self:Expression("value")

        if self:IsValue("...") then
            node.value = self:ReadValue("...")
        else
            node.value = self:ReadType("letter")
        end

        if self.ReadTypeExpression and self:IsValue(":") then
            node.tokens[":"] = self:ReadValue(":")
            node.type_expression = self:ReadTypeExpression()
        end

        return node
    end

    function META:ReadIdentifierList(max)
        local out = {}

        for i = 1, max or self:GetLength() do
            if (not self:IsType("letter") and not self:IsValue("...")) or self:HandleListSeparator(out, i, self:ReadIdentifier()) then
                break
            end
        end

        return out
    end
end

do -- expression
    function META:ReadAnonymousFunction()
        local node = self:Expression("function")
        node.tokens["function"] = self:ReadValue("function")
        self:ReadFunctionBody(node)
        return node
    end

    function META:ReadTable()
        local tree = self:Expression("table")

        tree.children = {}
        tree.tokens["{"] = self:ReadValue("{")

        for i = 1, self:GetLength() do
            if self:IsValue("}") then
                break
            end

            local node

            if self:IsValue("[") then
                node = self:Expression("table_expression_value")

                node.tokens["["] = self:ReadValue("[")
                node.key = self:ReadExpectExpression()
                node.tokens["]"] = self:ReadValue("]")
                node.tokens["="] = self:ReadValue("=")
                node.expression_key = true
            elseif self:IsType("letter") and self:IsValue("=", 1) then
                node = self:Expression("table_key_value")

                node.key = self:ReadType("letter")
                node.tokens["="] = self:ReadValue("=")
            else
                node = self:Expression("table_index_value")

                node.key = i
            end

            if self:IsValue("...") and (self:IsType("letter", 1) or self:IsValue("{", 1) or self:IsValue("(", 1)) then
                local v = self:Expression("table_spread")
                v.tokens["..."] = self:ReadValue("...")
                v.expression = self:ReadExpectExpression()
                node.value = v
                tree.spread = true
            else
                node.value = self:ReadExpectExpression()
            end

            tree.children[i] = node

            if not self:IsValue(",") and not self:IsValue(";") and not self:IsValue("}") then
                self:Error("expected $1 got $2", nil, nil,  {",", ";", "}"}, (self:GetToken() and self:GetToken().value) or "no token")
                break
            end

            if not self:IsValue("}") then
                node.tokens[","] = self:ReadValues({[","] = true, [";"] = true})
            end
        end

        tree.tokens["}"] = self:ReadValue("}")

        return tree
    end

    function META:ReadExpression(priority, no_ambigious_calls)
        priority = priority or 0

        local node

        if self:IsValue("(") then
            local pleft = self:ReadValue("(")
            node = self:ReadExpression(0, no_ambigious_calls)
            if not node then
                self:Error("empty parentheses group", pleft)
                return
            end

            node.tokens["("] = node.tokens["("] or {}
            table_insert(node.tokens["("], 1, pleft)

            node.tokens[")"] = node.tokens[")"] or {}
            table_insert(node.tokens[")"], self:ReadValue(")"))

        elseif syntax.IsPrefixOperator(self:GetToken()) then
            node = self:Expression("prefix_operator")
            node.value = self:ReadTokenLoose()
            node.right = self:ReadExpression(0, no_ambigious_calls)
        elseif self:IsValue("function") then
            node = self:ReadAnonymousFunction()
        elseif self.ReadImportExpression and self:IsValue("import") and self:IsValue("(", 1) then
            node = self:ReadImportExpression()
        elseif self:IsLSXExpression() then
            node = self:ReadLSXExpression()
        elseif syntax.IsValue(self:GetToken()) or self:IsType("letter") then
            node = self:Expression("value")
            node.value = self:ReadTokenLoose()
        elseif self:IsValue("{") then
            node = self:ReadTable()
        end

        local first = node

        if node then
            for _ = 1, self:GetLength() do
                local left = node
                if not self:GetToken() then break end

                if self:IsValue(".") and self:IsType("letter", 1) then
                    local op = self:ReadTokenLoose()

                    local right = self:Expression("value")
                    right.value = self:ReadType("letter")

                    node = self:Expression("binary_operator")
                    node.value = op
                    node.left = left
                    node.right = right
                elseif self:IsValue(":") then
                    if self:IsType("letter", 1) and (self:IsValue("(", 2) or (not no_ambigious_calls and self:IsValue("{", 2) or self:IsType("string", 2))) then
                        local op = self:ReadTokenLoose()

                        local right = self:Expression("value")
                        right.value = self:ReadType("letter")

                        node = self:Expression("binary_operator")
                        node.value = op
                        node.left = left
                        node.right = right
                    else
                        node.tokens[":"] = self:ReadValue(":")
                        node.type_expression = self:ReadTypeExpression()
                    end
                elseif syntax.IsPostfixOperator(self:GetToken()) then
                    node = self:Expression("postfix_operator")
                    node.left = left
                    node.value = self:ReadTokenLoose()
                elseif self:IsValue("(") then
                    node = self:Expression("postfix_call")
                    node.left = left
                    node.tokens["call("] = self:ReadValue("(")
                    node.expressions = self:ReadExpressionList()
                    node.tokens["call)"] = self:ReadValue(")")

                    if left.value and left.value.value == ":" then
                        node.self_call = true
                    end
                elseif not no_ambigious_calls and (self:IsValue("{") or self:IsType("string")) then
                    node = self:Expression("postfix_call")
                    node.left = left
                    if self:IsValue("{") then
                        node.expressions = {self:ReadTable()}
                    else
                        local val = self:Expression("value")
                        val.value = self:ReadTokenLoose()
                        node.expressions = {val}
                    end
                elseif self:IsValue("[") then
                    node = self:Expression("postfix_expression_index")
                    node.left = left
                    node.tokens["["] = self:ReadValue("[")
                    node.expression = self:ReadExpectExpression()
                    node.tokens["]"] = self:ReadValue("]")
                elseif self:IsValue("as") then
                    node.tokens["as"] = self:ReadValue("as")
                    node.type_expression = self:ReadTypeExpression()
                elseif self:IsValue("is") then
                    node.tokens["is"] = self:ReadValue("is")
                    node.type_expression = self:ReadTypeExpression()
                else
                    break
                end

                if node then
                    node.primary = first
                end
            end
        end

        if first and first.kind == "value" and (first.value.type == "letter" or first.value.value == "...") then
            first.upvalue_or_global = node
        end

        while syntax.IsBinaryOperator(self:GetToken()) and syntax.GetLeftOperatorPriority(self:GetToken()) > priority do
            local op = self:GetToken()
            local right_priority = syntax.GetRightOperatorPriority(op)
            if not op or not right_priority then break end
            self:Advance(1)

            local left = node
            local right = self:ReadExpression(right_priority, no_ambigious_calls)

            node = self:Expression("binary_operator")
            node.value = op
            node.left = node.left or left
            node.right = node.right or right
        end

        return node
    end

    function META:ReadExpectExpression(priority, no_ambigious_calls)
        if syntax.IsDefinetlyNotStartOfExpression(self:GetToken()) then
            self:Error("expected beginning of expression, got $1", nil, nil, self:GetToken() and self:GetToken().value ~= "" and self:GetToken().value or self:GetToken().type)
            return
        end

        return self:ReadExpression(priority, no_ambigious_calls)
    end

    function META:ReadExpressionList(max)
        local out = {}

        for i = 1, max or self:GetLength() do
            local exp = max and self:ReadExpectExpression() or self:ReadExpression()

            if self:HandleListSeparator(out, i, exp) then
                break
            end
        end

        return out
    end

    function META:IsLSXExpression()
        return self:IsValue("[") and self:IsType("letter", 1)
    end

    function META:ReadLSXStatement()
        return self:ReadLSXExpression(true)
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

return require("oh.parser")(META, require("oh.lua.syntax"), require("oh.lua.emitter"))