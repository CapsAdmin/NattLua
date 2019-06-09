local oh = ...
local table_remove = table.remove
local ipairs = ipairs

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


function META:Emit(str)
    if type(str) ~= "string" then
        for k,v in pairs(str) do print(k,v) end
        print(debug.traceback())
    end
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
    return prev and oh.syntax.GetCharacterType(prev:sub(-1))
end

function META:EmitToken(v, translate)
    if v and v.whitespace then
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

        if self.FORCE_INTEGER then
            if v.type == "number" then
                self:Emit("LL")
            end
        end
    end
end

function META:BuildCode(block)
    self.level = 0
    self.out = {}
    self.i = 1

    self:Block(block)

    return table.concat(self.out)
end

function META:Expression(v)
    if v.attributes then
        self:Emit("oh.attributes(")
    end

    if v.tokens["left("] then
        for _, v in ipairs(v.tokens["left("]) do
            self:EmitToken(v)
        end
    end

    if v.type == "operator" then
        local func_name = oh.syntax.GetFunctionForOperator(v.tokens["operator"])
        if func_name then
            self:Emit(" " .. func_name .. "(")
            if v.left then self:Expression(v.left) end
            self:Emit(",")
            if v.right then self:Expression(v.right) end
            self:Emit(") ")
        else
            if v.left then self:Expression(v.left) end
            self:Operator(v)
            if v.right then self:Expression(v.right) end
        end
    elseif v.type == "function" then
        self:Function(v)
    elseif v.type == "list" then
        self:List(v)
    elseif v.type == "table" then
        self:Table(v)
    elseif v.type == "unary" then
        self:Unary(v)
    elseif v.type == "value" then
        if v.annotation then
            self:Emit("oh.number_postfix(")
            self:EmitToken(v.value)
            self:Emit(",'")
            self:EmitToken(v.annotation)
            self:Emit("'")
            self:Emit(")")
        else
            self:EmitToken(v.value)
        end
    elseif v.type == "lsx" then
        self:LSX(v)
    elseif v.type == "lsx2" then
        self:LSX2(v)
    elseif v.type == "struct" then
        self:Struct(v)
    else
        error("unhandled token type " .. v.type)
    end

    if v.tokens["right)"] then
        for _, v in ipairs(v.tokens["right)"]) do
            self:EmitToken(v)
        end
    end

    if v.suffixes then
        for _, node in ipairs(v.suffixes) do
            if node.type == "index" then
                self:EmitToken(node.tokens["."])
                self:EmitToken(node.value.value)
            elseif node.type == "self_index" then
                self:EmitToken(node.tokens[":"])
                self:EmitToken(node.value.value)
            elseif node.type == "index_expression" then
                self:EmitToken(node.tokens["["])
                self:Expression(node.value)
                self:EmitToken(node.tokens["]"])
            elseif node.type == "call" then
                if node.tokens["call("] then
                    self:EmitToken(node.tokens["call("])
                end
                self:ExpressionList(node.arguments)

                if node.tokens["call)"] then
                    self:EmitToken(node.tokens["call)"])
                end
            end
        end
    end

    if v.attributes then
        self:Emit(",")

        for _, attr in ipairs(v.attributes) do
            print(attr)
            self:Emit("{'")
            self:EmitToken(attr.name)
            self:Emit("'")
            if attr.arguments then
                self:Emit(",")
                self:ExpressionList(attr.arguments)
            end
            self:Emit("}")
            if _ ~= #v.attributes then
                self:Emit(",")
            end
        end
        self:Emit(")")
    end
end


function META:LSX2(node)
    self:Emit(" oh.lsx(")

    self:Emit("'")self:Emit(node.class.value)self:Emit("'")
    self:Emit(",")

    self:Emit("{")
    for i, prop in ipairs(node.props) do
        self:Expression(prop.key)
        self:EmitToken(prop.tokens["="])
        self:Expression(prop.expression)
        if i ~= #node.props then
            self:Emit(",")
        end
    end
    self:Emit("}")

    self:Emit(",")

    self:Emit("{")

    for _, child in ipairs(node.children) do
        self:Expression(child)
        self:Emit(",")
    end
    self:Emit("}")

    self:Emit(")")
end

function META:LSX(node)
    self:Emit(" oh.lsx(")

    self:Emit("'")self:EmitToken(node.class)self:Emit("'")
    self:Emit(",")

    if node.props then
        self:Emit("{")
        for i, prop in ipairs(node.props) do
            self:EmitToken(prop.key)
            self:EmitToken(prop.tokens["="])

            if prop.expression then
                self:Expression(prop.expression)
            else
                self:EmitToken(prop.value)
            end

            if i ~= #node.props then
                self:Emit(",")
            end
        end
        self:Emit("}")
    else
        self:Emit("nil")
    end

    if node.children[1] then
        self:Emit(",")
        self:Emit("{")

        local max = #node.children
        for i, child in ipairs(node.children) do
            if child.tokens then
                self:Expression(child)
            else
                self:Emit("[[")
                self:EmitToken(child)
                if i == max then
                    self:EmitToken(node.tokens["stop<"], "") -- emit the whitespce from <
                end
                self:Emit("]]")
            end
            self:Emit(",")
        end
        self:Emit("}")
    end

    self:Emit(")")
end

function META:Operator(v)
    self:EmitToken(v.tokens.operator)
end

function META:Function(v)
    self:Whitespace("\t")

    if v.is_local then
        self:EmitToken(v.tokens["local"], "local")
    end

    self:EmitToken(v.tokens["function"], "function")
    self:Whitespace(" ")

    if v.value then
        self:Expression(v.value)
    end

    self:EmitToken(v.tokens["func("], "(")
    do
        local tbl = v.arguments
        for i = 1, #tbl do
            if tbl[i].destructor then
                self:Emit("__DSTR" .. i)
            else
                self:Expression(tbl[i])
            end
            if i ~= #tbl then
                self:EmitToken(tbl[i].tokens[","])
                self:Whitespace(" ")
            end
        end
        self:EmitToken(v.tokens["func)"], ")")
        for i = 1, #tbl do
            if tbl[i].destructor then
                self:Emit("local ")
                for i2,v in ipairs(tbl[i].destructor) do
                    self:Expression(v)
                    if i2 ~= #tbl[i].destructor then
                        self:Emit(",")

                    end
                end
                self:Emit("=")
                for i2,v in ipairs(tbl[i].destructor) do
                    self:Emit("__DSTR" .. i)
                    self:Emit(".")
                    self:Expression(v)
                    if i2 ~= #tbl[i].destructor then
                        self:Emit(",")
                    else
                        self:Emit(";")
                        self:Emit("__DSTR" .. i .. "=nil;")
                    end
                end
            end
        end
    end

    if v.return_types then
        for _,args in ipairs(v.return_types) do
            for _,v in ipairs(args) do
                self:Emit(" --[[")
                self:Emit(table.concat(v, ", "))
                self:Emit("]]")
            end
        end
    end

    self:Whitespace("\n")
        self:Whitespace("\t+")
            self:Block(v.block)
        self:Whitespace("\t-")
    self:Whitespace("\t")
    if v.no_end then
        self:Emit(" end")
    else
        self:EmitToken(v.tokens["end"])
    end

    if v.async then
        self:Emit(";") self:Expression(v.value) self:Emit("=")self:Emit("async(") self:Expression(v.value) self:Emit(")")
    end
end

function META:List(v)
    self:EmitToken(v.tokens["["], "oh.list(")
    for _, val in ipairs(v.values) do
        self:Expression(val.expr)
        if val.tokens[","] then
            self:EmitToken(val.tokens[","])
        end
    end
    self:EmitToken(v.tokens["]"], ")")
end

function META:Table(v)
    if not v.children[1] then
        self:EmitToken(v.tokens["{"])self:EmitToken(v.tokens["}"])
    else
        self:EmitToken(v.tokens["{"])self:Whitespace("\n")
            self:Whitespace("\t+")
            for _,v in ipairs(v.children) do
                self:Whitespace("\t")
                if v.type == "table_index_value" then
                    self:Expression(v.value)
                elseif v.type == "table_key_value" then
                    self:Expression(v.key)
                    if v.tokens["="] then
                        self:EmitToken(v.tokens["="])
                        self:Expression(v.value)
                    else
                        self:Emit(" = nil")
                    end
                elseif v.type == "table_expression_value" then

                    self:EmitToken(v.tokens["["])
                    self:Whitespace("(")
                    self:Expression(v.key)
                    self:Whitespace(")")
                    self:EmitToken(v.tokens["]"])

                    self:EmitToken(v.tokens["="])

                    self:Expression(v.value)
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

function META:Struct(v)
    self:Emit("oh.struct({")
    for _, v in ipairs(v.values) do
        self:Emit("{'")
        self:Emit(v.value.value)
        self:Emit("',")
        self:EmitToken(v.data_type[1].value)
        self:Emit("},")
    end
    self:Emit("})")
end

function META:Unary(v)
    local func_name = oh.syntax.GetFunctionForUnaryOperator(v.tokens["operator"])
    if func_name then
        self:Emit(" " .. func_name .. "(")
        self:Expression(v.expression)
        self:Emit(") ")
    else
        if oh.syntax.IsKeyword(v.operator) then
            self:EmitToken(v.tokens.operator, "")
            self:Whitespace("?", true)
            self:Emit(v.operator)
            self:Expression(v.expression)
        else
            if v.tokens["("] and v.tokens.operator.start > v.tokens["("].start then
                if v.tokens["("] then self:EmitToken(v.tokens["("]) end
                self:EmitToken(v.tokens.operator)
            else
                self:EmitToken(v.tokens.operator)
                if v.tokens["("] then self:EmitToken(v.tokens["("]) end
            end

            self:Expression(v.expression)

            if v.tokens[")"] then self:EmitToken(v.tokens[")"]) end
        end
    end
end

local function emit_block_with_continue(self, data, repeat_expression)
    if data.has_continue and data.block[#data.block] and data.block[#data.block].type == "return" then
        local ret = table_remove(data.block)
        self:Block(data.block)

        self:Whitespace("\t")self:EmitToken(ret["return"], "")self:Emit("do return")self:Whitespace("?", true)
        if ret.expressions then
            self:ExpressionList(ret.expressions)
        end
        self:Whitespace("?", true)
        self:Emit("end")
    else
        self:Block(data.block)
    end

    if not repeat_expression and data.has_continue then
        self:Whitespace("\t")self:Emit("::continue__oh::")
    end
end

function META:Block(block)
    for _, data in ipairs(block.statements) do
        if data.type == "if" then
            for _,v in ipairs(data.clauses) do
                self:Whitespace("\t")self:EmitToken(v.tokens["if/else/elseif"]) if v.condition then self:Expression(v.condition) self:Whitespace(" ") self:EmitToken(v.tokens["then"]) end self:Whitespace("\n")
                self:Whitespace("\t+")
                    self:Block(v.block)
                self:Whitespace("\t-")
            end
            self:Whitespace("\t") self:EmitToken(data.tokens["end"])
        elseif data.type == "goto" then
            self:Whitespace("\t") self:EmitToken(data.tokens["goto"]) self:Whitespace(" ") self:Expression(data.label)
        elseif data.type == "goto_label" then
            self:Whitespace("\t") self:EmitToken(data.tokens["::left"]) self:Expression(data.label) self:EmitToken(data.tokens["::right"])
        elseif data.type == "while" then
            self:Whitespace("\t")self:EmitToken(data.tokens["while"])self:Expression(data.expression)self:Whitespace("?")self:EmitToken(data.tokens["do"])self:Whitespace("\n")
                self:Whitespace("\t+")
                    emit_block_with_continue(self, data)
                self:Whitespace("\t-")
            self:Whitespace("\t")self:EmitToken(data.tokens["end"])
        elseif data.type == "repeat" then
            if data.has_continue then
                self:Whitespace("\t")self:EmitToken(data.tokens["repeat"], "while true do --[[repeat]]")self:Whitespace("\n")
                    self:Whitespace("\t+")
                        emit_block_with_continue(self, data, true)
                    self:Whitespace("\t-")
                self:Whitespace("\t") self:EmitToken(data.tokens["until"],"")
                self:Emit("if--[[until]](") self:Expression(data.condition) self:Emit(")then break end") self:Emit("::continue__oh::end")
            else
                self:Whitespace("\t")self:EmitToken(data.tokens["repeat"])self:Whitespace("\n")
                    self:Whitespace("\t+")
                        emit_block_with_continue(self, data)
                    self:Whitespace("\t-")
                self:Whitespace("\t") self:EmitToken(data.tokens["until"])self:Expression(data.condition)
            end
        elseif data.type == "break" then
            self:Whitespace("\t")self:EmitToken(data.tokens["break"])
        elseif data.type == "return" then
            self:Whitespace("\t")
            self:Whitespace("?")
            if data.implicit then
                self:Emit(" return ")
            else
                self:EmitToken(data.tokens["return"])
            end

            if data.expressions then
                self:ExpressionList(data.expressions)
            end
        elseif data.type == "continue" then
            self:Whitespace("\t")self:Whitespace("?") self:EmitToken(data.tokens["continue"], "goto continue__oh")
        elseif data.type == "for_i" or data.type == "for_kv" then
            self:Whitespace("\t")

            if data.of then
                --for __curindex = 1, object.iterate_length(list) do
                    --local v,i = list:__iterate_index(__curindex)

                self:Emit(" local __iterobject = ")
                self:ExpressionList(data.expressions)

                self:EmitToken(data.tokens["for"])
                self:Emit(" ")
                self:Emit("__curindex = 1, object.iterate_length(__iterobject)")

            elseif data.type == "for_i" then
                self:EmitToken(data.tokens["for"])
                self:EmitToken(data.identifier.value)
                self:Whitespace(" ")
                self:EmitToken(data.tokens["="])
                self:Whitespace(" ")
                self:Expression(data.expression)
                self:EmitToken(data.tokens[",1"])
                self:Whitespace(" ")
                self:Expression(data.max)
                if data.step then
                    self:EmitToken(data.tokens[",2"])self:Whitespace(" ")self:Expression(data.step)
                end
            else
                self:EmitToken(data.tokens["for"])
                self:Whitespace("?")
                self:ExpressionList(data.identifiers)
                self:Whitespace("?")
                self:EmitToken(data.tokens["in"])
                self:Whitespace("?")
                self:ExpressionList(data.expressions)
            end

            self:Whitespace("?")self:EmitToken(data.tokens["do"])self:Whitespace("\n")
                self:Whitespace("\t+")

                    if data.of then
                        self:Emit(" local ")
                        self:ExpressionList(data.identifiers)
                        self:Emit(" = __iterobject:__iterate_index(__curindex)")
                    end

                    emit_block_with_continue(self, data)
                self:Whitespace("\t-")
            self:Whitespace("\t")self:EmitToken(data.tokens["end"])

        elseif data.type == "do" then
            self:Whitespace("\t")self:EmitToken(data.tokens["do"])self:Whitespace("\n")
                self:Whitespace("\t+")
                    self:Block(data.block)
                self:Whitespace("\t-")
            self:Whitespace("\t")self:EmitToken(data.tokens["end"])
        elseif data.type == "assignment" then
            self:Whitespace("\t") if data.is_local then self:EmitToken(data.tokens["local"], "local")self:Whitespace(" ") end

            for i,v in ipairs(data.lvalues) do
                if data.is_local or data.destructor then
                    if v.destructor then
                        self:EmitToken(v.tokens["{"], "")
                        self:ExpressionList(v.destructor)
                    else
                        self:EmitToken(v.value)
                    end
                else
                    self:Expression(v)
                end
                if data.lvalues[2] and i ~= #data.lvalues then
                    self:EmitToken(v.tokens[","])self:Whitespace(" ")
                end

                if v.value_type then
                    self:Emit(" --[[")
                    self:Emit(table.concat(v.value_type, ", "))
                    self:Emit("]]")
                end

                if v.attributes then
                    self:Emit(";")
                    self:Emit("oh.attributes(")
                    self:EmitToken(v.value)

                    self:Emit(",")

                    for _, attr in ipairs(v.attributes) do
                        print(attr)
                        self:Emit("{'")
                        self:EmitToken(attr.name)
                        self:Emit("'")
                        if attr.arguments then
                            self:Emit(",")
                            self:ExpressionList(attr.arguments)
                        end
                        self:Emit("}")
                        if _ ~= #v.attributes then
                            self:Emit(",")
                        end
                    end
                    self:Emit(")")

                    self:EmitToken(v.value)
                end
            end

            if data.rvalues then
                self:Whitespace(" ")self:EmitToken(data.tokens["="])self:Whitespace(" ")

                for i,v in ipairs(data.rvalues) do
                    if data.lvalues[i] and data.lvalues[i].destructor then
                        for i2,v2 in ipairs(data.lvalues[i].destructor) do
                            self:Emit("(")
                            self:Expression(v)
                            self:Emit(").")
                            self:EmitToken(v2.value)
                            if i2 ~= #data.lvalues[i].destructor then
                                self:Emit(",")
                            end
                        end
                    else
                        self:Expression(v)
                    end

                    if data.rvalues[2] and i ~= #data.rvalues then
                        self:EmitToken(v.tokens[","])self:Whitespace(" ")
                    end
                end

                for i in ipairs(data.rvalues) do
                    if data.lvalues[i] and data.lvalues[i].destructor then
                        for _,v2 in ipairs(data.lvalues[i].destructor) do
                            if v2.default then
                                self:Emit(" ")
                                self:EmitToken(v2.value)
                                self:Emit("=")
                                self:EmitToken(v2.value)
                                self:Emit("~=nil and ")
                                self:EmitToken(v2.value)
                                self:Emit(" or ")
                                self:Expression(v2.default)
                                self:Emit(";")
                            end
                        end
                    end
                end
            end
        elseif data.type == "function" then
            self:Function(data)
        elseif data.type == "expression" then
            self:Expression(data.value)
        elseif data.type == "call" then
            self:Whitespace("\t")self:Expression(data.value)
        elseif data.type == "end_of_statement" then
            self:EmitToken(data.tokens[";"])
        elseif data.type == "end_of_file" then
            self:EmitToken(data.tokens["end_of_file"])
        elseif data.type == "shebang" then
            self:EmitToken(data.tokens["shebang"])
        elseif data.type == "interface" then
            self:Emit("-- interface TODO")
        elseif data.type == "struct" then
            self:StructStatement()
        elseif data.type == "compiler_option" then
            self:Emit("--" .. data.lua)

            if data.lua:sub(1, 2) == "E:" then
                assert(loadstring("local self = ...;" .. data.lua:sub(3)))(self)
            end
        else
            error("unhandled value: " .. data.type)
        end

        self:Whitespace("\n")
    end
end

function META:ExpressionList(tbl)
    for i = 1, #tbl do
        self:Expression(tbl[i])
        if i ~= #tbl then
            self:EmitToken(tbl[i].tokens[","])
            self:Whitespace(" ")
        end
    end
end

function oh.LuaEmitter()
    return setmetatable({}, META)
end