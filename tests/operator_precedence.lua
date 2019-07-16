local oh = require("oh")

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

function dump_precedence(expr)
    local list = expand(expr, {})
    local a = table_concat(list)
    return a
end

local function check(tbl)
    for i, val in ipairs(tbl) do
        local code = "a = " .. val[1]
        local ast = assert(oh.TokensToAST(assert(oh.CodeToTokens(code)), "test " .. i, code))

        local expr = ast:FindStatementsByType("assignment")[1].right[1]
        local res = dump_precedence(expr)
        if val[2] ~= res then
            print("EXPECT: " .. val[2])
            print("GOT   : " .. res)
        end
    end
end

check {
    {'pcall(require, "ffi")', 'call(pcall, require, "ffi")'},
    {"1 / #a", "/(1, #(a))"},
    {"jit.status and jit.status()", "and(.(jit, status), call(.(jit, status)))"},
    {"a.b.c.d.e.f()", "call(.(.(.(.(.(a, b), c), d), e), f))"},
    {"(foo.bar())", "call(.(foo, bar))"},
    {[[-1^21+2+a(1,2,3)()[1]""++ ÆØÅ]], [[+(+(^(-(1), 21), 2), ÆØÅ(++(call(expression_index(call(call(a, 1, 2, 3)), 1), ""))))]]},
}