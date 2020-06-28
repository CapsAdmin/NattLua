local oh = require("oh")
local C = oh.Code

local table_insert = table.insert
local table_concat = table.concat

local function expand(node, tbl)

    if node.kind == "prefix_operator" or node.kind == "postfix_operator" then
        table_insert(tbl, node.value.value)
        table_insert(tbl, "(")
        expand(node.right or node.left, tbl)
        table_insert(tbl, ")")
        return tbl
    elseif node.kind:sub(1, #"postfix") == "postfix" then
        table_insert(tbl, node.kind:sub(#"postfix"+2))
    elseif node.kind ~= "binary_operator" then
        table_insert(tbl, node:Render())
    else
        table_insert(tbl, node.value.value)
    end

    if node.left then
        table_insert(tbl, "(")
        expand(node.left, tbl)
    end


    if node.right then
        table_insert(tbl, ", ")
        expand(node.right, tbl)
        table_insert(tbl, ")")
    end

    if node.kind:sub(1, #"postfix") == "postfix" then
        local str = {""}
        for _, exp in ipairs(node.expressions or {node.expression}) do
            table_insert(str, exp:Render())
        end
        table_insert(tbl, table_concat(str, ", "))
        table_insert(tbl, ")")
    end

    return tbl
end

local function dump_precedence(expr)
    local list = expand(expr, {})
    local a = table_concat(list)
    return a
end

local function check(tbl)
    for i, val in ipairs(tbl) do
        val[1].code = "a = " .. val[1].code
        local ast = assert(val[1]:Parse()).SyntaxTree

        local expr = ast:FindStatementsByType("assignment")[1].right[1]
        local res = dump_precedence(expr)
        if val[2] and val[2].code ~= res then
            io.write("EXPECT: " .. val[2].code, "\n")
            io.write("GOT   : " .. res, "\n")
        end
    end
end
describe("parser operator precedence", function()
    it("correct order", function()
        check {
            {C'-2 ^ 2', C'-(^(2, 2))'},
            {C'pcall(require, "ffi")', C'call(pcall, require, "ffi")'},
            {C"1 / #a", C"/(1, #(a))"},
            {C"jit.status and jit.status()", C"and(.(jit, status), call(.(jit, status)))"},
            {C"a.b.c.d.e.f()", C"call(.(.(.(.(.(a, b), c), d), e), f))"},
            {C"(foo.bar())", C"call(.(foo, bar))"},
            {C[[-1^21+2+a(1,2,3)()[1]""++ ÆØÅ]], C[[-(+(+(^(1, 21), 2), ÆØÅ(++(call(expression_index(call(call(a, 1, 2, 3)), 1), "")))))]]},
        }
    end)
end)