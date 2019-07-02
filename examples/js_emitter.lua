local oh = require("oh.oh")
local util = require("oh.util")
local code = io.open("examples/scimark.lua"):read("*all")

local token_translate = {
    ["and"] = "&&",
    ["or"] = "||",
    ["do"] = "{",
    ["~="] = "!=",
    ["not"] = "!",
    ["else"] = "} else {",
    ["elseif"] = "} else if ",
    ["then"] = "{",
    ["end"] = "}",
    ["in"] = "of",
    [".."] = "+",
    ["=="] = "===",
    ["~"] = "^",
}

local meta_methods = {
    prefix = {
        __unm = "-",
        __bnot = "~",
        __len = {
            op = "#",
            code = "v.length"
        }
    },
    postfix = {
        __addadd = "++",
    },
    binary = {
        __add = "+",
        __sub = "-",
        __mul = "*",
        __div = "/",

        __band = "&",
        __bor = "|",
        __shl = "<<",
        __shr = ">>",


        __index = {
            op = ".",
            code = "l[r]",
        },
        __concat = {
            op =  "..",
            code = "l+r"
        },
        __idiv = {
           op =  "//",
           code = "Math.floor(l/r)"
        },
        __pow = {
            op =  "^",
            code = "Math.pow(l, r)"
        },
        __mod = {
            op =  "%",
            code = "l%%r"
        },
        __bxor = {
            op =  "~",
            code = "l^r",
        },
    },
}

local operator_translate = {
    ["."] = {
        name = "__index",
    },
    [":"] = {
        name = "self_index",
    },
}

for what, operators in pairs(meta_methods) do
    for name, data in pairs(operators) do
        local op
        local exp

        if type(data) == "string" then
            op = data
            if what == "prefix" then
                exp = data .. " v"
            elseif what == "postfix" then
                exp = "v " .. data
            elseif what == "binary" then
                exp = "r " .. data .. " l"
            end
        else
            op = data.op
            exp = data.code
        end

        local code

        if what == "binary" then
            code = [[
                "NAME": (l, r) => {
                    if (m[l] && m[l].NAME) {
                        return m[l].NAME(l, r)[0]
                    }
                    return EXPRESSION;
                },
                "raw_NAME": (l, r) => { return EXPRESSION; },
            ]]
        else
            code = [[
                "NAME": (v) => {
                    if (m[v] && m[v].NAME) {
                        return m[v].NAME(v)[0]
                    }
                    return EXPRESSION;
                },
                "raw_NAME": (v) => { return EXPRESSION; },
            ]]
        end

        code = code:gsub("NAME", name)
        code = code:gsub("EXPRESSION", exp)

        meta_methods[what][name] = {
            op = op,
            code = code,
            name = name,
        }

        operator_translate[op] = meta_methods[what][name]
    end
end

local runtime = [[
    let _G = {}
    _G._G = _G
    _G.math = Math

    _G.print = console.log
    _G.math = Math
    _G.os = {
        clock: () => { return new Date().getTime() / 1000 },
        exit:(num) => {process.exit(num);},
    }
    _G.string = {format: function(fmt, ...args) { return fmt; }}
    _G.jit = {status: function() { return [true]; }}
    _G.bit = {

    }

    let VARARG = {}

    _G.table = {
        unpack: function(a) {return [VARARG, ...a];},
    }
    _G.io = {
        write: (...args) => { console.log(...args); },
        flush: () => {},
        stderr: {
            write: (self, ...args) => { console.log(...args); },
        }
    }

    _G.pcall = (func, ...args) => {
        try {
            return [true, func(...args)]
        } catch(e) {
            return [undefined, e]
        }
    }

    _G.require = (str) => {
        throw str + " " + "not found!"
        //console.log("REQUIRE: " + str)
    }

    function* ipairs(o) {
        if (typeof o === "object") {
            for (let i = 1; i < Infinity; i++) {
                let val = o[i.toString()]
                if (!val)
                    break

                yield [ i, val ];
            }
        } else {
            for (let i = 1; i < o.length; i++) {
                yield [ i, o[i] ];
            }
        }
    }

    function* pairs(o) {
        let keys = Object.keys(o);
        for (let i = 0; i < keys.length; i++) {
            yield [ keys[i], o[ keys[i] ] ];
        }
    }

    _G.ipairs = ipairs
    _G.pairs = pairs

    let OH
    {
        let m = {}

        _G.setmetatable = (tbl, meta) => {
            m[tbl] = meta
            return tbl
        }

        let last_self = undefined

        OH = {
            self_index: (l, r) => {
                last_self = l
                if (m[l] && m[l].__index) {
                    return m[l].__index(l, r)[0]
                }
                return l[r]
            },
            get_global: (a) => {
                return _G[a]
            },
            __newindex: (obj, key, val) => {
                if (m[obj] && m[obj].__newindex) {
                    return m[obj].__newindex(obj, key, val)
                }
                obj[key] = val
            },
            call: function(a, ...args) {
                if (last_self) {
                    args.unshift(last_self)
                    last_self = undefined
                }

                if (args[0] && args[0][0] == VARARG) {
                }

                return a(...args)
            },
            ]] .. (function()
                local js = ""

                for name, info in pairs(meta_methods.binary) do
                    js = js .. info.code
                end
                for name, info in pairs(meta_methods.prefix) do
                    js = js .. info.code
                end

                for name, info in pairs(meta_methods.postfix) do
                    js = js .. info.code
                end

                return js
            end)() ..
            [[
        }
    }

    ////////
]]

code = [===[

do
    local tbl = {}
    setmetatable(tbl, {
        __index = function(self, str)
            if str == "foo" then
                return function()
                    print("foo!")
                    return "aaa",1,2
                end
            end
            return true
        end
    })

    local a,b,c = tbl:foo(1,2,3)

    print(a,b,c)
end

do
    local a = {b = {c = 999}}
    b = a.b.c + 1 / 2
    lol = a
    print(b)
end

do
    print(_G.b)
end

for i = 1, 10 do
    print(i)
end

do
    local a,b,c = 1,2,3
    print(a,b,c)
end

do
    lol.b.c = 1337
    print(lol.b.c)

    a = 1
    print(a)
    a = 2
    print(a)
end

do
    local foo = {lol=1}

    function foo.bar(self, n)
        print(self, n)
    end

    foo:bar("hello")
end


do
    local foo = {lol=1}

    function foo:bar(n)
        print(self, n)
    end

    foo:bar("hello")
end

local aaaa

do

    function aaaa(n) return os.clock() end
    print(aaaa, aaaa())
end

do
    local b = 1
    local a = a or b or 1
    print(a, "!")
end

do
    local a = {1,2,3}
    print(1 / #a)
end

do
    print(jit.status)
    print(jit.status and jit.status)
end

do
    local tbl = {1,2,3}
    for i,v in ipairs(tbl) do
        print(i,v)
    end
end

do
    local tbl = {foo = true, bar = false, baz = "lol"}
    for k,v in pairs(tbl) do
        print(k,v)
    end
end

do
    local tbl = {1,2,3, foo = true, bar = false, baz = "lol"}
    for k,v in ipairs(tbl) do
        print(k,v)
    end

    for k,v in pairs(tbl) do
        print(k,v)
    end
end

do
    local function test(...)
        local a,b,c =...
        print(a,b,c)
    end

    local func = function(a,b,c, ...)
        print(a,b,c)
        local foo, bar, faz = ...
        print(foo, bar, faz)
        return test(...)
    end

    func(1,2,3, "foo", "bar", "faz")
end

do
    local ok, ffi = pcall(require, "ffi")
    print(ok, ffi)
end

do
    local n = 1024
    local abs, log, sin, floor = math.abs, math.log, math.sin, math.floor
    local l2n = log(n)/log(2)
    if l2n % 1 ~= 0 then
      io.stderr:write("Error: FFT data length is not a power of 2\n")
      os.exit(1)
    end
end

do
    local tbl = {
        foo = {1,2,3},
        bar = {4,5,6},
    }

    local function test(a,b,c)
        print(a,b,c)
    end

    test(1, table.unpack(tbl.foo))
end

]===]

--loadstring(code)()


local keywords = {
    let = true,
    new = true,
    try = true,
    var = true,
    case = true,
    enum = true,
    eval = true,
    null = true,
    this = true,
    void = true,
    with = true,
    await = true,
    catch = true,
    class = true,
    const = true,
    super = true,
    throw = true,
    yield = true,
    delete = true,
    export = true,
    import = true,
    public = true,
    static = true,
    switch = true,
    typeof = true,
    default = true,
    extends = true,
    finally = true,
    package = true,
    private = true,
    continue = true,
    debugger = true,
    arguments = true,
    interface = true,
    protected = true,
    implements = true,
    instanceof = true,
}

local ast = assert(oh.TokensToAST(assert(oh.CodeToTokens(code)), nil,  code))
--util.TablePrint(ast)
local em = oh.LuaEmitter()
do
    local META = getmetatable(em)

    function META:DeclareIdentifier(str) do return str end
        for i = 1, 100 do
            if self:GetUpvalue(str) or keywords[str] then
                str = str .. "$"
            else
                break
            end
        end
        return str
    end

    function META:PushScope()
        local scope = {children = {}, parent = self.scope, upvalues = {}}
        if self.scope then
            for k,v in pairs(self.scope.upvalues) do
                scope.upvalues[k] = v
            end
            table.insert(self.scope.children, scope)
        end
        self.scope = scope
    end

    function META:SetUpvalue(key, val)
        self.scope.upvalues[key] = val
    end

    function META:GetUpvalue(key)
        return self.scope.upvalues[key]
    end

    function META:PopScope()
        local scope = self.scope.parent
        if scope then
            self.scope = scope
        end
    end

    function META:GetScope()
        return self.scope
    end

    function META:NoSpace()
        self.suppress_space = true
    end

    function META:PushSpace()
        self.push_space = {}
    end

    function META:EmitWhitespace(whitespace)
        for _, data in ipairs(whitespace) do
            if data.type == "line_comment" then
                self:Emit("//" .. data.value:sub(2))
            elseif data.type == "multiline_comment" then
                self:Emit("/*" .. data.value:sub(2) .. "*/")
            elseif data.type ~= "space" or self.PreserveWhitespace then
                self:Emit(data.value)
            end
        end
    end

    function META:PopSpace(when)
        if when then
            self.space_pop = self.space_pop or {}

            table.insert(self.space_pop, {when = when, space = self.push_space})
            return
        end
        if not self.push_space then return end
        for _, whitespace in ipairs(self.push_space) do
            self:EmitWhitespace(whitespace)
        end
        self.push_space = nil
    end

    function META:Emit(str) assert(type(str) == "string")
        self.out[self.i] = str or ""
        self.i = self.i + 1

        if self.space_pop and self.space_pop[1] then
            for i = #self.space_pop, 1, -1 do
                if self.space_pop[i].when == str then
                    local data = table.remove(self.space_pop)
                    for _, whitespace in ipairs(data.space) do
                        self:EmitWhitespace(whitespace)
                    end
                end
            end
        end
    end

    function META:EmitToken(v, translate)
        if v.whitespace then
            if self.suppress_space then
                self.suppress_space = nil
            elseif self.push_space then
                table.insert(self.push_space, v.whitespace)
            else
                self:EmitWhitespace(v.whitespace)
            end
        end

        if translate then
            if type(translate) == "table" then
                self:Emit(translate[v.value] or v.value)
            elseif translate ~= "" then
                self:Emit(translate)
            end
        else
            if keywords[v.value] then
                v.value = "_" .. v.value
            end

            if v.value == "nil" then
                v.value = "undefined"
            end

            self:Emit(v.value)
        end
    end

    local function transform(v)
        local ops = v:Flatten()
        for i, node in ipairs(ops) do
            if node.kind == "value" then
                local prev = ops[i - 1]
                if node.value.type == "letter" then
                    if prev and prev.right == node then
                        node.index = true
                    else
                        node.upvalue = true
                    end
                end
            end
        end
    end

    function META:EmitExpression(v, index)
        if v.kind == "binary_operator" then
            transform(v)

            if operator_translate[v.value.value] then
                local name = operator_translate[v.value.value].name

                self:Emit("OH."..name.."(")

                if v.right.kind == "postfix_call" then
                    self:EmitExpression(v.right)
                    self:Emit(",")
                    self:EmitExpression(v.left)
                else

                    if v.left then
                        self:EmitExpression(v.left)
                    end
                    self:Emit(",")
                    if v.right then
                        self:EmitExpression(v.right)
                    end
                end

                self:Emit(")")
            else
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
                    self:EmitBinaryOperator(v, v.left)
                    if v.right then self:EmitExpression(v.right) end
                end
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
            self.during_call = true
            self:Emit("OH.call(")

            transform(v.left)
            self:EmitExpression(v.left)
            self:Emit(",")

            if v.kind == "postfix_call" and not v.tokens["call("] then
                v.expressions[1].parenthesise_me = true
            end

            if v.tokens["call("] then
                --self:EmitToken(v.tokens["call("])
            end


            for _, exp in ipairs(v.expressions) do
                transform(exp)
            end

            self:EmitExpressionList(v.expressions)

            self:Emit(")")

            self.during_call = false

            if v.tokens["call)"] then
                --self:EmitToken(v.tokens["call)"])
            end
        elseif v.kind == "postfix_expression_index" then
            self:EmitExpression(v.left)
            self:EmitToken(v.tokens["["])
            self:EmitExpression(v.expression)
            self:EmitToken(v.tokens["]"])
        elseif v.kind == "value" then


            if v.value.type == "number" then
                if v.value.value:sub(-3):lower() == "ull" then
                    v.value.value = v.value.value:sub(1, #v.value.value - 3)
                elseif v.value.value:sub(-3):lower() == "ul" or v.value.value:sub(-3):lower() == "ll" then
                    v.value.value = v.value.value:sub(1, #v.value.value - 2)
                elseif v.value.value:sub(-3):lower() == "i" then
                    v.value.value = v.value.value:sub(1, #v.value.value - 1)
                end
                self:EmitToken(v.value)
            elseif v.value.value == "..." then
                if self.during_call then
                    self:EmitToken(v.value, "...LUA_ARGS")
                else
                    self:EmitToken(v.value, "LUA_ARGS")
                end
            elseif v.value.type == "string" and v.value.value:sub(1,1) == "[" then
                self:EmitToken(v.value, v.value.value:gsub("\\", "\\\\"):gsub("`", "\\`"):gsub("^%[=-%[(.+)%]=-%]$", "`%1`"))
            else
                if v.index then
                    self:Emit('"')
                    self:Emit(v.value.value)
                    self:Emit('"')
                elseif v.upvalue and not self:GetUpvalue(v.value.value) then
                    self:Emit('OH.get_global("')
                    self:Emit(v.value.value)
                    self:Emit('")')
                else
                    self:EmitToken(v.value)
                end
            end
        else
            error("unhandled token type " .. v.kind)
        end

        if v.parenthesise_me then
            self:Emit(")")
        end

        if v.tokens[")"] then
            for _, v in ipairs(v.tokens[")"]) do
                --self:EmitToken(v)
            end
        end
    end

    function META:EmitBinaryOperator(v, left)
        if v.value.value == ":" then
            self:EmitToken(v.value, ".")
        elseif v.value.value == "." then
            self:EmitToken(v.value)
        else
            self:Whitespace(" ")
            self:EmitToken(v.value, token_translate[v.value.value])
            self:Whitespace(" ")
        end
    end

    do
        function META:EmitFunction(node, anon)
            self.SELF_INDEX = false
            local table_assign = false

            if anon then
                self:EmitToken(node.tokens["function"])
            elseif node.is_local then
                self:Whitespace("\t")
                self:EmitToken(node.tokens["local"], "")
                self:Whitespace(" ")
                self:EmitToken(node.tokens["function"], "")
                self:Emit("let")
                self:Whitespace(" ")
                node.name.value.value = self:DeclareIdentifier(node.name.value.value)
                self:EmitExpression(node.name)
                self:SetUpvalue(node.name.value.value, true)
                self:Emit(" = function")
            else
                table_assign = true
                self:Whitespace("\t")
                --self:Emit("OH.__newindex(")
                self:EmitToken(node.tokens["function"], "") -- emit white space only

                if node.expression.right then
                    self:Emit("OH.__newindex(")
                    self:EmitExpression(node.expression.left)
                    self:Emit(", ")

                    if not node.expression.right.transformed then
                        node.expression.right.value.value = "'" .. node.expression.right.value.value .. "'"
                        node.expression.right.transformed = true
                    end

                    self:EmitExpression(node.expression.right)

                    local last
                    for l,op,r in node.expression:Walk() do
                        last = op
                    end
                    if last and last.value.value == ":" then
                        self.SELF_INDEX = true
                    end

                    --self:EmitExpression(node.expression)
                    self:Whitespace(" ")
                    self:Emit(", function")
                else
                    if self:GetUpvalue(node.expression.value.value) then
                        self:EmitExpression(node.expression)
                        self:Emit(" = function")
                        table_assign = false
                    else
                        self:Emit("OH.__newindex(")
                        self:Emit("'")
                        self:EmitExpression(node.expression)
                        self:Emit("'")
                    end
                end
            end

            self:EmitToken(node.tokens["("])
            if self.SELF_INDEX and not node.is_local then
                self:DeclareIdentifier("self")
                self:Emit("self, ")
                self.SELF_INDEX = false
            end

            if node.identifiers then
                for i,v in ipairs(node.identifiers) do
                    self:SetUpvalue(v.value.value, true)
                end
            end

            self:PushScope()

            for i,v in ipairs(node.identifiers) do
                v.value.value = self:DeclareIdentifier(v.value.value)
                if v.value.value == "..." then
                    v.value.value = "...LUA_ARGS"
                end
            end

            self:EmitExpressionList(node.identifiers)
            self:EmitToken(node.tokens[")"])

            self:Emit(" {")

            self:Whitespace("\n")
            self:Whitespace("\t+")
            self:EmitStatements(node.statements)
            self:PopScope()
            self:Whitespace("\t-")

            self:Whitespace("\t")
            self:EmitToken(node.tokens["end"], token_translate["end"])

            if table_assign then
                self:Emit(")")
            end
        end
    end

    function META:EmitTable(v)
        local array_open = nil
        local array_close = nil

        if not v.children[1] then
            array_open = "["
            array_close = "]"
        end

        for _,v in ipairs(v.children) do
            if v.kind == "table_index_value" then
                array_open = "["
                array_close = "]"
            else
                array_close = nil
                array_open = nil
                break
            end
        end

        if not v.children[1] then
            self:EmitToken(v.tokens["{"], array_open)
            self:EmitToken(v.tokens["}"], array_close)
        else
            self:EmitToken(v.tokens["{"], array_open)

            if array_open then
                self:Emit("null,")
            end

            self:Whitespace("\n")
                self:Whitespace("\t+")
                for _,v in ipairs(v.children) do
                    self:Whitespace("\t")
                    if v.kind == "table_index_value" then
                        if not array_close  then
                            self:Emit(v.key .. ": ")
                        end
                        self:EmitExpression(v.value)
                    elseif v.kind == "table_key_value" then
                        self:EmitToken(v.key)
                        self:EmitToken(v.tokens["="], ":")
                        self:EmitExpression(v.value)
                    elseif v.kind == "table_expression_value" then
                        if not array_open then
                            self:EmitToken(v.tokens["["])
                            self:Whitespace("(")
                            self:EmitExpression(v.key)
                            self:Whitespace(")")
                            self:EmitToken(v.tokens["]"])

                            self:EmitToken(v.tokens["="], ":")
                        end

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
            self:Whitespace("\t")
            self:EmitToken(v.tokens["}"], array_close)
        end
    end

    function META:EmitPrefixOperator(v)
        if operator_translate[v.value.value] then
            local name = operator_translate[v.value.value].name
            self:Emit("OH."..name.."(")
            self:EmitExpression(v.right)
            self:Emit(")")
        else
            local func_chunks = oh.syntax.GetFunctionForPrefixOperator(v.value)
            if func_chunks then
                self:Emit(func_chunks[1])
                self:EmitExpression(v.right)
                self:Emit(func_chunks[2])
                self.operator_transformed = true
            else
                if oh.syntax.IsKeyword(v.value) then
                    self:Whitespace("?")
                    self:EmitToken(v.value, token_translate[v.value.value])
                    self:Whitespace("?")
                    self:EmitExpression(v.right)
                else
                    self:EmitToken(v.value, token_translate[v.value.value])
                    self:EmitExpression(v.right)
                end
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
            if oh.syntax.IsKeyword(v.value) then
                self:EmitExpression(v.left)
                self:Whitespace("?")
                self:EmitToken(v.value)
                self:Whitespace("?")
            else
                self:EmitExpression(v.left)
                self:EmitToken(v.value)
            end
        end
    end

    function META:EmitIfStatement(node)
        for i = 1, #node.statements do
            self:Whitespace("\t")
            local what = node.tokens["if/else/elseif"][i].value
            if node.expressions[i] then
                self:EmitToken(node.tokens["if/else/elseif"][i], token_translate[what])
                self:Whitespace(" ")
                self:Emit("(")
                self:EmitExpression(node.expressions[i])
                self:Whitespace(" ")
                self:Emit(")")
                self:EmitToken(node.tokens["then"][i], token_translate["then"])
            elseif node.tokens["if/else/elseif"][i] then
                self:EmitToken(node.tokens["if/else/elseif"][i], token_translate[what])
            end
            self:Whitespace("\n")
            self:Whitespace("\t+")
            self:PushScope()
            self:EmitStatements(node.statements[i])
            self:PopScope()
            self:Whitespace("\t-")
        end
        self:Whitespace("\t")
        self:EmitToken(node.tokens["end"], token_translate["end"])
    end

    function META:EmitForStatement(node)
        self:Whitespace("\t")
        self:EmitToken(node.tokens["for"])
        self:Whitespace(" ")
        self:Emit("(")
        if node.fori then
            self:Emit("let ")
            self:EmitExpression(node.identifiers[1])
            self:Whitespace(" ")
            self:EmitToken(node.tokens["="])
            self:Whitespace(" ")
            self:EmitExpression(node.expressions[1])
            self:Emit(";")
            self:EmitExpression(node.identifiers[1])
            self:Emit("<=")
            self:EmitExpression(node.expressions[2])
            self:Emit(";")
            self:EmitExpression(node.identifiers[1])
            self:Emit("=")
            self:EmitExpression(node.identifiers[1])
            self:Emit("+")
            if node.expressions[3] then
                self:EmitExpression(node.expressions[3])
            else
                self:Emit("1")
            end
        else
            self:Emit("let [")
            self:EmitExpressionList(node.identifiers)
            self:Emit("]")
            self:Whitespace(" ")
            self:EmitToken(node.tokens["in"], token_translate["in"])
            self:Emit(" ")
            self:Whitespace(" ")
            self:EmitExpressionList(node.expressions)
        end
        self:Emit(")")

        for i,v in ipairs(node.identifiers) do
            self:SetUpvalue(v.value.value, true)
        end

        self:Whitespace(" ")
        self:EmitToken(node.tokens["do"], token_translate["do"])
        self:Whitespace("\n")
        self:Whitespace("\t+")
        self:PushScope()
        self:EmitStatements(node.statements)
        self:PopScope()
        self:Whitespace("\t-")
        self:Whitespace("\t")
        self:EmitToken(node.tokens["end"], token_translate["end"])
    end

    function META:EmitWhileStatement(node)
        self:Whitespace("\t")
        self:EmitToken(node.tokens["while"])
        self:Whitespace(" ")
        self:Emit("(")
        self:EmitExpression(node.expression)
        self:Emit(")")
        self:Whitespace(" ")
        self:EmitToken(node.tokens["do"], token_translate["do"])
        self:Whitespace("\n")
        self:Whitespace("\t+")
        self:PushScope()
        self:EmitStatements(node.statements)
        self:PopScope()
        self:Whitespace("\t-")
        self:Whitespace("\t")
        self:EmitToken(node.tokens["end"], token_translate["end"])
    end

    function META:EmitRepeatStatement(node)
        self:Whitespace("\t")
        self:EmitToken(node.tokens["repeat"], "do")
        self:Whitespace("\n")

        self:Emit("{")
        self:Whitespace("\t+")
        self:PushScope()
        self:EmitStatements(node.statements)
        self:PopScope()
        self:Whitespace("\t-")
        self:Emit("}")

        self:Whitespace("\t")
        self:EmitToken(node.tokens["until"], "while")
        self:Whitespace(" ")
        self:Emit("(")
        self:EmitExpression(node.expression)
        self:Emit(")")
    end

    do
        function META:EmitLabelStatement(node)
            self:Emit("/*")
            self:Whitespace("\t")
            self:EmitToken(node.tokens["::left"])
            self:EmitToken(node.identifier)
            self:EmitToken(node.tokens["::right"])
            self:Emit("*/")
        end

        function META:EmitGotoStatement(node)
            self:Emit("/*")
            self:Whitespace("\t")
            self:EmitToken(node.tokens["goto"])
            self:Whitespace(" ")
            self:EmitToken(node.identifier)
            self:Emit("*/")
        end
    end

    function META:EmitBreakStatement(node)
        self:Whitespace("\t")
        self:EmitToken(node.tokens["break"])
    end

    function META:EmitDoStatement(node)
        self:Whitespace("\t")
        self:EmitToken(node.tokens["do"], token_translate["do"])
        self:Whitespace("\n")

        self:Whitespace("\t+")
        self:PushScope()
        self:EmitStatements(node.statements)
        self:PopScope()
        self:Whitespace("\t-")

        self:Whitespace("\t")
        self:EmitToken(node.tokens["end"], token_translate["end"])
    end

    function META:EmitReturnStatement(node)
        self:Whitespace("\t")
        self:EmitToken(node.tokens["return"])

        if node.expressions[1] and node.expressions[1].kind == "postfix_call" then
            self:Emit(" ")
            self:EmitExpressionList(node.expressions)
        else
            self:Emit("[")
            self:Whitespace(" ")
            self:EmitExpressionList(node.expressions)
            self:Emit("]")
        end
    end

    function META:EmitSemicolonStatement(node)
        self:EmitToken(node.tokens[";"])
    end

    function META:EmitAssignment(node)
        self:Whitespace("\t")

        local global_assignment = false

        if node.is_local then
            self:EmitToken(node.tokens["local"], "let")
            self:Whitespace(" ")

            local expr = node.expressions_right or node.expressions
            local use_destructor = expr and (expr[1].kind == "postfix_call" or expr[2] or (expr[1].value and expr[1].value.value == "..."))
            if use_destructor then
                self:Emit(" [")
            end
            for i,v in ipairs(node.identifiers) do
                v.value.value = self:DeclareIdentifier(v.value.value)
            end

            self:EmitExpressionList(node.identifiers)
            if use_destructor then
                self:Emit(" ]")
            end
        else
            if node.expressions_left[1] and node.expressions_left[1].value and self:GetUpvalue(node.expressions_left[1].value.value) then
                self:EmitExpressionList(node.expressions_left)
            else
                if node.expressions_left[1] and node.expressions_left[1].value and not node.expressions_left[1].right then
                    global_assignment = true
                    self:Emit("OH.__newindex(_G, ")
                    if not node.expressions_left[1].value.transformed then
                        node.expressions_left[1].value.value = "'" .. node.expressions_left[1].value.value .. "'"
                        node.expressions_left[1].value.transformed = true
                    end
                end

                if node.expressions_left[1].right then
                    global_assignment = true

                    self:Emit("OH.__newindex(")
                    self:EmitExpression(node.expressions_left[1].left)
                    self:Emit(", ")

                    if not node.expressions_left[1].right.transformed then
                        node.expressions_left[1].right.value.value = "'" .. node.expressions_left[1].right.value.value .. "'"
                        node.expressions_left[1].right.transformed = true
                    end

                    self:EmitExpression(node.expressions_left[1].right)
                else
                    self:EmitExpressionList(node.expressions_left)
                end
            end
        end

        if node.tokens["="] then
            self:Whitespace(" ")
            if global_assignment then
                self:EmitToken(node.tokens["="], ",")
            else
                self:EmitToken(node.tokens["="])
            end
            self:Whitespace(" ")
            local expr = node.expressions_right or node.expressions
            if expr[2] then
                self:Emit(" [")
            end
            self:EmitExpressionList(expr)

            if expr[2] then
                self:Emit("]")
            end
        end

        if global_assignment then
            self:Emit(")")
        end

        if node.identifiers then
            for i,v in ipairs(node.identifiers) do
                self:SetUpvalue(v.value.value, true)
            end
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
            self:Emit(";")
        elseif node.kind == "assignment" then
            self:EmitAssignment(node)
            self:Emit(";")
        elseif node.kind == "function" then
            self:Function(node)
        elseif node.kind == "expression" then
            self:Whitespace("\t")
            self:EmitExpression(node.value)
            local flat = node.value:Flatten()
            if flat[#flat].kind == "postfix_call" then
                self:Emit(";")
            end
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
end

em:PushScope()
local js = em:BuildCode(ast)
em:PopScope()

--util.TablePrint(em.scope, {parent = "table"})
--print(js)
local f = io.open("temp.js", "w")
f:write(runtime .. js)
f:close()
--print(js)
os.execute("node temp.js")
--os.remove("temp.js")